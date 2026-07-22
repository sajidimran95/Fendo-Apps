import '../core/network/api_client.dart';
import '../models/contact_match_model.dart';

/// Contacts Match API — POST /contacts/match (Create Loan phonebook badge).
class ContactsApi {
  ContactsApi(this._client);

  final ApiClient _client;

  Future<List<ContactMatchResult>> matchContacts(
    List<ContactMatchInput> contacts,
  ) async {
    final res = await _client.post(
      '/contacts/match',
      data: {
        'contacts': contacts.map((e) => e.toJson()).toList(),
      },
    );
    return unwrapList(res.data).map(ContactMatchResult.fromJson).toList();
  }
}
