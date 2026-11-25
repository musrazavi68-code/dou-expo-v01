import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Controls where the second exposure is allowed to appear.
enum OverlayMaskMode { fullFrame, insidePortrait, outsidePortrait }

class MaskStroke {
  const MaskStroke({required this.path, required this.width, this.erase = false});
  final Path path;
  final double width;
  final bool erase;
}

/// Real two-image compositor. The second exposure is painted with a true
/// Porter-Duff blend mode; it is not a decorative gradient overlay.
class ExposureComposer {
  /// Normalized head-and-shoulders silhouette, scaled to the output canvas.
  static Path portraitMaskPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * .50, h * .07)
      ..cubicTo(w * .36, h * .07, w * .27, h * .17, w * .27, h * .30)
      ..cubicTo(w * .27, h * .41, w * .34, h * .49, w * .41, h * .52)
      ..cubicTo(w * .27, h * .55, w * .12, h * .64, w * .08, h * .78)
      ..cubicTo(w * .05, h * .86, w * .05, h * .92, w * .05, h * .96)
      ..lineTo(w * .95, h * .96)
      ..cubicTo(w * .95, h * .92, w * .95, h * .86, w * .92, h * .78)
      ..cubicTo(w * .88, h * .64, w * .73, h * .55, w * .59, h * .52)
      ..cubicTo(w * .66, h * .49, w * .73, h * .41, w * .73, h * .30)
      ..cubicTo(w * .73, h * .17, w * .64, h * .07, w * .50, h * .07)
      ..close();
  }
  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  static List<double> exposureMatrix(double ev) {
    final gain = math.pow(2.0, ev).toDouble();
    return <double>[
      gain, 0, 0, 0, 0,
      0, gain, 0, 0, 0,
      0, 0, gain, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static Rect coverRect(ui.Image image, Size size) {
    final scale = (size.width / image.width).clamp(
      size.height / image.height,
      double.infinity,
    );
    final w = image.width * scale;
    final h = image.height * scale;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  static void paint({
    required Canvas canvas,
    required Size size,
    required ui.Image base,
    ui.Image? overlay,
    required BlendMode blendMode,
    required double mix,
    required double baseEv,
    required double overlayEv,
    required Offset overlayOffset,
    required double overlayScale,
    required OverlayMaskMode maskMode,
    double maskFeather = 0,
    List<MaskStroke> maskStrokes = const [],
  }) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      coverRect(base, size),
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.matrix(exposureMatrix(baseEv)),
    );

    if (overlay != null) {
      final destination = coverRect(overlay, size);
      final scaled = Rect.fromCenter(
        center: destination.center + Offset(
          overlayOffset.dx * size.width,
          overlayOffset.dy * size.height,
        ),
        width: destination.width * overlayScale,
        height: destination.height * overlayScale,
      );
      if (maskMode == OverlayMaskMode.fullFrame && maskStrokes.isEmpty) {
        canvas.drawImageRect(
          overlay,
          Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
          scaled,
          Paint()
            ..filterQuality = FilterQuality.high
            ..blendMode = blendMode
            ..color = Color.fromRGBO(255, 255, 255, mix.clamp(0, 1))
            ..colorFilter = ColorFilter.matrix(exposureMatrix(overlayEv)),
        );
      } else {
        canvas.saveLayer(Offset.zero & size, Paint()..blendMode = blendMode);
        canvas.drawImageRect(
          overlay,
          Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
          scaled,
          Paint()
            ..filterQuality = FilterQuality.high
            ..blendMode = BlendMode.srcOver
            ..color = Color.fromRGBO(255, 255, 255, mix.clamp(0, 1))
            ..colorFilter = ColorFilter.matrix(exposureMatrix(overlayEv)),
        );
        canvas.saveLayer(Offset.zero & size, Paint());
        final maskPaint = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill
          ..maskFilter = maskFeather > 0
              ? MaskFilter.blur(BlurStyle.normal, maskFeather)
              : null;
        if (maskMode == OverlayMaskMode.fullFrame) {
          canvas.drawRect(Offset.zero & size, maskPaint);
        } else {
          canvas.drawPath(portraitMaskPath(size), maskPaint);
          if (maskMode == OverlayMaskMode.outsidePortrait) {
            canvas.drawRect(
              Offset.zero & size,
              Paint()..color = const Color(0xFFFFFFFF),
            );
            canvas.drawPath(
              portraitMaskPath(size),
              Paint()
                ..color = const Color(0x00000000)
                ..blendMode = BlendMode.clear
                ..maskFilter = maskFeather > 0
                    ? MaskFilter.blur(BlurStyle.normal, maskFeather)
                    : null,
            );
          }
        }
        for (final stroke in maskStrokes) {
          canvas.drawPath(
            stroke.path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = stroke.width
              ..color = stroke.erase
                  ? const Color(0x00000000)
                  : const Color(0xFFFFFFFF)
              ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver
              ..maskFilter = maskFeather > 0
                  ? MaskFilter.blur(BlurStyle.normal, maskFeather)
                  : null,
          );
        }
        canvas.restore(Paint()..blendMode = BlendMode.dstIn);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  static Future<Uint8List> renderPng({
    required ui.Image base,
    ui.Image? overlay,
    required int width,
    required int height,
    required BlendMode blendMode,
    required double mix,
    required double baseEv,
    required double overlayEv,
    required Offset overlayOffset,
    required double overlayScale,
    required OverlayMaskMode maskMode,
    double maskFeather = 0,
    List<MaskStroke> maskStrokes = const [],
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(
      canvas: canvas,
      size: Size(width.toDouble(), height.toDouble()),
      base: base,
      overlay: overlay,
      blendMode: blendMode,
      mix: mix,
      baseEv: baseEv,
      overlayEv: overlayEv,
      overlayOffset: overlayOffset,
      overlayScale: overlayScale,
      maskMode: maskMode,
      maskFeather: maskFeather,
      maskStrokes: maskStrokes,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode PNG');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}

class ExposurePreviewPainter extends CustomPainter {
  const ExposurePreviewPainter({
    required this.base,
    required this.overlay,
    required this.blendMode,
    required this.mix,
    required this.baseEv,
    required this.overlayEv,
    required this.overlayOffset,
    required this.overlayScale,
    required this.maskMode,
    this.maskFeather = 0,
    this.maskStrokes = const [],
  });

  final ui.Image? base;
  final ui.Image? overlay;
  final BlendMode blendMode;
  final double mix;
  final double baseEv;
  final double overlayEv;
  final Offset overlayOffset;
  final double overlayScale;
  final OverlayMaskMode maskMode;
  final double maskFeather;
  final List<MaskStroke> maskStrokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF17171B), BlendMode.src);
    final image = base;
    if (image == null) return;
    ExposureComposer.paint(
      canvas: canvas,
      size: size,
      base: image,
      overlay: overlay,
      blendMode: blendMode,
      mix: mix,
      baseEv: baseEv,
      overlayEv: overlayEv,
      overlayOffset: overlayOffset,
      overlayScale: overlayScale,
      maskMode: maskMode,
      maskFeather: maskFeather,
      maskStrokes: maskStrokes,
    );
  }

  @override
  bool shouldRepaint(covariant ExposurePreviewPainter old) =>
      old.base != base ||
      old.overlay != overlay ||
      old.blendMode != blendMode ||
      old.mix != mix ||
      old.baseEv != baseEv ||
      old.overlayEv != overlayEv ||
      old.overlayOffset != overlayOffset ||
      old.overlayScale != overlayScale ||
      old.maskMode != maskMode ||
      old.maskFeather != maskFeather ||
      old.maskStrokes != maskStrokes;
}
