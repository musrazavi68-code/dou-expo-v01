import 'package:flutter_test/flutter_test.dart';
import 'package:dou_expo_beta/main.dart';
void main() {
 testWidgets('Dou Expo editor opens with its functional workflow controls', (tester) async {
  await tester.pumpWidget(const DouExpoApp());
  await tester.pump();
  expect(find.text('DOU EXPO'), findsOneWidget);
  expect(find.text('FIRST PHOTO'), findsWidgets);
  expect(find.text('PATTERN / 2ND'), findsWidgets);
  expect(find.text('BLEND'), findsOneWidget);
  expect(find.text('EXPORT · RATIO · SIZE'), findsOneWidget);
 });
}
