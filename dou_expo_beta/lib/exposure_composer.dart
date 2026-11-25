import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Controls where the second exposure is allowed to appear.
enum OverlayMaskMode { fullFrame, insidePortrait, outsidePortrait }

enum StencilKind { none, tree, lotus, cypress, arch, wingedBull, senmurv, map, flag, monument, flame, hand, brokenChain, people, skyline, tower, carpet, lute, pomegranate, laurel, wreath, persianGuard, royalHead, lionShield }
enum StencilFillMode { photo, pureWhite, tinted }
enum FilmEffect { none, grain, scanlines }

class StencilLibrary {
  static Path pathFor(StencilKind kind, Size size) {
    final w = size.width, h = size.height;
    final p = Path();
    switch (kind) {
      case StencilKind.none:
        return p..addRect(Offset.zero & size);
      case StencilKind.tree:
        p.moveTo(w*.5,h*.03); p.lineTo(w*.12,h*.42); p.lineTo(w*.34,h*.42);
        p.lineTo(w*.08,h*.68); p.lineTo(w*.38,h*.68); p.lineTo(w*.38,h*.96);
        p.lineTo(w*.62,h*.96); p.lineTo(w*.62,h*.68); p.lineTo(w*.92,h*.68);
        p.lineTo(w*.66,h*.42); p.lineTo(w*.88,h*.42); p.close(); return p;
      case StencilKind.cypress:
        p.moveTo(w*.5,h*.02); p.cubicTo(w*.42,h*.25,w*.18,h*.4,w*.28,h*.58);
        p.cubicTo(w*.12,h*.72,w*.3,h*.82,w*.42,h*.84);
        p.lineTo(w*.42,h*.98); p.lineTo(w*.58,h*.98); p.lineTo(w*.58,h*.84);
        p.cubicTo(w*.8,h*.8,w*.88,h*.68,w*.72,h*.56);
        p.cubicTo(w*.84,h*.38,w*.58,h*.22,w*.5,h*.02); p.close(); return p;
      case StencilKind.lotus:
        p.moveTo(w*.5,h*.95);
        p.cubicTo(w*.12,h*.78,w*.12,h*.5,w*.5,h*.18);
        p.cubicTo(w*.88,h*.5,w*.88,h*.78,w*.5,h*.95);
        p.moveTo(w*.5,h*.88);
        p.cubicTo(w*.32,h*.62,w*.32,h*.38,w*.5,h*.08);
        p.cubicTo(w*.68,h*.38,w*.68,h*.62,w*.5,h*.88);
        p.close(); return p;
      case StencilKind.arch:
        p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.12,h*.08,w*.76,h*.88),Radius.circular(w*.34)));
        p.addRect(Rect.fromLTWH(w*.27,h*.32,w*.46,h*.64));
        return Path.combine(PathOperation.difference,p,Path()..addRect(Rect.fromLTWH(w*.27,h*.32,w*.46,h*.64)));
      case StencilKind.wingedBull:
        p.moveTo(w*.08,h*.55); p.lineTo(w*.24,h*.36); p.lineTo(w*.44,h*.4);
        p.lineTo(w*.55,h*.16); p.lineTo(w*.7,h*.36); p.lineTo(w*.92,h*.48);
        p.lineTo(w*.78,h*.62); p.lineTo(w*.9,h*.78); p.lineTo(w*.64,h*.72);
        p.lineTo(w*.5,h*.92); p.lineTo(w*.36,h*.72); p.lineTo(w*.1,h*.8); p.close(); return p;
      case StencilKind.senmurv:
        p.moveTo(w*.12,h*.68); p.cubicTo(w*.05,h*.42,w*.28,h*.34,w*.4,h*.43);
        p.cubicTo(w*.42,h*.12,w*.75,h*.08,w*.82,h*.35);
        p.cubicTo(w*.98,h*.45,w*.9,h*.66,w*.72,h*.68);
        p.cubicTo(w*.65,h*.92,w*.42,h*.9,w*.34,h*.72); p.close(); return p;
      case StencilKind.map:
        p.moveTo(w*.08,h*.18); p.lineTo(w*.32,h*.1); p.lineTo(w*.46,h*.24); p.lineTo(w*.62,h*.12);
        p.lineTo(w*.9,h*.22); p.lineTo(w*.86,h*.78); p.lineTo(w*.62,h*.9); p.lineTo(w*.43,h*.78);
        p.lineTo(w*.22,h*.88); p.lineTo(w*.08,h*.65); p.close(); return p;
      case StencilKind.flag:
        p.addRect(Rect.fromLTWH(w*.16,h*.08,w*.07,h*.86));
        p.moveTo(w*.23,h*.12); p.cubicTo(w*.48,h*.02,w*.68,h*.22,w*.9,h*.12);
        p.lineTo(w*.9,h*.43); p.cubicTo(w*.65,h*.53,w*.46,h*.33,w*.23,h*.43); p.close(); return p;
      case StencilKind.monument:
        p.moveTo(w*.5,h*.04); p.lineTo(w*.58,h*.26); p.lineTo(w*.7,h*.38); p.lineTo(w*.7,h*.7);
        p.lineTo(w*.88,h*.7); p.lineTo(w*.88,h*.9); p.lineTo(w*.12,h*.9); p.lineTo(w*.12,h*.7);
        p.lineTo(w*.3,h*.7); p.lineTo(w*.3,h*.38); p.lineTo(w*.42,h*.26); p.close(); return p;
      case StencilKind.flame:
        p.moveTo(w*.5,h*.96); p.cubicTo(w*.08,h*.78,w*.35,h*.48,w*.3,h*.28);
        p.cubicTo(w*.52,h*.4,w*.52,h*.16,w*.64,h*.04);
        p.cubicTo(w*.65,h*.34,w*.98,h*.48,w*.78,h*.82); p.cubicTo(w*.7,h*.94,w*.6,h*.98,w*.5,h*.96); p.close(); return p;
      case StencilKind.hand:
        p.moveTo(w*.3,h*.94); p.lineTo(w*.3,h*.48);
        for (var handIndex=0;handIndex<4;handIndex++) { final x=w*(.22+handIndex*.15); p.lineTo(x,h*.48); p.lineTo(x,h*(.12+(handIndex%2)*.04)); p.quadraticBezierTo(x,h*.04,x+w*.07,h*.1); p.lineTo(x+w*.07,h*.52); }
        p.lineTo(w*.82,h*.62); p.quadraticBezierTo(w*.95,h*.64,w*.88,h*.76); p.lineTo(w*.7,h*.94); p.close(); return p;
      case StencilKind.brokenChain:
        p.addOval(Rect.fromLTWH(w*.08,h*.18,w*.48,h*.34));
        p.addOval(Rect.fromLTWH(w*.44,h*.5,w*.48,h*.34));
        return p;
      case StencilKind.people:
        for (var peopleIndex=0;peopleIndex<5;peopleIndex++) { final x=w*(.12+peopleIndex*.17); p.addOval(Rect.fromCircle(center:Offset(x+w*.055,h*.22),radius:w*.055)); p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,h*.31,w*.11,h*.52),Radius.circular(w*.035))); }
        return p;
      case StencilKind.skyline:
        p.moveTo(0,h*.9); p.lineTo(0,h*.48); p.lineTo(w*.14,h*.48); p.lineTo(w*.2,h*.22);
        p.lineTo(w*.27,h*.48); p.lineTo(w*.38,h*.48); p.lineTo(w*.48,h*.08); p.lineTo(w*.58,h*.48);
        p.lineTo(w*.7,h*.48); p.lineTo(w*.78,h*.3); p.lineTo(w*.86,h*.48); p.lineTo(w,h*.48); p.lineTo(w,h*.9); p.close(); return p;
      case StencilKind.tower:
        p.addRect(Rect.fromLTWH(w*.18,h*.32,w*.64,h*.58));
        p.moveTo(w*.12,h*.32); p.lineTo(w*.5,h*.06); p.lineTo(w*.88,h*.32); p.close(); return p;
      case StencilKind.carpet:
        p.addRect(Rect.fromLTWH(w*.08,h*.08,w*.84,h*.84));
        p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.2,h*.2,w*.6,h*.6),Radius.circular(w*.06)));
        p.addOval(Rect.fromLTWH(w*.36,h*.36,w*.28,h*.28)); return p;
      case StencilKind.lute:
        p.moveTo(w*.48,h*.08); p.lineTo(w*.57,h*.08); p.lineTo(w*.57,h*.56);
        p.cubicTo(w*.9,h*.45,w*.98,h*.85,w*.72,h*.94);
        p.cubicTo(w*.55,h*.99,w*.48,h*.82,w*.38,h*.9);
        p.cubicTo(w*.05,h*.92,w*.08,h*.56,w*.43,h*.56); p.close(); return p;
      case StencilKind.pomegranate:
        p.moveTo(w*.5,h*.18); p.lineTo(w*.4,h*.06); p.lineTo(w*.5,h*.12); p.lineTo(w*.6,h*.06);
        p.lineTo(w*.58,h*.2); p.cubicTo(w*.95,h*.25,w*.92,h*.85,w*.5,h*.94);
        p.cubicTo(w*.08,h*.85,w*.05,h*.25,w*.5,h*.2); p.close(); return p;
      case StencilKind.laurel:
      case StencilKind.wreath:
        p.addOval(Rect.fromLTWH(w*.16,h*.12,w*.68,h*.78));
        for(var wreathIndex=0;wreathIndex<9;wreathIndex++){final y=h*(.2+wreathIndex*.075); p.addOval(Rect.fromLTWH(w*(wreathIndex % 2 == 0 ? .16 : .68),y,w*.16,h*.065));}
        return p;
      case StencilKind.persianGuard:
        p.moveTo(w*.5,h*.04); p.lineTo(w*.68,h*.12); p.lineTo(w*.72,h*.3);
        p.lineTo(w*.85,h*.4); p.lineTo(w*.78,h*.88); p.lineTo(w*.5,h*.98);
        p.lineTo(w*.22,h*.88); p.lineTo(w*.15,h*.4); p.lineTo(w*.28,h*.3); p.lineTo(w*.32,h*.12); p.close(); return p;
      case StencilKind.royalHead:
        p.moveTo(w*.28,h*.16); p.lineTo(w*.72,h*.16); p.lineTo(w*.68,h*.3);
        p.cubicTo(w*.9,h*.48,w*.72,h*.82,w*.5,h*.92); p.cubicTo(w*.28,h*.82,w*.1,h*.48,w*.32,h*.3); p.close(); return p;
      case StencilKind.lionShield:
        p.moveTo(w*.5,h*.05); p.cubicTo(w*.12,h*.12,w*.08,h*.42,w*.5,h*.94);
        p.cubicTo(w*.92,h*.42,w*.88,h*.12,w*.5,h*.05); p.close();
        p.addOval(Rect.fromLTWH(w*.32,h*.28,w*.36,h*.36)); return p;
    }
  }

  static Future<Color> complementaryColor(ui.Image image, {StencilKind stencil = StencilKind.none}) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const Color(0xFFFF8A00);
    var r = 0.0, g = 0.0, b = 0.0, count = 0;
    final step = math.max(1, (image.width * image.height ~/ 12000));
    final mask = stencil == StencilKind.none ? null : pathFor(stencil, Size(image.width.toDouble(), image.height.toDouble()));
    for (var i = 0; i < image.width * image.height; i += step) {
      final x = i % image.width, y = i ~/ image.width;
      if (mask != null && !mask.contains(Offset(x.toDouble(), y.toDouble()))) continue;
      final o = i * 4;
      if (data.getUint8(o + 3) < 24) continue;
      r += data.getUint8(o); g += data.getUint8(o + 1); b += data.getUint8(o + 2); count++;
    }
    if (count == 0) return const Color(0xFFFF8A00);
    final average = Color.fromARGB(255, (r/count).round(), (g/count).round(), (b/count).round());
    final hsl = HSLColor.fromColor(average);
    final targetHue = hsl.hue >= 70 && hsl.hue <= 160 ? 32.0 : (hsl.hue + 180) % 360;
    return hsl.withHue(targetHue).withSaturation(math.max(.45,hsl.saturation)).withLightness(.58).toColor();
  }
}

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

  static List<double> toneMatrix(double ev, double contrast, double saturation) {
    final gain = math.pow(2.0, ev).toDouble();
    final c = contrast.clamp(0.0, 2.0) * gain;
    final s = saturation.clamp(0.0, 2.0);
    final offset = 128.0 * (1 - contrast.clamp(0.0, 2.0));
    return <double>[
      (0.213 + 0.787*s)*c, (0.715 - 0.715*s)*c, (0.072 - 0.072*s)*c, 0, offset,
      (0.213 - 0.213*s)*c, (0.715 + 0.285*s)*c, (0.072 - 0.072*s)*c, 0, offset,
      (0.213 - 0.213*s)*c, (0.715 - 0.715*s)*c, (0.072 + 0.928*s)*c, 0, offset,
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
    StencilKind stencil = StencilKind.none,
    StencilFillMode stencilFillMode = StencilFillMode.photo,
    Color stencilTint = const Color(0xFFFF8A00),
    double contrast = 1,
    double saturation = 1,
    FilmEffect filmEffect = FilmEffect.none,
    double effectAmount = 0,
  }) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      coverRect(base, size),
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.matrix(toneMatrix(baseEv, contrast, saturation)),
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
      if (stencil != StencilKind.none) {
        canvas.save();
        canvas.clipPath(StencilLibrary.pathFor(stencil, size), doAntiAlias: true);
      }
      final overlayColorMatrix = stencil != StencilKind.none && stencilFillMode != StencilFillMode.photo
          ? <double>[0,0,0,0,stencilFillMode == StencilFillMode.pureWhite ? 255 : stencilTint.red.toDouble(), 0,0,0,0,stencilFillMode == StencilFillMode.pureWhite ? 255 : stencilTint.green.toDouble(), 0,0,0,0,stencilFillMode == StencilFillMode.pureWhite ? 255 : stencilTint.blue.toDouble(), 0,0,0,1,0]
          : toneMatrix(overlayEv, contrast, saturation);
      if (maskMode == OverlayMaskMode.fullFrame && maskStrokes.isEmpty) {
        canvas.drawImageRect(
          overlay,
          Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
          scaled,
          Paint()
            ..filterQuality = FilterQuality.high
            ..blendMode = blendMode
            ..color = Color.fromRGBO(255, 255, 255, mix.clamp(0, 1))
            ..colorFilter = ColorFilter.matrix(overlayColorMatrix),
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
            ..colorFilter = ColorFilter.matrix(overlayColorMatrix),
        );
        canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.dstIn);
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
          canvas.save();
          canvas.scale(size.width, size.height);
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
          canvas.restore();
        }
        canvas.restore();
        canvas.restore();
      }
      if (stencil != StencilKind.none) canvas.restore();
    }
    if (filmEffect == FilmEffect.scanlines && effectAmount > 0) {
      final spacing = math.max(2.0, size.width / 240);
      final lineHeight = math.max(1.0, size.width / 1800);
      final paint = Paint()..color = Color.fromRGBO(0, 0, 0, .22 * effectAmount);
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineHeight), paint);
      }
    } else if (filmEffect == FilmEffect.grain && effectAmount > 0) {
      final random = math.Random(31);
      final count = (size.width * size.height / 850 * effectAmount).round();
      final paint = Paint();
      for (var i = 0; i < count; i++) {
        paint.color = random.nextBool()
            ? Color.fromRGBO(255, 255, 255, .18 * effectAmount)
            : Color.fromRGBO(0, 0, 0, .2 * effectAmount);
        canvas.drawRect(
          Rect.fromLTWH(random.nextDouble()*size.width, random.nextDouble()*size.height, 1, 1),
          paint,
        );
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
    StencilKind stencil = StencilKind.none,
    StencilFillMode stencilFillMode = StencilFillMode.photo,
    Color stencilTint = const Color(0xFFFF8A00),
    double contrast = 1,
    double saturation = 1,
    FilmEffect filmEffect = FilmEffect.none,
    double effectAmount = 0,
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
      stencil: stencil,
      stencilFillMode: stencilFillMode,
      stencilTint: stencilTint,
      contrast: contrast,
      saturation: saturation,
      filmEffect: filmEffect,
      effectAmount: effectAmount,
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
    this.stencil = StencilKind.none,
    this.stencilFillMode = StencilFillMode.photo,
    this.stencilTint = const Color(0xFFFF8A00),
    this.contrast = 1,
    this.saturation = 1,
    this.filmEffect = FilmEffect.none,
    this.effectAmount = 0,
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
  final StencilKind stencil;
  final StencilFillMode stencilFillMode;
  final Color stencilTint;
  final double contrast;
  final double saturation;
  final FilmEffect filmEffect;
  final double effectAmount;

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
      stencil: stencil,
      stencilFillMode: stencilFillMode,
      stencilTint: stencilTint,
      contrast: contrast,
      saturation: saturation,
      filmEffect: filmEffect,
      effectAmount: effectAmount,
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
      old.maskStrokes != maskStrokes ||
      old.stencil != stencil ||
      old.stencilFillMode != stencilFillMode ||
      old.stencilTint != stencilTint ||
      old.contrast != contrast ||
      old.saturation != saturation ||
      old.filmEffect != filmEffect ||
      old.effectAmount != effectAmount;
}
