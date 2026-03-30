import 'package:flutter_test/flutter_test.dart';
import 'package:myfyp_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UniRideApp());
    expect(find.byType(UniRideApp), findsOneWidget);
  });
}
