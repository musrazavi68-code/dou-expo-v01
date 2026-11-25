import 'package:dou_expo_beta/core/project_document.dart';
import 'package:dou_expo_beta/core/history_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project round trip preserves all layer settings and mask data', () {
    final now = DateTime.utc(2026, 11, 25);
    final project = ProjectDocument(
      id: 'project-1', name: 'Night study', createdAt: now, updatedAt: now,
      canvas: const {'width': 3000, 'height': 2000, 'ratio': '3:2'},
      activeLayerId: 'layer-2',
      layers: [
        LayerDocument(id: 'layer-1', name: 'Base', assetPath: 'assets/base.jpg'),
        LayerDocument(
          id: 'layer-2', name: 'Exposure two', assetPath: 'assets/second.jpg',
          opacity: .72, blendMode: 'screen', offsetX: .12, offsetY: -.08,
          scale: 1.4, exposure: -.3,
          maskStrokes: [{'erase': false, 'width': .02, 'points': [[.1, .2], [.4, .6]]}],
          settings: {'contrast': 1.2, 'saturation': .8},
        ),
      ],
    );

    final restored = ProjectDocument.decode(project.encode());
    expect(restored.id, project.id);
    expect(restored.canvas['width'], 3000);
    expect(restored.layers[1].maskStrokes.single['points'], [[.1, .2], [.4, .6]]);
    expect(restored.layers[1].settings['contrast'], 1.2);
    expect(restored.activeLayerId, 'layer-2');
  });

  test('project and nested layer data are deeply immutable', () {
    final points = <List<double>>[[.1, .2]];
    final stroke = <String, Object?>{'points': points};
    final settings = <String, Object?>{'recipe': {'grain': .3}};
    final layer = LayerDocument(
      id: 'immutable-layer',
      name: 'Mask',
      assetPath: 'assets/mask.png',
      maskStrokes: [stroke],
      settings: settings,
    );
    final canvas = <String, Object?>{'metadata': {'tags': ['one']}};
    final project = ProjectDocument(
      id: 'immutable-project',
      name: 'Immutable',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      canvas: canvas,
      layers: [layer],
    );

    points[0][0] = .9;
    stroke['erase'] = true;
    settings['recipe'] = 'changed';
    canvas['metadata'] = 'changed';

    expect((project.layers.single.maskStrokes.single['points'] as List).first, [.1, .2]);
    expect(project.layers.single.maskStrokes.single.containsKey('erase'), isFalse);
    expect(project.layers.single.settings['recipe'], {'grain': .3});
    expect(project.canvas['metadata'], {'tags': ['one']});
    expect(() => project.canvas['new'] = true, throwsUnsupportedError);
    expect(() => project.layers.clear(), throwsUnsupportedError);
  });

  test('invalid opacity, scale and active layer are rejected', () {
    expect(
      () => LayerDocument(id: 'x', name: 'X', assetPath: 'assets/x.png', opacity: 2),
      throwsArgumentError,
    );
    expect(
      () => LayerDocument(id: 'x', name: 'X', assetPath: 'assets/x.png', scale: 0),
      throwsArgumentError,
    );
    expect(
      () => ProjectDocument(
        id: 'p',
        name: 'P',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        canvas: const {},
        layers: const [],
        activeLayerId: 'missing',
      ),
      throwsArgumentError,
    );
  });

  test('copy helpers preserve identity and freeze changed values', () {
    final now = DateTime.utc(2026);
    final base = ProjectDocument(
      id: 'copy-project',
      name: 'Original',
      createdAt: now,
      updatedAt: now,
      canvas: const {'width': 100},
      layers: [
        LayerDocument(id: 'base', name: 'Base', assetPath: 'assets/base.jpg'),
      ],
    );
    final changed = base.copyWith(
      name: 'Renamed',
      canvas: {'width': 200},
      layers: [base.layers.single.copyWith(opacity: .5)],
    );

    expect(changed.id, base.id);
    expect(changed.createdAt, base.createdAt);
    expect(changed.name, 'Renamed');
    expect(changed.canvas['width'], 200);
    expect(changed.layers.single.opacity, .5);
    expect(base.name, 'Original');
    expect(base.layers.single.opacity, 1);
  });

  test('unknown schema version is rejected instead of silently corrupted', () {
    expect(
      () => ProjectDocument.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
  });

  test('undo redo branches and capacity remain bounded', () {
    final history = HistoryStack<int>(initial: 0, capacity: 2);
    history.record(1);
    history.record(2);
    history.record(3);
    expect(history.undo(), 2);
    expect(history.undo(), 1);
    expect(history.canUndo, isFalse);
    expect(history.redo(), 2);
    history.record(9);
    expect(history.canRedo, isFalse);
    expect(history.current, 9);
  });
}
