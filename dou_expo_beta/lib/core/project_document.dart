import 'dart:convert';

/// Recursively freezes JSON-compatible data so history snapshots cannot be
/// mutated through nested map/list references after publication.
Object? _freezeJson(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) throw ArgumentError('Project data cannot contain NaN or infinity');
    return value;
  }
  if (value is Map) {
    final frozen = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError('Project JSON map keys must be strings');
      }
      frozen[entry.key as String] = _freezeJson(entry.value);
    }
    return Map<String, Object?>.unmodifiable(frozen);
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  throw ArgumentError('Unsupported project data type: ${value.runtimeType}');
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) =>
    _freezeJson(value) as Map<String, Object?>;

/// Serializable immutable editor state. Image bytes are stored as project
/// assets; this document contains stable relative asset paths, never picker
/// or camera temporary paths.
class ProjectDocument {
  ProjectDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required Map<String, Object?> canvas,
    required List<LayerDocument> layers,
    this.activeLayerId,
    this.schemaVersion = 1,
  })  : canvas = _freezeMap(canvas),
        layers = List<LayerDocument>.unmodifiable(layers) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Project id cannot be empty');
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name', 'Project name cannot be empty');
    if (schemaVersion != 1) {
      throw FormatException('Unsupported project schema: $schemaVersion');
    }
    final ids = this.layers.map((layer) => layer.id).toSet();
    if (ids.length != this.layers.length) {
      throw ArgumentError('Layer identifiers must be unique within a project');
    }
    if (activeLayerId != null && !ids.contains(activeLayerId)) {
      throw ArgumentError.value(activeLayerId, 'activeLayerId', 'Active layer does not exist');
    }
  }

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
  LayerDocument({
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
    List<Map<String, Object?>> maskStrokes = const [],
    Map<String, Object?> settings = const {},
  })  : maskStrokes = List<Map<String, Object?>>.unmodifiable(
          maskStrokes.map(_freezeMap),
        ),
        settings = _freezeMap(settings) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Layer id cannot be empty');
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(opacity, 'opacity', 'Opacity must be between 0 and 1');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be finite and greater than zero');
    }
    if (!offsetX.isFinite || !offsetY.isFinite || !exposure.isFinite) {
      throw ArgumentError('Layer transform and exposure values must be finite');
    }
  }

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
