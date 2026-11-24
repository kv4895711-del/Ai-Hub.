/// Ek attachment (image, video ya file) ka model.
/// JSON keys EXACTLY: type, name, mime, path, size, text
class Attachment {
  static const String typeImage = 'image';
  static const String typeVideo = 'video';
  static const String typeFile = 'file';

  /// 'image' | 'video' | 'file'
  final String type;
  final String name;
  final String mime;
  final String path;
  final int size;

  /// Text/code files ka andar ka text (baaki types ke liye null).
  final String? text;

  const Attachment({
    required this.type,
    required this.name,
    this.mime = '',
    this.path = '',
    this.size = 0,
    this.text,
  });

  bool get isImage => type == typeImage;
  bool get isVideo => type == typeVideo;
  bool get isFile => type == typeFile;

  /// Kya is attachment ke saath padha hua text hai?
  bool get hasText => text != null && text!.trim().isNotEmpty;

  Attachment copyWith({
    String? type,
    String? name,
    String? mime,
    String? path,
    int? size,
    String? text,
  }) {
    return Attachment(
      type: type ?? this.type,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      path: path ?? this.path,
      size: size ?? this.size,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'mime': mime,
        'path': path,
        'size': size,
        'text': text,
      };

  factory Attachment.fromJson(Map<String, dynamic> json) {
    int parseSize(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String parseType(dynamic v) {
      final s = v?.toString() ?? '';
      if (s == typeImage || s == typeVideo || s == typeFile) return s;
      return typeFile;
    }

    return Attachment(
      type: parseType(json['type']),
      name: json['name']?.toString() ?? '',
      mime: json['mime']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      size: parseSize(json['size']),
      text: json['text']?.toString(),
    );
  }

  @override
  String toString() => 'Attachment($type, $name, $size bytes)';
}
