import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/app_prefs.dart';
import '../../models/contact_match_model.dart';
import '../../services/contacts_match_service.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import '../loans/contacts_permission_screen.dart';

class GroupInviteScreen extends StatefulWidget {
  const GroupInviteScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  final _emails = TextEditingController();
  final _phones = TextEditingController();
  final _search = TextEditingController();
  bool _sending = false;
  bool _linking = false;
  bool _loadingContacts = true;
  bool _contactsAllowed = false;
  String? _inviteLink;
  String? _inviteToken;
  String? _expiresAt;

  List<ContactMatchResult> _contacts = const [];
  final Set<String> _selectedLocalIds = {};

  @override
  void initState() {
    super.initState();
    _emails.addListener(() => setState(() {}));
    _phones.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _emails.dispose();
    _phones.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final allowed = await AppPrefs.instance.contactsAllowed;
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _contactsAllowed = false;
        _loadingContacts = false;
      });
      return;
    }
    setState(() {
      _contactsAllowed = true;
      _loadingContacts = true;
    });
    try {
      final matched = await ContactsMatchService.loadMatchedContacts();
      if (!mounted) return;
      setState(() {
        _contacts = matched;
        _loadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContacts = false);
    }
  }

  Future<void> _enableContacts() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContactsPermissionScreen(
          onAllow: () => Navigator.pop(context, true),
          onSkip: () => Navigator.pop(context, false),
        ),
      ),
    );
    if (result == true) {
      final granted = await ContactsMatchService.requestPermission();
      await AppPrefs.instance.setContactsAllowed(granted);
      if (!mounted) return;
      if (!granted) {
        showApiError(
          context,
          ApiException(message: 'Contacts permission denied'),
        );
        return;
      }
      setState(() {
        _contactsAllowed = true;
        _loadingContacts = true;
      });
      try {
        final matched = await ContactsMatchService.loadMatchedContacts();
        if (!mounted) return;
        setState(() {
          _contacts = matched;
          _loadingContacts = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _loadingContacts = false);
        showApiError(context, e);
      }
    } else if (result == false) {
      await AppPrefs.instance.setContactsAllowed(false);
    }
  }

  List<ContactMatchResult> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) {
      final name = (c.user?.name ?? c.name).toLowerCase();
      final email = [
        ...c.emails,
        if (c.user?.email != null) c.user!.email,
      ].join(' ').toLowerCase();
      final phone = c.phones.join(' ').toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  List<String> get _manualEmails => _emails.text
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.contains('@'))
      .toList();

  List<String> get _manualPhones => _phones.text
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.replaceAll(RegExp(r'\D'), '').length >= 7)
      .toList();

  List<ContactMatchResult> get _selectedContacts => _contacts
      .where((c) => _selectedLocalIds.contains(c.localId))
      .toList();

  List<ContactMatchResult> get _selectedOnFendo =>
      _selectedContacts.where((c) => c.isAppUser).toList();

  List<ContactMatchResult> get _selectedNeedInvite =>
      _selectedContacts.where((c) => !c.isAppUser).toList();

  /// Emails for contacts already on Fendo (add to group).
  List<String> get _onFendoEmails {
    final emails = <String>{};
    for (final c in _selectedOnFendo) {
      final fromUser = c.user?.email.trim();
      if (fromUser != null && fromUser.contains('@')) {
        emails.add(fromUser);
        continue;
      }
      for (final e in c.emails) {
        final t = e.trim();
        if (t.contains('@')) emails.add(t);
      }
    }
    return emails.toList();
  }

  /// Phones for contacts already on Fendo (add to group).
  List<String> get _onFendoPhones {
    final phones = <String>{};
    for (final c in _selectedOnFendo) {
      final fromUser = c.user?.phone?.trim();
      if (fromUser != null && fromUser.isNotEmpty) {
        phones.add(fromUser);
      }
      for (final p in c.phones) {
        final t = p.trim();
        if (t.isNotEmpty) phones.add(t);
      }
    }
    return phones.toList();
  }

  bool get _hasPendingInviteAction =>
      _selectedLocalIds.isNotEmpty ||
      _manualEmails.isNotEmpty ||
      _manualPhones.isNotEmpty;

  void _toggleContact(ContactMatchResult c) {
    final hasEmail = c.emails.any((e) => e.contains('@')) ||
        (c.user?.email.contains('@') ?? false);
    final hasPhone = c.phones.any((p) => p.trim().isNotEmpty) ||
        ((c.user?.phone ?? '').trim().isNotEmpty);
    if (!c.isAppUser && !hasEmail && !hasPhone) {
      showApiError(
        context,
        ApiException(message: 'This contact needs an email or phone to invite'),
      );
      return;
    }
    setState(() {
      if (_selectedLocalIds.contains(c.localId)) {
        _selectedLocalIds.remove(c.localId);
      } else {
        _selectedLocalIds.add(c.localId);
      }
    });
  }

  Future<String> _ensureInviteLink() async {
    if (_inviteLink != null && _inviteLink!.isNotEmpty) return _inviteLink!;
    final link =
        await GroupsController.instance.createInviteLink(widget.groupId);
    if (!mounted) return link.inviteLink;
    setState(() {
      _inviteLink = link.inviteLink;
      _inviteToken = link.inviteToken;
      _expiresAt = link.expiresAt;
    });
    return link.inviteLink;
  }

  Future<void> _showInviteLinkSheet({
    required String link,
    required List<String> names,
  }) async {
    if (!mounted) return;
    final namesLabel = names.isEmpty
        ? 'people not on Fendo yet'
        : names.take(4).join(', ') + (names.length > 4 ? '…' : '');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite to Fendo',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this link with $namesLabel so they can join the group.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                link,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Copy invite link',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  showApiMessage(this.context, 'Invite link copied');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendInvites() async {
    if (!_hasPendingInviteAction) {
      showApiError(
        context,
        ApiException(
          message: 'Select contacts or enter email / mobile number',
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      var added = 0;
      var already = 0;
      final needInviteNames = <String>[
        ..._selectedNeedInvite.map((c) => c.user?.name ?? c.name),
      ];
      final needInviteLookup = <String>{};

      // 1) Add people already on Fendo (email + phone).
      final addEmails = <String>{..._onFendoEmails};
      final addPhones = <String>{..._onFendoPhones};

      // Manual entries: try add first; failures become invite-needed.
      addEmails.addAll(_manualEmails);
      addPhones.addAll(_manualPhones);

      if (addEmails.isNotEmpty || addPhones.isNotEmpty) {
        try {
          final result = await GroupsController.instance.inviteContacts(
            widget.groupId,
            emails: addEmails.toList(),
            phones: addPhones.toList(),
          );
          added += result.addedCount;
          already += result.alreadyMembers.length;
          for (final miss in result.notFound) {
            needInviteLookup.add(miss);
            needInviteNames.add(miss);
          }
        } on ApiException catch (e) {
          // Email invite rejects non-registered emails with 422.
          if (e.isValidation) {
            needInviteNames.addAll(_manualEmails);
            needInviteLookup.addAll(_manualEmails);
            // Still try phones alone if email batch failed entirely.
            if (addPhones.isNotEmpty && addEmails.isNotEmpty) {
              try {
                final phoneOnly =
                    await GroupsController.instance.inviteByPhone(
                  widget.groupId,
                  phones: addPhones.toList(),
                );
                added += phoneOnly.addedCount;
                already += phoneOnly.alreadyMembers.length;
                for (final miss in phoneOnly.notFound) {
                  needInviteLookup.add(miss);
                  needInviteNames.add(miss);
                }
              } on ApiException {
                needInviteNames.addAll(addPhones);
              }
            } else if (addPhones.isNotEmpty) {
              needInviteNames.addAll(addPhones);
            }
          } else {
            rethrow;
          }
        }
      }

      // Selected non-users always get invite link option.
      final shouldOfferInvite =
          needInviteNames.isNotEmpty || _selectedNeedInvite.isNotEmpty;

      if (!mounted) return;
      final parts = <String>[];
      if (added > 0) parts.add('$added added');
      if (already > 0) parts.add('$already already members');
      if (shouldOfferInvite) {
        parts.add(
          '${_selectedNeedInvite.length + needInviteLookup.length} need invite',
        );
      }

      if (parts.isNotEmpty) {
        showApiMessage(context, parts.join(' · '));
      }

      if (shouldOfferInvite) {
        final link = await _ensureInviteLink();
        final uniqueNames = <String>{
          ..._selectedNeedInvite.map((c) => c.user?.name ?? c.name),
          ...needInviteLookup,
        }.toList();
        await _showInviteLinkSheet(link: link, names: uniqueNames);
      } else if (parts.isEmpty) {
        showApiMessage(context, 'Invite finished');
      }

      setState(() {
        _emails.clear();
        _phones.clear();
        _selectedLocalIds.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _createLink() async {
    setState(() => _linking = true);
    try {
      final link =
          await GroupsController.instance.createInviteLink(widget.groupId);
      if (!mounted) return;
      setState(() {
        _inviteLink = link.inviteLink;
        _inviteToken = link.inviteToken;
        _expiresAt = link.expiresAt;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Invite',
                subtitle: 'Email, link, or contacts',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Text(
                      'Add by email or mobile',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'On Fendo accounts are added to the group. Others get an invite link.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AuthTextField(
                      controller: _emails,
                      label: 'Emails',
                      hint: 'a@mail.com, b@mail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      controller: _phones,
                      label: 'Mobile numbers',
                      hint: '+1 555 123 4567',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Invite link',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SoftTile(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_inviteLink == null)
                            Text(
                              'Generate a link others can use to join.',
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                              ),
                            )
                          else ...[
                            SelectableText(
                              _inviteLink!,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                            if (_inviteToken != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Token: $_inviteToken',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            if (_expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Expires: $_expiresAt',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _inviteLink!),
                                );
                                if (!context.mounted) return;
                                showApiMessage(context, 'Link copied');
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy link'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          AuthPrimaryButton(
                            label: _inviteLink == null
                                ? 'Create invite link'
                                : 'Refresh link',
                            loading: _linking,
                            onPressed: _linking ? null : _createLink,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'From contacts',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select anyone — On Fendo are added, others get an invite option.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingContacts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mint,
                          ),
                        ),
                      )
                    else if (!_contactsAllowed)
                      _ContactsLocked(onEnable: _enableContacts)
                    else ...[
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search contacts',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_selectedLocalIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '${_selectedOnFendo.length} add · ${_selectedNeedInvite.length} invite',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mintDim,
                            ),
                          ),
                        ),
                      ..._filtered.map((c) {
                        final selected =
                            _selectedLocalIds.contains(c.localId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InviteContactTile(
                            contact: c,
                            selected: selected,
                            onTap: () => _toggleContact(c),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              if (_hasPendingInviteAction)
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: AuthPrimaryButton(
                      label: () {
                        final inviteN = _selectedNeedInvite.length;
                        final addN = _selectedOnFendo.length;
                        if (_selectedLocalIds.isEmpty &&
                            (_manualEmails.isNotEmpty ||
                                _manualPhones.isNotEmpty)) {
                          return 'Add / invite';
                        }
                        if (inviteN > 0 && addN == 0) {
                          return 'Invite $inviteN contact${inviteN == 1 ? '' : 's'}';
                        }
                        if (inviteN > 0) {
                          return 'Add $addN · Invite $inviteN';
                        }
                        final n = _selectedLocalIds.isEmpty
                            ? (_manualEmails.length + _manualPhones.length)
                            : _selectedLocalIds.length;
                        return 'Add $n contact${n == 1 ? '' : 's'}';
                      }(),
                      loading: _sending,
                      onPressed: _sending ? null : _sendInvites,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactsLocked extends StatelessWidget {
  const _ContactsLocked({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contacts not enabled',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Allow contacts to pick people from your phonebook.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: 'Allow contacts',
            onPressed: onEnable,
          ),
        ],
      ),
    );
  }
}

class _InviteContactTile extends StatelessWidget {
  const _InviteContactTile({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  final ContactMatchResult contact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onApp = contact.isAppUser;
    final display = contact.user?.name ?? contact.name;
    final email = contact.user?.email ??
        (contact.emails.isNotEmpty ? contact.emails.first : null);
    final phone = contact.phones.isNotEmpty ? contact.phones.first : null;
    final subtitle = email ?? phone ?? '';
    final initial = display.isNotEmpty ? display[0].toUpperCase() : '?';
    final hasEmail = email != null && email.contains('@');
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    final canInvite = hasEmail || hasPhone || onApp;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.mint.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.7),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    onApp ? AppColors.mintWash : AppColors.surfaceMuted,
                child: Text(
                  initial,
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700,
                    color: onApp ? AppColors.mint : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.forest,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: canInvite
                              ? AppColors.textMuted
                              : AppColors.coral,
                        ),
                      ),
                    ],
                    if (!canInvite)
                      Text(
                        'Needs email or phone to invite',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.coral,
                        ),
                      )
                    else if (!hasEmail && hasPhone)
                      Text(
                        'Invite by phone',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.mintDim,
                        ),
                      ),
                  ],
                ),
              ),
              if (onApp)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mintWash,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'On Fendo',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mintDim,
                      ),
                    ),
                  ),
                )
              else if (canInvite)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Invite',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.mint : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.mint : AppColors.border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
