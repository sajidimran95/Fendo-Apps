import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../screens/bills/bill_detail_screen.dart';
import '../screens/bills/bills_screen.dart';
import '../screens/expenses/expense_detail_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/notifications/notification_detail_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settlements/settlement_detail_screen.dart';
import '../screens/settlements/settlements_screen.dart';
import '../services/notifications_controller.dart';

/// Opens the right screen for a notification / push payload.
class NotificationRouter {
  NotificationRouter._();

  static Future<void> open(
    BuildContext context, {
    AppNotification? notification,
    Map<String, dynamic>? pushData,
    bool markRead = true,
  }) async {
    final n = notification ??
        (pushData != null && pushData.isNotEmpty
            ? AppNotification.fromPushData(pushData)
            : null);

    if (n != null && markRead && n.id > 0 && !n.read) {
      try {
        await NotificationsController.instance.markRead(n.id);
      } catch (_) {}
    }

    if (!context.mounted) return;

    final type = (n?.type ?? pushData?['type']?.toString() ?? '')
        .toLowerCase()
        .trim();

    // — Payment request → Settlements (incoming requests) —
    if (_isPaymentRequest(type) || (n?.requestId != null && n!.requestId! > 0)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettlementsScreen(
            highlightRequestId: n?.requestId,
            openRequestsSection: true,
          ),
        ),
      );
      return;
    }

    // — Recorded settlement —
    if (type.contains('settlement') &&
        !type.contains('request') &&
        n?.settlementId != null &&
        n!.settlementId! > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettlementDetailScreen(
            settlementId: n.settlementId!,
          ),
        ),
      );
      return;
    }
    if (type.contains('settlement')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SettlementsScreen(),
        ),
      );
      return;
    }

    // — Expense —
    if (type.contains('expense') &&
        n?.expenseId != null &&
        n!.expenseId! > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseDetailScreen(expenseId: n.expenseId!),
        ),
      );
      return;
    }
    if (type.contains('expense')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ExpensesScreen(),
        ),
      );
      return;
    }

    // — Bill —
    if (type.contains('bill') && n?.billId != null && n!.billId! > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BillDetailScreen(billId: n.billId!),
        ),
      );
      return;
    }
    if (type.contains('bill') || type.contains('reminder')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BillsScreen(),
        ),
      );
      return;
    }

    // — Group —
    if ((type.contains('group') || type.contains('member')) &&
        n?.groupId != null &&
        n!.groupId! > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupDetailScreen(groupId: n.groupId!),
        ),
      );
      return;
    }
    if (type.contains('group') || type.contains('invite')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const GroupsScreen(),
        ),
      );
      return;
    }

    // — View-only / unknown → detail if we have title, else inbox —
    if (n != null && (n.title.isNotEmpty || n.body.isNotEmpty)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationDetailScreen(notification: n),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  static bool _isPaymentRequest(String type) {
    return type.contains('settlement_request') ||
        type.contains('settlement_requested') ||
        type.contains('payment_request') ||
        type.contains('money_request') ||
        type == 'request';
  }
}
