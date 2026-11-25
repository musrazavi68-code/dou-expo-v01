import 'dart:convert';

/// Serializable editor state. Image bytes are stored as project assets; this
/// document contains stable relative asset paths, never temporary picker paths.
class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.canvas,
    required this.layers,
    this.activeLayerId,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> canvas;
  final List<LayerDocument> layers;
  final String? activeLayerId;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'canvas': canvas,
    'activeLayerId': activeLayerId,
    'layers': layers.map((layer) => layer.toJson()).toList(),
  };

  factory ProjectDocument.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version != 1) throw FormatException('Unsupported project schema: $version');
    return ProjectDocument(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      canvas: Map<String, Object?>.from(json['canvas'] as Map? ?? const {}),
      activeLayerId: json['activeLayerId'] as String?,
      layers: (json['layers'] as List? ?? const [])
          .map((item) => LayerDocument.fromJson(Map<String, Object?>.from(item as Map)))
          .toList(growable: false),
    );
  }

  String encode() => jsonEncode(toJson());
  factory ProjectDocument.decode(String source) =>
      ProjectDocument.fromJson(Map<String, Object?>.from(jsonDecode(source) as Map));
}

class LayerDocument {
  const LayerDocument({
    required this.id,
    required this.name,
    required this.assetPath,
    this.visible = true,
    this.opacity = 1,
    this.blendMode = 'screen',
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1,
    this.exposure = 0,
    this.maskStrokes = const [],
    this.settings = const {},
  });

  final String id;
  final String name;
  final String assetPath;
  final bool visible;
  final double opacity;
  final String blendMode;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double exposure;
  final List<Map<String, Object?>> maskStrokes;
  final Map<String, Object?> settings;

  Map<String, Object?> toJson() => {
    'id': id, 'name': name, 'assetPath': assetPath, 'visible': visible,
    'opacity': opacity, 'blendMode': blendMode, 'offsetX': offsetX,
    'offsetY': offsetY, 'scale': scale, 'exposure': exposure,
    'maskStrokes': maskStrokes, 'settings': settings,
  };

  factory LayerDocument.fromJson(Map<String, Object?> json) => LayerDocument(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Layer',
    assetPath: json['assetPath'] as String,
    visible: json['visible'] as bool? ?? true,
    opacity: (json['opacity'] as num? ?? 1).toDouble(),
    blendMode: json['blendMode'] as String? ?? 'screen',
    offsetX: (json['offsetX'] as num? ?? 0).toDouble(),
    offsetY: (json['offsetY'] as num? ?? 0).toDouble(),
    scale: (json['scale'] as num? ?? 1).toDouble(),
    exposure: (json['exposure'] as num? ?? 0).toDouble(),
    maskStrokes: (json['maskStrokes'] as List? ?? const [])
        .map((e) => Map<String, Object?>.from(e as Map)).toList(growable: false),
    settings: Map<String, Object?>.from(json['settings'] as Map? ?? const {}),
  );
}
