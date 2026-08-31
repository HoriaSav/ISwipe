import 'package:flutter_test/flutter_test.dart';

import 'package:iswipe/main.dart';

void main() {
  testWidgets('App loads main shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ISwipeApp());
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
  });
}
