import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/mosque.dart';

class MosqueException implements Exception {
  final String message;
  const MosqueException(this.message);
  @override
  String toString() => message;
}

class MosqueService {
  static const _mirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  static const _cacheKey = 'mosque_cache_v1';
  static const _requestTimeout = Duration(seconds: 12);
  static const _cacheMaxAge = Duration(days: 7);
  static const _cacheReuseKm = 0.3; // bu mesafe içinde ağa gitme
  static const _cacheFallbackKm = 0.5; // ağ yoksa eski veriyi bu mesafeye kadar kullan

  Future<List<Mosque>> fetchNearby(
    double lat,
    double lng, {
    int radiusM = 2000,
  }) async {
    final cached = await _readCache(radiusM);
    if (cached != null) {
      final dist = _distKm(lat, lng, cached.lat, cached.lng);
      final fresh = DateTime.now().difference(cached.savedAt) < _cacheMaxAge;
      if (fresh && dist <= _cacheReuseKm) {
        debugPrint('MosqueService: önbellekten (${cached.items.length} cami)');
        return _toMosques(cached.items, lat, lng);
      }
    }

    try {
      final items = await _fetchFromNetwork(lat, lng, radiusM);
      await _writeCache(lat, lng, radiusM, items);
      return _toMosques(items, lat, lng);
    } catch (e) {
      // Ağ başarısız: yakın bir eski önbellek varsa onu göster
      if (cached != null &&
          _distKm(lat, lng, cached.lat, cached.lng) <= _cacheFallbackKm) {
        debugPrint('MosqueService: ağ hatası, eski önbellek kullanılıyor → $e');
        return _toMosques(cached.items, lat, lng);
      }
      rethrow;
    }
  }

  // ── Gömülü veri ─────────────────────────────────────────────────────────────

  static String? _assetJson;

  /// Uygulamaya gömülü Türkiye cami listesinden yakındakileri döner (internetsiz,
  /// anında). Veri dosyası okunamazsa boş liste döner.
  Future<List<Mosque>> fetchLocal(
    double lat,
    double lng, {
    int radiusM = 2000,
  }) async {
    try {
      _assetJson ??= await rootBundle.loadString('assets/data/tr_mosques.json');
      final items = await compute(
        _filterAsset,
        _FilterArgs(_assetJson!, lat, lng, radiusM / 1000.0),
      );
      return _toMosques(items, lat, lng);
    } catch (e) {
      debugPrint('MosqueService: gömülü veri okunamadı → $e');
      return [];
    }
  }

  static List<_RawMosque> _filterAsset(_FilterArgs a) {
    final rows = jsonDecode(a.json) as List<dynamic>;
    // Önce kaba kutu filtresi, sonra gerçek mesafe
    final dLat = a.radiusKm / 111.0;
    final dLng = a.radiusKm / (111.0 * max(0.1, cos(_rad(a.lat))));
    final out = <_RawMosque>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i] as List<dynamic>;
      final la = (r[1] as num).toDouble();
      final lo = (r[2] as num).toDouble();
      if ((la - a.lat).abs() > dLat || (lo - a.lng).abs() > dLng) continue;
      if (_distKm(a.lat, a.lng, la, lo) > a.radiusKm) continue;
      final name = (r[0] as String);
      out.add(_RawMosque(
        'l_$i',
        name.isEmpty ? Mosque.unnamedLabel : name,
        la,
        lo,
      ));
    }
    return out;
  }

  // ── Ağ ──────────────────────────────────────────────────────────────────────

  /// Tüm mirror'lara aynı anda istek atar, ilk başarılı cevabı döner.
  Future<List<_RawMosque>> _fetchFromNetwork(
    double lat,
    double lng,
    int radiusM,
  ) async {
    final query = '''
[out:json][timeout:10];
nwr["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusM,$lat,$lng);
out center tags;
''';

    final client = http.Client();
    final completer = Completer<String>();
    var pending = _mirrors.length;

    void failed() {
      if (--pending == 0 && !completer.isCompleted) {
        completer.completeError(const MosqueException(
          'Cami sunucularına ulaşılamadı.\n'
          'İnternet bağlantınızı kontrol edin veya biraz sonra tekrar deneyin.',
        ));
      }
    }

    for (final mirror in _mirrors) {
      client
          .post(
            Uri.parse(mirror),
            headers: {'User-Agent': 'EzanVaktiApp/1.0'},
            body: {'data': query},
          )
          .timeout(_requestTimeout)
          .then((r) {
        debugPrint('MosqueService: $mirror → ${r.statusCode}');
        if (r.statusCode == 200) {
          if (!completer.isCompleted) completer.complete(r.body);
        } else {
          failed();
        }
      }).catchError((Object e) {
        debugPrint('MosqueService: $mirror hata → $e');
        failed();
      });
    }

    try {
      final body = await completer.future;
      return _parse(body);
    } finally {
      client.close(); // kazanamayan istekleri iptal eder
    }
  }

  static List<_RawMosque> _parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final elements = json['elements'] as List<dynamic>? ?? const [];

    final items = <_RawMosque>[];
    for (final e in elements) {
      final type = e['type'] as String;
      final double eLat;
      final double eLng;

      if (type == 'node') {
        eLat = (e['lat'] as num).toDouble();
        eLng = (e['lon'] as num).toDouble();
      } else {
        // way / relation — center koordinatları
        final center = e['center'] as Map<String, dynamic>?;
        if (center == null) continue;
        eLat = (center['lat'] as num).toDouble();
        eLng = (center['lon'] as num).toDouble();
      }

      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      var name = (tags['name'] as String?)?.trim();
      name ??= (tags['name:tr'] as String?)?.trim();
      if (name == null || name.isEmpty) name = Mosque.unnamedLabel;

      items.add(_RawMosque('${type}_${e['id']}', name, eLat, eLng));
    }
    return items;
  }

  // ── Önbellek ────────────────────────────────────────────────────────────────

  Future<_Cache?> _readCache(int radiusM) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['radius'] != radiusM) return null;
      return _Cache(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        savedAt: DateTime.parse(m['savedAt'] as String),
        items: [
          for (final i in m['items'] as List<dynamic>)
            _RawMosque(
              i['id'] as String,
              i['name'] as String,
              (i['lat'] as num).toDouble(),
              (i['lng'] as num).toDouble(),
            ),
        ],
      );
    } catch (_) {
      return null; // bozuk önbellek yok sayılır
    }
  }

  Future<void> _writeCache(
    double lat,
    double lng,
    int radiusM,
    List<_RawMosque> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'lat': lat,
          'lng': lng,
          'radius': radiusM,
          'savedAt': DateTime.now().toIso8601String(),
          'items': [
            for (final i in items)
              {'id': i.id, 'name': i.name, 'lat': i.lat, 'lng': i.lng},
          ],
        }),
      );
    } catch (_) {}
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────────

  static List<Mosque> _toMosques(
    List<_RawMosque> items,
    double lat,
    double lng,
  ) {
    final mosques = [
      for (final i in items)
        Mosque(
          id: i.id,
          name: i.name,
          lat: i.lat,
          lng: i.lng,
          distanceKm: _distKm(lat, lng, i.lat, i.lng),
        ),
    ];
    return _sorted(mosques);
  }

  /// İsimli camiler önce (yakından uzağa), isimsizler en sonda (yakından uzağa).
  static List<Mosque> _sorted(List<Mosque> mosques) {
    mosques.sort((a, b) {
      if (a.isUnnamed != b.isUnnamed) return a.isUnnamed ? 1 : -1;
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return mosques;
  }

  static double _distKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}

class _FilterArgs {
  final String json;
  final double lat;
  final double lng;
  final double radiusKm;
  const _FilterArgs(this.json, this.lat, this.lng, this.radiusKm);
}

class _RawMosque {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const _RawMosque(this.id, this.name, this.lat, this.lng);
}

class _Cache {
  final double lat;
  final double lng;
  final DateTime savedAt;
  final List<_RawMosque> items;
  const _Cache({
    required this.lat,
    required this.lng,
    required this.savedAt,
    required this.items,
  });
}
