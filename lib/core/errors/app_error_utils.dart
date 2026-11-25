import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

class AppErrorUtils {
  AppErrorUtils._();

  static String newCode({String scope = 'GEN'}) {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final tail = now.microsecondsSinceEpoch
        .remainder(65536)
        .toRadixString(16)
        .padLeft(4, '0');

    final normalizedScope = scope
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);

    return '$normalizedScope-$y$m$d-$hh$mm$ss-${tail.toUpperCase()}';
  }

  static String messageWithCode(String message, String code) {
    return '$message\nCodigo: $code';
  }

  static SnackBar buildErrorSnackBar({
    required String message,
    required String code,
    Color? backgroundColor,
    Duration? duration,
  }) {
    return SnackBar(
      backgroundColor: backgroundColor ?? Colors.red.shade800,
      duration: duration ?? const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 6),
          Text(
            'Codigo de error: $code',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static Future<String> capture(
    Object error,
    StackTrace stack, {
    String scope = 'GEN',
    String? reason,
    bool fatal = false,
  }) async {
    final code = newCode(scope: scope);
    final r = reason ?? 'error';

    debugPrint('❌ [$code] $r: $error');

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: '$r | code=$code',
        fatal: fatal,
      );
    } catch (_) {
      // Evita que el flujo principal falle si Crashlytics no responde.
    }

    return code;
  }
}
