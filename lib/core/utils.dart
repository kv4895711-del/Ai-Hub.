import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

/// Small helpers used all over the app.
class AppUtils {
  AppUtils._();

  // ---------- Time ----------

  /// "3:45 PM"
  static String formatTime(DateTime time) => DateFormat('h:mm a').format(time);

  /// "Today", "Yesterday", or "12 Nov" (used in the chat list).
  static String formatDay(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (time.year == now.year) return DateFormat('d MMM').format(time);
    return DateFormat('d MMM y').format(time);
  }

  // ---------- Text ----------

  /// Makes a short chat title from the first message.
  static String makeTitle(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return AppConstants.newChatTitle;
    if (clean.length <= AppConstants.maxTitleLength) return clean;
    return '${clean.substring(0, AppConstants.maxTitleLength).trim()}...';
  }

  /// "1.2 MB", "340 KB"
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Hides most of a secret, e.g. "freellmapi-d4ca...8fc".
  static String maskKey(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 14) return '*' * key.length;
    return '${key.substring(0, 12)}...${key.substring(key.length - 3)}';
  }

  // ---------- Haptics ----------

  static void lightHaptic(bool enabled) {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumHaptic(bool enabled) {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void selectionHaptic(bool enabled) {
    if (enabled) HapticFeedback.selectionClick();
  }

  // ---------- Messages ----------

  /// Floating glass-style snack bar.
  static void showSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Copies text to the clipboard and tells the user.
  static Future<void> copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showSnack(context, 'Copied');
  }
}
