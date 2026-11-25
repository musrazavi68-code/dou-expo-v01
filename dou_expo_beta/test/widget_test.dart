import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:dou_expo_beta/main.dart';

void main() {
  testWidgets('Dou Expo editor renders its main controls', (tester) async {
    await tester.pumpWidget(const DouExpoApp());
    await tester.pump();

    expect(find.text('DOU EXPO · BETA'), findsOneWidget);
    expect(find.text('PATTERN OPACITY'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_mosaic_outlined), findsOneWidget);
  });
}
