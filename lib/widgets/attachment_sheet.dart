import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';

/// "+" button dabane par khulne wala menu.
enum AttachmentSource { camera, gallery, video, file }

/// Use:
///   final result = await AttachmentSheet.show(context);
///   if (result == null) return;            // sheet bina chune band hui
///   if (result.hasError) { ... }           // result.error dikhao
///   result.attachments                     // chuni hui files
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  /// Sheet kholta hai, user ke choice par picker chalata hai
  /// aur FilePickResult wapas deta hai.
  static Future<FilePickResult?> show(BuildContext context) async {
    final source = await showModalBottomSheet<AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const AttachmentSheet(),
    );
    if (source == null) return null;

    final service = FileService();
    switch (source) {
      case AttachmentSource.camera:
        return service.takePhoto();
      case AttachmentSource.gallery:
        return service.pickImages();
      case AttachmentSource.video:
        return service.pickVideo();
      case AttachmentSource.file:
        return service.pickFiles();
    }
  }

  void _choose(BuildContext context, AttachmentSource source) {
    final haptics = context.read<SettingsProvider>().haptics;
    AppUtils.selectionHaptic(haptics);
    Navigator.of(context).pop(source);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = AppTheme.textPrimary(isDark);
    final textSecondary = AppTheme.textSecondary(isDark);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(
          color: AppTheme.baseBackground(isDark).withOpacity(0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.glassBorder(isDark)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kya attach karna hai?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _option(
                  context,
                  Icons.photo_camera_rounded,
                  'Camera',
                  AttachmentSource.camera,
                  accent,
                  textPrimary,
                ),
                _option(
                  context,
                  Icons.photo_library_rounded,
                  'Gallery',
                  AttachmentSource.gallery,
                  accent,
                  textPrimary,
                ),
                _option(
                  context,
                  Icons.videocam_rounded,
                  'Video',
                  AttachmentSource.video,
                  accent,
                  textPrimary,
                ),
                _option(
                  context,
                  Icons.insert_drive_file_rounded,
                  'File',
                  AttachmentSource.file,
                  accent,
                  textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Image samajhne ke liye vision wala model chuno.',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String label,
    AttachmentSource source,
    Color accent,
    Color textPrimary,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _choose(context, source),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
