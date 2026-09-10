import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/location_utils.dart';
import '../../domain/models/prayer_times.dart';

class PrayerTimesService {
  // Ana cache anahtarları
  static const _keyData  = 'prayer_cache_data';
  static const _keyLat   = 'prayer_cache_lat';
  static const _keyLng   = 'prayer_cache_lng';
  static const _keyMonth = 'prayer_cache_month'; // "2026-06"

  // Ay sonu önceden çekilen bir sonraki ayın anahtarları
  static const _keyDataNext  = 'prayer_cache_data_next';
  static const _keyMonthNext = 'prayer_cache_month_next';

  /// Bugünün namaz vakitlerini döner.
  Future<PrayerTimes?> getTodayPrayerTimes(double lat, double lng) async {
    final list = await _getMonthly(lat, lng);
    return list == null ? null : _findDay(list, DateTime.now().day);
  }

  /// Yarının namaz vakitlerini döner.
  Future<PrayerTimes?> getTomorrowPrayerTimes(double lat, double lng) async {
    final list = await _getMonthly(lat, lng);
    return list == null ? null : _findDay(list, DateTime.now().day + 1);
  }

  /// Bugün dahil ayın kalan tüm günlerini sıralı döner.
  /// Ek API isteği atmaz — veri zaten cache'de.
  Future<List<PrayerTimes>> getUpcomingDays(double lat, double lng) async {
    final list = await _getMonthly(lat, lng);
    if (list == null) return [];
    final today = DateTime.now().day;
    return list.where((p) => p.day >= today).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  /// Ana cache'i temizler (konum değişikliğinde).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyData);
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
    await prefs.remove(_keyMonth);
  }

  // ── İç yardımcılar ────────────────────────────────────────────────────────

  // Cache varsa oradan, yoksa API'dan çeker.
  // Ayın 25'inden sonra bir sonraki ayı da arka planda hazırlar.
  Future<List<PrayerTimes>?> _getMonthly(double lat, double lng) async {
    final cached = await _loadFromCache(lat, lng);
    if (cached != null) {
      // Ay sonuna yaklaşıldıysa bir sonraki ayı arka planda hazırla
      if (DateTime.now().day >= 25) {
        _preloadNextMonthIfNeeded(lat, lng);
      }
      return cached;
    }

    final monthly = await _fetchMonthlyFromApi(lat, lng);
    if (monthly != null) await _saveToCache(monthly, lat, lng);
    return monthly;
  }

  // Cache geçerliyse döner; geçersizse bir sonraki ay ön-cache'ini dener.
  Future<List<PrayerTimes>?> _loadFromCache(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = _monthKey(now);

    // Ana cache geçerli mi?
    if (prefs.getString(_keyMonth) == currentMonthKey) {
      final ok = _locationOk(prefs, lat, lng);
      final raw = prefs.getString(_keyData);
      if (ok && raw != null) return _parseList(raw);
    }

    // Ana cache bayat, ön-cache'de bu aya ait veri var mı?
    if (prefs.getString(_keyMonthNext) == currentMonthKey) {
      final raw = prefs.getString(_keyDataNext);
      if (raw != null) {
        final list = _parseList(raw);
        if (list != null) {
          // Bir sonraki ay artık bu ay; ana cache'e taşı
          await prefs.setString(_keyData, raw);
          await prefs.setDouble(_keyLat, lat);
          await prefs.setDouble(_keyLng, lng);
          await prefs.setString(_keyMonth, currentMonthKey);
          await prefs.remove(_keyDataNext);
          await prefs.remove(_keyMonthNext);
          return list;
        }
      }
    }

    return null;
  }

  // 25. günden itibaren bir sonraki ayı arka planda çekip ön-cache'e yazar.
  // Fire-and-forget; hata olursa sessizce geçilir.
  Future<void> _preloadNextMonthIfNeeded(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nextDt  = DateTime(DateTime.now().year, DateTime.now().month + 1);
      final nextKey = _monthKey(nextDt);

      if (prefs.getString(_keyMonthNext) == nextKey) return; // Zaten var

      final monthly = await _fetchMonthlyFromApi(lat, lng, forMonth: nextDt);
      if (monthly == null) return;

      await prefs.setString(
        _keyDataNext,
        jsonEncode(monthly.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(_keyMonthNext, nextKey);
    } catch (_) {}
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

  // Aladhan'dan aylık veri çeker.
  // [forMonth] verilmezse bu ay çekilir.
  Future<List<PrayerTimes>?> _fetchMonthlyFromApi(
    double lat,
    double lng, {
    DateTime? forMonth,
  }) async {
    final dt  = forMonth ?? DateTime.now();
    final uri = Uri.parse(
      '${ApiConstants.aladhanBaseUrl}/${dt.year}/${dt.month}'
      '?latitude=$lat&longitude=$lng&method=${ApiConstants.diyanetMethod}',
    );

    try {
      final response = await http.get(uri).timeout(ApiConstants.requestTimeout);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 200) return null;

      final data = body['data'] as List<dynamic>;
      return data
          .map((d) => PrayerTimes.fromApiResponse(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  bool _locationOk(SharedPreferences prefs, double lat, double lng) {
    final cachedLat = prefs.getDouble(_keyLat);
    final cachedLng = prefs.getDouble(_keyLng);
    if (cachedLat == null || cachedLng == null) return false;
    final d = LocationUtils.calculateDistanceKm(
      lat1: cachedLat, lon1: cachedLng,
      lat2: lat,       lon2: lng,
    );
    return d < AppConstants.locationChangeThresholdKm;
  }

  List<PrayerTimes>? _parseList(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((d) => PrayerTimes.fromJson(d as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  PrayerTimes? _findDay(List<PrayerTimes> list, int day) {
    try {
      return list.firstWhere((p) => p.day == day);
    } catch (_) {
      return null;
    }
  }

  String _monthKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
}
