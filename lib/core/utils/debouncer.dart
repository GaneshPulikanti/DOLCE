import 'dart:async';

/// A simple debouncer for search input and other rapid-fire events.
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({required this.duration});

  /// Run [action] after [duration] has passed since the last call.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancel any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether the debouncer has a pending action.
  bool get isPending => _timer?.isActive ?? false;

  /// Dispose of the debouncer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
