import 'dart:async';

import 'project_session.dart';

/// Debounced autosave policy observing revision changes from the shared
/// session. Callers do not need to remember to schedule saves per feature.
class AutosaveCoordinator {
  AutosaveCoordinator({
    required ProjectSession session,
    this.debounce = const Duration(seconds: 3),
    this.onError,
  }) : _session = session {
    if (debounce <= Duration.zero) {
      throw ArgumentError.value(debounce, 'debounce', 'Must be positive');
    }
    _lastRevision = session.revision;
    session.addListener(_onSessionChanged);
  }

  final ProjectSession _session;
  final Duration debounce;
  final void Function(Object error, StackTrace stackTrace)? onError;

  Timer? _timer;
  bool _disposed = false;
  int _lastRevision = 0;
  Future<void>? _flushFuture;

  bool get isScheduled => _timer?.isActive ?? false;

  void _onSessionChanged() {
    final revision = _session.revision;
    if (revision == _lastRevision) return;
    _lastRevision = revision;
    _schedule();
  }

  /// Kept for explicit feature hooks; normally revision observation is enough.
  void markChanged() {
    if (_disposed) throw StateError('AutosaveCoordinator is disposed');
    _schedule();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_saveInBackground());
    });
  }

  Future<void> _saveInBackground() async {
    try {
      if (_session.isDirty) await _session.save();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  /// Explicit flush propagates failures to the lifecycle owner.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    final active = _flushFuture;
    if (active != null) return active;
    final operation = _session.isDirty ? _session.save() : Future<void>.value();
    _flushFuture = operation;
    return operation.whenComplete(() {
      if (identical(_flushFuture, operation)) _flushFuture = null;
    });
  }

  void dispose() {
    _disposed = true;
    _session.removeListener(_onSessionChanged);
    _timer?.cancel();
    _timer = null;
  }
}
