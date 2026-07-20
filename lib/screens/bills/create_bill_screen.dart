import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../models/group_member.dart';
import '../../models/group_model.dart';
import '../../services/bills_controller.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  DateTime? _recurrenceEnd;
  bool _recurring = false;
  String _frequency = 'monthly';
  bool _loading = false;
  bool _booting = true;
  final Set<int> _reminderDays = {3, 1};

  List<GroupModel> _groups = const [];
  GroupModel? _group;
  List<GroupMember> _members = const [];
  final Map<int, TextEditingController> _splitAmt = {};
  final Set<int> _selected = {};

  static const _frequencies = [
    'weekly',
    'biweekly',
    'monthly',
    'quarterly',
    'annually',
  ];

  static const _reminderOptions = [1, 3, 7, 14];

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(_distributeEqual);
  }

  Future<void> _bootstrap() async {
    await GroupsController.instance.loadGroups();
    if (!mounted) return;
    final groups = GroupsController.instance.groups;
    final selected = groups.isNotEmpty ? groups.first : null;
    setState(() {
      _groups = groups;
      _group = selected;
      _booting = false;
    });
    if (selected != null) await _loadMembers(selected.id);
  }

  Future<void> _loadMembers(int groupId) async {
    final members = await GroupsController.instance.getMembers(groupId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _selected
        ..clear()
        ..addAll(members.map((m) => m.userId));
      for (final m in members) {
        _splitAmt.putIfAbsent(m.userId, TextEditingController.new);
      }
      _distributeEqual();
    });
  }

  void _distributeEqual() {
    final total = double.tryParse(_amount.text.trim()) ?? 0;
    if (_selected.isEmpty || total <= 0) return;
    final each = total / _selected.length;
    for (final id in _selected) {
      _splitAmt[id]?.text = each.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountChanged);
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    for (final c in _splitAmt.values) {
      c.dispose();
    }
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

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
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
    if (d != null) setState(() => _due = d);
  }

  Future<void> _pickRecurrenceEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _recurrenceEnd ?? _due.add(const Duration(days: 365)),
      firstDate: _due,
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
    if (d != null) setState(() => _recurrenceEnd = d);
  }

  Future<void> _save() async {
    if (_group == null) {
      showApiError(context, ApiException(message: 'Select a group'));
      return;
    }
    if (_name.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Enter bill name'));
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }

    final reminders = _reminderDays.toList()..sort((a, b) => b.compareTo(a));

    final splits = _selected
        .map(
          (id) => BillSplit(
            userId: id,
            amountOwed: double.tryParse(_splitAmt[id]?.text ?? '') ?? 0,
            name: _members
                .where((m) => m.userId == id)
                .map((m) => m.name)
                .firstOrNull,
          ),
        )
        .where((s) => s.amountOwed > 0)
        .toList();

    setState(() => _loading = true);
    try {
      await BillsController.instance.createBill(
        name: _name.text.trim(),
        amount: amount,
        dueDate: _fmt(_due),
        groupId: _group!.id,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        reminderDays: reminders,
        splits: splits,
        billType: _recurring ? 'recurring' : 'one_time',
        frequency: _recurring ? _frequency : null,
        recurrenceEndDate:
            _recurring && _recurrenceEnd != null ? _fmt(_recurrenceEnd!) : null,
      );
      if (!mounted) return;
      showApiMessage(context, 'Bill created');
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
                title: 'New bill',
                subtitle: 'One-time or recurring',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _TypeToggle(
                      recurring: _recurring,
                      onChanged: (v) => setState(() => _recurring = v),
                    ),
                    const SizedBox(height: 18),
                    _AmountHero(controller: _amount),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _name,
                      label: 'Bill name',
                      hint: 'Electricity, Internet…',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel('Group'),
                    const SizedBox(height: 8),
                    if (_groups.isEmpty)
                      _EmptyGroupHint()
                    else
                      _GroupPicker(
                        groups: _groups,
                        selected: _group,
                        onChanged: (g) async {
                          setState(() => _group = g);
                          await _loadMembers(g.id);
                        },
                      ),
                    const SizedBox(height: 18),
                    _DateTile(
                      label: 'Due date',
                      value: _prettyDate(_due),
                      icon: Icons.event_rounded,
                      onTap: _pickDue,
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _notes,
                      label: 'Notes',
                      hint: 'Optional',
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel('Reminders'),
                    const SizedBox(height: 4),
                    Text(
                      'Days before due',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reminderOptions.map((d) {
                        final selected = _reminderDays.contains(d);
                        return FilterChip(
                          label: Text(
                            '$d day${d == 1 ? '' : 's'}',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _reminderDays.add(d);
                            } else {
                              _reminderDays.remove(d);
                            }
                          }),
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
                    if (_recurring) ...[
                      const SizedBox(height: 22),
                      _FieldLabel('Frequency'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _frequencies.map((f) {
                          final selected = _frequency == f;
                          return ChoiceChip(
                            label: Text(
                              f,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.forest
                                    : AppColors.textSecondary,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _frequency = f),
                            selectedColor: AppColors.mintWash,
                            backgroundColor: AppColors.surface,
                            showCheckmark: false,
                            side: BorderSide(
                              color: selected
                                  ? AppColors.mint
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _DateTile(
                        label: 'Ends on',
                        value: _recurrenceEnd == null
                            ? 'Optional'
                            : _prettyDate(_recurrenceEnd!),
                        icon: Icons.flag_outlined,
                        muted: _recurrenceEnd == null,
                        onTap: _pickRecurrenceEnd,
                        trailing: _recurrenceEnd == null
                            ? null
                            : IconButton(
                                onPressed: () =>
                                    setState(() => _recurrenceEnd = null),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: AppColors.textMuted,
                              ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Splits',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        const Spacer(),
                        if (_selected.isNotEmpty)
                          Text(
                            '${_selected.length} people',
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
                        'Pick a group to split',
                        style: GoogleFonts.manrope(color: AppColors.textMuted),
                      )
                    else
                      ..._members.map((m) {
                        final active = _selected.contains(m.userId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SplitRow(
                            name: m.name,
                            active: active,
                            controller: _splitAmt[m.userId]!,
                            onToggle: (v) {
                              setState(() {
                                if (v) {
                                  _selected.add(m.userId);
                                } else {
                                  _selected.remove(m.userId);
                                  _splitAmt[m.userId]?.clear();
                                }
                                _distributeEqual();
                              });
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    AuthPrimaryButton(
                      label: 'Create bill',
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

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.recurring, required this.onChanged});

  final bool recurring;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypePill(
              label: 'One-time',
              selected: !recurring,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _TypePill(
              label: 'Recurring',
              selected: recurring,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        elevation: selected ? 1 : 0,
        shadowColor: AppColors.forest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? AppColors.forest : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  const _AmountHero({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mintWash,
            AppColors.surface,
            AppColors.canvasDeep.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Text(
            'Amount',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.forestSoft,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '\$',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: IntrinsicWidth(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    style: GoogleFonts.sora(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forest,
                      letterSpacing: -1.2,
                      height: 1.1,
                    ),
                    cursorColor: AppColors.mint,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.sora(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted.withValues(alpha: 0.35),
                        letterSpacing: -1.2,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              color: active ? AppColors.forest : AppColors.surface,
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
                      color: active ? AppColors.forest : AppColors.border,
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

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;
  final Widget? trailing;

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
                        color: muted
                            ? AppColors.textMuted
                            : AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
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

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.name,
    required this.active,
    required this.controller,
    required this.onToggle,
  });

  final String name;
  final bool active;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? AppColors.mint.withValues(alpha: 0.45)
              : AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: active
                    ? AppColors.mintWash
                    : AppColors.surfaceMuted,
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
                child: Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.forest,
                  ),
                ),
              ),
              Switch.adaptive(
                value: active,
                activeTrackColor: AppColors.mint,
                onChanged: onToggle,
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
              decoration: InputDecoration(
                labelText: 'Amount owed',
                labelStyle: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixText: '\$ ',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.mint),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
