import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/app_prefs.dart';
import '../../data/mock_loans.dart';
import '../../models/contact_match_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _emails.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final allowed = await AppPrefs.instance.contactsAllowed;
    if (!mounted) return;
    setState(() {
      _contactsAllowed = allowed;
      _loadingContacts = false;
      if (allowed) {
        _contacts = MockLoans.matchedContacts;
      }
    });
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
      await AppPrefs.instance.setContactsAllowed(true);
      if (!mounted) return;
      setState(() {
        _contactsAllowed = true;
        _contacts = MockLoans.matchedContacts;
      });
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

  List<String> get _contactEmails {
    final emails = <String>{};
    for (final c in _contacts) {
      if (!_selectedLocalIds.contains(c.localId)) continue;
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

  List<String> get _allInviteEmails {
    final set = <String>{..._manualEmails, ..._contactEmails};
    return set.toList();
  }

  void _toggleContact(ContactMatchResult c) {
    setState(() {
      if (_selectedLocalIds.contains(c.localId)) {
        _selectedLocalIds.remove(c.localId);
      } else {
        _selectedLocalIds.add(c.localId);
      }
    });
  }

  Future<void> _sendInvites() async {
    final emails = _allInviteEmails;
    if (emails.isEmpty) {
      showApiError(
        context,
        ApiException(
          message: 'Select contacts with email or type emails below',
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await GroupsController.instance.inviteByEmail(
        widget.groupId,
        emails: emails,
      );
      if (!mounted) return;
      showApiMessage(context, 'Invites sent to ${emails.length} people');
      setState(() {
        _emails.clear();
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
                      'Invite by email',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AuthTextField(
                      controller: _emails,
                      label: 'Emails',
                      hint: 'a@mail.com, b@mail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    AuthPrimaryButton(
                      label: 'Send invites',
                      loading: _sending,
                      onPressed: _sending ? null : _sendInvites,
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
                      'Select people to invite by email match',
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
                            '${_selectedLocalIds.length} selected'
                            '${_contactEmails.isNotEmpty ? ' · ${_contactEmails.length} with email' : ''}',
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
                  ],
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
                          color: hasEmail
                              ? AppColors.textMuted
                              : AppColors.coral,
                        ),
                      ),
                    ],
                    if (!hasEmail)
                      Text(
                        'No email — add manually to invite',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.coral,
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
