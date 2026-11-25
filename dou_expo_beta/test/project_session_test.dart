import 'dart:async';
import 'dart:typed_data';

import 'package:dou_expo_beta/core/project_document.dart';
import 'package:dou_expo_beta/core/project_session.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectDocument doc(String name) {
  final now = DateTime.utc(2026, 11, 25);
  return ProjectDocument(
    id: 'session-test',
    name: name,
    createdAt: now,
    updatedAt: now,
    canvas: const {},
    layers: const [],
  );
}

void main() {
  test('session tracks edits and undo/redo across immutable snapshots', () {
    final initial = doc('Initial');
    final session = ProjectSession.withBackend(
      initial: initial,
      persist: (_) async {},
      restore: (_) async => null,
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    session.replace(doc('Edited'));
    expect(session.isDirty, isTrue);
    expect(session.document.name, 'Edited');

    expect(session.undo()?.name, 'Initial');
    expect(session.canRedo, isTrue);
    expect(session.redo()?.name, 'Edited');
    expect(session.document.name, 'Edited');
  });

  test('clearHistory removes only in-memory undo and redo snapshots', () {
    final session = ProjectSession.withBackend(
      initial: doc('Initial'),
      persist: (_) async {},
      restore: (_) async => null,
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    session.replace(doc('Edited'));
    expect(session.canUndo, isTrue);
    session.clearHistory();

    expect(session.canUndo, isFalse);
    expect(session.canRedo, isFalse);
    expect(session.document.name, 'Edited');
    expect(session.isDirty, isTrue);
  });

  test('save persists a newer edit that occurs while IO is in progress', () async {
    final gate = Completer<void>();
    final saved = <String>[];
    final session = ProjectSession.withBackend(
      initial: doc('Initial'),
      persist: (value) async {
        saved.add(value.name);
        if (saved.length == 1) await gate.future;
      },
      restore: (_) async => null,
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    session.replace(doc('First edit'));
    final saving = session.save();
    expect(session.isSaving, isTrue);
    session.replace(doc('Edit while saving'));
    gate.complete();
    await saving;

    expect(session.isSaving, isFalse);
    expect(session.isDirty, isFalse);
    expect(session.document.name, 'Edit while saving');
    expect(saved, ['First edit', 'Edit while saving']);
  });

  test('save clears dirty flag only after persisted snapshot completes', () async {
    var savedName = '';
    final session = ProjectSession.withBackend(
      initial: doc('Initial'),
      persist: (value) async { savedName = value.name; },
      restore: (_) async => null,
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    session.replace(doc('Saved'));
    await session.save();
    expect(savedName, 'Saved');
    expect(session.isDirty, isFalse);
  });

  test('missing project does not replace current session', () async {
    final session = ProjectSession.withBackend(
      initial: doc('Keep me'),
      persist: (_) async {},
      restore: (_) async => null,
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    expect(await session.open('missing'), isFalse);
    expect(session.document.name, 'Keep me');
    expect(session.isDirty, isFalse);
  });

  test('latest overlapping open request wins', () async {
    final firstGate = Completer<ProjectDocument?>();
    final session = ProjectSession.withBackend(
      initial: doc('Initial'),
      persist: (_) async {},
      restore: (id) async {
        if (id == 'first') return firstGate.future;
        return ProjectDocument(
          id: id,
          name: id,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          canvas: const {},
          layers: const [],
        );
      },
      writeAsset: (_, _, _) async => 'assets/test.png',
    );

    final firstOpen = session.open('first');
    expect(await session.open('second'), isTrue);
    firstGate.complete(ProjectDocument(
      id: 'first',
      name: 'first',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      canvas: const {},
      layers: const [],
    ));

    expect(await firstOpen, isFalse);
    expect(session.document.id, 'second');
  });

  test('asset writer uses the active project id', () async {
    String? receivedId;
    final session = ProjectSession.withBackend(
      initial: doc('Initial'),
      persist: (_) async {},
      restore: (_) async => null,
      writeAsset: (id, _, __) async {
        receivedId = id;
        return 'assets/photo.png';
      },
    );

    expect(await session.addAsset('photo.png', Uint8List.fromList([1, 2, 3])),
        'assets/photo.png');
    expect(receivedId, 'session-test');
  });
}

