import 'package:dou_expo_beta/core/rgb_curves.dart';
import 'package:dou_expo_beta/core/halation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('identity RGB curves preserve every channel value', () {
    const points = [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)];
    final master = RgbCurveProcessor.buildTable(points);
    final red = RgbCurveProcessor.buildTable(points);
    for (var i = 0; i < 256; i++) {
      expect(RgbCurveProcessor.applyChannel(i, master, red), i);
    }
  });

  test('tone curve clamps out-of-range points and output', () {
    final curve = ToneCurve([(x: -1, y: 2), (x: .5, y: .8), (x: 2, y: -1)]);
    expect(curve.evaluate(-2), 0);
    expect(curve.evaluate(2), 1);
    expect(curve.evaluate(.5), closeTo(.8, .0001));
  });

  test('halation leaves image unchanged when intensity is zero', () {
    final source = img.Image(width: 4, height: 4);
    img.fill(source, color: img.ColorRgb8(40, 80, 120));
    final result = HalationProcessor.apply(source, const HalationSettings(intensity: 0));
    expect(result.getPixel(0, 0).r, 40);
    expect(result.getPixel(0, 0).g, 80);
    expect(result.getPixel(0, 0).b, 120);
  });

  test('halation warms bright areas and preserves dimensions', () {
    final source = img.Image(width: 24, height: 24);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    final result = HalationProcessor.apply(source,
      const HalationSettings(threshold: .5, radius: 3, intensity: .8));
    expect(result.width, 24);
    expect(result.height, 24);
    final p = result.getPixel(12, 12);
    expect(p.r, 255);
    expect(p.g, 255);
    expect(p.b, 255);
  });
}
