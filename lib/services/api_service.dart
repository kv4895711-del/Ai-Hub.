import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/message.dart';

/// The kinds of problems that can happen when talking to the gateway.
enum ApiErrorKind {
  offline,
  unauthorized,
  rateLimit,
  badRequest,
  server,
  timeout,
  unknown,
}

/// An error with a message that is safe and friendly to show to the user.
class ApiException implements Exception {
  final ApiErrorKind kind;
  final String detail;
  final int? statusCode;

  const ApiException(this.kind, {this.detail = '', this.statusCode});

  String get friendlyMessage {
    switch (kind) {
      case ApiErrorKind.offline:
        return "Can't reach the gateway. Make sure FreeLLMAPI is running in "
            'Termux, then try again.';
      case ApiErrorKind.unauthorized:
        return 'The API key was rejected. Check the key in Settings.';
      case ApiErrorKind.rateLimit:
        return 'The free models are busy or the rate limit was reached. '
            'Wait a little and try again, or pick another model.';
      case ApiErrorKind.badRequest:
        return 'The model could not handle this request.${_tail()}';
      case ApiErrorKind.server:
        return 'The gateway or the model had a problem.${_tail()}';
      case ApiErrorKind.timeout:
        return 'The reply took too long. Try again or choose another model.';
      case ApiErrorKind.unknown:
        return 'Something went wrong.${_tail()}';
    }
  }

  String _tail() {
    final d = detail.trim();
    if (d.isEmpty) return '';
    return ' ${d.length > 200 ? '${d.substring(0, 200)}...' : d}';
  }

  @override
  String toString() => friendlyMessage;
}

/// Talks to the FreeLLMAPI gateway (OpenAI-compatible).
/// It keeps no settings itself: the base URL and key are passed in on every call.
class ApiService {
  http.Client? _client;
  bool _cancelled = false;

  static const int _maxImageBytes = 8 * 1024 * 1024;

  // ---------- Helpers ----------

  static String _join(String baseUrl, String path) {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base$path';
  }

  Map<String, String> _headers(String apiKey) {
    return {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };
  }

  /// Stops the reply that is being written right now.
  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  // ---------- Streaming chat ----------

  /// Sends the chat and yields the answer piece by piece.
  Stream<String> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async* {
    _cancelled = false;
    final client = http.Client();
    _client = client;

    try {
      final request = http.Request(
        'POST',
        Uri.parse(_join(baseUrl, '/chat/completions')),
      );
      request.headers.addAll(_headers(apiKey));
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
      });

      final response =
          await client.send(request).timeout(AppConstants.connectTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw _errorFromResponse(response.statusCode, body);
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines.timeout(AppConstants.replyTimeout)) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;

        final piece = _extractDelta(data);
        if (piece != null && piece.isNotEmpty) yield piece;
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      if (_cancelled) return;
      throw _mapError(e);
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  // ---------- Normal (non-streaming) chat ----------

  /// Fallback when streaming does not work: waits for the whole answer.
  Future<String> chat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    _cancelled = false;
    final client = http.Client();
    _client = client;

    try {
      final response = await client
          .post(
            Uri.parse(_join(baseUrl, '/chat/completions')),
            headers: _headers(apiKey),
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'stream': false,
            }),
          )
          .timeout(AppConstants.replyTimeout);

      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFromResponse(response.statusCode, body);
      }

      final json = jsonDecode(body);
      if (json is Map) {
        if (json['error'] != null) {
          throw ApiException(ApiErrorKind.server,
              detail: _errorText(json['error']));
        }
        final choices = json['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final message = (choices.first as Map)['message'];
          if (message is Map) {
            return _contentToString(message['content']) ?? '';
          }
        }
      }
      throw const ApiException(ApiErrorKind.unknown,
          detail: 'The reply had an unexpected format.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (_cancelled) return '';
      throw _mapError(e);
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  // ---------- Connection test ----------

  /// Checks the address and key. Returns how many models the gateway offers.
  Future<int> testConnection({
    required String baseUrl,
    required String apiKey,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(_join(baseUrl, '/models')), headers: _headers(apiKey))
          .timeout(const Duration(seconds: 8));

      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _errorFromResponse(response.statusCode, body);
      }
      final json = jsonDecode(body);
      if (json is Map && json['data'] is List) {
        return (json['data'] as List).length;
      }
      return 0;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _mapError(e);
    } finally {
      client.close();
    }
  }

  // ---------- Building the messages to send ----------

  /// Turns our saved chat into the list the API wants.
  ///
  /// Attachment maps use these keys (Attachment.toJson in attachment.dart):
  ///   type: 'image' | 'video' | 'file', name, mime, path, size, text
  /// Images are read from [path] and sent as base64. Files send their [text].
  Future<List<Map<String, dynamic>>> buildMessages(
    List<ChatMessage> history, {
    String? systemPrompt,
  }) async {
    final out = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      out.add({'role': 'system', 'content': systemPrompt.trim()});
    }

    for (final m in history) {
      if (m.isError) continue;
      if (m.isAssistant) {
        if (m.content.trim().isEmpty) continue;
        out.add({'role': 'assistant', 'content': m.content});
      } else if (m.isUser) {
        out.add(await _userMessage(m));
      }
    }
    return out;
  }

  Future<Map<String, dynamic>> _userMessage(ChatMessage m) async {
    final text = StringBuffer(m.content);
    final images = <Map<String, dynamic>>[];

    for (final a in m.attachments) {
      final type = (a['type'] ?? 'file').toString();
      final name = (a['name'] ?? 'file').toString();

      if (type == 'image') {
        final mime = (a['mime'] ?? 'image/jpeg').toString();
        final data = await _readBase64(a['path']?.toString());
        if (data != null) {
          images.add({
            'type': 'image_url',
            'image_url': {'url': 'data:$mime;base64,$data'},
          });
        } else {
          text.write('\n\n[The image "$name" could not be attached.]');
        }
      } else if (type == 'video') {
        text.write('\n\n[A video named "$name" was attached, but videos '
            'cannot be read by this model.]');
      } else {
        final fileText = a['text'];
        if (fileText is String && fileText.trim().isNotEmpty) {
          text.write('\n\n--- File: $name ---\n$fileText\n--- End of file ---');
        } else {
          text.write('\n\n[The file "$name" was attached, but its text '
              'could not be read.]');
        }
      }
    }

    final finalText = text.toString();
    if (images.isEmpty) {
      return {'role': 'user', 'content': finalText};
    }
    return {
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': finalText.trim().isEmpty
              ? 'Please look at the attached image.'
              : finalText,
        },
        ...images,
      ],
    };
  }

  Future<String?> _readBase64(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      if (await file.length() > _maxImageBytes) return null;
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  // ---------- Reading the answer ----------

  String? _extractDelta(String data) {
    dynamic json;
    try {
      json = jsonDecode(data);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;

    if (json['error'] != null) {
      throw ApiException(ApiErrorKind.server, detail: _errorText(json['error']));
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;

    final delta = first['delta'] ?? first['message'];
    if (delta is! Map) return null;
    return _contentToString(delta['content']);
  }

  String? _contentToString(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
      return buffer.toString();
    }
    return null;
  }

  // ---------- Errors ----------

  String _errorText(dynamic error) {
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    return error.toString();
  }

  ApiException _errorFromResponse(int status, String body) {
    var detail = '';
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] != null) {
        detail = _errorText(json['error']);
      } else if (json is Map && json['message'] != null) {
        detail = json['message'].toString();
      }
    } catch (_) {
      detail = body.length > 200 ? body.substring(0, 200) : body;
    }

    ApiErrorKind kind;
    if (status == 401 || status == 403) {
      kind = ApiErrorKind.unauthorized;
    } else if (status == 429) {
      kind = ApiErrorKind.rateLimit;
    } else if (status == 400 || status == 404 || status == 422) {
      kind = ApiErrorKind.badRequest;
    } else if (status >= 500) {
      kind = ApiErrorKind.server;
    } else {
      kind = ApiErrorKind.unknown;
    }
    return ApiException(kind, detail: detail, statusCode: status);
  }

  ApiException _mapError(Object e) {
    if (e is ApiException) return e;
    if (e is TimeoutException) return const ApiException(ApiErrorKind.timeout);
    if (e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException) {
      return const ApiException(ApiErrorKind.offline);
    }
    return ApiException(ApiErrorKind.unknown, detail: e.toString());
  }
}
