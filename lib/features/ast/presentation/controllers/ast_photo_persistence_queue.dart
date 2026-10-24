import 'dart:async';

class AstPhotoPersistenceQueue {
  AstPhotoPersistenceQueue({this.onChanged});

  final void Function()? onChanged;
  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  int _activeOperations = 0;

  bool get isProcessing => _activeOperations > 0;

  Future<void> track(Future<void> operation) {
    _generation++;
    _activeOperations++;
    onChanged?.call();

    final tracked = operation.whenComplete(() {
      _activeOperations--;
      onChanged?.call();
    });
    _pending = Future.wait([_pending, tracked]);
    return tracked;
  }

  Future<void> waitUntilIdle() async {
    while (true) {
      final generation = _generation;
      await _pending;
      if (generation == _generation) return;
    }
  }
}
