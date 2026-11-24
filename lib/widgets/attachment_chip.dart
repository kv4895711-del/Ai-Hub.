import 'dart:io';

import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../theme/app_theme.dart';

/// Chhota preview chip: thumbnail/icon + naam + size.
/// `onRemove` dene par X button dikhta hai (input bar ke liye).
/// `onRemove` na do to sirf preview dikhta hai (message bubble ke liye).
///
/// Use:
///   AttachmentChip(attachment: a, onRemove: () { ... })
///   AttachmentChip(attachment: Attachment.fromJson(map))
class AttachmentChip extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const AttachmentChip({
    super.key,
    required this.attachment,
    this.onRemove,
    this.onTap,
  });

  static String _size(int bytes) {
    if (bytes <= 0) return '';
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  String get _subtitle {
    final String kind;
    if (attachment.isImage) {
      kind = 'Image';
    } else if (attachment.isVideo) {
      kind = 'Video';
    } else if (attachment.hasText) {
      kind = 'Text';
    } else {
      kind = 'File';
    }
    final s = _size(attachment.size);
    return s.isEmpty ? kind : '$kind • $s';
  }

  IconData get _icon {
    if (attachment.isImage) return Icons.image_rounded;
    if (attachment.isVideo) return Icons.videocam_rounded;
    if (attachment.hasText) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _leading(Color accent) {
    final fallback = Icon(_icon, color: accent, size: 24);

    Widget child = fallback;
    if (attachment.isImage && attachment.path.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(attachment.path),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, __, ___) => Center(child: fallback),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = AppTheme.textPrimary(isDark);
    final textSecondary = AppTheme.textSecondary(isDark);

    final name = attachment.name.trim().isEmpty ? 'file' : attachment.name;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: AppTheme.glassFill(isDark),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.fromLTRB(6, 6, onRemove != null ? 2 : 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _leading(accent),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Hatao',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: textSecondary),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
