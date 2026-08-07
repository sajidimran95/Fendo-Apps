import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/activity_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'activity_tile.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  bool _loadingMore = false;
  bool _initial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    ActivityController.instance.addListener(_onController);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    ActivityController.instance.removeListener(_onController);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      ActivityController.instance.silentRefresh();
    }
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _bootstrap() async {
    final ctrl = ActivityController.instance;
    // Show cache immediately if already filled by live sync.
    if (ctrl.items.isNotEmpty) {
      setState(() => _initial = false);
      // ignore: unawaited_futures
      ctrl.silentRefresh();
      return;
    }
    try {
      await ctrl.loadActivity();
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _initial = false);
    }
  }

  void _onScroll() {
    final ctrl = ActivityController.instance;
    if (!_scroll.hasClients || _loadingMore || ctrl.loading) return;
    if (!ctrl.hasMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      _loadMore();
    }
  }

  Future<void> _pullRefresh() async {
    try {
      await ActivityController.instance.loadActivity();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      await ActivityController.instance.loadMore();
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ActivityController.instance;
    final items = ctrl.items;
    final loading = (_initial || ctrl.loading) && items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _pullRefresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: AppHeader(
                  title: 'Activity',
                  subtitle: 'Updates live · pull to refresh anytime',
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(message: 'No activity yet'),
                )
              else ...[
                if (ctrl.isLive)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: _LiveBadge(),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => ActivityTile(item: items[i]),
                    childCount: items.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: _loadingMore
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: AppColors.mint,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : ctrl.hasMore
                            ? TextButton(
                                onPressed: _loadMore,
                                child: Text(
                                  'Load more',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mint,
                                  ),
                                ),
                              )
                            : Text(
                                'You’re all caught up',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Live updates',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
