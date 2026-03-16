import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'admin_analytics_service.dart';

/// Client-side service for tracking anonymous guest interactions.
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  static const String _guestIdKey = 'guest_telemetry_id';
  static const String _installDateKey = 'app_install_date';
  
  String? _guestId;
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  Completer<void>? _initCompleter;

  /// Initializes the telemetry service, generating a persistent guest ID if needed.
  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      _guestId = prefs.getString(_guestIdKey);
      
      if (_guestId == null) {
        _guestId = const Uuid().v4();
        await prefs.setString(_guestIdKey, _guestId!);
        await prefs.setString(_installDateKey, DateTime.now().toIso8601String());
        
        // Log the initial install event
        await logEvent(
          'app_install',
          details: 'Initial app installation detected.',
        );
      }
      _initCompleter!.complete();
    } catch (e, stack) {
      _initCompleter!.completeError(e, stack);
      _initCompleter = null; // Allow retry on failure
    }
  }

  /// Logs a telemetry event with guest context.
  Future<void> logEvent(String action, {String? details, String? targetId}) async {
    if (_guestId == null) await init();
    
    await _analytics.logGuestEvent(
      guestId: _guestId!,
      action: action,
      details: details,
      targetId: targetId,
    );
  }
}
