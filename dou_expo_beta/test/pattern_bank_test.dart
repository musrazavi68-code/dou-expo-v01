import 'package:flutter_test/flutter_test.dart';
import 'package:dou_expo_beta/main.dart';

void main() {
  test('pattern bank contains the expected categorized starter patterns', () {
    expect(kPatternBank.length, 10);
    expect(kPatternBank.map((item) => item.id).toSet().length, 10);
    expect(kPatternBank.map((item) => item.category).toSet(),
        containsAll(['Optics', 'Nature', 'Editorial']));
  });
}
