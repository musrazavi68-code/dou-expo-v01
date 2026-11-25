import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// CPU image-space halation pass. The glow is generated from bright pixels,
/// blurred at a scale-dependent radius, then composited with a warm tint.
class HalationSettings {
  const HalationSettings({
    this.threshold = .78,
    this.radius = 12,
    this.intensity = .28,
    this.red = 1,
    this.green = .22,
    this.blue = .04,
  });
  final double threshold;
  final int radius;
  final double intensity;
  final double red, green, blue;

  HalationSettings clamped() => HalationSettings(
    threshold: threshold.clamp(0.0, 1.0),
    radius: radius.clamp(1, 80),
    intensity: intensity.clamp(0.0, 1.0),
    red: red.clamp(0.0, 1.0),
    green: green.clamp(0.0, 1.0),
    blue: blue.clamp(0.0, 1.0),
  );
}

class HalationProcessor {
  /// Returns a new image; the caller retains ownership of [source].
  static img.Image apply(img.Image source, HalationSettings settings) {
    final s = settings.clamped();
    if (s.intensity == 0) return img.Image.from(source);
    final mask = img.Image(width: source.width, height: source.height, numChannels: 4);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final p = source.getPixel(x, y);
        final luminance = (.2126 * p.r + .7152 * p.g + .0722 * p.b) / 255;
        final t = ((luminance - s.threshold) / math.max(.0001, 1 - s.threshold)).clamp(0.0, 1.0);
        final alpha = (t * 255).round();
        mask.setPixelRgba(x, y, 255, 255, 255, alpha);
      }
    }
    final blurred = img.gaussianBlur(mask, radius: s.radius);
    final output = img.Image.from(source);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final glow = blurred.getPixel(x, y).a / 255 * s.intensity;
        if (glow <= .001) continue;
        final p = source.getPixel(x, y);
        output.setPixelRgba(
          x, y,
          (p.r + (255 - p.r) * glow * s.red).round().clamp(0, 255),
          (p.g + (255 - p.g) * glow * s.green).round().clamp(0, 255),
          (p.b + (255 - p.b) * glow * s.blue).round().clamp(0, 255),
          p.a.toInt(),
        );
      }
    }
    return output;
  }
}
