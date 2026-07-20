import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/expenses_controller.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'create_expense_screen.dart';
import 'expense_detail_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.initialGroupId});

  final int? initialGroupId;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _loading = true;
  List<ExpenseModel> _items = const [];
  List<GroupModel> _groups = const [];
  int? _groupId;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await GroupsController.instance.loadGroups();
      if (mounted) {
        setState(() => _groups = GroupsController.instance.groups);
      }
    } catch (_) {}
    await _load();
  }

  String? get _fromStr => _from == null ? null : _fmt(_from!);
  String? get _toStr => _to == null ? null : _fmt(_to!);

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ExpensesController.instance.loadExpenses(
        groupId: _groupId,
        from: _fromStr,
        to: _toStr,
      );
      if (!mounted) return;
      setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => _from = d);
    _load();
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => _to = d);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_expenses',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateExpenseScreen(initialGroupId: _groupId),
            ),
          );
          _load();
        },
        backgroundColor: AppColors.mint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Add expense',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppHeader(
                title: 'Expenses',
                subtitle: 'All shared spending',
                onBack: () => Navigator.pop(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        _groupId == null
                            ? 'All groups'
                            : _groups
                                .where((g) => g.id == _groupId)
                                .map((g) => g.name)
                                .firstOrNull ??
                                'Group',
                      ),
                      selected: _groupId != null,
                      onSelected: (_) async {
                        final selected = await showModalBottomSheet<int?>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  title: const Text('All groups'),
                                  onTap: () => Navigator.pop(ctx, -1),
                                ),
                                ..._groups.map(
                                  (g) => ListTile(
                                    title: Text(g.name),
                                    onTap: () => Navigator.pop(ctx, g.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (selected == null) return;
                        setState(() => _groupId = selected == -1 ? null : selected);
                        _load();
                      },
                    ),
                    ActionChip(
                      label: Text(_from == null ? 'From date' : 'From $_fromStr'),
                      onPressed: _pickFrom,
                    ),
                    ActionChip(
                      label: Text(_to == null ? 'To date' : 'To $_toStr'),
                      onPressed: _pickTo,
                    ),
                    if (_from != null || _to != null || _groupId != null)
                      ActionChip(
                        label: const Text('Clear'),
                        onPressed: () {
                          setState(() {
                            _from = null;
                            _to = null;
                            if (widget.initialGroupId == null) _groupId = null;
                          });
                          _load();
                        },
                      ),
                  ],
                ),
              ),
              if (_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (_items.isEmpty)
                const EmptyHint(message: 'No expenses match these filters')
              else
                ..._items.map(
                  (e) => SoftTile(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExpenseDetailScreen(expenseId: e.id),
                        ),
                      );
                      _load();
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.mintWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forest,
                                ),
                              ),
                              Text(
                                '${e.groupName ?? 'Group'} · ${e.paidByLabel} · ${e.expenseDate}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MoneyText(e.amount, positive: false, size: 16),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
