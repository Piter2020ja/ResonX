import 'package:flutter_test/flutter_test.dart';
import 'package:resonx/main.dart';

void main() {
  testWidgets('ResonX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ResonXApp());
    expect(find.byType(ResonXApp), findsOneWidget);
  });
}