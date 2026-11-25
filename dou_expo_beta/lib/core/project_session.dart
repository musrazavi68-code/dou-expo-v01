import 'dart:typed_data';

import 'history_stack.dart';
import 'project_document.dart';
import 'project_store.dart';

/// Shared project state used by camera capture, Double Exposure and Darkroom.
///
/// UI layers should publish completed edits through [replace], rather than
/// keeping independent, unsynchronised copies of project metadata.
class ProjectSession {
  ProjectSession._({
    required ProjectDocument initial,
    required Future<void> Function(ProjectDocument) persist,
    required Future<ProjectDocument?> Function(String) restore,
    required Future<String> Function(String, String, List<int>) writeAsset,
  })  : _history = HistoryStack<ProjectDocument>(initial: initial),
        _persist = persist,
        _restore = restore,
        _writeAsset = writeAsset;

  factory ProjectSession({
    required ProjectDocument initial,
    ProjectStore? store,
  }) {
    final projectStore = store ?? ProjectStore();
    return ProjectSession.withBackend(
      initial: initial,
      persist: projectStore.save,
      restore: projectStore.load,
      writeAsset: projectStore.saveAsset,
    );
  }

  /// Backend injection keeps session behavior testable without platform IO.
  factory ProjectSession.withBackend({
    required ProjectDocument initial,
    required Future<void> Function(ProjectDocument) persist,
    required Future<ProjectDocument?> Function(String) restore,
    required Future<String> Function(String, String, List<int>) writeAsset,
  }) => ProjectSession._(
        initial: initial,
        persist: persist,
        restore: restore,
        writeAsset: writeAsset,
      );

  final HistoryStack<ProjectDocument> _history;
  final Future<void> Function(ProjectDocument) _persist;
  final Future<ProjectDocument?> Function(String) _restore;
  final Future<String> Function(String, String, List<int>) _writeAsset;

  bool _dirty = false;
  bool _saving = false;
  int _revision = 0;

  ProjectDocument get document => _history.current;
  bool get isDirty => _dirty;
  bool get isSaving => _saving;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Atomically publishes a complete immutable document snapshot.
  void replace(ProjectDocument next) {
    if (_saving && next.id != document.id) {
      throw StateError('Cannot switch projects while saving');
    }
    if (next.id != document.id) {
      throw ArgumentError('A session cannot be replaced with another project id');
    }
    if (identical(next, document)) return;
    _history.record(next);
    _markDirty();
  }

  void _markDirty() {
    _revision++;
    _dirty = true;
  }

  ProjectDocument? undo() {
    final value = _history.undo();
    if (value != null) _markDirty();
    return value;
  }

  ProjectDocument? redo() {
    final value = _history.redo();
    if (value != null) _markDirty();
    return value;
  }

  /// Writes the asset before its path is referenced by the project manifest.
  Future<String> addAsset(String fileName, Uint8List bytes) =>
      _writeAsset(document.id, fileName, bytes);

  Future<void> save() async {
    if (_saving) throw StateError('A project save is already in progress');
    _saving = true;
    final revisionAtStart = _revision;
    final snapshot = document;
    try {
      await _persist(snapshot);
      // An edit may have happened while disk IO was in progress. In that
      // case the persisted snapshot is valid, but the newer state stays dirty.
      if (_revision == revisionAtStart && identical(document, snapshot)) {
        _dirty = false;
      }
    } finally {
      _saving = false;
    }
  }

  /// Replaces the current project only after a valid manifest has been read.
  Future<bool> open(String id) async {
    if (_saving) throw StateError('Cannot open a project while saving');
    final loaded = await _restore(id);
    if (loaded == null) return false;
    _history.reset(loaded);
    _revision++;
    _dirty = false;
    return true;
  }
}
