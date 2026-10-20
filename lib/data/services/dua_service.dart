import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/dua.dart';

/// Gömülü dua verisini (assets/data/dualar.json) okur.
class DuaService {
  static DuaData? _cache;

  /// Dosya okunamazsa boş veri döner.
  static Future<DuaData> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/dualar.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final src = j['kaynaklar'] as Map<String, dynamic>;
      _cache = DuaData(
        [
          for (final d in j['duas'] as List<dynamic>)
            Dua.fromJson(d as Map<String, dynamic>),
        ],
        {
          for (final e in src.entries)
            e.key: DuaSource(
              (e.value as Map<String, dynamic>)['ad'] as String,
              (e.value as Map<String, dynamic>)['url'] as String,
            ),
        },
        [for (final n in j['notlar'] as List<dynamic>) n as String],
      );
    } catch (e) {
      debugPrint('DuaService: veri okunamadı → $e');
      _cache = const DuaData([], {}, []);
    }
    return _cache!;
  }

  /// Arama için: küçük harf + Türkçe/aksanlı harfleri sadeleştir
  static String fold(String s) {
    const map = {
      'İ': 'i', 'I': 'i', 'ı': 'i', 'â': 'a', 'Â': 'a', 'î': 'i', 'Î': 'i',
      'û': 'u', 'Û': 'u', 'ö': 'o', 'Ö': 'o', 'ü': 'u', 'Ü': 'u', 'ş': 's',
      'Ş': 's', 'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', '’': '', "'": '',
    };
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      b.write(map[c] ?? c.toLowerCase());
    }
    return b.toString();
  }
}
