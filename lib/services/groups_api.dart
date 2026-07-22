import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/group_balances.dart';
import '../models/group_member.dart';
import '../models/group_model.dart';

/// Groups endpoints 3.1 – 3.14 (+ photo / mute).
class GroupsApi {
  GroupsApi(this._client);

  final ApiClient _client;

  GroupModel _parseGroup(dynamic body) {
    final map = unwrapMap(body);
    final group = map['group'] ?? map;
    if (group is! Map) {
      throw ApiException(message: 'Invalid group response');
    }
    return GroupModel.fromJson(Map<String, dynamic>.from(group));
  }

  /// 3.1 GET /groups
  Future<List<GroupModel>> listGroups() async {
    final res = await _client.get('/groups');
    return unwrapList(res.data, key: 'groups').map(GroupModel.fromJson).toList();
  }

  /// 3.2 POST /groups
  Future<GroupModel> createGroup({
    required String name,
    required String type,
    required String currency,
    required bool simplifyDebts,
    List<String> memberEmails = const [],
  }) async {
    final res = await _client.post(
      '/groups',
      data: {
        'name': name,
        'type': type,
        'currency': currency,
        'simplify_debts': simplifyDebts,
        'member_emails': memberEmails,
      },
    );
    return _parseGroup(res.data);
  }

  /// 3.3 GET /groups/{id}
  Future<GroupModel> getGroup(int id) async {
    final res = await _client.get('/groups/$id');
    return _parseGroup(res.data);
  }

  /// 3.4 PUT /groups/{id}
  Future<GroupModel> updateGroup(
    int id, {
    String? name,
    String? type,
    String? currency,
    bool? simplifyDebts,
  }) async {
    final res = await _client.put(
      '/groups/$id',
      data: {
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (currency != null) 'currency': currency,
        if (simplifyDebts != null) 'simplify_debts': simplifyDebts,
      },
    );
    return _parseGroup(res.data);
  }

  /// 3.5 DELETE /groups/{id}
  Future<void> deleteGroup(int id) async {
    await _client.delete('/groups/$id');
  }

  /// 3.6 POST /groups/{id}/archive | unarchive
  Future<GroupModel> archiveGroup(int id, {required bool archive}) async {
    final path = archive ? '/groups/$id/archive' : '/groups/$id/unarchive';
    final res = await _client.post(path);
    return _parseGroup(res.data);
  }

  /// 3.7 POST /groups/{id}/leave
  Future<void> leaveGroup(int id) async {
    await _client.post('/groups/$id/leave');
  }

  /// 3.8 POST /groups/{id}/invite-link
  Future<InviteLinkResult> createInviteLink(int id) async {
    final res = await _client.post('/groups/$id/invite-link');
    return InviteLinkResult.fromJson(unwrapMap(res.data));
  }

  /// 3.9 POST /groups/{id}/invite
  Future<InviteMembersResult> inviteByEmail(
    int id, {
    required List<String> emails,
  }) async {
    final res = await _client.post(
      '/groups/$id/invite',
      data: {'emails': emails},
    );
    final map = unwrapMap(res.data);
    return InviteMembersResult.fromJson({
      ...map,
      if (res.data is Map && (res.data as Map)['message'] != null)
        'message': (res.data as Map)['message'],
    });
  }

  /// POST /groups/{id}/invite-phone — add registered users by phone.
  Future<InviteMembersResult> inviteByPhone(
    int id, {
    required List<String> phones,
  }) async {
    final res = await _client.post(
      '/groups/$id/invite-phone',
      data: {'phones': phones},
    );
    final map = unwrapMap(res.data);
    return InviteMembersResult.fromJson({
      ...map,
      if (res.data is Map && (res.data as Map)['message'] != null)
        'message': (res.data as Map)['message'],
    });
  }

  /// 3.10 POST /groups/join/{token}
  Future<GroupModel> joinByToken(String token) async {
    final res = await _client.post('/groups/join/$token');
    return _parseGroup(res.data);
  }

  /// 3.11 GET /groups/{id}/members
  Future<List<GroupMember>> getMembers(int id) async {
    final res = await _client.get('/groups/$id/members');
    return unwrapList(res.data, key: 'members')
        .map(GroupMember.fromJson)
        .toList();
  }

  /// 3.12 PUT /groups/{id}/members/{userId}/role
  Future<GroupMember> updateMemberRole(
    int groupId,
    int userId, {
    required String role,
  }) async {
    final res = await _client.put(
      '/groups/$groupId/members/$userId/role',
      data: {'role': role},
    );
    final map = unwrapMap(res.data);
    final member = map['member'] ?? map;
    if (member is! Map) {
      throw ApiException(message: 'Invalid member response');
    }
    return GroupMember.fromJson(Map<String, dynamic>.from(member));
  }

  /// 3.13 DELETE /groups/{id}/members/{userId}
  Future<void> removeMember(int groupId, int userId) async {
    await _client.delete('/groups/$groupId/members/$userId');
  }

  /// 3.14 GET /groups/{id}/balances
  Future<GroupBalances> getBalances(int id) async {
    final res = await _client.get('/groups/$id/balances');
    return GroupBalances.fromJson(unwrapMap(res.data));
  }

  /// Extra: POST /groups/{id}/photo
  Future<GroupModel> uploadPhoto({
    required int id,
    required String filePath,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _client.postMultipart('/groups/$id/photo', data: form);
    return _parseGroup(res.data);
  }

  /// Extra: PUT /groups/{id}/mute-notifications
  Future<GroupModel> muteNotifications(int id, {required bool muted}) async {
    final res = await _client.put(
      '/groups/$id/mute-notifications',
      data: {'muted': muted},
    );
    return _parseGroup(res.data);
  }
}
