import 'package:flutter/foundation.dart';

import 'history_stack.dart';
import 'project_document.dart';
import 'project_store.dart';

/// Shared project state used by all studio features. UI code publishes
/// complete immutable snapshots; persistence and history stay centralized.
class ProjectSession extends ChangeNotifier {
  ProjectSession._({
    required ProjectDocument initial,
    required Future<void> Function(ProjectDocument) this._persist,
    required Future<ProjectDocument?> Function(String) this._restore,
    required Future<String> Function(String, String, List<int>) this._writeAsset,
    required int historyCapacity,
  })  : _history = HistoryStack<ProjectDocument>(
          initial: initial,
          capacity: historyCapacity,
        );

  factory ProjectSession({
    required ProjectDocument initial,
    ProjectStore? store,
    int historyCapacity = 80,
  }) {
    final projectStore = store ?? ProjectStore();
    return ProjectSession.withBackend(
      initial: initial,
      persist: projectStore.save,
      restore: projectStore.load,
      writeAsset: projectStore.saveAsset,
      historyCapacity: historyCapacity,
    );
  }

  factory ProjectSession.withBackend({
    required ProjectDocument initial,
    required Future<void> Function(ProjectDocument) persist,
    required Future<ProjectDocument?> Function(String) restore,
    required Future<String> Function(String, String, List<int>) this._writeAsset,
    int historyCapacity = 80,
  }) => ProjectSession._(
        initial: initial,
        persist: persist,
        restore: restore,
        historyCapacity: historyCapacity,
      );

  final HistoryStack<ProjectDocument> _history;
  final Future<void> Function(ProjectDocument) _persist;
  final Future<ProjectDocument?> Function(String) _restore;
  final Future<String> Function(String, String, List<int>) _writeAsset;

  bool _dirty = false;
  bool _saving = false;
  int _revision = 0;
  Future<void>? _saveFuture;
  int _openToken = 0;

  ProjectDocument get document => _history.current;
  bool get isDirty => _dirty;
  bool get isSaving => _saving;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  int get undoCount => _history.undoCount;
  int get revision => _revision;

  void replace(ProjectDocument next) {
    if (next.id != document.id) {
      throw ArgumentError('A session cannot be replaced with another project id');
    }
    if (identical(next, document)) return;
    _history.record(next);
    _markDirty();
  }

  /// Applies one semantic edit and records exactly one history snapshot.
  ProjectDocument edit(ProjectDocument Function(ProjectDocument current) change) {
    final next = change(document);
    if (next.id != document.id) {
      throw ArgumentError('An edit cannot change the active project identifier');
    }
    replace(next);
    return document;
  }

  void _markDirty() {
    _revision++;
    _dirty = true;
    notifyListeners();
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

  /// Persists the asset before a manifest can refer to its stable path.
  Future<String> addAsset(String fileName, Uint8List bytes) =>
      _writeAsset(document.id, fileName, bytes);

  /// Concurrent save requests join one writer. If edits occur during IO, the
  /// writer persists the latest revision before completing.
  Future<void> save() {
    final active = _saveFuture;
    if (active != null) return active;
    // Defer execution one microtask so _saveFuture is installed before
    // notifyListeners can re-enter save() through an observer.
    final operation = Future<void>.microtask(_saveUntilClean);
    _saveFuture = operation;
    return operation.whenComplete(() {
      if (identical(_saveFuture, operation)) _saveFuture = null;
    });
  }

  Future<void> _saveUntilClean() async {
    _saving = true;
    notifyListeners();
    try {
      var firstPass = true;
      while (firstPass || _dirty) {
        firstPass = false;
        final revisionAtStart = _revision;
        final snapshot = document;
        await _persist(snapshot);
        if (_revision == revisionAtStart && identical(document, snapshot)) {
          _dirty = false;
          notifyListeners();
        }
      }
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Restores the currently selected project's persisted snapshot, if present.
  /// Existing edits are saved first so recovery never discards dirty work.
  Future<bool> restoreCurrent() async {
    if (_dirty || _saving) await save();
    final revisionAtStart = _revision;
    final loaded = await _restore(document.id);
    if (loaded == null) return false;
    if (_revision != revisionAtStart || _dirty || _saving) return false;
    if (loaded.id != document.id) {
      throw FormatException('Restored project identifier does not match the active id');
    }
    _history.reset(loaded);
    _revision++;
    _dirty = false;
    notifyListeners();
    return true;
  }

  /// A slow read must not overwrite edits made while it was in flight.
  Future<bool> open(String id) async {
    if (id == document.id) return true;
    final openToken = ++_openToken;
    if (_dirty || _saving) await save();
    final revisionAtStart = _revision;
    final loaded = await _restore(id);
    if (loaded == null) return false;
    if (openToken != _openToken) return false;
    if (loaded.id != id) {
      throw FormatException('Restored project identifier does not match the requested id');
    }
    if (_revision != revisionAtStart || _dirty || _saving) {
      throw StateError('Project changed while another project was loading');
    }
    _history.reset(loaded);
    _revision++;
    _dirty = false;
    notifyListeners();
    return true;
  }
}
