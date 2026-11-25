import 'dart:async';

import 'project_session.dart';

/// Debounced autosave policy kept outside widgets and feature screens.
class AutosaveCoordinator {
  AutosaveCoordinator({
    required ProjectSession session,
    this.debounce = const Duration(seconds: 3),
    this.onError,
  }) : _session = session {
    if (debounce <= Duration.zero) {
      throw ArgumentError.value(debounce, 'debounce', 'Must be positive');
    }
  }

  final ProjectSession _session;
  final Duration debounce;
  final void Function(Object error, StackTrace stackTrace)? onError;

  Timer? _timer;
  bool _disposed = false;
  Future<void>? _flushFuture;

  bool get isScheduled => _timer?.isActive ?? false;

  void markChanged() {
    if (_disposed) throw StateError('AutosaveCoordinator is disposed');
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
      // Background timer failures are reported but never become unhandled
      // asynchronous exceptions. Dirty state remains available for retry.
      onError?.call(error, stackTrace);
    }
  }

  /// Explicit flush propagates errors to its caller so lifecycle owners can
  /// show a retry/leave-with-unsaved-changes decision instead of hiding data loss.
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

  /// Stops future timers. The owner should await [flush] before disposing.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
