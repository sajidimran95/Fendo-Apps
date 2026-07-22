import '../models/contact_match_model.dart';

/// Static loan + contact data until contacts/match + expense(group_id:null) are live.
class MockLoans {
  MockLoans._();

  static final List<MockLoan> loans = [
    const MockLoan(
      id: 1,
      personName: 'Alice Smith',
      amount: 40,
      currency: 'USD',
      direction: LoanDirection.give,
      date: '2026-07-18',
      note: 'Coffee & lunch',
    ),
    const MockLoan(
      id: 2,
      personName: 'Bob Khan',
      amount: 25,
      currency: 'USD',
      direction: LoanDirection.take,
      date: '2026-07-15',
      note: 'Uber share',
    ),
    const MockLoan(
      id: 3,
      personName: 'Sara Lee',
      amount: 100,
      currency: 'USD',
      direction: LoanDirection.give,
      date: '2026-07-10',
    ),
  ];

  static double get youLent => loans
      .where((l) => l.isGive)
      .fold(0.0, (s, l) => s + l.amount);

  static double get youBorrowed => loans
      .where((l) => !l.isGive)
      .fold(0.0, (s, l) => s + l.amount);

  /// Simulated phonebook after permission + POST /contacts/match.
  static const matchedContacts = <ContactMatchResult>[
    ContactMatchResult(
      localId: 'device-contact-1',
      name: 'Alice',
      isAppUser: true,
      phones: ['+1 555-123-4567'],
      emails: ['alice@example.com'],
      user: ContactMatchUser(
        id: 12,
        name: 'Alice Smith',
        email: 'alice@example.com',
        phone: '+15551234567',
      ),
    ),
    ContactMatchResult(
      localId: 'device-contact-2',
      name: 'Bob Khan',
      isAppUser: true,
      phones: ['+8801712345678'],
      emails: [],
      user: ContactMatchUser(
        id: 13,
        name: 'Bob Khan',
        email: 'bob@example.com',
        phone: '+8801712345678',
      ),
    ),
    ContactMatchResult(
      localId: 'device-contact-3',
      name: 'Sara Lee',
      isAppUser: true,
      phones: ['5559876543'],
      emails: ['sara@example.com'],
      user: ContactMatchUser(
        id: 14,
        name: 'Sara Lee',
        email: 'sara@example.com',
      ),
    ),
    ContactMatchResult(
      localId: 'device-contact-4',
      name: 'Chris Park',
      isAppUser: false,
      phones: ['+1 555-000-1111'],
      emails: [],
    ),
    ContactMatchResult(
      localId: 'device-contact-5',
      name: 'Dana Ruiz',
      isAppUser: false,
      phones: [],
      emails: ['dana@mail.com'],
    ),
  ];
}
