import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/dini_gun.dart';

/// Diyanet'in resmî dini gün tablosundan (assets/data/dini_gunler.json) okur.
/// Dosya her release öncesi tools/build_dini_gunler.py ile yenilenir.
class DiniGunService {
  static const sourceUrl =
      'https://mobil.diyanet.gov.tr/mobile/dinigunler/dinigunler.html';

  static List<DiniGun>? _cache;
  static String? _updated;

  /// Dosya okunamazsa boş liste döner (arayüz bildirim göstermez).
  static Future<List<DiniGun>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/dini_gunler.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _updated = json['updated'] as String?;
      _cache = [
        for (final d in json['days'] as List<dynamic>)
          DiniGun.fromJson(d as Map<String, dynamic>),
      ]..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('DiniGunService: veri okunamadı → $e');
      _cache = const [];
    }
    return _cache!;
  }

  static String? get updated => _updated;

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int daysUntil(DateTime from, DateTime to) =>
      dayOnly(to).difference(dayOnly(from)).inDays;

  /// Bugün/yarın ile ilgili bir dini gün varsa kısa bildirim döner.
  ///
  /// Kandil geceleri Diyanet tablosunda gösterilen günün AKŞAMIDIR; bu yüzden
  /// kandil günü "Bu akşam", bir önceki gün "Yarın akşam" denir.
  static DiniGunNotice? noticeFor(DateTime now, List<DiniGun> days) {
    final today = dayOnly(now);
    final tomorrow = today.add(const Duration(days: 1));

    DiniGunNotice? best;
    var bestRank = 99;

    for (final g in days) {
      if (g.kind == DiniGunKind.ay) continue;
      final String? text;
      final isToday = !today.isBefore(g.date) && !today.isAfter(g.lastDate);

      switch (g.kind) {
        case DiniGunKind.bayram:
          if (isToday) {
            final k = today.difference(g.date).inDays + 1;
            text = '${g.name}\'nın $k. günü';
          } else if (tomorrow == g.date) {
            text = 'Yarın ${g.name}';
          } else {
            text = null;
          }
        case DiniGunKind.arefe:
          text = isToday
              ? 'Bugün ${g.name}'
              : (tomorrow == g.date ? 'Yarın ${g.name}' : null);
        case DiniGunKind.kandil:
          text = isToday
              ? 'Bu akşam ${g.name}'
              : (tomorrow == g.date ? 'Yarın akşam ${g.name}' : null);
        case DiniGunKind.ozel:
          text = isToday
              ? 'Bugün ${g.name}'
              : (tomorrow == g.date ? 'Yarın ${g.name}' : null);
        case DiniGunKind.ay:
          text = null;
      }
      if (text == null) continue;

      // Aynı gün birden fazla kayıt varsa: bayram > arefe > kandil > özel
      final rank = switch (g.kind) {
        DiniGunKind.bayram => 0,
        DiniGunKind.arefe => 1,
        DiniGunKind.kandil => 2,
        _ => 3,
      };
      // Bugünkü kayıt yarınkinden önce gelir
      final adj = rank + (isToday ? 0 : 10);
      if (adj < bestRank) {
        bestRank = adj;
        best = DiniGunNotice(text, g);
      }
    }
    return best;
  }

  /// Henüz bitmemiş dini günler (takvim ekranı için); aylık başlangıçlar hariç.
  static List<DiniGun> upcoming(DateTime now, List<DiniGun> days) {
    final today = dayOnly(now);
    return [
      for (final g in days)
        if (g.kind != DiniGunKind.ay && !g.lastDate.isBefore(today)) g,
    ];
  }
}
