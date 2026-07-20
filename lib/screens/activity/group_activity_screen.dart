import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/activity_model.dart';
import '../../services/activity_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/common/app_widgets.dart';
import 'activity_tile.dart';

class GroupActivityScreen extends StatefulWidget {
  const GroupActivityScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  final int groupId;
  final String? groupName;

  @override
  State<GroupActivityScreen> createState() => _GroupActivityScreenState();
}

class _GroupActivityScreenState extends State<GroupActivityScreen> {
  List<ActivityItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items =
          await ActivityController.instance.loadGroupActivity(widget.groupId);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mint,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppHeader(
                title: 'Group activity',
                subtitle: widget.groupName,
                onBack: () => Navigator.pop(context),
              ),
              if (_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.mint),
                  ),
                )
              else if (_items.isEmpty)
                const EmptyHint(message: 'No activity in this group yet')
              else
                ..._items.map((a) => ActivityTile(item: a)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
