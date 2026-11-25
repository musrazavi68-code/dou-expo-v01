/// Cubic-free piecewise-linear RGB tone curves. Points are normalized 0..1.
/// The endpoints are always anchored, preventing accidental clipping ranges.
class ToneCurve {
  ToneCurve(Iterable<({double x, double y})> points)
      : points = _normalize(points);

  final List<({double x, double y})> points;

  static List<({double x, double y})> _normalize(
      Iterable<({double x, double y})> input) {
    final sorted = input.map((p) => (
      x: p.x.clamp(0.0, 1.0).toDouble(),
      y: p.y.clamp(0.0, 1.0).toDouble(),
    )).toList()..sort((a, b) => a.x.compareTo(b.x));
    final result = <({double x, double y})>[(x: 0, y: 0)];
    for (final point in sorted) {
      if (point.x <= 0 || point.x >= 1) continue;
      if (result.last.x == point.x) {
        result[result.length - 1] = point;
      } else {
        result.add(point);
      }
    }
    result.add((x: 1, y: 1));
    return List.unmodifiable(result);
  }

  double evaluate(double input) {
    final x = input.clamp(0.0, 1.0).toDouble();
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (x <= b.x) {
        final span = b.x - a.x;
        if (span <= 0) return b.y;
        final t = (x - a.x) / span;
        return (a.y + (b.y - a.y) * t).clamp(0.0, 1.0);
      }
    }
    return 1;
  }

  List<int> get lookupTable =>
      List.generate(256, (i) => (evaluate(i / 255) * 255).round());
}

class RgbCurves {
  const RgbCurves({
    this.master = const [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)],
    this.red = const [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)],
    this.green = const [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)],
    this.blue = const [(x: 0.0, y: 0.0), (x: 1.0, y: 1.0)],
  });

  final List<({double x, double y})> master;
  final List<({double x, double y})> red;
  final List<({double x, double y})> green;
  final List<({double x, double y})> blue;

  Map<String, List<Map<String, double>>> toJson() => {
    'master': _encode(master), 'red': _encode(red),
    'green': _encode(green), 'blue': _encode(blue),
  };

  static List<Map<String, double>> _encode(List<({double x, double y})> points) =>
      points.map((p) => {'x': p.x, 'y': p.y}).toList(growable: false);
}

/// Applies master then per-channel lookup tables in-place to decoded pixels.
class RgbCurveProcessor {
  static List<int> buildTable(List<({double x, double y})> points) =>
      ToneCurve(points).lookupTable;

  static int applyChannel(int value, List<int> master, List<int> channel) {
    final input = value.clamp(0, 255);
    return channel[master[input]].clamp(0, 255);
  }
}
