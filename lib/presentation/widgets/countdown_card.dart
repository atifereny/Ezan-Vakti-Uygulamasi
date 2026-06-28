import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/prayer_times.dart';

class CountdownCard extends StatefulWidget {
  final PrayerTimes prayerTimes;

  const CountdownCard({super.key, required this.prayerTimes});

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  Timer? _timer;

  Duration _remaining = Duration.zero;
  String _nextPrayerName = '';
  bool _allPassed = false;
  bool _isKerahat = false;
  String _kerahatLabel = '';

  // Kerahat süresi sabitleri (dakika)
  static const int _sunriseDuration = 45;
  static const int _istiwaDuration = 5;
  static const int _sunsetDuration = 45;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final nowSeconds = nowMinutes * 60 + now.second;

    final entries = widget.prayerTimes.entries;

    // Tüm vakitleri dakikaya çevir
    final minuteMap = {
      for (final e in entries) e.name: _toMinutes(e.time),
    };

    // Kerahat kontrolü
    final kerahat = _getKerahat(nowMinutes, minuteMap);

    // Sonraki vakti bul (saniye bazında karşılaştır)
    PrayerEntry? next;
    for (final entry in entries) {
      if (_toMinutes(entry.time) * 60 > nowSeconds) {
        next = entry;
        break;
      }
    }

    Duration remaining = Duration.zero;
    String nextName = '';
    bool allPassed = false;

    if (next != null) {
      remaining = Duration(seconds: _toMinutes(next.time) * 60 - nowSeconds);
      nextName = next.name;
    } else {
      allPassed = true;
    }

    setState(() {
      _remaining = remaining;
      _nextPrayerName = nextName;
      _allPassed = allPassed;
      _isKerahat = kerahat.$1;
      _kerahatLabel = kerahat.$2;
    });
  }

  /// Şu anki dakikanın kerahat vaktine denk gelip gelmediğini döner
  (bool, String) _getKerahat(int nowMin, Map<String, int> m) {
    final sunrise = m['Güneş'] ?? 0;
    final dhuhr = m['Öğle'] ?? 0;
    final maghrib = m['Akşam'] ?? 0;

    // Güneş doğuşu: sunrise → sunrise + 45 dk
    if (nowMin >= sunrise && nowMin < sunrise + _sunriseDuration) {
      return (true, 'Güneş doğuşu kerahat vaktindesiniz');
    }
    // İstiwa: öğleden 5 dk önce
    if (nowMin >= dhuhr - _istiwaDuration && nowMin < dhuhr) {
      return (true, 'İstiwa (öğle) kerahat vaktindesiniz');
    }
    // Güneş batışı: akşamdan 45 dk önce
    if (nowMin >= maghrib - _sunsetDuration && nowMin < maghrib) {
      return (true, 'Güneş batışı kerahat vaktindesiniz');
    }
    return (false, '');
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isKerahat
        ? const Color(0xFFFFEBEE) // soluk kırmızı
        : const Color(0xFFE8F5E9); // soluk yeşil
    final Color borderColor = _isKerahat
        ? const Color(0xFFEF9A9A)
        : const Color(0xFFA5D6A7);
    final Color accentColor = _isKerahat
        ? const Color(0xFFC62828)
        : const Color(0xFF1B5E20);

    final String h = _remaining.inHours.toString().padLeft(2, '0');
    final String m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          if (!_allPassed) ...[
            Text(
              '$_nextPrayerName vaktine kalan süre',
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$h:$m:$s',
              style: TextStyle(
                color: accentColor,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ] else
            Text(
              'Tüm vakitler geçti.',
              style: TextStyle(color: accentColor, fontSize: 16),
            ),

          // Kerahat uyarısı
          if (_isKerahat) ...[
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFC62828),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _kerahatLabel,
                  style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
