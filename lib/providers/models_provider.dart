import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/ai_model.dart';
import '../services/api_service.dart';
import '../services/models_service.dart';
import 'settings_provider.dart';

/// Keeps the list of models offered by the gateway and the model that is chosen
/// right now. The chosen model is saved in Settings (lastModel), so the chat
/// uses it for the next message, even if you change it in the middle of a chat.
class ModelsProvider extends ChangeNotifier {
  ModelsProvider(this._settings, {ModelsService? service})
      : _service = service ?? ModelsService();

  final SettingsProvider _settings;
  final ModelsService _service;

  List<AiModel> _models = const [AiModel.auto];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  bool _disposed = false;

  List<AiModel> get models => List.unmodifiable(_models);
  bool get isLoading => _loading;
  bool get hasLoaded => _loadedOnce;

  /// A friendly error text, or null when everything is fine.
  String? get error => _error;

  /// The id of the model that will answer the next message.
  String get selectedId => _settings.lastModel;

  /// The chosen model. If it is not in the list (for example the gateway
  /// removed it), a simple placeholder with the same id is returned.
  AiModel get selected {
    final id = selectedId;
    for (final m in _models) {
      if (m.id == id) return m;
    }
    if (id == AppConstants.autoModel) return AiModel.auto;
    final short = id.contains('/') ? id.split('/').last : id;
    return AiModel(id: id, name: short);
  }

  /// Short name for the chip next to the chat box.
  String get selectedName => selected.name;

  // ---------- Loading ----------

  /// Loads the list once. Call [load] with force: true to refresh it.
  Future<void> loadIfNeeded() async {
    if (_loadedOnce || _loading) return;
    await load();
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force) return;

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final list = await _service.fetchModels(
        baseUrl: _settings.baseUrl,
        apiKey: _settings.apiKey,
      );
      _models = list;
      _loadedOnce = true;
    } on ApiException catch (e) {
      _error = e.friendlyMessage;
    } catch (_) {
      _error = 'The model list could not be loaded.';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // ---------- Choosing ----------

  /// Chooses the model for the next message.
  Future<void> select(String modelId) async {
    final id = modelId.trim().isEmpty ? AppConstants.autoModel : modelId.trim();
    await _settings.setLastModel(id);
    _safeNotify();
  }

  // ---------- Searching and grouping ----------

  /// Models that match [query] (name, id or provider). Auto always stays first.
  /// With [visionOnly] true, only models that can read images are shown.
  List<AiModel> search(String query, {bool visionOnly = false}) {
    final q = query.trim().toLowerCase();
    final out = <AiModel>[];

    for (final m in _models) {
      if (m.isAuto) {
        if (q.isEmpty || 'auto'.contains(q) || 'gateway'.contains(q)) {
          out.add(m);
        }
        continue;
      }
      if (visionOnly && !m.supportsVision) continue;
      if (q.isNotEmpty) {
        final hit = m.name.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q) ||
            m.provider.toLowerCase().contains(q);
        if (!hit) continue;
      }
      out.add(m);
    }
    return out;
  }

  /// The search result grouped by provider, e.g. {"Google": [...], "Groq": [...]}.
  /// Auto is not part of the groups (the sheet shows it on top by itself).
  Map<String, List<AiModel>> grouped(String query, {bool visionOnly = false}) {
    final result = <String, List<AiModel>>{};
    for (final m in search(query, visionOnly: visionOnly)) {
      if (m.isAuto) continue;
      result.putIfAbsent(m.provider, () => []).add(m);
    }
    return result;
  }

  /// How many real models (without Auto) the gateway offers.
  int get modelCount => _models.where((m) => !m.isAuto).length;

  /// True when the chosen model is known to read images, or when we do not
  /// know (Auto and guessed models may still work).
  bool get selectedMayReadImages {
    final m = selected;
    return m.isAuto || m.supportsVision;
  }

  // ---------- Safe notify ----------

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
