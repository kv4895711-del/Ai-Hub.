import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../models/attachment.dart';

/// Picker ka natija: attachments ki list, aur agar kuch galat hua to error.
/// User ne cancel kiya to list khaali hogi aur error null.
class FilePickResult {
  final List<Attachment> attachments;
  final String? error;

  const FilePickResult({this.attachments = const [], this.error});

  bool get isEmpty => attachments.isEmpty;
  bool get hasError => error != null && error!.isNotEmpty;
}

/// Image / camera / video / file pick karta hai aur text-code files ka
/// text padhta hai.
class FileService {
  /// Isse badi file allow nahi (bytes).
  static const int maxFileBytes = 25 * 1024 * 1024;

  /// Text files se maximum itne bytes padhe jayenge.
  static const int maxTextBytes = 120 * 1024;

  /// Padhe hue text ki maximum length (characters).
  static const int maxTextChars = 30000;

  static const Set<String> _textExtensions = {
    'txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml',
    'toml', 'ini', 'cfg', 'conf', 'log', 'html', 'htm', 'css', 'scss',
    'js', 'jsx', 'ts', 'tsx', 'dart', 'py', 'java', 'kt', 'kts', 'swift',
    'c', 'h', 'cpp', 'hpp', 'cc', 'cs', 'go', 'rs', 'rb', 'php', 'sh',
    'bash', 'zsh', 'bat', 'sql', 'r', 'lua', 'pl', 'gradle', 'properties',
    'env', 'gitignore', 'tex', 'srt', 'vtt', 'svg',
  };

  final ImagePicker _imagePicker = ImagePicker();

  // ---------- public pickers ----------

  /// Gallery se ek ya zyada images.
  Future<FilePickResult> pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (files.isEmpty) return const FilePickResult();
      return _fromPaths(files.map((f) => f.path).toList(), forceType: null);
    } catch (e) {
      debugPrint('pickImages error: $e');
      return const FilePickResult(
          error: 'Gallery nahi khul payi. Permission check karo.');
    }
  }

  /// Camera se photo.
  Future<FilePickResult> takePhoto() async {
    try {
      final f = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (f == null) return const FilePickResult();
      return _fromPaths([f.path], forceType: Attachment.typeImage);
    } catch (e) {
      debugPrint('takePhoto error: $e');
      return const FilePickResult(
          error: 'Camera nahi khula. Camera permission allow karo.');
    }
  }

  /// Gallery se video.
  Future<FilePickResult> pickVideo() async {
    try {
      final f = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (f == null) return const FilePickResult();
      return _fromPaths([f.path], forceType: Attachment.typeVideo);
    } catch (e) {
      debugPrint('pickVideo error: $e');
      return const FilePickResult(
          error: 'Video nahi mil payi. Permission check karo.');
    }
  }

  /// Koi bhi file (text, code, pdf, etc).
  Future<FilePickResult> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return const FilePickResult();
      }
      final paths = <String>[];
      for (final f in result.files) {
        final p = f.path;
        if (p != null && p.isNotEmpty) paths.add(p);
      }
      if (paths.isEmpty) {
        return const FilePickResult(error: 'File ka path nahi mila.');
      }
      return _fromPaths(paths, forceType: null);
    } catch (e) {
      debugPrint('pickFiles error: $e');
      return const FilePickResult(error: 'File picker nahi khul paya.');
    }
  }

  // ---------- helpers ----------

  /// Mime type se 'image' | 'video' | 'file' nikalta hai.
  static String typeFromMime(String mime) {
    if (mime.startsWith('image/')) return Attachment.typeImage;
    if (mime.startsWith('video/')) return Attachment.typeVideo;
    return Attachment.typeFile;
  }

  /// Kya ye file text/code jaisi hai (jise padha ja sakta hai)?
  static bool isTextLike(String path, String mime) {
    if (mime.startsWith('text/')) return true;
    if (mime == 'application/json' ||
        mime == 'application/xml' ||
        mime == 'application/javascript' ||
        mime == 'application/x-sh' ||
        mime == 'application/x-yaml' ||
        mime == 'application/sql') {
      return true;
    }
    return _textExtensions.contains(_extension(path));
  }

  static String _extension(String path) {
    final name = _fileName(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0) {
      // '.gitignore' jaisi files
      return name.toLowerCase().replaceAll('.', '');
    }
    return name.substring(dot + 1).toLowerCase();
  }

  static String _fileName(String path) {
    final i = path.lastIndexOf(Platform.pathSeparator);
    final j = path.lastIndexOf('/');
    final k = i > j ? i : j;
    return k < 0 ? path : path.substring(k + 1);
  }

  Future<FilePickResult> _fromPaths(
    List<String> paths, {
    String? forceType,
  }) async {
    final List<Attachment> out = [];
    final List<String> problems = [];

    for (final path in paths) {
      final name = _fileName(path);
      try {
        final file = File(path);
        if (!await file.exists()) {
          problems.add('"$name" nahi mili.');
          continue;
        }
        final size = await file.length();
        if (size > maxFileBytes) {
          problems.add('"$name" bahut badi hai (max 25 MB).');
          continue;
        }

        final mime = lookupMimeType(path) ?? _fallbackMime(forceType);
        final type = forceType ?? typeFromMime(mime);

        String? text;
        if (type == Attachment.typeFile && isTextLike(path, mime)) {
          text = await _readText(file, size);
        }

        out.add(Attachment(
          type: type,
          name: name,
          mime: mime,
          path: path,
          size: size,
          text: text,
        ));
      } catch (e) {
        debugPrint('_fromPaths error ($name): $e');
        problems.add('"$name" padh nahi paya.');
      }
    }

    return FilePickResult(
      attachments: out,
      error: problems.isEmpty ? null : problems.join('\n'),
    );
  }

  String _fallbackMime(String? forceType) {
    if (forceType == Attachment.typeImage) return 'image/jpeg';
    if (forceType == Attachment.typeVideo) return 'video/mp4';
    return 'application/octet-stream';
  }

  /// Text file ka shuru ka hissa padhta hai (badi file ho to kaat deta hai).
  Future<String?> _readText(File file, int size) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final toRead = size < maxTextBytes ? size : maxTextBytes;
      final bytes = await raf.read(toRead);
      String text = utf8.decode(bytes, allowMalformed: true);
      bool cut = size > maxTextBytes;
      if (text.length > maxTextChars) {
        text = text.substring(0, maxTextChars);
        cut = true;
      }
      if (cut) {
        text = '$text\n\n[... file bahut badi thi, aage ka hissa kaat diya gaya ...]';
      }
      return text;
    } catch (e) {
      debugPrint('_readText error: $e');
      return null;
    } finally {
      await raf?.close();
    }
  }
}
