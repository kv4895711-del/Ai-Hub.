import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// What happened when we tried to start the gateway.
enum GatewayStartResult {
  alreadyRunning,
  started,
  termuxMissing,
  needsPermission,
  failed,
}

/// Checks whether the FreeLLMAPI gateway is running and asks Termux to start it.
/// The Termux part uses the Kotlin bridge in tools/MainActivity.kt.
class GatewayService {
  static const MethodChannel _channel = MethodChannel(AppConstants.termuxChannel);

  // ---------- Address helpers ----------

  /// "http://localhost:3001/v1" becomes "http://localhost:3001".
  static String rootFromBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/v1')) {
      url = url.substring(0, url.length - 3);
    }
    return url.isEmpty ? AppConstants.gatewayRoot : url;
  }

  /// Auto-start only makes sense when the gateway is on this same phone.
  static bool isLocalAddress(String baseUrl) {
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase() ?? '';
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  // ---------- Health check ----------

  /// True when the gateway answers at all (any reply counts as "running").
  Future<bool> isRunning({String? baseUrl}) async {
    final root = baseUrl == null
        ? AppConstants.gatewayRoot
        : rootFromBaseUrl(baseUrl);
    final client = http.Client();
    try {
      await client
          .get(Uri.parse(root))
          .timeout(Duration(seconds: AppConstants.healthCheckSeconds));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ---------- Termux bridge ----------

  Future<bool> isTermuxInstalled() async {
    try {
      return (await _channel.invokeMethod<bool>('isTermuxInstalled')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return (await _channel.invokeMethod<bool>('hasRunCommandPermission')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Shows Android's permission pop-up for "Run commands in Termux environment".
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestRunCommandPermission');
    } catch (_) {}
  }

  /// Opens this app's page in Android Settings.
  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Sends the "run ~/startgateway.sh" command to Termux. Does not wait.
  Future<bool> _sendStartCommand() async {
    try {
      await _channel.invokeMethod('startGateway', {
        'script': AppConstants.termuxScript,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------- Start and wait ----------

  /// Starts the gateway (if needed) and waits up to 40 seconds for it to answer.
  /// [onTick] is called every second with the seconds that are left.
  Future<GatewayStartResult> startAndWait({
    String? baseUrl,
    void Function(int secondsLeft)? onTick,
  }) async {
    if (await isRunning(baseUrl: baseUrl)) {
      return GatewayStartResult.alreadyRunning;
    }

    if (!await isTermuxInstalled()) return GatewayStartResult.termuxMissing;
    if (!await hasPermission()) return GatewayStartResult.needsPermission;

    final sent = await _sendStartCommand();
    if (!sent) return GatewayStartResult.failed;

    final total = AppConstants.startupWaitSeconds;
    for (var i = 0; i < total; i++) {
      onTick?.call(total - i);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (await isRunning(baseUrl: baseUrl)) {
        return GatewayStartResult.started;
      }
    }
    return GatewayStartResult.failed;
  }
}
