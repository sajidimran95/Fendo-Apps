import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/settlement_model.dart';
import '../../services/auth_controller.dart';
import '../../services/settlements_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';

class SettlementDetailScreen extends StatefulWidget {
  const SettlementDetailScreen({super.key, required this.settlementId});

  final int settlementId;

  @override
  State<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  SettlementModel? _settlement;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s =
          await SettlementsController.instance.getSettlement(widget.settlementId);
      if (!mounted) return;
      setState(() => _settlement = s);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settlement;
    final me = AuthController.instance.user?.id ?? 1;
    final iPaid = s?.payerId == me;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: _loading && s == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              )
            : s == null
                ? const EmptyHint(message: 'Settlement not found')
                : ListView(
                    children: [
                      AppHeader(
                        title: 'Settlement',
                        subtitle: s.groupName,
                        onBack: () => Navigator.pop(context),
                      ),
                      SoftTile(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MoneyText(
                              s.amount,
                              positive: iPaid ? false : true,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              iPaid
                                  ? 'You paid ${s.payeeName ?? 'someone'}'
                                  : '${s.payerName ?? 'Someone'} paid you',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.forest,
                              ),
                            ),
                            if (s.settlementDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                s.settlementDate!,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SoftTile(
                        child: Column(
                          children: [
                            _row('Group', s.groupName ?? '#${s.groupId}'),
                            _row(
                              'Method',
                              s.paymentMethod?.replaceAll('_', ' ') ?? '—',
                            ),
                            _row('Reference', s.paymentReference ?? '—'),
                            _row('Currency', s.currency),
                            if (s.notes != null && s.notes!.isNotEmpty)
                              _row('Notes', s.notes!),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
