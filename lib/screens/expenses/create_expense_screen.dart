import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../models/expense_model.dart';
import '../../models/group_member.dart';
import '../../models/group_model.dart';
import '../../services/auth_controller.dart';
import '../../services/expenses_controller.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({super.key, this.initialGroupId});

  final int? initialGroupId;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _categoryId = TextEditingController();
  DateTime _date = DateTime.now();
  String _split = 'equal';
  bool _loading = false;
  bool _scanning = false;
  bool _booting = true;

  List<GroupModel> _groups = const [];
  GroupModel? _group;
  List<GroupMember> _members = const [];
  final Set<int> _selectedParticipants = {};
  final Map<int, TextEditingController> _pct = {};
  final Map<int, TextEditingController> _shares = {};
  final Map<int, TextEditingController> _customAmt = {};
  final Map<int, TextEditingController> _payerAmt = {};
  final List<_ItemDraft> _items = [];

  final _splits = const [
    'equal',
    'percentage',
    'shares',
    'custom',
    'itemized',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _booting = true);
    try {
      await GroupsController.instance.loadGroups();
      if (!mounted) return;
      final groups = GroupsController.instance.groups;
      final selected = GroupsController.instance.groupById(widget.initialGroupId) ??
          (groups.isNotEmpty ? groups.first : null);
      setState(() {
        _groups = groups;
        _group = selected;
      });
      if (selected != null) await _loadMembers(selected.id);
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _loadMembers(int groupId) async {
    try {
      final members = await GroupsController.instance.getMembers(groupId);
      if (!mounted) return;
      setState(() {
        _members = members.isNotEmpty
            ? members
            : [
                GroupMember(
                  userId: AuthController.instance.user?.id ?? 1,
                  name: AuthController.instance.user?.name ?? 'You',
                  email: AuthController.instance.user?.email ?? 'demo@fendo.app',
                  role: 'admin',
                ),
              ];
        _selectedParticipants
          ..clear()
          ..addAll(_members.map((m) => m.userId));
        for (final m in _members) {
          _pct.putIfAbsent(m.userId, TextEditingController.new);
          _shares.putIfAbsent(
            m.userId,
            () => TextEditingController(text: '1'),
          );
          _customAmt.putIfAbsent(m.userId, TextEditingController.new);
          _payerAmt.putIfAbsent(m.userId, TextEditingController.new);
        }
        final me = AuthController.instance.user?.id ?? _members.first.userId;
        _payerAmt[me]?.text = _amount.text;
      });
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _currency.dispose();
    _categoryId.dispose();
    for (final c in _pct.values) {
      c.dispose();
    }
    for (final c in _shares.values) {
      c.dispose();
    }
    for (final c in _customAmt.values) {
      c.dispose();
    }
    for (final c in _payerAmt.values) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _scanReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.length();
    if (bytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      showApiError(context, ApiException(message: 'Receipt must be 5MB or less'));
      return;
    }
    if (kIsWeb) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Receipt scan on web is not supported yet'),
      );
      return;
    }

    setState(() => _scanning = true);
    try {
      final scanned = await ExpensesController.instance.scanReceipt(
        filePath: file.path,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() {
        if (scanned.title != null) _title.text = scanned.title!;
        if (scanned.amount != null) {
          _amount.text = scanned.amount!.toStringAsFixed(2);
        }
        if (scanned.currency != null) _currency.text = scanned.currency!;
        if (scanned.expenseDate != null) {
          final parts = scanned.expenseDate!.split('-');
          if (parts.length == 3) {
            _date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        }
        if (scanned.items.isNotEmpty) {
          for (final i in _items) {
            i.dispose();
          }
          _items
            ..clear()
            ..addAll(
              scanned.items.map(
                (e) => _ItemDraft(
                  name: TextEditingController(text: e.name),
                  amount: TextEditingController(
                    text: e.amount.toStringAsFixed(2),
                  ),
                ),
              ),
            );
          _split = 'itemized';
        }
      });
      showApiMessage(context, 'Receipt scanned');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<ExpenseParticipant> _buildParticipants() {
    final selected = _members
        .where((m) => _selectedParticipants.contains(m.userId))
        .toList();
    switch (_split) {
      case 'percentage':
        return selected
            .map(
              (m) => ExpenseParticipant(
                userId: m.userId,
                name: m.name,
                percentage: double.tryParse(_pct[m.userId]?.text ?? '') ?? 0,
              ),
            )
            .toList();
      case 'shares':
        return selected
            .map(
              (m) => ExpenseParticipant(
                userId: m.userId,
                name: m.name,
                shares: double.tryParse(_shares[m.userId]?.text ?? '') ?? 1,
              ),
            )
            .toList();
      case 'custom':
        return selected
            .map(
              (m) => ExpenseParticipant(
                userId: m.userId,
                name: m.name,
                amount: double.tryParse(_customAmt[m.userId]?.text ?? '') ?? 0,
              ),
            )
            .toList();
      default:
        return selected
            .map((m) => ExpenseParticipant(userId: m.userId, name: m.name))
            .toList();
    }
  }

  List<ExpensePayer> _buildPayers(double amount) {
    final fromPaid = _members
        .where((m) => _selectedParticipants.contains(m.userId))
        .where((m) {
          final v = double.tryParse(_payerAmt[m.userId]?.text ?? '') ?? 0;
          return v > 0;
        })
        .map(
          (m) => ExpensePayer(
            userId: m.userId,
            amountPaid: double.tryParse(_payerAmt[m.userId]!.text) ?? 0,
            name: m.name,
          ),
        )
        .toList();

    if (fromPaid.isNotEmpty) return fromPaid;

    // Default: current user paid the full amount (API still needs payers[]).
    final me = AuthController.instance.user?.id ??
        (_members.isNotEmpty ? _members.first.userId : 1);
    final payer = _members.cast<GroupMember?>().firstWhere(
          (m) => m?.userId == me,
          orElse: () => _members.isNotEmpty ? _members.first : null,
        );
    return [
      ExpensePayer(
        userId: payer?.userId ?? me,
        amountPaid: amount,
        name: payer?.name ?? 'You',
      ),
    ];
  }

  Future<void> _save() async {
    if (_group == null) {
      showApiError(context, ApiException(message: 'Select a group'));
      return;
    }
    if (_title.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Enter a title'));
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }

    final participants = _buildParticipants();
    if (participants.isEmpty && _split != 'itemized') {
      showApiError(context, ApiException(message: 'Select participants'));
      return;
    }

    final items = _split == 'itemized'
        ? _items
            .where((i) => i.name.text.trim().isNotEmpty)
            .map(
              (i) => ExpenseItem(
                name: i.name.text.trim(),
                amount: double.tryParse(i.amount.text) ?? 0,
                assignedTo: i.assigned.toList(),
              ),
            )
            .toList()
        : <ExpenseItem>[];

    final payers = _buildPayers(amount);
    if (payers.isEmpty) {
      showApiError(context, ApiException(message: 'Add at least one payer'));
      return;
    }

    setState(() => _loading = true);
    try {
      await ExpensesController.instance.createExpense(
        title: _title.text.trim(),
        amount: amount,
        currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
        expenseDate: _dateStr,
        groupId: _group!.id,
        groupName: _group!.name,
        categoryId: int.tryParse(_categoryId.text.trim()),
        splitMethod: _split,
        payers: payers,
        participants: participants,
        items: items,
        isMultiPayer: payers.length > 1,
      );
      if (!mounted) return;
      showApiMessage(context, 'Expense saved');
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Add expense',
              onBack: () => Navigator.pop(context),
              trailing: IconButton(
                tooltip: 'Scan receipt',
                onPressed: _scanning ? null : _scanReceipt,
                icon: _scanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                color: AppColors.forest,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group *',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_groups.isEmpty)
                    Text(
                      'No groups yet. Create a group first.',
                      style: GoogleFonts.manrope(color: AppColors.coral),
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey('group-${_group?.id}'),
                      initialValue: _group?.id,
                      items: _groups
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                      onChanged: (id) async {
                        if (id == null) return;
                        final g = _groups.firstWhere((e) => e.id == id);
                        setState(() => _group = g);
                        await _loadMembers(id);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Required',
                      ),
                    ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _title,
                    label: 'Title',
                    hint: 'Dinner at Nobu',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount',
                    hint: '120.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _currency,
                    label: 'Currency',
                    hint: 'USD',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _categoryId,
                    label: 'Category ID',
                    hint: 'optional',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Expense date',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_dateStr),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Split method',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _splits.map((m) {
                      return ChoiceChip(
                        label: Text(m),
                        selected: _split == m,
                        onSelected: (_) => setState(() => _split = m),
                        selectedColor: AppColors.mintWash,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_split != 'itemized') ...[
                    const SectionLabel('Participants'),
                    ..._members.map((m) {
                      final active =
                          _selectedParticipants.contains(m.userId);
                      return SoftTile(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: active,
                              title: Text(m.name),
                              subtitle: Text(m.email),
                              activeColor: AppColors.mint,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedParticipants.add(m.userId);
                                  } else {
                                    _selectedParticipants.remove(m.userId);
                                    _payerAmt[m.userId]?.clear();
                                  }
                                });
                              },
                            ),
                            if (active) ...[
                              AuthTextField(
                                controller: _payerAmt[m.userId]!,
                                label: 'Paid (amount_paid)',
                                hint: '0.00 if they did not pay',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                              if (_split == 'percentage') ...[
                                const SizedBox(height: 10),
                                AuthTextField(
                                  controller: _pct[m.userId]!,
                                  label: 'Percentage',
                                  hint: '33.33',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ],
                              if (_split == 'shares') ...[
                                const SizedBox(height: 10),
                                AuthTextField(
                                  controller: _shares[m.userId]!,
                                  label: 'Shares',
                                  hint: '1',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ],
                              if (_split == 'custom') ...[
                                const SizedBox(height: 10),
                                AuthTextField(
                                  controller: _customAmt[m.userId]!,
                                  label: 'Share amount',
                                  hint: '0.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_split == 'itemized') ...[
                    SectionLabel(
                      'Items',
                      actionLabel: 'Add item',
                      onAction: () {
                        setState(() {
                          _items.add(
                            _ItemDraft(
                              name: TextEditingController(),
                              amount: TextEditingController(),
                            ),
                          );
                        });
                      },
                    ),
                    ..._items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return SoftTile(
                        child: Column(
                          children: [
                            AuthTextField(
                              controller: item.name,
                              label: 'Item ${i + 1}',
                              hint: 'Coffee',
                            ),
                            const SizedBox(height: 10),
                            AuthTextField(
                              controller: item.amount,
                              label: 'Amount',
                              hint: '12.50',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: _members.map((m) {
                                final selected =
                                    item.assigned.contains(m.userId);
                                return FilterChip(
                                  label: Text(m.name),
                                  selected: selected,
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        item.assigned.add(m.userId);
                                      } else {
                                        item.assigned.remove(m.userId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Save expense',
                    loading: _loading,
                    onPressed: _loading ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft({required this.name, required this.amount});

  final TextEditingController name;
  final TextEditingController amount;
  final Set<int> assigned = {};

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}
