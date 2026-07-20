class NotificationSettings {
  const NotificationSettings({
    this.allEnabled = true,
    this.expenseAdded = true,
    this.expenseEdited = true,
    this.settlementReceived = true,
    this.settlementRequested = true,
    this.billReminder = true,
    this.billOverdue = true,
    this.groupInvitation = true,
    this.memberJoined = true,
    this.weeklySummary = true,
    this.emailNotifications = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final bool allEnabled;
  final bool expenseAdded;
  final bool expenseEdited;
  final bool settlementReceived;
  final bool settlementRequested;
  final bool billReminder;
  final bool billOverdue;
  final bool groupInvitation;
  final bool memberJoined;
  final bool weeklySummary;
  final bool emailNotifications;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key, [bool fallback = true]) {
      final v = json[key];
      if (v is bool) return v;
      if (v == 1 || v == '1' || v == 'true') return true;
      if (v == 0 || v == '0' || v == 'false') return false;
      return fallback;
    }

    return NotificationSettings(
      allEnabled: flag('all_enabled'),
      expenseAdded: flag('expense_added'),
      expenseEdited: flag('expense_edited'),
      settlementReceived: flag('settlement_received'),
      settlementRequested: flag('settlement_requested'),
      billReminder: flag('bill_reminder'),
      billOverdue: flag('bill_overdue'),
      groupInvitation: flag('group_invitation'),
      memberJoined: flag('member_joined'),
      weeklySummary: flag('weekly_summary'),
      emailNotifications: flag('email_notifications'),
      quietHoursStart: json['quiet_hours_start']?.toString(),
      quietHoursEnd: json['quiet_hours_end']?.toString(),
    );
  }

  NotificationSettings copyWith({
    bool? allEnabled,
    bool? expenseAdded,
    bool? expenseEdited,
    bool? settlementReceived,
    bool? settlementRequested,
    bool? billReminder,
    bool? billOverdue,
    bool? groupInvitation,
    bool? memberJoined,
    bool? weeklySummary,
    bool? emailNotifications,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationSettings(
      allEnabled: allEnabled ?? this.allEnabled,
      expenseAdded: expenseAdded ?? this.expenseAdded,
      expenseEdited: expenseEdited ?? this.expenseEdited,
      settlementReceived: settlementReceived ?? this.settlementReceived,
      settlementRequested: settlementRequested ?? this.settlementRequested,
      billReminder: billReminder ?? this.billReminder,
      billOverdue: billOverdue ?? this.billOverdue,
      groupInvitation: groupInvitation ?? this.groupInvitation,
      memberJoined: memberJoined ?? this.memberJoined,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'all_enabled': allEnabled,
        'expense_added': expenseAdded,
        'expense_edited': expenseEdited,
        'settlement_received': settlementReceived,
        'settlement_requested': settlementRequested,
        'bill_reminder': billReminder,
        'bill_overdue': billOverdue,
        'group_invitation': groupInvitation,
        'member_joined': memberJoined,
        'weekly_summary': weeklySummary,
        'email_notifications': emailNotifications,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
      };
}
