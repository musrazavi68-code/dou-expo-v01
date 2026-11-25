/// Bounded immutable-snapshot history with predictable undo/redo semantics.
/// Call [record] only after a user-visible edit has completed successfully.
class HistoryStack<T> {
  HistoryStack({this.capacity = 80, required T initial})
      : _current = initial {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }

  final int capacity;
  T _current;
  final List<T> _undo = [];
  final List<T> _redo = [];

  T get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;

  void record(T next) {
    if (identical(next, _current) || next == _current) return;
    _undo.add(_current);
    if (_undo.length > capacity) _undo.removeAt(0);
    _current = next;
    _redo.clear();
  }

  T? undo() {
    if (!canUndo) return null;
    _redo.add(_current);
    _current = _undo.removeLast();
    return _current;
  }

  T? redo() {
    if (!canRedo) return null;
    _undo.add(_current);
    if (_undo.length > capacity) _undo.removeAt(0);
    _current = _redo.removeLast();
    return _current;
  }

  void reset(T value) {
    _current = value;
    _undo.clear();
    _redo.clear();
  }
}
