import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/settlement_model.dart';
import '../../services/auth_controller.dart';
import '../../services/settlements_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'payment_deeplink_screen.dart';
import 'record_settlement_screen.dart';
import 'send_payment_request_screen.dart';
import 'settlement_detail_screen.dart';

class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  bool _loading = true;
  List<SettlementModel> _settlements = const [];
  List<SettlementRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settlements =
          await SettlementsController.instance.loadSettlements();
      List<SettlementRequest> requests = const [];
      try {
        requests = await SettlementsController.instance.loadRequests();
      } on ApiException {
        // Live GET /settlements/requests is broken (route conflict). Continue.
        requests = SettlementsController.instance.requests;
      }
      if (!mounted) return;
      setState(() {
        _settlements = settlements;
        _requests = requests;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _meId => AuthController.instance.user?.id ?? 1;

  Future<void> _accept(SettlementRequest req) async {
    final method = await _askAcceptMethod();
    if (method == null || !mounted) return;
    try {
      await SettlementsController.instance.acceptRequest(
        req.id,
        paymentMethod: method.isEmpty ? null : method,
      );
      if (!mounted) return;
      showApiMessage(context, 'Request accepted');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<String?> _askAcceptMethod() async {
    String selected = 'venmo';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accept request',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Payment method (optional)',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kSettlementPaymentMethods.map((m) {
                      final active = selected == m;
                      return ChoiceChip(
                        label: Text(m.replaceAll('_', ' ')),
                        selected: active,
                        onSelected: (_) => setModal(() => selected = m),
                        selectedColor: AppColors.mintWash,
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mint,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true) return null;
    return selected;
  }

  Future<void> _decline(SettlementRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Decline request?',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SettlementsController.instance.declineRequest(req.id);
      if (!mounted) return;
      showApiMessage(context, 'Request declined');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((r) => r.isPending).toList();
    final incoming =
        pending.where((r) => r.debtorId == _meId).toList();
    final outgoing =
        pending.where((r) => r.requesterId == _meId).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _load,
          child: ListView(
            children: [
              AppHeader(
                title: 'Settlements',
                subtitle: 'Settle up & payment requests',
                onBack: () => Navigator.pop(context),
              ),
              SoftTile(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecordSettlementScreen(),
                    ),
                  );
                  if (mounted) _load();
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.mintWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.handshake_outlined,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Settle up',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              SoftTile(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SendPaymentRequestScreen(),
                    ),
                  );
                  if (mounted) _load();
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.request_page_outlined,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Send payment request',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              SoftTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentDeeplinkScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: AppColors.forestSoft,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment deep link',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else ...[
                if (incoming.isNotEmpty) ...[
                  const SectionLabel('Incoming requests'),
                  ...incoming.map(
                    (r) => SoftTile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r.requesterName ?? 'Someone'} requested',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (r.groupName != null) r.groupName!,
                                        if (r.message != null &&
                                            r.message!.isNotEmpty)
                                          r.message!,
                                      ].join(' · '),
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MoneyText(r.amount, positive: false, size: 16),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _decline(r),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _accept(r),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.mint,
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (outgoing.isNotEmpty) ...[
                  const SectionLabel('Sent requests'),
                  ...outgoing.map(
                    (r) => SoftTile(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You requested ${r.debtorName ?? 'someone'}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                                Text(
                                  [
                                    if (r.groupName != null) r.groupName!,
                                    if (r.message != null &&
                                        r.message!.isNotEmpty)
                                      r.message!,
                                    'pending',
                                  ].join(' · '),
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MoneyText(r.amount, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
                const SectionLabel('Recent settlements'),
                if (_settlements.isEmpty)
                  const EmptyHint(message: 'No settlements yet')
                else
                  ..._settlements.map((s) {
                    final iPaid = s.payerId == _meId;
                    final title = iPaid
                        ? 'You paid ${s.payeeName ?? 'someone'}'
                        : '${s.payerName ?? 'Someone'} paid you';
                    final subtitle = [
                      if (s.groupName != null) s.groupName!,
                      if (s.paymentMethod != null)
                        s.paymentMethod!.replaceAll('_', ' '),
                      if (s.settlementDate != null) s.settlementDate!,
                    ].join(' · ');
                    return SoftTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SettlementDetailScreen(
                                  settlementId: s.id,
                                  initial: s,
                                ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          MoneyText(
                            s.amount,
                            positive: iPaid ? false : true,
                            size: 16,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}