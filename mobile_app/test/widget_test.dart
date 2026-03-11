import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('renders EasyChat home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('EasyChat'), findsOneWidget);
    expect(find.text('连接电脑'), findsOneWidget);
  });
}
