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
    // flutter_contacts also has its own request path on some devices.
    return FlutterContacts.requestPermission(readonly: true);
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
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

    final deviceContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final inputs = <ContactMatchInput>[];
    for (final c in deviceContacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      final phones = c.phones
          .map((p) => p.number.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      final emails = c.emails
          .map((e) => e.address.trim())
          .where((e) => e.contains('@'))
          .toList();
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

    // Match in chunks to avoid huge payloads.
    const chunkSize = 100;
    final matched = <ContactMatchResult>[];
    for (var i = 0; i < inputs.length; i += chunkSize) {
      final end = (i + chunkSize < inputs.length) ? i + chunkSize : inputs.length;
      final chunk = inputs.sublist(i, end);
      try {
        final rows =
            await AuthController.instance.contactsApi.matchContacts(chunk);
        matched.addAll(rows);
      } on ApiException {
        // Fall back to unmatched device rows for this chunk.
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
