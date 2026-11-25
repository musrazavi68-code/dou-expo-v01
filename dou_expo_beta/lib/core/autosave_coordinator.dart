import 'dart:async';

import 'project_session.dart';

/// Debounced autosave policy kept outside widgets and feature screens.
///
/// Call [markChanged] after a completed user action and [flush] when the app
/// becomes inactive/paused. A failed save is surfaced to the owner and the
/// session remains dirty so a later flush can retry.
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
      unawaited(_saveAndReport());
    });
  }

  Future<void> _saveAndReport() async {
    try {
      if (_session.isDirty) await _session.save();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  /// Cancels the debounce and waits for the current session revision to save.
  Future<void> flush() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    final active = _flushFuture;
    if (active != null) return active;
    final operation = _saveAndReport();
    _flushFuture = operation;
    return operation.whenComplete(() {
      if (identical(_flushFuture, operation)) _flushFuture = null;
    });
  }

  /// Stops future timers. Call [flush] before disposing when data is dirty.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
