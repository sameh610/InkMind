import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform haptics — no-ops on web.
abstract final class InkHaptics {
  static Future<void> selection() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    if (kIsWeb) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> success() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> divergence() async {
    if (kIsWeb) return;
    await HapticFeedback.heavyImpact();
  }
}
