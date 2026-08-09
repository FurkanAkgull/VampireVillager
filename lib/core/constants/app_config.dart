import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Server address the app talks to. Defaults to the Android emulator's
/// host-loopback alias, but can be overridden (e.g. to a LAN IP) from the
/// Settings screen so a physical device can reach a server running on
/// another machine on the same network.
class AppConfig {
  static const _kHost = 'vk_server_host';
  static const _kPort = 'vk_server_port';

  static String? _hostOverride;
  static int? _portOverride;

  /// Loads a persisted host/port override, if any. Call once before the app
  /// starts using [httpBase]/[wsBase] (e.g. in main()).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hostOverride = prefs.getString(_kHost);
    _portOverride = prefs.getInt(_kPort);
  }

  /// Persists and applies a manual server address. Pass null values to clear
  /// the override and fall back to the platform default.
  static Future<void> setOverride({String? host, int? port}) async {
    final prefs = await SharedPreferences.getInstance();
    _hostOverride = (host == null || host.isEmpty) ? null : host;
    _portOverride = port;
    if (_hostOverride == null) {
      await prefs.remove(_kHost);
    } else {
      await prefs.setString(_kHost, _hostOverride!);
    }
    if (_portOverride == null) {
      await prefs.remove(_kPort);
    } else {
      await prefs.setInt(_kPort, _portOverride!);
    }
  }

  static String? get hostOverride => _hostOverride;
  static int? get portOverride => _portOverride;

  /// 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
  static String get _defaultHost {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {
      // Platform isn't available on some targets (e.g. tests); fall through.
    }
    return 'localhost';
  }

  static String get _host => _hostOverride ?? _defaultHost;
  static int get _port => _portOverride ?? 8000;

  static String get httpBase => 'http://$_host:$_port';
  static String get wsBase => 'ws://$_host:$_port';
}
