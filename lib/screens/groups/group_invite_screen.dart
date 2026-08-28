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
import '../../utils/group_invite_link.dart';
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
  final _quick = TextEditingController();
  bool _sending = false;
  bool _linking = false;
  bool _loadingContacts = true;
  bool _contactsAllowed = false;
  String? _inviteLink;
  String? _inviteToken;
  String? _expiresAt;
  String? _busyLocalId;

  List<ContactMatchResult> _contacts = const [];
  final Set<String> _selectedLocalIds = {};
  final Set<String> _addedLocalIds = {};

  @override
  void initState() {
    super.initState();
    _emails.addListener(() => setState(() {}));
    _phones.addListener(() => setState(() {}));
    _quick.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _emails.dispose();
    _phones.dispose();
    _search.dispose();
    _quick.dispose();
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
      final matched = await ContactsMatchService.loadMatchedContacts(
        onProgress: (partial) {
          if (!mounted) return;
          setState(() {
            _contacts = partial;
            _loadingContacts = false;
          });
        },
      );
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
        final matched = await ContactsMatchService.loadMatchedContacts(
          forceRefresh: true,
          onProgress: (partial) {
            if (!mounted) return;
            setState(() {
              _contacts = partial;
              _loadingContacts = false;
            });
          },
        );
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
    var list = q.isEmpty
        ? _contacts
        : _contacts.where((c) {
            final name = (c.user?.name ?? c.name).toLowerCase();
            final email = [
              ...c.emails,
              if (c.user?.email != null) c.user!.email,
            ].join(' ').toLowerCase();
            final phone = c.phones.join(' ').toLowerCase();
            return name.contains(q) || email.contains(q) || phone.contains(q);
          }).toList();
    // On Fendo first so friends are easy to add.
    list = [...list]..sort((a, b) {
        if (a.isAppUser == b.isAppUser) {
          return (a.user?.name ?? a.name)
              .toLowerCase()
              .compareTo((b.user?.name ?? b.name).toLowerCase());
        }
        return a.isAppUser ? -1 : 1;
      });
    return list;
  }

  List<String> get _manualEmails {
    final fromQuick = _quick.text.trim();
    final emails = <String>{
      ..._emails.text
          .split(RegExp(r'[,;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.contains('@')),
      if (fromQuick.contains('@')) fromQuick,
    };
    return emails.toList();
  }

  List<String> get _manualPhones {
    final fromQuick = _quick.text.trim();
    final digits = fromQuick.replaceAll(RegExp(r'\D'), '');
    final phones = <String>{
      ..._phones.text
          .split(RegExp(r'[,;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.replaceAll(RegExp(r'\D'), '').length >= 7),
      if (!fromQuick.contains('@') && digits.length >= 7) fromQuick,
    };
    return phones.toList();
  }

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
      emails.addAll(_emailsForContact(c));
    }
    return emails.toList();
  }

  /// Phones for contacts already on Fendo (add to group).
  List<String> get _onFendoPhones {
    final phones = <String>{};
    for (final c in _selectedOnFendo) {
      phones.addAll(_phonesForContact(c));
    }
    return phones.toList();
  }

  bool get _hasPendingInviteAction =>
      _selectedLocalIds.isNotEmpty ||
      _manualEmails.isNotEmpty ||
      _manualPhones.isNotEmpty;

  List<String> _emailsForContact(ContactMatchResult c) {
    final emails = <String>{};
    final fromUser = c.user?.email.trim();
    if (fromUser != null && fromUser.contains('@')) emails.add(fromUser);
    for (final e in c.emails) {
      final t = e.trim();
      if (t.contains('@')) emails.add(t);
    }
    return emails.toList();
  }

  List<String> _phonesForContact(ContactMatchResult c) {
    final phones = <String>{};
    final fromUser = c.user?.phone?.trim();
    if (fromUser != null && fromUser.isNotEmpty) phones.add(fromUser);
    for (final p in c.phones) {
      final t = p.trim();
      if (t.isNotEmpty) phones.add(t);
    }
    return phones.toList();
  }

  void _toggleContact(ContactMatchResult c) {
    final hasEmail = _emailsForContact(c).isNotEmpty;
    final hasPhone = _phonesForContact(c).isNotEmpty;
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

  /// One tap:
  /// 1) Try API with phone/email → if on Fendo, add to group directly.
  /// 2) If not on Fendo, open share message that includes their number.
  Future<void> _oneTapContact(ContactMatchResult c) async {
    if (_busyLocalId != null || _sending) return;
    if (_addedLocalIds.contains(c.localId)) {
      showApiMessage(context, 'Already added');
      return;
    }

    final emails = _emailsForContact(c);
    final phones = _phonesForContact(c);
    final displayName = c.user?.name ?? c.name;
    if (emails.isEmpty && phones.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'This contact needs a mobile number or email'),
      );
      return;
    }

    setState(() => _busyLocalId = c.localId);
    try {
      // Always check server: contact match can miss app users.
      final result = await GroupsController.instance.inviteContacts(
        widget.groupId,
        emails: emails,
        phones: phones,
      );
      if (!mounted) return;

      if (result.addedCount > 0) {
        setState(() => _addedLocalIds.add(c.localId));
        showApiMessage(context, 'Added $displayName to the group');
        return;
      }
      if (result.alreadyMembers.isNotEmpty) {
        setState(() => _addedLocalIds.add(c.localId));
        showApiMessage(context, 'Already in group');
        return;
      }

      // Not on Fendo (or number not registered) → share invite with number.
      final link = await _ensureInviteLink();
      if (!mounted) return;
      setState(() => _addedLocalIds.add(c.localId));
      await _showInviteLinkSheet(
        link: link,
        names: displayName.trim().isEmpty ? const [] : [displayName],
        phones: phones,
        emails: emails,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Validation / not found → treat as invite needed.
      if (e.isValidation) {
        final link = await _ensureInviteLink();
        if (!mounted) return;
        setState(() => _addedLocalIds.add(c.localId));
        await _showInviteLinkSheet(
          link: link,
          names: displayName.trim().isEmpty ? const [] : [displayName],
          phones: phones,
          emails: emails,
        );
      } else {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busyLocalId = null);
    }
  }

  /// Type phone or email:
  /// - On Fendo → added directly
  /// - Not on Fendo → invite message with that mobile/email
  Future<void> _quickAdd() async {
    final emails = _manualEmails;
    final phones = _manualPhones;
    if (emails.isEmpty && phones.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'Enter a mobile number or email'),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      var added = 0;
      var already = 0;
      var needInvite = false;
      try {
        final result = await GroupsController.instance.inviteContacts(
          widget.groupId,
          emails: emails,
          phones: phones,
        );
        added = result.addedCount;
        already = result.alreadyMembers.length;
        // If nothing added/already, or server listed not_found → invite.
        needInvite = result.notFound.isNotEmpty ||
            (added == 0 && already == 0);
      } on ApiException catch (e) {
        if (e.isValidation) {
          needInvite = true;
        } else {
          rethrow;
        }
      }
      if (!mounted) return;

      if (added > 0) {
        showApiMessage(
          context,
          added == 1
              ? 'Added directly (uses Fendo)'
              : 'Added $added people directly (use Fendo)',
        );
      }
      if (already > 0 && added == 0) {
        showApiMessage(context, 'Already in group');
      }

      if (needInvite && added == 0 && already == 0) {
        final link = await _ensureInviteLink();
        if (!mounted) return;
        await _showInviteLinkSheet(
          link: link,
          names: const [],
          phones: phones,
          emails: emails,
        );
      } else if (needInvite && (added > 0 || already > 0)) {
        // Partial: some on app, some not.
        final link = await _ensureInviteLink();
        if (!mounted) return;
        await _showInviteLinkSheet(
          link: link,
          names: const [],
          phones: phones,
          emails: emails,
        );
      }

      setState(() {
        _quick.clear();
        _emails.clear();
        _phones.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  String get _shareClipboard {
    final token = _inviteToken ?? GroupInviteLink.extractToken(_inviteLink ?? '');
    return GroupInviteLink.shareMessage(
      token: token,
      inviteLink: _inviteLink,
    );
  }

  Future<void> _showInviteLinkSheet({
    required String link,
    List<String> names = const [],
    List<String> phones = const [],
    List<String> emails = const [],
  }) async {
    if (!mounted) return;
    final shareText = GroupInviteLink.shareMessage(
      token: '',
      inviteLink: link,
    );
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
                'Invite friend',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Copy includes Invite code: … plus download steps. Share via WhatsApp / SMS.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                shareText,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Copy invite message',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: shareText));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  showApiMessage(context, 'Invite message copied');
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

      // Selected contacts not match-marked as app users: still try API
      // (match can be wrong), then collect phones for invite message.
      for (final c in _selectedNeedInvite) {
        for (final e in _emailsForContact(c)) {
          addEmails.add(e);
        }
        for (final p in _phonesForContact(c)) {
          addPhones.add(p);
        }
      }

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
                needInviteLookup.addAll(addPhones);
              }
            } else if (addPhones.isNotEmpty) {
              needInviteNames.addAll(addPhones);
              needInviteLookup.addAll(addPhones);
            }
          } else {
            rethrow;
          }
        }
      }

      // Who still needs an outside invite (include phone in share message).
      final invitePhones = <String>{
        for (final c in _selectedNeedInvite) ..._phonesForContact(c),
        ..._manualPhones,
        ...needInviteLookup.where((s) {
          final digits = s.replaceAll(RegExp(r'\D'), '');
          return !s.contains('@') && digits.length >= 7;
        }),
      };
      final inviteEmails = <String>{
        for (final c in _selectedNeedInvite) ..._emailsForContact(c),
        ..._manualEmails,
        ...needInviteLookup.where((s) => s.contains('@')),
      };
      // Share only when someone wasn't found / not on Fendo.
      final shouldShare = needInviteLookup.isNotEmpty ||
          (added == 0 &&
              already == 0 &&
              (_selectedNeedInvite.isNotEmpty ||
                  invitePhones.isNotEmpty ||
                  inviteEmails.isNotEmpty));

      if (!mounted) return;
      final parts = <String>[];
      if (added > 0) parts.add('$added added directly');
      if (already > 0) parts.add('$already already in group');
      if (shouldShare) parts.add('share invite for rest');

      if (parts.isNotEmpty) {
        showApiMessage(context, parts.join(' · '));
      }

      if (shouldShare) {
        final link = await _ensureInviteLink();
        final uniqueNames = <String>{
          ..._selectedNeedInvite.map((c) => c.user?.name ?? c.name),
        }.toList();
        await _showInviteLinkSheet(
          link: link,
          names: uniqueNames,
          phones: invitePhones.toList(),
          emails: inviteEmails.toList(),
        );
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
              title: 'Add friends',
              subtitle: 'Quick add or link first · contacts at the bottom',
              onBack: () => Navigator.pop(context),
            ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                    // 1) Quick add first
                    Text(
                      'Quick add',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type mobile or email. On Fendo → added now. Else → download message.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AuthTextField(
                            controller: _quick,
                            label: 'Phone or email',
                            hint: '+8801… or name@mail.com',
                            keyboardType: TextInputType.text,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _sending ? null : _quickAdd,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.mint,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Add',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 2) Invite link
                    const SizedBox(height: 28),
                    Text(
                      'Invite link (optional)',
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
                              'Create a code to share. Friends: download Fendo and register.',
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                              ),
                            )
                          else ...[
                            Text(
                              'Invite code',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SelectableText(
                              _inviteToken ??
                                  GroupInviteLink.extractToken(_inviteLink!),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              _inviteLink!,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                                fontSize: 13,
                              ),
                            ),
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
                                  ClipboardData(text: _shareClipboard),
                                );
                                if (!context.mounted) return;
                                showApiMessage(context, 'Invite message copied');
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy invite message'),
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

                    // 3) Contacts last
                    const SizedBox(height: 28),
                    Text(
                      'Phone contacts',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add = join if on Fendo. Invite = download & register.',
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
                      if (_filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No contacts matched your search.',
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ..._filtered.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InviteContactTile(
                            contact: c,
                            selected: _selectedLocalIds.contains(c.localId),
                            added: _addedLocalIds.contains(c.localId),
                            busy: _busyLocalId == c.localId,
                            onTap: () => _toggleContact(c),
                            onAction: () => _oneTapContact(c),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
              if (_selectedLocalIds.isNotEmpty)
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
                        if (inviteN > 0 && addN == 0) {
                          return 'Invite $inviteN selected';
                        }
                        if (inviteN > 0) {
                          return 'Add $addN · Invite $inviteN';
                        }
                        return 'Add ${_selectedLocalIds.length} selected';
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
    required this.added,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });

  final ContactMatchResult contact;
  final bool selected;
  final bool added;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAction;

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
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected || added
                  ? AppColors.mint.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.7),
              width: selected || added ? 1.6 : 1,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: canInvite
                              ? AppColors.textMuted
                              : AppColors.coral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (added)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'Added',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mintDim,
                    ),
                  ),
                )
              else
                FilledButton(
                  onPressed: !canInvite || busy ? null : onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        onApp ? AppColors.mint : AppColors.forest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.border.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          onApp ? 'Add' : 'Invite',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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

