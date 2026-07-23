import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/network/api_exception.dart';
import '../models/contact_match_model.dart';
import 'auth_controller.dart';

/// Reads the device phonebook and badges rows via POST /contacts/match.
class ContactsMatchService {
  ContactsMatchService._();

  static List<ContactMatchResult>? _cache;
  static DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 5);
  static Future<List<ContactMatchResult>>? _inFlight;

  /// Requests OS contacts permission (if needed).
  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) return true;
    return FlutterContacts.requestPermission(readonly: true);
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Clears the in-memory contacts cache (e.g. after logout).
  static void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
  }

  static List<String> _phonesOf(Contact c) {
    final out = <String>[];
    final seen = <String>{};
    for (final p in c.phones) {
      final raw = p.number.trim();
      if (raw.isEmpty) continue;
      if (seen.add(raw)) out.add(raw);
    }
    return out;
  }

  static List<String> _emailsOf(Contact c) {
    final out = <String>[];
    final seen = <String>{};
    for (final e in c.emails) {
      final raw = e.address.trim();
      if (!raw.contains('@')) continue;
      if (seen.add(raw.toLowerCase())) out.add(raw);
    }
    return out;
  }

  static List<ContactMatchInput> _inputsFromDevice(List<Contact> deviceContacts) {
    final inputs = <ContactMatchInput>[];
    for (final c in deviceContacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;

      final phones = _phonesOf(c);
      final emails = _emailsOf(c);
      // Skip name-only rows — nothing to invite/match with.
      if (phones.isEmpty && emails.isEmpty) continue;

      inputs.add(
        ContactMatchInput(
          localId: c.id.isNotEmpty ? c.id : 'contact-${inputs.length}',
          name: name,
          phones: phones,
          emails: emails,
        ),
      );
    }
    return inputs;
  }

  static List<ContactMatchResult> _deviceOnlyResults(
    List<ContactMatchInput> inputs,
  ) {
    final rows = inputs
        .map(
          (c) => ContactMatchResult(
            localId: c.localId,
            name: c.name,
            isAppUser: false,
            phones: c.phones,
            emails: c.emails,
          ),
        )
        .toList();
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  static Future<List<ContactMatchResult>> _matchChunks(
    List<ContactMatchInput> inputs,
  ) async {
    const chunkSize = 100;
    final chunks = <List<ContactMatchInput>>[];
    for (var i = 0; i < inputs.length; i += chunkSize) {
      final end =
          (i + chunkSize < inputs.length) ? i + chunkSize : inputs.length;
      chunks.add(inputs.sublist(i, end));
    }

    // Match chunks in parallel (cap concurrency lightly via batching).
    const parallel = 3;
    final matched = <ContactMatchResult>[];
    for (var i = 0; i < chunks.length; i += parallel) {
      final batch = chunks.sublist(
        i,
        (i + parallel < chunks.length) ? i + parallel : chunks.length,
      );
      final parts = await Future.wait(batch.map(_matchOneChunk));
      for (final part in parts) {
        matched.addAll(part);
      }
    }

    matched.sort((a, b) {
      if (a.isAppUser != b.isAppUser) return a.isAppUser ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matched;
  }

  static Future<List<ContactMatchResult>> _matchOneChunk(
    List<ContactMatchInput> chunk,
  ) async {
    final byLocalId = {for (final c in chunk) c.localId: c};
    try {
      final rows =
          await AuthController.instance.contactsApi.matchContacts(chunk);
      final out = <ContactMatchResult>[];
      final seen = <String>{};
      for (final row in rows) {
        final local = byLocalId[row.localId];
        seen.add(row.localId);
        out.add(
          ContactMatchResult(
            localId: row.localId.isNotEmpty
                ? row.localId
                : (local?.localId ?? ''),
            name: row.name.trim().isNotEmpty
                ? row.name.trim()
                : (local?.name ?? ''),
            isAppUser: row.isAppUser || row.user != null,
            user: row.user,
            phones: row.phones.isNotEmpty
                ? row.phones
                : (local?.phones ?? const []),
            emails: row.emails.isNotEmpty
                ? row.emails
                : (local?.emails ?? const []),
          ),
        );
      }
      for (final c in chunk) {
        if (seen.contains(c.localId)) continue;
        out.add(
          ContactMatchResult(
            localId: c.localId,
            name: c.name,
            isAppUser: false,
            phones: c.phones,
            emails: c.emails,
          ),
        );
      }
      return out;
    } on ApiException {
      return chunk
          .map(
            (c) => ContactMatchResult(
              localId: c.localId,
              name: c.name,
              isAppUser: false,
              phones: c.phones,
              emails: c.emails,
            ),
          )
          .toList();
    }
  }

  /// Loads device contacts, then matches against Fendo users.
  ///
  /// [onProgress] is called as soon as the phonebook is ready (before API
  /// match), so loan / invite screens can render immediately.
  static Future<List<ContactMatchResult>> loadMatchedContacts({
    void Function(List<ContactMatchResult> partial)? onProgress,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      onProgress?.call(_cache!);
      return _cache!;
    }

    // Deduplicate concurrent loads (loan + invite opening together).
    if (_inFlight != null && !forceRefresh) {
      final shared = await _inFlight!;
      onProgress?.call(shared);
      return shared;
    }

    final future = _loadMatchedContactsInternal(onProgress: onProgress);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  static Future<List<ContactMatchResult>> _loadMatchedContactsInternal({
    void Function(List<ContactMatchResult> partial)? onProgress,
  }) async {
    var allowed = await hasPermission();
    if (!allowed) {
      allowed = await requestPermission();
    }
    if (!allowed) {
      throw ApiException(
        message: 'Contacts permission is required to show your phonebook',
      );
    }

    // One bulk read — avoid per-contact getContact (very slow on Android).
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final inputs = _inputsFromDevice(deviceContacts);
    if (inputs.isEmpty) {
      _cache = const [];
      _cacheAt = DateTime.now();
      onProgress?.call(const []);
      return const [];
    }

    // Show phonebook immediately, then badge On Fendo via API.
    final quick = _deviceOnlyResults(inputs);
    onProgress?.call(quick);

    final matched = await _matchChunks(inputs);
    _cache = matched;
    _cacheAt = DateTime.now();
    return matched;
  }
}
