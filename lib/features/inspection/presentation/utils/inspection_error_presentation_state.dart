class InspectionErrorPresentationState {
  bool _isFinalizing = false;

  bool get shouldHandleControllerError => !_isFinalizing;

  void beginFinalization() {
    _isFinalizing = true;
  }

  void endFinalization() {
    _isFinalizing = false;
  }
}
