import 'package:flutter_test/flutter_test.dart';
import 'package:dou_expo_beta/main.dart';

void main() {
  test('Dou Expo starts with ten selectable patterns', () {
    expect(kPatternBank, hasLength(10));
    expect(kPatternBank.first.id, 'light_leak');
  });
}
