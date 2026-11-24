/// One AI model offered by the gateway (a row of GET /v1/models).
///
/// The gateway's reply can differ a little between versions, so everything here
/// is read carefully: missing fields never crash the app.
class AiModel {
  final String id;
  final String name;
  final String provider;
  final bool supportsVision;

  /// True when we only GUESSED vision support from the model's name.
  final bool visionGuessed;
  final bool supportsTools;
  final int? contextLength;

  const AiModel({
    required this.id,
    required this.name,
    this.provider = 'Other',
    this.supportsVision = false,
    this.visionGuessed = false,
    this.supportsTools = false,
    this.contextLength,
  });

  /// The "let the gateway choose" model. It is always the first item.
  static const AiModel auto = AiModel(
    id: 'auto',
    name: 'Auto',
    provider: 'Gateway',
  );

  bool get isAuto => id == 'auto';

  /// "128K", "1M" or an empty text when unknown.
  String get contextLabel {
    final c = contextLength;
    if (c == null || c <= 0) return '';
    if (c >= 1000000) {
      final m = c / 1000000;
      return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    if (c >= 1000) return '${(c / 1000).round()}K';
    return '$c';
  }

  // ---------- Reading from the gateway ----------

  factory AiModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['model'] ?? '').toString().trim();

    // Provider: an explicit field, or the part before "/" in the id.
    String provider = '';
    for (final key in ['provider', 'owned_by', 'vendor']) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) {
        provider = v.trim();
        break;
      }
    }
    if (provider.isEmpty && id.contains('/')) {
      provider = id.split('/').first;
    }
    if (provider.isEmpty) provider = _providerFromName(id);

    // Name: the id without a "provider/" prefix.
    final shortName = id.contains('/') ? id.split('/').last : id;
    final name = (json['name'] ?? json['display_name'] ?? shortName)
        .toString()
        .trim();

    final explicitVision = _readVision(json);
    final guessed = explicitVision == null && _guessVisionFromName(id);

    return AiModel(
      id: id,
      name: name.isEmpty ? shortName : name,
      provider: providerLabelOf(provider),
      supportsVision: explicitVision ?? guessed,
      visionGuessed: guessed,
      supportsTools: _readTools(json),
      contextLength: _readContext(json),
    );
  }

  // ---------- Provider names ----------

  static const Map<String, String> _providerNames = {
    'google': 'Google',
    'gemini': 'Google',
    'groq': 'Groq',
    'openrouter': 'OpenRouter',
    'mistral': 'Mistral',
    'cerebras': 'Cerebras',
    'nvidia': 'NVIDIA',
    'cohere': 'Cohere',
    'github': 'GitHub Models',
    'cloudflare': 'Cloudflare',
    'huggingface': 'Hugging Face',
    'ovh': 'OVH',
    'kilo': 'Kilo',
    'aihorde': 'AI Horde',
    'openai': 'OpenAI',
    'anthropic': 'Anthropic',
    'xai': 'xAI',
    'deepseek': 'DeepSeek',
  };

  /// A friendly provider name, e.g. "openrouter" becomes "OpenRouter".
  static String providerLabelOf(String raw) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) return 'Other';
    final known = _providerNames[key];
    if (known != null) return known;
    return key[0].toUpperCase() + key.substring(1);
  }

  static String _providerFromName(String id) {
    final n = id.toLowerCase();
    if (n.startsWith('gemini') || n.startsWith('gemma')) return 'google';
    if (n.startsWith('mistral') ||
        n.startsWith('codestral') ||
        n.startsWith('devstral') ||
        n.startsWith('pixtral')) {
      return 'mistral';
    }
    if (n.startsWith('deepseek')) return 'deepseek';
    if (n.startsWith('gpt') || n.startsWith('o1') || n.startsWith('o3')) {
      return 'openai';
    }
    if (n.startsWith('grok')) return 'xai';
    return '';
  }

  // ---------- Reading abilities ----------

  static bool? _boolOf(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == 'yes') return true;
      if (s == 'false' || s == 'no') return false;
    }
    return null;
  }

  static bool _listHasAny(dynamic list, List<String> words) {
    if (list is! List) return false;
    for (final item in list) {
      final s = item.toString().toLowerCase();
      for (final w in words) {
        if (s.contains(w)) return true;
      }
    }
    return false;
  }

  /// true / false when the gateway says it, null when it says nothing.
  static bool? _readVision(Map<String, dynamic> json) {
    for (final key in ['vision', 'supports_vision', 'supportsVision']) {
      final b = _boolOf(json[key]);
      if (b != null) return b;
    }
    final caps = json['capabilities'];
    if (caps is Map) {
      for (final key in ['vision', 'image', 'images']) {
        final b = _boolOf(caps[key]);
        if (b != null) return b;
      }
    }
    if (caps is List) {
      return _listHasAny(caps, ['vision', 'image']);
    }
    for (final key in ['input_modalities', 'modalities']) {
      final m = json[key];
      if (m is List) return _listHasAny(m, ['image', 'vision']);
      if (m is Map && m['input'] is List) {
        return _listHasAny(m['input'], ['image', 'vision']);
      }
    }
    return null;
  }

  static bool _readTools(Map<String, dynamic> json) {
    for (final key in [
      'tools',
      'supports_tools',
      'supportsTools',
      'function_calling',
      'tool_calling',
    ]) {
      final b = _boolOf(json[key]);
      if (b != null) return b;
    }
    final caps = json['capabilities'];
    if (caps is Map) {
      for (final key in ['tools', 'function_calling', 'tool_calling']) {
        final b = _boolOf(caps[key]);
        if (b != null) return b;
      }
    }
    if (caps is List) {
      return _listHasAny(caps, ['tool', 'function']);
    }
    return false;
  }

  static int? _readContext(Map<String, dynamic> json) {
    for (final key in [
      'context_length',
      'context_window',
      'max_context',
      'context',
      'ctx',
    ]) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
        if (n != null) return n;
      }
    }
    return null;
  }

  /// A best-effort guess used only when the gateway does not say.
  static bool _guessVisionFromName(String id) {
    final n = id.toLowerCase();
    const hints = [
      'vision',
      '-vl',
      'vl-',
      'llava',
      'pixtral',
      'gemini',
      'gpt-4o',
      'gpt-4.1',
      'omni',
      'multimodal',
      'llama-4',
      'gemma-3',
      'gemma3',
      'qwen2.5-vl',
      'qwen3-vl',
    ];
    for (final h in hints) {
      if (n.contains(h)) return true;
    }
    return false;
  }
}
