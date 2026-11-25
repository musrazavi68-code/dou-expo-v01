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
      layers: const [
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
