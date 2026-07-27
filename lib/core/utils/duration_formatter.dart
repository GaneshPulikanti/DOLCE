/// Utility for formatting durations into human-readable strings.
class DurationFormatter {
  DurationFormatter._();

  /// Formats a [Duration] as "mm:ss" or "h:mm:ss" if > 1 hour.
  static String format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats total milliseconds as "mm:ss".
  static String formatMs(int milliseconds) {
    return format(Duration(milliseconds: milliseconds));
  }

  /// Formats a duration in a compact human-readable way.
  /// e.g., "3 hr 22 min", "45 min", "2 min"
  static String formatCompact(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }
}
