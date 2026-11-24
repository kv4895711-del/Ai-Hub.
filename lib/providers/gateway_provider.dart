import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/gateway_service.dart';
import 'settings_provider.dart';

/// The gateway's state, as shown by the status pill and the splash screen.
enum GatewayStatus {
  unknown,
  checking,
  connected,
  starting,
  offline,
  termuxMissing,
  needsPermission,
}

/// Keeps track of whether the FreeLLMAPI gateway is running and can start it
/// through Termux. It reads the gateway address from [SettingsProvider].
class GatewayProvider extends ChangeNotifier {
  GatewayProvider(this._settings, {GatewayService? service})
      : _service = service ?? GatewayService();

  final SettingsProvider _settings;
  final GatewayService _service;

  GatewayStatus _status = GatewayStatus.unknown;
  int _secondsLeft = 0;
  bool _busy = false;
  bool _disposed = false;
  Timer? _monitor;

  GatewayStatus get status => _status;
  int get secondsLeft => _secondsLeft;
  bool get isConnected => _status == GatewayStatus.connected;
  bool get isStarting => _status == GatewayStatus.starting;

  /// True while a check or a start is in progress.
  bool get isBusy => _busy;

  /// Short text for the status pill.
  String get label {
    switch (_status) {
      case GatewayStatus.unknown:
      case GatewayStatus.checking:
        return 'Checking...';
      case GatewayStatus.connected:
        return 'Connected';
      case GatewayStatus.starting:
        return 'Starting...';
      case GatewayStatus.offline:
        return 'Offline';
      case GatewayStatus.termuxMissing:
        return 'Termux missing';
      case GatewayStatus.needsPermission:
        return 'Permission needed';
    }
  }

  /// Longer, friendly text for the splash screen and help messages.
  String get message {
    switch (_status) {
      case GatewayStatus.unknown:
      case GatewayStatus.checking:
        return 'Checking the gateway...';
      case GatewayStatus.connected:
        return 'The gateway is running.';
      case GatewayStatus.starting:
        return _secondsLeft > 0
            ? 'Starting the gateway in Termux... about $_secondsLeft s left'
            : 'Starting the gateway in Termux...';
      case GatewayStatus.offline:
        return 'The gateway is not running. Open Setup help to start it.';
      case GatewayStatus.termuxMissing:
        return 'Termux was not found on this phone. Install it from F-Droid.';
      case GatewayStatus.needsPermission:
        return 'Allow "Run commands in Termux environment" for this app '
            'so it can start the gateway.';
    }
  }

  // ---------- Safe notify ----------

  void _set(GatewayStatus status, {int? secondsLeft}) {
    _status = status;
    if (secondsLeft != null) _secondsLeft = secondsLeft;
    if (!_disposed) notifyListeners();
  }

  // ---------- Check only ----------

  /// Looks once whether the gateway answers. Does not try to start it.
  Future<void> check() async {
    if (_busy || _status == GatewayStatus.starting) return;
    _busy = true;
    try {
      final firstTime = _status == GatewayStatus.unknown;
      if (firstTime) _set(GatewayStatus.checking);
      final running = await _service.isRunning(baseUrl: _settings.baseUrl);
      _set(running ? GatewayStatus.connected : GatewayStatus.offline);
    } finally {
      _busy = false;
    }
  }

  // ---------- Check and start ----------

  /// Makes sure the gateway is running. Starts it through Termux if needed.
  /// With [force] false, it respects the "auto-start" switch in Settings.
  Future<void> ensureRunning({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      _set(GatewayStatus.checking);
      final baseUrl = _settings.baseUrl;

      if (await _service.isRunning(baseUrl: baseUrl)) {
        _set(GatewayStatus.connected);
        return;
      }

      // Starting is only possible for a gateway on this same phone.
      final canStart = GatewayService.isLocalAddress(baseUrl);
      if (!canStart || (!_settings.autoStart && !force)) {
        _set(GatewayStatus.offline);
        return;
      }

      _set(GatewayStatus.starting, secondsLeft: 0);
      final result = await _service.startAndWait(
        baseUrl: baseUrl,
        onTick: (left) => _set(GatewayStatus.starting, secondsLeft: left),
      );

      switch (result) {
        case GatewayStartResult.alreadyRunning:
        case GatewayStartResult.started:
          _set(GatewayStatus.connected, secondsLeft: 0);
          break;
        case GatewayStartResult.termuxMissing:
          _set(GatewayStatus.termuxMissing, secondsLeft: 0);
          break;
        case GatewayStartResult.needsPermission:
          _set(GatewayStatus.needsPermission, secondsLeft: 0);
          break;
        case GatewayStartResult.failed:
          _set(GatewayStatus.offline, secondsLeft: 0);
          break;
      }
    } finally {
      _busy = false;
    }
  }

  // ---------- Permission helpers ----------

  Future<void> requestPermission() => _service.requestPermission();

  Future<void> openAppSettings() => _service.openAppSettings();

  // ---------- Background watching ----------

  /// Checks every 20 seconds so the status pill stays correct.
  void startMonitoring() {
    _monitor?.cancel();
    _monitor = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_status != GatewayStatus.starting && !_busy) {
        check();
      }
    });
  }

  void stopMonitoring() {
    _monitor?.cancel();
    _monitor = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _monitor?.cancel();
    super.dispose();
  }
}
