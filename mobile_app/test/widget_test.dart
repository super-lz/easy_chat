import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('renders Easy Chat home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EasyChatApp());

    expect(find.text('Easy Chat'), findsOneWidget);
    expect(find.text('Connect to Computer'), findsOneWidget);
    expect(find.text('Recent History'), findsOneWidget);
  });
}
