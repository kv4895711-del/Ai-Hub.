import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_model.dart';
import 'api_service.dart';

/// Asks the gateway which models it offers (GET /v1/models).
/// Errors are reported with the same [ApiException] the chat uses,
/// so the screen can show a friendly message.
class ModelsService {
  static const Duration _timeout = Duration(seconds: 12);

  // Words that mean "this is not a chat model" (so it is hidden from the list).
  static const List<String> _notChat = [
    'embed',
    'whisper',
    'tts',
    'moderation',
    'rerank',
    'dall-e',
    'stable-diffusion',
    'sdxl',
    'flux',
  ];

  static String _join(String baseUrl, String path) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base$path';
  }

  /// Returns the list with "Auto" first, then models sorted by provider and name.
  Future<List<AiModel>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse(_join(baseUrl, '/models')),
        headers: {
          'Accept': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
      ).timeout(_timeout);

      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFromStatus(response.statusCode, body);
      }

      return _parse(body);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    } finally {
      client.close();
    }
  }

  // ---------- Reading the reply ----------

  List<AiModel> _parse(String body) {
    dynamic json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      throw const ApiException(
        ApiErrorKind.unknown,
        detail: 'The model list had an unexpected format.',
      );
    }

    // Usually {"data": [...]}, but some gateways send a plain list.
    List<dynamic>? items;
    if (json is Map && json['data'] is List) {
      items = json['data'] as List<dynamic>;
    } else if (json is Map && json['models'] is List) {
      items = json['models'] as List<dynamic>;
    } else if (json is List) {
      items = json;
    }

    if (items == null) {
      throw const ApiException(
        ApiErrorKind.unknown,
        detail: 'The model list had an unexpected format.',
      );
    }

    final seen = <String>{};
    final all = <AiModel>[];
    final chatOnly = <AiModel>[];

    for (final item in items) {
      Map<String, dynamic>? map;
      if (item is Map) {
        map = Map<String, dynamic>.from(item);
      } else if (item is String) {
        map = {'id': item};
      }
      if (map == null) continue;

      final model = AiModel.fromJson(map);
      if (model.id.isEmpty || model.isAuto) continue;
      if (!seen.add(model.id)) continue;

      all.add(model);
      if (_looksLikeChatModel(model.id)) chatOnly.add(model);
    }

    // If our filter removed everything, show the full list instead.
    final list = chatOnly.isNotEmpty ? chatOnly : all;

    list.sort((a, b) {
      final p = a.provider.toLowerCase().compareTo(b.provider.toLowerCase());
      if (p != 0) return p;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return [AiModel.auto, ...list];
  }

  bool _looksLikeChatModel(String id) {
    final n = id.toLowerCase();
    for (final word in _notChat) {
      if (n.contains(word)) return false;
    }
    return true;
  }

  // ---------- Errors ----------

  ApiException _errorFromStatus(int status, String body) {
    var detail = '';
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] != null) {
        final e = json['error'];
        detail = e is Map && e['message'] != null
            ? e['message'].toString()
            : e.toString();
      }
    } catch (_) {
      detail = body.length > 160 ? body.substring(0, 160) : body;
    }

    ApiErrorKind kind;
    if (status == 401 || status == 403) {
      kind = ApiErrorKind.unauthorized;
    } else if (status == 429) {
      kind = ApiErrorKind.rateLimit;
    } else if (status >= 500) {
      kind = ApiErrorKind.server;
    } else {
      kind = ApiErrorKind.unknown;
    }
    return ApiException(kind, detail: detail, statusCode: status);
  }

  ApiException _mapError(Object e) {
    if (e is TimeoutException) return const ApiException(ApiErrorKind.timeout);
    if (e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException) {
      return const ApiException(ApiErrorKind.offline);
    }
    return ApiException(ApiErrorKind.unknown, detail: e.toString());
  }
}
