import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/group_balances.dart';
import '../models/group_member.dart';
import '../models/group_model.dart';
import 'auth_controller.dart';
import 'groups_api.dart';

/// Groups data: live API or local demo store when [ApiConfig.demoAuth].
class GroupsController extends ChangeNotifier {
  GroupsController._();

  static final GroupsController instance = GroupsController._();

  GroupsApi get _api => AuthController.instance.groupsApi;

  final List<GroupModel> _groups = [];
  final Map<int, List<GroupMember>> _members = {};
  final Map<int, GroupBalances> _balances = {};
  int _nextId = 100;

  List<GroupModel> get groups => List.unmodifiable(_groups);

  GroupModel? groupById(int? id) {
    if (id == null) return null;
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  void _seedDemoIfNeeded() {
    if (_groups.isNotEmpty) return;
    _groups.addAll([
      const GroupModel(
        id: 1,
        name: 'Bali Trip',
        type: 'vacation',
        currency: 'USD',
        memberCount: 4,
        netBalance: 42.50,
        role: 'admin',
      ),
      const GroupModel(
        id: 2,
        name: 'Apartment 4B',
        type: 'apartment',
        currency: 'USD',
        memberCount: 3,
        netBalance: -120,
        role: 'member',
      ),
      const GroupModel(
        id: 3,
        name: 'Weekend Crew',
        type: 'friends',
        currency: 'USD',
        memberCount: 5,
        netBalance: 18,
        role: 'admin',
      ),
    ]);
    _members[1] = const [
      GroupMember(
        userId: 1,
        name: 'You',
        email: 'demo@fendo.app',
        role: 'admin',
        balance: 42.5,
      ),
      GroupMember(
        userId: 2,
        name: 'Sam',
        email: 'sam@fendo.app',
        role: 'member',
        balance: -20,
      ),
      GroupMember(
        userId: 3,
        name: 'Maya',
        email: 'maya@fendo.app',
        role: 'member',
        balance: -22.5,
      ),
    ];
    _balances[1] = const GroupBalances(
      summary: GroupBalanceSummary(
        youOwe: 0,
        youAreOwed: 42.5,
        netBalance: 42.5,
      ),
      balances: [
        GroupBalanceRow(userId: 2, name: 'Sam', amount: -20),
        GroupBalanceRow(userId: 3, name: 'Maya', amount: -22.5),
      ],
      simplified: [
        GroupBalanceRow(userId: 2, name: 'Sam owes you', amount: 20),
        GroupBalanceRow(userId: 3, name: 'Maya owes you', amount: 22.5),
      ],
    );
  }

  Future<List<GroupModel>> loadGroups() async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      notifyListeners();
      return groups;
    }
    final list = await _api.listGroups();
    _groups
      ..clear()
      ..addAll(list);
    notifyListeners();
    return groups;
  }

  Future<GroupModel> createGroup({
    required String name,
    required String type,
    required String currency,
    required bool simplifyDebts,
    List<String> memberEmails = const [],
  }) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final me = AuthController.instance.user;
      final group = GroupModel(
        id: _nextId++,
        name: name,
        type: type,
        currency: currency,
        simplifyDebts: simplifyDebts,
        memberCount: 1 + memberEmails.length,
        role: 'admin',
        netBalance: 0,
      );
      _groups.insert(0, group);
      _members[group.id] = [
        GroupMember(
          userId: me?.id ?? 1,
          name: me?.name ?? 'You',
          email: me?.email ?? 'demo@fendo.app',
          role: 'admin',
        ),
        ...memberEmails.map(
          (e) => GroupMember(
            userId: _nextId++,
            name: e.split('@').first,
            email: e,
          ),
        ),
      ];
      notifyListeners();
      return group;
    }
    final group = await _api.createGroup(
      name: name,
      type: type,
      currency: currency,
      simplifyDebts: simplifyDebts,
      memberEmails: memberEmails,
    );
    _groups.insert(0, group);
    notifyListeners();
    return group;
  }

  Future<GroupModel> getGroup(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _groups.firstWhere(
        (g) => g.id == id,
        orElse: () => throw ApiException(message: 'Group not found'),
      );
    }
    final group = await _api.getGroup(id);
    final i = _groups.indexWhere((g) => g.id == id);
    if (i >= 0) {
      _groups[i] = group;
    } else {
      _groups.add(group);
    }
    notifyListeners();
    return group;
  }

  Future<GroupModel> updateGroup(
    int id, {
    String? name,
    String? type,
    String? currency,
    bool? simplifyDebts,
  }) async {
    if (ApiConfig.demoAuth) {
      final i = _groups.indexWhere((g) => g.id == id);
      if (i < 0) throw ApiException(message: 'Group not found');
      final updated = _groups[i].copyWith(
        name: name,
        type: type,
        currency: currency,
        simplifyDebts: simplifyDebts,
      );
      _groups[i] = updated;
      notifyListeners();
      return updated;
    }
    final group = await _api.updateGroup(
      id,
      name: name,
      type: type,
      currency: currency,
      simplifyDebts: simplifyDebts,
    );
    final i = _groups.indexWhere((g) => g.id == id);
    if (i >= 0) _groups[i] = group;
    notifyListeners();
    return group;
  }

  Future<void> deleteGroup(int id) async {
    if (!ApiConfig.demoAuth) {
      await _api.deleteGroup(id);
    }
    _groups.removeWhere((g) => g.id == id);
    _members.remove(id);
    _balances.remove(id);
    notifyListeners();
  }

  Future<GroupModel> archiveGroup(int id, {required bool archive}) async {
    if (ApiConfig.demoAuth) {
      final i = _groups.indexWhere((g) => g.id == id);
      if (i < 0) throw ApiException(message: 'Group not found');
      _groups[i] = _groups[i].copyWith(archived: archive);
      notifyListeners();
      return _groups[i];
    }
    final group = await _api.archiveGroup(id, archive: archive);
    final i = _groups.indexWhere((g) => g.id == id);
    if (i >= 0) _groups[i] = group;
    notifyListeners();
    return group;
  }

  Future<void> leaveGroup(int id) async {
    if (!ApiConfig.demoAuth) {
      await _api.leaveGroup(id);
    }
    _groups.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<InviteLinkResult> createInviteLink(int id) async {
    if (ApiConfig.demoAuth) {
      return InviteLinkResult(
        inviteToken: 'demo-invite-$id',
        inviteLink: 'https://fendo.app/join/demo-invite-$id',
        expiresAt: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      );
    }
    return _api.createInviteLink(id);
  }

  Future<InviteMembersResult> inviteByEmail(
    int id, {
    required List<String> emails,
  }) async {
    if (ApiConfig.demoAuth) {
      final list = _members.putIfAbsent(id, () => []);
      final added = <String>[];
      for (final e in emails) {
        if (list.any((m) => m.email == e)) continue;
        list.add(
          GroupMember(
            userId: _nextId++,
            name: e.split('@').first,
            email: e,
          ),
        );
        added.add(e);
      }
      final gi = _groups.indexWhere((g) => g.id == id);
      if (gi >= 0) {
        _groups[gi] = _groups[gi].copyWith(memberCount: list.length);
      }
      notifyListeners();
      return InviteMembersResult(added: added);
    }
    return _api.inviteByEmail(id, emails: emails);
  }

  Future<InviteMembersResult> inviteByPhone(
    int id, {
    required List<String> phones,
  }) async {
    if (ApiConfig.demoAuth) {
      final list = _members.putIfAbsent(id, () => []);
      final added = <String>[];
      for (final p in phones) {
        if (list.any((m) => m.email == p)) continue;
        list.add(
          GroupMember(
            userId: _nextId++,
            name: p,
            email: '',
          ),
        );
        added.add(p);
      }
      final gi = _groups.indexWhere((g) => g.id == id);
      if (gi >= 0) {
        _groups[gi] = _groups[gi].copyWith(memberCount: list.length);
      }
      notifyListeners();
      return InviteMembersResult(added: added);
    }
    return _api.inviteByPhone(id, phones: phones);
  }

  /// Invite selected contacts via email and/or phone (Postman v1.0.3).
  Future<InviteMembersResult> inviteContacts(
    int id, {
    List<String> emails = const [],
    List<String> phones = const [],
  }) async {
    var result = const InviteMembersResult();
    if (emails.isNotEmpty) {
      result = result.merge(await inviteByEmail(id, emails: emails));
    }
    if (phones.isNotEmpty) {
      result = result.merge(await inviteByPhone(id, phones: phones));
    }
    return result;
  }

  Future<GroupModel> joinByToken(String token) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      final group = GroupModel(
        id: _nextId++,
        name: 'Joined group',
        type: 'friends',
        memberCount: 2,
        role: 'member',
      );
      _groups.insert(0, group);
      notifyListeners();
      return group;
    }
    final group = await _api.joinByToken(token);
    _groups.insert(0, group);
    notifyListeners();
    return group;
  }

  Future<List<GroupMember>> getMembers(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return List.unmodifiable(_members[id] ?? const []);
    }
    final list = await _api.getMembers(id);
    _members[id] = list;
    notifyListeners();
    return list;
  }

  Future<GroupMember> updateMemberRole(
    int groupId,
    int userId, {
    required String role,
  }) async {
    if (ApiConfig.demoAuth) {
      final list = _members[groupId] ?? [];
      final i = list.indexWhere((m) => m.userId == userId);
      if (i < 0) throw ApiException(message: 'Member not found');
      list[i] = list[i].copyWith(role: role);
      _members[groupId] = list;
      notifyListeners();
      return list[i];
    }
    return _api.updateMemberRole(groupId, userId, role: role);
  }

  Future<void> removeMember(int groupId, int userId) async {
    if (ApiConfig.demoAuth) {
      final list = _members[groupId] ?? [];
      list.removeWhere((m) => m.userId == userId);
      _members[groupId] = list;
      final gi = _groups.indexWhere((g) => g.id == groupId);
      if (gi >= 0) {
        _groups[gi] = _groups[gi].copyWith(memberCount: list.length);
      }
      notifyListeners();
      return;
    }
    await _api.removeMember(groupId, userId);
  }

  Future<GroupBalances> getBalances(int id) async {
    if (ApiConfig.demoAuth) {
      _seedDemoIfNeeded();
      return _balances[id] ??
          const GroupBalances(summary: GroupBalanceSummary());
    }
    final bal = await _api.getBalances(id);
    _balances[id] = bal;
    return bal;
  }

  Future<GroupModel> muteNotifications(int id, {required bool muted}) async {
    if (ApiConfig.demoAuth) {
      final i = _groups.indexWhere((g) => g.id == id);
      if (i < 0) throw ApiException(message: 'Group not found');
      _groups[i] = _groups[i].copyWith(muted: muted);
      notifyListeners();
      return _groups[i];
    }
    final group = await _api.muteNotifications(id, muted: muted);
    final i = _groups.indexWhere((g) => g.id == id);
    if (i >= 0) _groups[i] = group;
    notifyListeners();
    return group;
  }

  Future<GroupModel> uploadPhoto({
    required int id,
    required String filePath,
    required String fileName,
  }) async {
    if (ApiConfig.demoAuth) {
      final i = _groups.indexWhere((g) => g.id == id);
      if (i < 0) throw ApiException(message: 'Group not found');
      // Local path as preview in demo.
      _groups[i] = _groups[i].copyWith(photo: filePath);
      notifyListeners();
      return _groups[i];
    }
    final group = await _api.uploadPhoto(
      id: id,
      filePath: filePath,
      fileName: fileName,
    );
    final i = _groups.indexWhere((g) => g.id == id);
    if (i >= 0) _groups[i] = group;
    notifyListeners();
    return group;
  }
}
