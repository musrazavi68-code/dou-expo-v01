import 'package:flutter_test/flutter_test.dart';
import 'package:dou_expo_beta/main.dart';

void main() {
  testWidgets('three independent studio environments are reachable', (tester) async {
    await tester.pumpWidget(const DouExpoApp());
    await tester.pump();

    expect(find.text('ORDINARY CAMERA'), findsOneWidget);
    expect(find.text('ORDINARY'), findsOneWidget);
    expect(find.text('DOUBLE'), findsOneWidget);
    expect(find.text('DARKROOM'), findsOneWidget);

    await tester.tap(find.text('DOUBLE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DOU EXPO'), findsOneWidget);
    expect(find.text('FIRST PHOTO'), findsWidgets);
    expect(find.text('PATTERN / 2ND'), findsOneWidget);
    expect(find.text('BLEND'), findsOneWidget);

    await tester.tap(find.text('DARKROOM'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('DARKROOM'), findsWidgets);
    expect(find.text('OPEN PHOTO'), findsOneWidget);
  });
}
