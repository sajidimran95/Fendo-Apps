import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/app_prefs.dart';
import '../../models/contact_match_model.dart';
import '../../services/contacts_match_service.dart';
import '../../services/loans_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import 'contacts_permission_screen.dart';

/// Create Loan — contacts matched via POST /contacts/match.
/// Contacts permission is asked once after first login (MainShell).
class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

enum _LoanStep { permission, contacts, details }

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  _LoanStep _step = _LoanStep.contacts;
  bool _booting = true;
  bool _matching = false;
  bool _saving = false;
  String _query = '';
  ContactMatchResult? _selected;
  LoanDirection _direction = LoanDirection.give;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<ContactMatchResult> _contacts = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final allowed = await AppPrefs.instance.contactsAllowed;
    if (!mounted) return;
    if (allowed) {
      setState(() {
        _step = _LoanStep.contacts;
        _booting = false;
        _matching = true;
      });
      await _loadMatchedContacts();
    } else {
      setState(() {
        _step = _LoanStep.permission;
        _booting = false;
      });
    }
  }

  Future<void> _loadMatchedContacts() async {
    try {
      final matched = await ContactsMatchService.loadMatchedContacts();
      if (!mounted) return;
      setState(() {
        _contacts = matched;
        _matching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _matching = false);
      showApiError(context, e);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _allowContacts() async {
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
      _matching = true;
      _step = _LoanStep.contacts;
    });
    await _loadMatchedContacts();
  }

  Future<void> _skipPermission() async {
    await AppPrefs.instance.setContactsAllowed(false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  List<ContactMatchResult> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) {
      final name = c.name.toLowerCase();
      final userName = c.user?.name.toLowerCase() ?? '';
      final phone = c.phones.join(' ').toLowerCase();
      return name.contains(q) || userName.contains(q) || phone.contains(q);
    }).toList();
  }

  void _pickContact(ContactMatchResult c) {
    setState(() => _selected = c);
  }

  void _continueWithSelected() {
    final c = _selected;
    if (c == null) {
      showApiError(context, ApiException(message: 'Select a contact'));
      return;
    }
    if (!c.isAppUser || c.user == null) {
      showApiError(
        context,
        ApiException(
          message: 'Only On Fendo contacts can be saved to the server',
        ),
      );
      return;
    }
    setState(() => _step = _LoanStep.details);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }
    if (_selected == null) {
      showApiError(context, ApiException(message: 'Select a contact'));
      return;
    }
    final user = _selected!.user;
    if (user == null || !(_selected!.isAppUser)) {
      showApiError(
        context,
        ApiException(
          message: 'Only On Fendo contacts can be saved to the server',
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final personName = user.name.trim().isNotEmpty
          ? user.name.trim()
          : _selected!.name;
      await LoansController.instance.createLoan(
        personName: personName,
        amount: amount,
        direction: _direction,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        counterpartyUserId: user.id,
        counterpartyEmail: user.email,
      );
      if (!mounted) return;
      showApiMessage(
        context,
        _direction == LoanDirection.give
            ? 'Loan saved — you lent \$${amount.toStringAsFixed(2)}'
            : 'Loan saved — you borrowed \$${amount.toStringAsFixed(2)}',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mint),
        ),
      );
    }

    if (_step == _LoanStep.permission) {
      return ContactsPermissionScreen(
        onAllow: _allowContacts,
        onSkip: _skipPermission,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Create loan',
                subtitle: _step == _LoanStep.contacts
                    ? 'Who is this loan with?'
                    : 'Give or take',
                onBack: () {
                  if (_step == _LoanStep.details) {
                    setState(() => _step = _LoanStep.contacts);
                    return;
                  }
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _step == _LoanStep.contacts
                      ? _ContactsStep(
                          key: const ValueKey('contacts'),
                          matching: _matching,
                          contacts: _filtered,
                          query: _query,
                          selected: _selected,
                          onQuery: (v) => setState(() => _query = v),
                          onSelect: _pickContact,
                          onContinue: _continueWithSelected,
                        )
                      : _DetailsStep(
                          key: const ValueKey('details'),
                          contact: _selected!,
                          direction: _direction,
                          amount: _amount,
                          note: _note,
                          saving: _saving,
                          onDirection: (d) =>
                              setState(() => _direction = d),
                          onSave: _save,
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

class _ContactsStep extends StatelessWidget {
  const _ContactsStep({
    super.key,
    required this.matching,
    required this.contacts,
    required this.query,
    required this.selected,
    required this.onQuery,
    required this.onSelect,
    required this.onContinue,
  });

  final bool matching;
  final List<ContactMatchResult> contacts;
  final String query;
  final ContactMatchResult? selected;
  final ValueChanged<String> onQuery;
  final ValueChanged<ContactMatchResult> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (matching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.mint),
            SizedBox(height: 14),
            Text('Matching contacts…'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = contacts[i];
              return _ContactTile(
                contact: c,
                selected: selected?.localId == c.localId,
                onTap: () => onSelect(c),
              );
            },
          ),
        ),
        if (selected != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AuthPrimaryButton(
                label: 'Continue with ${selected!.user?.name ?? selected!.name}',
                onPressed: onContinue,
              ),
            ),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
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
    final subtitle = contact.phones.isNotEmpty
        ? contact.phones.first
        : (contact.emails.isNotEmpty
            ? contact.emails.first
            : (contact.user?.email ?? ''));
    final initial = display.isNotEmpty ? display[0].toUpperCase() : '?';

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
                radius: 22,
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
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onApp)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.mintWash,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'On Fendo',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mintDim,
                    ),
                  ),
                ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? AppColors.mint : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    super.key,
    required this.contact,
    required this.direction,
    required this.amount,
    required this.note,
    required this.saving,
    required this.onDirection,
    required this.onSave,
  });

  final ContactMatchResult contact;
  final LoanDirection direction;
  final TextEditingController amount;
  final TextEditingController note;
  final bool saving;
  final ValueChanged<LoanDirection> onDirection;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final name = contact.user?.name ?? contact.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        SoftTile(
          margin: EdgeInsets.zero,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.mintWash,
                child: Text(
                  name[0].toUpperCase(),
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mint,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.forest,
                      ),
                    ),
                    Text(
                      contact.isAppUser
                          ? 'On Fendo · ${contact.user?.email ?? ''}'
                          : (contact.phones.isNotEmpty
                              ? contact.phones.first
                              : (contact.emails.isNotEmpty
                                  ? contact.emails.first
                                  : 'Phone contact')),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Direction',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.forestSoft,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DirectionPill(
                label: 'Give',
                subtitle: 'You lent money',
                icon: Icons.north_east_rounded,
                selected: direction == LoanDirection.give,
                onTap: () => onDirection(LoanDirection.give),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DirectionPill(
                label: 'Take',
                subtitle: 'You borrowed',
                icon: Icons.south_west_rounded,
                selected: direction == LoanDirection.take,
                onTap: () => onDirection(LoanDirection.take),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AuthTextField(
          controller: amount,
          label: 'Amount',
          hint: '40.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: note,
          label: 'Note',
          hint: 'optional',
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: direction == LoanDirection.give
              ? 'Save loan (give)'
              : 'Save loan (take)',
          loading: saving,
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}

class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.mint : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.mint,
                size: 22,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
