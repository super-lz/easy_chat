import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('renders EasyChat home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('EasyChat'), findsOneWidget);
    expect(find.text('扫码连接'), findsOneWidget);
  });
}
