import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/quran.dart';

/// Gömülü Kur'an verisini (assets/data/kuran.json) okur ve son okunan sayfayı saklar.
class QuranService {
  static const _lastPageKey = 'quran_last_page';
  static QuranData? _cache;

  static Future<QuranData> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/kuran.json');
    _cache = await compute(_parse, raw);
    return _cache!;
  }

  static QuranData _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final surahs = [
      for (final s in j['surahs'] as List<dynamic>)
        QuranSurah(
          (s as List<dynamic>)[0] as int,
          s[1] as String,
          s[2] as String,
          s[3] == 'M',
          s[4] as int,
          s[5] as int,
        ),
    ];
    final pages = [
      for (final p in j['pages'] as List<dynamic>)
        [
          for (final a in p as List<dynamic>)
            QuranAyah(
              (a as List<dynamic>)[0] as int,
              a[1] as int,
              a[2] as String,
              a[3] as String,
              a[4] as int,
            ),
        ],
    ];
    return QuranData(
      surahs,
      [for (final x in j['juz'] as List<dynamic>) x as int],
      pages,
    );
  }

  static Future<int?> lastPage() async {
    try {
      final p = (await SharedPreferences.getInstance()).getInt(_lastPageKey);
      return (p != null && p >= 1 && p <= 604) ? p : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastPage(int page) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(_lastPageKey, page);
    } catch (_) {}
  }

  /// Arapça rakamlar (٠١٢٣٤٥٦٧٨٩)
  static String arabicDigits(int n) {
    const d = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }
}
