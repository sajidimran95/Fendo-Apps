import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_member.dart';
import '../../models/group_model.dart';
import '../../models/settlement_model.dart';
import '../../services/auth_controller.dart';
import '../../services/groups_controller.dart';
import '../../services/settlements_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class RecordSettlementScreen extends StatefulWidget {
  const RecordSettlementScreen({super.key});

  @override
  State<RecordSettlementScreen> createState() => _RecordSettlementScreenState();
}

class _RecordSettlementScreenState extends State<RecordSettlementScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _currencyCode = 'USD';
  String _method = 'venmo';
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _booting = true;

  List<GroupModel> _groups = const [];
  GroupModel? _group;
  List<GroupMember> _members = const [];
  GroupMember? _payee;

  String get _profileCurrency {
    final c = AuthController.instance.user?.currency.trim() ?? '';
    return c.isEmpty ? 'USD' : c.toUpperCase();
  }

  String _currencyFor(GroupModel? group) {
    final groupCode = group?.currency.trim() ?? '';
    if (groupCode.isNotEmpty) return groupCode.toUpperCase();
    return _profileCurrency;
  }

  @override
  void initState() {
    super.initState();
    _currencyCode = _profileCurrency;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await GroupsController.instance.loadGroups();
    if (!mounted) return;
    final groups = GroupsController.instance.groups;
    final selected = groups.isNotEmpty ? groups.first : null;
    setState(() {
      _groups = groups;
      _group = selected;
      _currencyCode = _currencyFor(selected);
      _booting = false;
    });
    if (selected != null) await _loadMembers(selected.id);
  }

  Future<void> _loadMembers(int groupId) async {
    final members = await GroupsController.instance.getMembers(groupId);
    if (!mounted) return;
    final me = AuthController.instance.user?.id ?? 1;
    final others =
        members.where((m) => m.userId != me && m.userId > 0).toList();
    setState(() {
      _members = others;
      _payee = others.isNotEmpty ? others.first : null;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prettyDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _save() async {
    if (_group == null) {
      showApiError(context, ApiException(message: 'Select a group'));
      return;
    }
    if (_payee == null) {
      showApiError(context, ApiException(message: 'Select a payee'));
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }

    setState(() => _loading = true);
    try {
      await SettlementsController.instance.createSettlement(
        payeeId: _payee!.userId,
        groupId: _group!.id,
        amount: amount,
        currency: _currencyCode,
        paymentMethod: _method,
        paymentReference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        settlementDate: _fmt(_date),
        payeeName: _payee!.name,
        groupName: _group!.name,
      );
      if (!mounted) return;
      showApiMessage(context, 'Settlement recorded');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroWash),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Settle up',
                subtitle: 'Record a payment',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    const _FieldLabel('Group'),
                    const SizedBox(height: 8),
                    if (_groups.isEmpty)
                      const _EmptyGroupHint()
                    else
                      _GroupPicker(
                        groups: _groups,
                        selected: _group,
                        onChanged: (g) async {
                          setState(() {
                            _group = g;
                            _currencyCode = _currencyFor(g);
                            _payee = null;
                            _members = const [];
                          });
                          await _loadMembers(g.id);
                        },
                      ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Payee',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        const Spacer(),
                        if (_payee != null)
                          Text(
                            'Paying ${_payee!.name.split(' ').first}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_members.isEmpty)
                      Text(
                        _group == null
                            ? 'Pick a group first'
                            : 'No other members in this group',
                        style:
                            GoogleFonts.manrope(color: AppColors.textMuted),
                      )
                    else
                      ..._members.map((m) {
                        final active = _payee?.userId == m.userId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PayeeCard(
                            name: m.name,
                            email: m.email,
                            active: active,
                            onTap: () => setState(() => _payee = m),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _amount,
                      label: 'Amount',
                      hint: '45.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Currency'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintWash,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _currencyCode,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel('Payment method'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kSettlementPaymentMethods.map((m) {
                        final selected = _method == m;
                        return ChoiceChip(
                          label: Text(
                            m.replaceAll('_', ' '),
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _method = m),
                          selectedColor: AppColors.mintWash,
                          backgroundColor: AppColors.surface,
                          showCheckmark: false,
                          side: BorderSide(
                            color:
                                selected ? AppColors.mint : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _reference,
                      label: 'Payment reference',
                      hint: 'optional',
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _notes,
                      label: 'Notes',
                      hint: 'optional',
                    ),
                    const SizedBox(height: 14),
                    _DateTile(
                      label: 'Settlement date',
                      value: _prettyDate(_date),
                      icon: Icons.event_rounded,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                                    primary: AppColors.mint,
                                    onPrimary: Colors.white,
                                    surface: AppColors.surface,
                                  ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Record settlement',
                      loading: _loading,
                      onPressed: _loading ? null : _save,
                    ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.forestSoft,
        letterSpacing: 0.15,
      ),
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  final List<GroupModel> groups;
  final GroupModel? selected;
  final ValueChanged<GroupModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final g = groups[i];
          final active = selected?.id == g.id;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: Material(
              color: active ? AppColors.mint : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onChanged(g),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? AppColors.mint : AppColors.border,
                    ),
                  ),
                  child: Text(
                    g.name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: active ? Colors.white : AppColors.forestSoft,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyGroupHint extends StatelessWidget {
  const _EmptyGroupHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Create a group first',
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          color: AppColors.coral,
        ),
      ),
    );
  }
}

class _PayeeCard extends StatelessWidget {
  const _PayeeCard({
    required this.name,
    required this.email,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String email;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? AppColors.mint.withValues(alpha: 0.55)
              : AppColors.border.withValues(alpha: 0.7),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      active ? AppColors.mintWash : AppColors.surfaceMuted,
                  child: Text(
                    initial,
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.mint : AppColors.textMuted,
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
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.forest,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.mint : Colors.transparent,
                    border: Border.all(
                      color: active ? AppColors.mint : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: active
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mintWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.mint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
