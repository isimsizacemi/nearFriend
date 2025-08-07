import 'dart:convert';
import 'package:http/http.dart' as http;

class TimeService {
  static const String _worldTimeApiUrl =
      'https://worldtimeapi.org/api/timezone/Europe/Istanbul';
  static const String _fallbackApiUrl = 'https://worldtimeapi.org/api/ip';

  static DateTime? _cachedTime;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  static Future<DateTime> getCurrentTime() async {
    try {
      if (_cachedTime != null && _lastFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _cacheDuration) {
          final elapsedTime = DateTime.now().difference(_lastFetchTime!);
          return _cachedTime!.add(elapsedTime);
        }
      }

      print('🕐 TimeService: İnternet saatini alıyor...');

      final response = await http
          .get(Uri.parse(_worldTimeApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dateTimeString = data['datetime'] as String;
        final utcTime = DateTime.parse(dateTimeString);

        final turkeyTime = utcTime.add(const Duration(hours: 3));

        _cachedTime = turkeyTime;
        _lastFetchTime = DateTime.now();

        print('✅ TimeService: İnternet saati alındı: $turkeyTime');
        return turkeyTime;
      }

      print('⚠️ TimeService: İlk API başarısız, fallback deneniyor...');
      final fallbackResponse = await http
          .get(Uri.parse(_fallbackApiUrl))
          .timeout(const Duration(seconds: 10));

      if (fallbackResponse.statusCode == 200) {
        final data = json.decode(fallbackResponse.body);
        final dateTimeString = data['datetime'] as String;
        final utcTime = DateTime.parse(dateTimeString);

        final turkeyTime = utcTime.add(const Duration(hours: 3));

        _cachedTime = turkeyTime;
        _lastFetchTime = DateTime.now();

        print('✅ TimeService: Fallback API ile saat alındı: $turkeyTime');
        return turkeyTime;
      }

      throw Exception('Her iki API de başarısız');
    } catch (e) {
      print('❌ TimeService: İnternet saati alınamadı: $e');
      print('⚠️ TimeService: Cihaz saati kullanılıyor');

      return DateTime.now();
    }
  }

  static Future<DateTime> getMessageTime() async {
    try {
      if (_cachedTime != null && _lastFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _cacheDuration) {
          final elapsedTime = DateTime.now().difference(_lastFetchTime!);
          return _cachedTime!.add(elapsedTime);
        }
      }

      final response = await http
          .get(Uri.parse(_fallbackApiUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dateTimeString = data['datetime'] as String;
        final utcTime = DateTime.parse(dateTimeString);
        final turkeyTime = utcTime.add(const Duration(hours: 3));

        _cachedTime = turkeyTime;
        _lastFetchTime = DateTime.now();

        return turkeyTime;
      }

      return DateTime.now();
    } catch (e) {
      print(
          '⚠️ TimeService: Hızlı saat alma başarısız, cihaz saati kullanılıyor');
      return DateTime.now();
    }
  }

  static void clearCache() {
    _cachedTime = null;
    _lastFetchTime = null;
    print('🗑️ TimeService: Cache temizlendi');
  }

  static Future<bool> isDeviceTimeAccurate() async {
    try {
      final internetTime = await getCurrentTime();
      final deviceTime = DateTime.now();
      final difference = internetTime.difference(deviceTime).abs();

      final isAccurate = difference.inMinutes < 5;

      print(
          '🕐 TimeService: Cihaz saati doğruluğu: ${isAccurate ? "✅ Doğru" : "❌ Yanlış"} (Fark: ${difference.inMinutes} dakika)');

      return isAccurate;
    } catch (e) {
      print('❌ TimeService: Saat doğruluğu kontrol edilemedi: $e');
      return false;
    }
  }

  static bool isCacheValid() {
    if (_cachedTime == null || _lastFetchTime == null) return false;
    final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
    return timeSinceLastFetch < _cacheDuration;
  }

  static Duration? getCacheRemainingTime() {
    if (!isCacheValid()) return null;
    final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
    return _cacheDuration - timeSinceLastFetch;
  }

  static Map<String, dynamic> getCacheStats() {
    return {
      'hasCache': _cachedTime != null,
      'isValid': isCacheValid(),
      'remainingTime': getCacheRemainingTime()?.inSeconds,
      'lastFetchTime': _lastFetchTime?.toIso8601String(),
      'cachedTime': _cachedTime?.toIso8601String(),
    };
  }
}
