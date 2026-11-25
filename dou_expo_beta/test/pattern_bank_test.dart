import 'package:flutter_test/flutter_test.dart';
import 'package:dou_expo_beta/exposure_composer.dart';
void main() {
 test('zero EV is neutral', () { expect(ExposureComposer.exposureMatrix(0)[0], 1); });
 test('positive one EV doubles brightness', () { expect(ExposureComposer.exposureMatrix(1)[0], 2); });
 test('negative one EV halves brightness', () { expect(ExposureComposer.exposureMatrix(-1)[0], closeTo(.5, .000001)); });
}
