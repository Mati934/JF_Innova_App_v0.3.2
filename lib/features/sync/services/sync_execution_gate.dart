class SyncExecutionGate<T> {
  Future<T>? _inFlight;

  Future<T> run(Future<T> Function() operation) {
    final active = _inFlight;
    if (active != null) return active;

    late final Future<T> current;
    current = Future<T>.sync(operation).whenComplete(() {
      if (identical(_inFlight, current)) _inFlight = null;
    });
    _inFlight = current;
    return current;
  }
}
