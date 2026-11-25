import 'package:dou_expo_beta/core/autosave_coordinator.dart';
import 'package:dou_expo_beta/core/project_document.dart';
import 'package:dou_expo_beta/core/project_session.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectDocument _document(String name) => ProjectDocument(
  id: 'autosave-test',
  name: name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  canvas: const {},
  layers: const [],
);

void main() {
  test('debounces multiple edits into one save of the latest snapshot', () async {
    final saved = <String>[];
    final session = ProjectSession.withBackend(
      initial: _document('Initial'),
      persist: (doc) async { saved.add(doc.name); },
      restore: (_) async => null,
      writeAsset: (_, __, ___) async => 'assets/test.png',
    );
    final autosave = AutosaveCoordinator(
      session: session,
      debounce: const Duration(milliseconds: 20),
    );

    session.replace(_document('First'));
    autosave.markChanged();
    session.replace(_document('Latest'));
    autosave.markChanged();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(saved, ['Latest']);
    expect(session.isDirty, isFalse);
    autosave.dispose();
  });

  test('flush cancels pending debounce and persists immediately', () async {
    var saves = 0;
    final session = ProjectSession.withBackend(
      initial: _document('Initial'),
      persist: (_) async { saves++; },
      restore: (_) async => null,
      writeAsset: (_, __, ___) async => 'assets/test.png',
    );
    final autosave = AutosaveCoordinator(
      session: session,
      debounce: const Duration(seconds: 10),
    );

    session.replace(_document('Changed'));
    autosave.markChanged();
    await autosave.flush();

    expect(saves, 1);
    expect(autosave.isScheduled, isFalse);
    expect(session.isDirty, isFalse);
    autosave.dispose();
  });

  test('failed explicit flush propagates and remains dirty for a later retry', () async {
    var attempts = 0;
    Object? reported;
    final session = ProjectSession.withBackend(
      initial: _document('Initial'),
      persist: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('disk full');
      },
      restore: (_) async => null,
      writeAsset: (_, __, ___) async => 'assets/test.png',
    );
    final autosave = AutosaveCoordinator(
      session: session,
      debounce: const Duration(seconds: 10),
      onError: (error, _) => reported = error,
    );

    session.replace(_document('Changed'));
    autosave.markChanged();
    await expectLater(autosave.flush(), throwsA(isA<StateError>()));
    expect(reported, isNull);
    expect(session.isDirty, isTrue);

    await autosave.flush();
    expect(attempts, 2);
    expect(session.isDirty, isFalse);
    autosave.dispose();
  });
}
