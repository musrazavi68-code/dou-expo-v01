import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Real two-image compositor. The second exposure is painted with a true
/// Porter-Duff blend mode; it is not a decorative gradient overlay.
class ExposureComposer {
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
    final gain = 2.0 * ev;
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
  });

  final ui.Image? base;
  final ui.Image? overlay;
  final BlendMode blendMode;
  final double mix;
  final double baseEv;
  final double overlayEv;
  final Offset overlayOffset;
  final double overlayScale;

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
      old.overlayScale != overlayScale;
}
