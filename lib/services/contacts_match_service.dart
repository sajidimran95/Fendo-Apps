import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/network/api_exception.dart';
import '../models/contact_match_model.dart';
import 'auth_controller.dart';

/// Reads the device phonebook and badges rows via POST /contacts/match.
class ContactsMatchService {
  ContactsMatchService._();

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

  static List<String> _phonesOf(Contact c) {
    final out = <String>[];
    final seen = <String>{};
    for (final p in c.phones) {
      final raw = p.number.trim();
      if (raw.isEmpty) continue;
      // Keep display form; also keep digits-only for matching uniqueness.
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

  /// Loads device contacts, then matches against Fendo users.
  static Future<List<ContactMatchResult>> loadMatchedContacts() async {
    var allowed = await hasPermission();
    if (!allowed) {
      allowed = await requestPermission();
    }
    if (!allowed) {
      throw ApiException(
        message: 'Contacts permission is required to show your phonebook',
      );
    }

    // Light list first (faster), then fill properties when missing.
    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final inputs = <ContactMatchInput>[];
    for (final c in deviceContacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;

      var phones = _phonesOf(c);
      var emails = _emailsOf(c);

      // Some Android builds return name-only until the contact is fully loaded.
      if (phones.isEmpty && emails.isEmpty && c.id.isNotEmpty) {
        try {
          final full = await FlutterContacts.getContact(
            c.id,
            withProperties: true,
            withPhoto: false,
          );
          if (full != null) {
            phones = _phonesOf(full);
            emails = _emailsOf(full);
          }
        } catch (_) {
          // Keep empty; skip below if still no phone/email.
        }
      }

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

    if (inputs.isEmpty) {
      return const [];
    }

    const chunkSize = 100;
    final matched = <ContactMatchResult>[];
    for (var i = 0; i < inputs.length; i += chunkSize) {
      final end =
          (i + chunkSize < inputs.length) ? i + chunkSize : inputs.length;
      final chunk = inputs.sublist(i, end);
      final byLocalId = {for (final c in chunk) c.localId: c};

      try {
        final rows =
            await AuthController.instance.contactsApi.matchContacts(chunk);
        final seen = <String>{};
        for (final row in rows) {
          final local = byLocalId[row.localId];
          seen.add(row.localId);
          // API often omits phones/emails — keep device values.
          matched.add(
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
        // Any device contact the API skipped.
        for (final c in chunk) {
          if (seen.contains(c.localId)) continue;
          matched.add(
            ContactMatchResult(
              localId: c.localId,
              name: c.name,
              isAppUser: false,
              phones: c.phones,
              emails: c.emails,
            ),
          );
        }
      } on ApiException {
        matched.addAll(
          chunk.map(
            (c) => ContactMatchResult(
              localId: c.localId,
              name: c.name,
              isAppUser: false,
              phones: c.phones,
              emails: c.emails,
            ),
          ),
        );
      }
    }

    matched.sort((a, b) {
      if (a.isAppUser != b.isAppUser) return a.isAppUser ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matched;
  }
}
