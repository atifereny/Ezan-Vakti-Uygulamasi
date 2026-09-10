import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/mosque.dart';

class MosqueService {
  static const _mirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  Future<List<Mosque>> fetchNearby(
    double lat,
    double lng, {
    int radiusM = 2000,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusM,$lat,$lng);
  way["amenity"="place_of_worship"]["religion"="muslim"](around:$radiusM,$lat,$lng);
);
out center;
''';

    debugPrint('MosqueService: istek gönderiliyor lat=$lat lng=$lng');
    http.Response? response;
    Object? lastError;
    for (final mirror in _mirrors) {
      final uri = Uri.parse(mirror).replace(queryParameters: {'data': query});
      try {
        final r = await http
            .get(uri, headers: {'User-Agent': 'EzanVaktiApp/1.0'})
            .timeout(const Duration(seconds: 30));
        debugPrint('MosqueService: $mirror → ${r.statusCode}');
        if (r.statusCode == 200) {
          response = r;
          break;
        }
      } catch (e) {
        debugPrint('MosqueService: $mirror hata → $e');
        lastError = e;
      }
    }

    if (response == null) {
      throw lastError ?? Exception('Tüm Overpass mirror\'ları başarısız');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = json['elements'] as List<dynamic>;

    final mosques = <Mosque>[];
    for (final e in elements) {
      final type = e['type'] as String;
      final double eLat;
      final double eLng;

      if (type == 'node') {
        eLat = (e['lat'] as num).toDouble();
        eLng = (e['lon'] as num).toDouble();
      } else {
        // way — center koordinatları
        final center = e['center'] as Map<String, dynamic>?;
        if (center == null) continue;
        eLat = (center['lat'] as num).toDouble();
        eLng = (center['lon'] as num).toDouble();
      }

      final tags = e['tags'] as Map<String, dynamic>? ?? {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue; // isimsizleri atla

      mosques.add(Mosque(
        id: '${type}_${e['id']}',
        name: name,
        lat: eLat,
        lng: eLng,
        distanceKm: _distKm(lat, lng, eLat, eLng),
      ));
    }

    mosques.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
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
