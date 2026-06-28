import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/location_utils.dart';
import '../../domain/models/prayer_times.dart';

class PrayerTimesService {
  // SharedPreferences cache anahtarları
  static const _keyData = 'prayer_cache_data';
  static const _keyLat = 'prayer_cache_lat';
  static const _keyLng = 'prayer_cache_lng';
  static const _keyMonth = 'prayer_cache_month'; // "2026-06" formatı

  /// Bugünün namaz vakitlerini döner.
  /// Önce cache'e bakar; geçerliyse API'ya istek atmaz.
  /// Cache geçersizse Aladhan'dan tüm ayı çeker ve cache'e yazar.
  Future<PrayerTimes?> getTodayPrayerTimes(double lat, double lng) async {
    final cached = await _loadFromCache(lat, lng);
    if (cached != null) {
      return _findToday(cached);
    }

    final monthly = await _fetchMonthlyFromApi(lat, lng);
    if (monthly == null) return null;

    await _saveToCache(monthly, lat, lng);
    return _findToday(monthly);
  }

  /// Mevcut ayın cache'ini temizler (konum değişikliğinde çağrılır)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyData);
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
    await prefs.remove(_keyMonth);
  }

  // Aladhan'dan bu ayın tüm günlerini çeker (1 istek/ay)
  Future<List<PrayerTimes>?> _fetchMonthlyFromApi(
    double lat,
    double lng,
  ) async {
    final now = DateTime.now();
    final uri = Uri.parse(
      '${ApiConstants.aladhanBaseUrl}/${now.year}/${now.month}'
      '?latitude=$lat&longitude=$lng&method=${ApiConstants.diyanetMethod}',
    );

    try {
      final response = await http
          .get(uri)
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 200) return null;

      final data = body['data'] as List<dynamic>;
      return data
          .map((d) => PrayerTimes.fromApiResponse(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Ağ hatası veya zaman aşımı
      return null;
    }
  }

  // Cache'den yükler; ay veya konum uyuşmazsa null döner
  Future<List<PrayerTimes>?> _loadFromCache(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();

    // Ay kontrolü
    final cachedMonth = prefs.getString(_keyMonth);
    if (cachedMonth != _monthKey(DateTime.now())) return null;

    // Konum kontrolü: cache'deki konumla mesafe eşiği içinde mi?
    final cachedLat = prefs.getDouble(_keyLat);
    final cachedLng = prefs.getDouble(_keyLng);
    if (cachedLat == null || cachedLng == null) return null;

    final distance = LocationUtils.calculateDistanceKm(
      lat1: cachedLat,
      lon1: cachedLng,
      lat2: lat,
      lon2: lng,
    );
    if (distance >= AppConstants.locationChangeThresholdKm) return null;

    // Veriyi oku ve parse et
    final raw = prefs.getString(_keyData);
    if (raw == null) return null;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((d) => PrayerTimes.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(
    List<PrayerTimes> data,
    double lat,
    double lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyData,
      jsonEncode(data.map((p) => p.toJson()).toList()),
    );
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
    await prefs.setString(_keyMonth, _monthKey(DateTime.now()));
  }

  PrayerTimes? _findToday(List<PrayerTimes> list) {
    final today = DateTime.now().day;
    try {
      return list.firstWhere((p) => p.day == today);
    } catch (_) {
      return null;
    }
  }

  String _monthKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
}
