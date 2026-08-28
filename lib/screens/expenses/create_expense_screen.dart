import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/app_currency.dart';
import '../../models/category_model.dart';
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
  DateTime _date = DateTime.now();
  String _split = 'equal';
  String _currencyCode = 'USD';
  int? _categoryId;
  bool _loading = false;
  bool _scanning = false;
  bool _booting = true;

  /// Simple default: one person paid the full bill (API-safe).
  bool _onePersonPaidFull = true;
  /// Show % / shares / custom / multi payer amounts.
  bool _advancedSplit = false;
  int? _paidByUserId;

  List<GroupModel> _groups = const [];
  GroupModel? _group;
  List<GroupMember> _members = const [];
  List<CategoryModel> _categories = const [];
  final Set<int> _selectedParticipants = {};
  final Map<int, TextEditingController> _pct = {};
  final Map<int, TextEditingController> _shares = {};
  final Map<int, TextEditingController> _customAmt = {};
  final Map<int, TextEditingController> _payerAmt = {};
  final List<_ItemDraft> _items = [];

  static const _currencies = AppCurrency.codes;

  final _splits = const [
    'equal',
    'percentage',
    'shares',
    'custom',
    'itemized',
  ];

  String get _profileCurrency => AppCurrency.profileCode;

  /// New expenses use **profile** currency (not group USD).
  String _currencyFor(GroupModel? group) => AppCurrency.profileCode;

  List<String> get _currencyOptions {
    final code = _currencyCode.trim().toUpperCase();
    if (code.isEmpty || _currencies.contains(code)) return _currencies;
    return [code, ..._currencies];
  }

  @override
  void initState() {
    super.initState();
    _currencyCode = _profileCurrency;
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
      List<CategoryModel> categories = const [];
      try {
        categories = await AuthController.instance.categoriesApi.listCategories();
      } catch (_) {
        categories = const [
          CategoryModel(id: 1, name: 'Food & Drink'),
          CategoryModel(id: 2, name: 'Transport'),
          CategoryModel(id: 3, name: 'Accommodation'),
          CategoryModel(id: 4, name: 'Entertainment'),
          CategoryModel(id: 5, name: 'Shopping'),
          CategoryModel(id: 6, name: 'Utilities'),
          CategoryModel(id: 7, name: 'Health'),
          CategoryModel(id: 8, name: 'Groceries'),
          CategoryModel(id: 9, name: 'Education'),
          CategoryModel(id: 10, name: 'Other'),
        ];
      }
      setState(() {
        _groups = groups;
        _group = selected;
        _currencyCode = _currencyFor(selected);
        _categories = categories;
        _categoryId = null;
      });
      if (selected != null) await _loadMembers(selected.id);
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _loadMembers(int groupId) async {
    try {
      final raw = await GroupsController.instance.getMembers(groupId);
      if (!mounted) return;
      final members = raw.where((m) => m.hasValidUserId).toList();
      final seen = <int>{};
      final unique = <GroupMember>[];
      for (final m in members) {
        if (seen.add(m.userId)) unique.add(m);
      }
      setState(() {
        _members = unique.isNotEmpty
            ? unique
            : [
                GroupMember(
                  userId: AuthController.instance.user?.id ?? 0,
                  name: AuthController.instance.user?.name ?? 'You',
                  email: AuthController.instance.user?.email ?? '',
                  role: 'admin',
                ),
              ].where((m) => m.hasValidUserId).toList();
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
          _payerAmt[m.userId]?.clear();
        }
        final me = AuthController.instance.user?.id;
        _paidByUserId = _members.any((m) => m.userId == me)
            ? me
            : (_members.isNotEmpty ? _members.first.userId : null);
      });
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan receipt',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Camera or photo — Fendo reads merchant, total, date & items',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.mint),
                  title: Text(
                    'Take photo',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppColors.forest),
                  title: Text(
                    'Choose from gallery',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
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

      final title =
          scanned.title ?? scanned.merchantName;
      final hasAny = (title != null && title.trim().isNotEmpty) ||
          scanned.amount != null ||
          (scanned.expenseDate != null && scanned.expenseDate!.isNotEmpty) ||
          scanned.items.isNotEmpty;

      if (!hasAny) {
        showApiError(
          context,
          ApiException(
            message:
                'Could not read this receipt. Try a clearer photo with the total visible.',
          ),
        );
        return;
      }

      setState(() {
        if (title != null && title.trim().isNotEmpty) {
          _title.text = title.trim();
        }
        if (scanned.amount != null) {
          _amount.text = scanned.amount!.toStringAsFixed(2);
        }
        if (scanned.currency != null && scanned.currency!.trim().isNotEmpty) {
          _currencyCode = scanned.currency!.trim().toUpperCase();
        }
        if (scanned.expenseDate != null) {
          final parts = scanned.expenseDate!.split(RegExp(r'[T\s]')).first.split('-');
          if (parts.length == 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) {
              _date = DateTime(y, m, d);
            }
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
          // Total from sum of items if amount missing.
          if (scanned.amount == null) {
            final sum = scanned.items.fold<double>(0, (a, b) => a + b.amount);
            if (sum > 0) _amount.text = sum.toStringAsFixed(2);
          }
        }
      });
      showApiMessage(context, 'Receipt scanned — fields filled');
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      showApiError(
        context,
        ApiException(message: 'Could not read receipt. Try again with a clearer photo.'),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<ExpenseParticipant> _buildParticipants() {
    final selected = _members
        .where(
          (m) =>
              m.hasValidUserId && _selectedParticipants.contains(m.userId),
        )
        .toList();
    // Simple mode always equal (reliable API path).
    final method = _advancedSplit ? _split : 'equal';
    switch (method) {
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
        // equal / itemized: user_id only
        return selected
            .map((m) => ExpenseParticipant(userId: m.userId, name: m.name))
            .toList();
    }
  }

  List<ExpensePayer> _buildPayers(double amount) {
    final total = roundMoney(amount);
    final validMembers =
        _members.where((m) => m.hasValidUserId).toList(growable: false);
    if (validMembers.isEmpty) return const [];

    // Default (and recommended): one person paid the full bill.
    if (_onePersonPaidFull || !_advancedSplit) {
      final me = AuthController.instance.user?.id;
      var payerId = _paidByUserId ?? me ?? 0;
      if (payerId <= 0 || !validMembers.any((m) => m.userId == payerId)) {
        payerId = validMembers
                .where((m) => m.userId == me)
                .map((m) => m.userId)
                .firstOrNull ??
            validMembers.first.userId;
      }
      final name = validMembers
              .where((m) => m.userId == payerId)
              .map((m) => m.name)
              .firstOrNull ??
          'You';
      return [
        ExpensePayer(userId: payerId, amountPaid: total, name: name),
      ];
    }

    final typed = <ExpensePayer>[];
    for (final m in validMembers) {
      final raw = double.tryParse(_payerAmt[m.userId]?.text ?? '') ?? 0;
      if (raw > 0) {
        typed.add(
          ExpensePayer(
            userId: m.userId,
            amountPaid: roundMoney(raw),
            name: m.name,
          ),
        );
      }
    }
    // If the user typed any "Paid" amounts, they must total the bill
    // (do not silently rewrite — wrong multi-payer sums crash the API).
    if (typed.isNotEmpty) {
      return typed;
    }

    // No paid amounts typed → one person pays full bill.
    final me = AuthController.instance.user?.id;
    final meMember = validMembers
            .where((m) => m.userId == me)
            .firstOrNull ??
        validMembers.first;
    return [
      ExpensePayer(
        userId: meMember.userId,
        amountPaid: total,
        name: meMember.name,
      ),
    ];
  }

  /// Equal % for selected people when percentage fields are empty / incomplete.
  void _autoFillEqualPercentages() {
    final selected = _members
        .where((m) => _selectedParticipants.contains(m.userId))
        .toList();
    if (selected.isEmpty) return;
    final each = roundMoney(100 / selected.length);
    var assigned = 0.0;
    for (var i = 0; i < selected.length; i++) {
      final id = selected[i].userId;
      final c = _pct[id];
      if (c == null) continue;
      if (i == selected.length - 1) {
        c.text = roundMoney(100 - assigned).toStringAsFixed(2);
      } else {
        c.text = each.toStringAsFixed(2);
        assigned = roundMoney(assigned + each);
      }
    }
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
    final amountRaw = double.tryParse(_amount.text.trim());
    if (amountRaw == null || amountRaw <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }
    final amount = roundMoney(amountRaw);

    final validMembers =
        _members.where((m) => m.hasValidUserId).toList(growable: false);
    if (validMembers.isEmpty) {
      showApiError(
        context,
        ApiException(
          message:
              'Could not load group members. Open Group → Members, then try again.',
        ),
      );
      return;
    }
    final methodPreview = _advancedSplit ? _split : 'equal';
    if (validMembers.length < 2 && methodPreview != 'itemized') {
      showApiError(
        context,
        ApiException(
          message:
              'This group only has you. Invite at least one friend before splitting an expense.',
        ),
      );
      return;
    }

    final participants = _buildParticipants();
    if (participants.isEmpty && methodPreview != 'itemized') {
      showApiError(
        context,
        ApiException(message: 'Select who shares this expense'),
      );
      return;
    }
    // Simple mode always equal (docs 4.2). Advanced keeps chosen method.
    final method = _advancedSplit ? _split : 'equal';

    // Equal / % / shares need 2+ people or balances never change.
    if (participants.length < 2 && method != 'itemized') {
      showApiError(
        context,
        ApiException(
          message:
              'Select at least you + one friend under “Split with”. Someone must share the bill.',
        ),
      );
      return;
    }

    // Client-side split checks (server still finalizes amounts).
    var finalParticipants = participants;
    if (method == 'percentage') {
      var sum = finalParticipants.fold<double>(
        0,
        (s, p) => s + (p.percentage ?? 0),
      );
      // Auto-balance empty / incomplete % so screenshot case (50 + empty) works.
      if ((sum - 100).abs() > 0.5) {
        _autoFillEqualPercentages();
        finalParticipants = _buildParticipants();
        sum = finalParticipants.fold<double>(
          0,
          (s, p) => s + (p.percentage ?? 0),
        );
      }
      if ((sum - 100).abs() > 0.5) {
        showApiError(
          context,
          ApiException(
            message:
                'Percentages must add up to 100% (now ${sum.toStringAsFixed(1)}%). '
                'Example for 2 people: 50 and 50 — not Paid amounts.',
          ),
        );
        return;
      }
    } else if (method == 'custom') {
      final sum = finalParticipants.fold<double>(
        0,
        (s, p) => s + (p.amount ?? 0),
      );
      if ((sum - amount).abs() > 0.05) {
        showApiError(
          context,
          ApiException(
            message:
                'Custom splits must total ${amount.toStringAsFixed(2)} (now ${sum.toStringAsFixed(2)}).',
          ),
        );
        return;
      }
    } else if (method == 'shares') {
      final shares = finalParticipants.fold<double>(
        0,
        (s, p) => s + (p.shares ?? 0),
      );
      if (shares <= 0) {
        showApiError(
          context,
          ApiException(message: 'Enter at least one share greater than 0'),
        );
        return;
      }
    }

    final items = method == 'itemized'
        ? _items
            .where((i) => i.name.text.trim().isNotEmpty)
            .map(
              (i) => ExpenseItem(
                name: i.name.text.trim(),
                amount: roundMoney(double.tryParse(i.amount.text) ?? 0),
                assignedTo: i.assigned.where((id) => id > 0).toList(),
              ),
            )
            .toList()
        : <ExpenseItem>[];

    if (method == 'itemized') {
      if (items.isEmpty) {
        showApiError(context, ApiException(message: 'Add at least one item'));
        return;
      }
      final itemSum = items.fold<double>(0, (s, i) => s + i.amount);
      if (itemSum <= 0) {
        showApiError(
          context,
          ApiException(message: 'Item amounts must be greater than 0'),
        );
        return;
      }
      if ((itemSum - amount).abs() > 0.05) {
        showApiError(
          context,
          ApiException(
            message:
                'Items total ${itemSum.toStringAsFixed(2)} must match expense ${amount.toStringAsFixed(2)}',
          ),
        );
        return;
      }
      for (final i in items) {
        if (i.assignedTo.isEmpty) {
          showApiError(
            context,
            ApiException(
              message: 'Assign “${i.name}” to at least one person',
            ),
          );
          return;
        }
      }
    }

    final payers = _buildPayers(amount);
    if (payers.isEmpty) {
      showApiError(
        context,
        ApiException(message: 'Could not set who paid. Re-select the group.'),
      );
      return;
    }
    final paidSum = payers.fold<double>(0, (s, p) => s + p.amountPaid);
    if ((paidSum - amount).abs() > 0.05) {
      showApiError(
        context,
        ApiException(
          message:
              '“Who paid” total ${paidSum.toStringAsFixed(2)} must equal ${amount.toStringAsFixed(2)}. '
              'If one person paid, turn ON “One person paid full bill” and leave Paid fields empty. '
              'Do not put the full amount on every person.',
        ),
      );
      return;
    }

    // Every payer must appear among members of this group.
    final memberIds = validMembers.map((m) => m.userId).toSet();
    for (final p in payers) {
      if (!memberIds.contains(p.userId)) {
        showApiError(
          context,
          ApiException(
            message:
                'Payer is not a group member. Refresh members and try again.',
          ),
        );
        return;
      }
    }
    for (final p in finalParticipants) {
      if (!memberIds.contains(p.userId)) {
        showApiError(
          context,
          ApiException(
            message:
                'A selected person is not a valid group member. Invite them or re-open this screen.',
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      await ExpensesController.instance.createExpense(
        title: _title.text.trim(),
        amount: amount,
        currency: _currencyCode.trim().isEmpty
            ? _profileCurrency
            : _currencyCode.trim().toUpperCase(),
        expenseDate: _dateStr,
        groupId: _group!.id,
        groupName: _group!.name,
        // Avoid category_id on simple path — optional field; bad IDs → 500.
        categoryId: _advancedSplit ? _categoryId : null,
        splitMethod: method,
        payers: payers,
        participants: finalParticipants,
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
                        });
                        await _loadMembers(g.id);
                      },
                    ),
                  const SizedBox(height: 18),
                  AuthTextField(
                    controller: _title,
                    label: 'Title',
                    hint: 'Dinner at Nobu',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Amount',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.forest,
                          ),
                          cursorColor: AppColors.mint,
                          decoration: InputDecoration(
                            hintText: '120.00',
                            prefixText:
                                '${AppCurrency.symbol(_currencyCode)} ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 128,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('currency-$_currencyCode'),
                          initialValue: _currencyOptions.contains(_currencyCode)
                              ? _currencyCode
                              : _currencyOptions.first,
                          items: _currencyOptions
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    '${AppCurrency.symbol(c)} $c',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.forest,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _currencyCode = v);
                          },
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.mint,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.mintWash,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.borderFocus,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Category'),
                  const SizedBox(height: 8),
                  if (_categories.isEmpty)
                    Text(
                      'No categories available',
                      style: GoogleFonts.manrope(color: AppColors.textMuted),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      key: ValueKey('category-$_categoryId'),
                      initialValue: _categoryId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (id) => setState(() => _categoryId = id),
                      decoration: const InputDecoration(
                        hintText: 'optional',
                      ),
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
                  SoftTile(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'One person paid full bill',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          subtitle: Text(
                            'Recommended. Others owe their share (equal split).',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _onePersonPaidFull,
                          activeThumbColor: AppColors.mint,
                          onChanged: (v) => setState(() {
                            _onePersonPaidFull = v;
                            if (v) _advancedSplit = false;
                          }),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Advanced split options',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          subtitle: Text(
                            'Multi-payer, %, shares, custom (may fail on some servers).',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _advancedSplit,
                          activeThumbColor: AppColors.mint,
                          onChanged: (v) => setState(() {
                            _advancedSplit = v;
                            if (v) _onePersonPaidFull = false;
                            if (!v) _split = 'equal';
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (_onePersonPaidFull || !_advancedSplit) ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Who paid full amount'),
                    const SizedBox(height: 8),
                    if (_members.isEmpty)
                      Text(
                        'Load a group first',
                        style: GoogleFonts.manrope(color: AppColors.textMuted),
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: ValueKey('payer-$_paidByUserId'),
                        initialValue: _paidByUserId != null &&
                                _members.any((m) => m.userId == _paidByUserId)
                            ? _paidByUserId
                            : _members.first.userId,
                        items: _members
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.userId,
                                child: Text(m.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() => _paidByUserId = id);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Payer',
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'With 3 people and equal split: one pays the full bill, '
                      'the other two each owe their 1/3 share.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (_advancedSplit) ...[
                    const SizedBox(height: 14),
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
                          onSelected: (_) => setState(() {
                            _split = m;
                            if (m == 'percentage') {
                              _autoFillEqualPercentages();
                            }
                          }),
                          selectedColor: AppColors.mintWash,
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Split method: Equal (server calculates shares)',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.forestSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_split != 'itemized' || !_advancedSplit) ...[
                    Row(
                      children: [
                        Text(
                          'Split with',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedParticipants.isNotEmpty)
                          Text(
                            '${_selectedParticipants.length} people',
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
                        final active =
                            _selectedParticipants.contains(m.userId);
                        final showPayerField =
                            _advancedSplit && !_onePersonPaidFull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ParticipantRow(
                            name: m.name,
                            active: active,
                            payerController: _payerAmt[m.userId]!,
                            split: _advancedSplit ? _split : 'equal',
                            showPayerField: showPayerField,
                            pctController: _pct[m.userId],
                            sharesController: _shares[m.userId],
                            customController: _customAmt[m.userId],
                            onToggle: (v) {
                              setState(() {
                                if (v) {
                                  _selectedParticipants.add(m.userId);
                                } else {
                                  _selectedParticipants.remove(m.userId);
                                  _payerAmt[m.userId]?.clear();
                                }
                              });
                            },
                          ),
                        );
                      }),
                  ],
                  if (_advancedSplit && _split == 'itemized') ...[
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

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.active,
    required this.payerController,
    required this.split,
    required this.onToggle,
    this.showPayerField = false,
    this.pctController,
    this.sharesController,
    this.customController,
  });

  final String name;
  final bool active;
  final TextEditingController payerController;
  final String split;
  final ValueChanged<bool> onToggle;
  final bool showPayerField;
  final TextEditingController? pctController;
  final TextEditingController? sharesController;
  final TextEditingController? customController;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final showExtra = active &&
        (showPayerField ||
            split == 'percentage' ||
            split == 'shares' ||
            split == 'custom');

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
          if (showExtra) ...[
            if (showPayerField) ...[
              const SizedBox(height: 10),
              _AmountField(
                controller: payerController,
                label: 'Paid',
              ),
            ],
            if (split == 'percentage' && pctController != null) ...[
              const SizedBox(height: 10),
              _AmountField(
                controller: pctController!,
                label: 'Percentage',
                prefix: null,
              ),
            ],
            if (split == 'shares' && sharesController != null) ...[
              const SizedBox(height: 10),
              _AmountField(
                controller: sharesController!,
                label: 'Shares',
                prefix: null,
              ),
            ],
            if (split == 'custom' && customController != null) ...[
              const SizedBox(height: 10),
              _AmountField(
                controller: customController!,
                label: 'Share amount',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.label,
    this.prefix = r'$ ',
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final p = prefix == r'$ '
        ? '${AppCurrency.symbol(AppCurrency.profileCode)} '
        : prefix;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        color: AppColors.forest,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: AppColors.textMuted,
        ),
        prefixText: p,
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
    );
  }
}
