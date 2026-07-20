import 'package:flutter_test/flutter_test.dart';
import 'package:fendo/main.dart';

void main() {
  testWidgets('Login screen shows Fendo brand', (WidgetTester tester) async {
    await tester.pumpWidget(const FendoApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Fendo'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
