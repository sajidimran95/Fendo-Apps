import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/bill_model.dart';
import '../../services/bills_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'bill_detail_screen.dart';
import 'create_bill_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  static const _statuses = [
    null,
    'upcoming',
    'due_today',
    'overdue',
    'paid',
    'partial',
  ];

  bool _loading = true;
  List<BillModel> _items = const [];
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'due_today':
        return AppColors.amber;
      case 'overdue':
        return AppColors.coral;
      case 'paid':
        return AppColors.mint;
      case 'partial':
        return AppColors.forestSoft;
      default:
        return AppColors.forestSoft;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await BillsController.instance.loadBills(status: _status);
      if (!mounted) return;
      setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_bills',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateBillScreen()),
          );
          _load();
        },
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New bill',
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
              const AppHeader(
                title: 'Bills',
                subtitle: 'Upcoming & recurring',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((s) {
                      final label = s == null ? 'all' : s.replaceAll('_', ' ');
                      final selected = _status == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _status = s);
                            _load();
                          },
                          selectedColor: AppColors.mintWash,
                        ),
                      );
                    }).toList(),
                  ),
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
                const EmptyHint(message: 'No bills for this filter')
              else
                ..._items.map(
                  (b) => SoftTile(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BillDetailScreen(billId: b.id),
                        ),
                      );
                      _load();
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forest,
                                ),
                              ),
                              Text(
                                '${b.groupName ?? 'Group'} · Due ${b.dueDate}',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  StatusChip(
                                    b.status.replaceAll('_', ' '),
                                    color: _statusColor(b.status),
                                  ),
                                  if (b.isRecurring)
                                    StatusChip(
                                      b.frequency ?? 'recurring',
                                      color: AppColors.mint,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        MoneyText(b.amount, positive: false, size: 16),
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
