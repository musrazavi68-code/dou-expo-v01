import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dou_expo_beta/exposure_composer.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _solidImage(int width, int height, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(color, ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<ui.Color> _pixel(Uint8List bytes, int width, int x, int y) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * width + x) * 4;
  final color = ui.Color.fromARGB(
    data!.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
  frame.image.dispose();
  codec.dispose();
  return color;
}

void main() {
  test('portrait mask path stays within normalized canvas', () {
    final path = ExposureComposer.portraitMaskPath(const ui.Size(100, 200));
    expect(path.getBounds().left, greaterThanOrEqualTo(0));
    expect(path.getBounds().top, greaterThanOrEqualTo(0));
    expect(path.getBounds().right, lessThanOrEqualTo(100));
    expect(path.getBounds().bottom, lessThanOrEqualTo(200));
  });

  test('inside and outside mask modes render second exposure independently', () async {
    final base = await _solidImage(20, 20, const ui.Color(0xFFFF0000));
    final overlay = await _solidImage(20, 20, const ui.Color(0xFF0000FF));
    try {
      Future<List<int>> render(OverlayMaskMode mode) => ExposureComposer.renderPng(
        base: base,
        overlay: overlay,
        width: 20,
        height: 20,
        blendMode: ui.BlendMode.srcOver,
        mix: 1,
        baseEv: 0,
        overlayEv: 0,
        overlayOffset: ui.Offset.zero,
        overlayScale: 1,
        maskMode: mode,
      );

      final inside = await render(OverlayMaskMode.insidePortrait);
      final outside = await render(OverlayMaskMode.outsidePortrait);
      final insideCenter = await _pixel(Uint8List.fromList(inside), 20, 10, 5);
      final insideCorner = await _pixel(Uint8List.fromList(inside), 20, 0, 0);
      final outsideCenter = await _pixel(Uint8List.fromList(outside), 20, 10, 5);
      final outsideCorner = await _pixel(Uint8List.fromList(outside), 20, 0, 0);

      expect(insideCenter.b, greaterThan(insideCenter.red));
      expect(insideCorner.r, greaterThan(insideCorner.blue));
      expect(outsideCenter.red, greaterThan(outsideCenter.blue));
      expect(outsideCorner.blue, greaterThan(outsideCorner.red));
    } finally {
      base.dispose();
      overlay.dispose();
    }
  });
}
