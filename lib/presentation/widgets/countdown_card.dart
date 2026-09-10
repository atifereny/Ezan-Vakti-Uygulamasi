import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/prayer_times.dart';

class CountdownCard extends StatefulWidget {
  final PrayerTimes prayerTimes;
  final String? tomorrowFajr;
  final bool heroMode;

  const CountdownCard({
    super.key,
    required this.prayerTimes,
    this.tomorrowFajr,
    this.heroMode = false,
  });

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
  String? _kerahatApproaching;

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

    final minuteMap = {
      for (final e in entries) e.name: _toMinutes(e.time),
    };

    final kerahat = _getKerahat(nowMinutes, minuteMap);
    final approaching = _getKerahatApproaching(nowMinutes, minuteMap);

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
    } else if (widget.tomorrowFajr != null) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final parts = widget.tomorrowFajr!.split(':');
      final fajrDt = tomorrowDate.copyWith(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      remaining = fajrDt.difference(DateTime.now());
      nextName = 'Yarın İmsak';
    } else {
      allPassed = true;
    }

    setState(() {
      _remaining = remaining;
      _nextPrayerName = nextName;
      _allPassed = allPassed;
      _isKerahat = kerahat.$1;
      _kerahatLabel = kerahat.$2;
      _kerahatApproaching = kerahat.$1 ? null : approaching;
    });
  }

  (bool, String) _getKerahat(int nowMin, Map<String, int> m) {
    final sunrise = m['Güneş'] ?? 0;
    final dhuhr = m['Öğle'] ?? 0;
    final maghrib = m['Akşam'] ?? 0;

    if (nowMin >= sunrise && nowMin < sunrise + _sunriseDuration) {
      return (true, 'Güneş doğuşu kerahat vaktindesiniz');
    }
    if (nowMin >= dhuhr - _istiwaDuration && nowMin < dhuhr) {
      return (true, 'İstiwa (öğle) kerahat vaktindesiniz');
    }
    if (nowMin >= maghrib - _sunsetDuration && nowMin < maghrib) {
      return (true, 'Güneş batışı kerahat vaktindesiniz');
    }
    return (false, '');
  }

  String? _getKerahatApproaching(int nowMin, Map<String, int> m) {
    final imsak   = m['İmsak']   ?? 0;
    final sunrise = m['Güneş']   ?? 0;
    final asr     = m['İkindi']  ?? 0;
    final maghrib = m['Akşam']   ?? 0;

    if (nowMin >= imsak && nowMin < sunrise) {
      final mins = sunrise - nowMin;
      return 'Kerahat vaktine ${_fmtMins(mins)} kaldı';
    }

    final sunsetKerahat = maghrib - _sunsetDuration;
    if (nowMin >= asr && nowMin < sunsetKerahat) {
      final mins = sunsetKerahat - nowMin;
      return 'Kerahat vaktine ${_fmtMins(mins)} kaldı';
    }

    return null;
  }

  String _fmtMins(int mins) {
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '$h sa' : '$h sa $m dk';
    }
    return '$mins dk';
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String h = _remaining.inHours.toString().padLeft(2, '0');
    final String m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    if (widget.heroMode) return _buildHero(cs, h, m, s);

    final Color bgColor = _isKerahat
        ? (isDark ? const Color(0xFF3B1111) : const Color(0xFFFFEBEE))
        : cs.surfaceContainerHighest;
    final Color borderColor = _isKerahat
        ? (isDark ? const Color(0xFF7A2020) : const Color(0xFFEF9A9A))
        : cs.outline;
    final Color accentColor =
        _isKerahat ? const Color(0xFFEF5350) : cs.primary;

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
          if (_isKerahat) ...[
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF5350),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _kerahatLabel,
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (_kerahatApproaching != null) ...[
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFFE07B20),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _kerahatApproaching!,
                  style: const TextStyle(
                    color: Color(0xFFE07B20),
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

  Widget _buildHero(ColorScheme cs, String h, String m, String s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_allPassed) ...[
          Text(
            '$_nextPrayerName vaktine kalan süre',
            style: TextStyle(
              color: cs.primary,
              fontSize: 13,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$h:$m:$s',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 54,
              fontWeight: FontWeight.w500,
              letterSpacing: 6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ] else
          Text(
            'Tüm vakitler geçti.',
            style: TextStyle(color: cs.onSurface, fontSize: 16),
          ),
        if (_isKerahat) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withAlpha(204),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  _kerahatLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_kerahatApproaching != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB45309).withAlpha(204),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  _kerahatApproaching!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
