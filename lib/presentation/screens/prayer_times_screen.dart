import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../domain/models/notification_prefs.dart';
import '../../domain/models/prayer_times.dart';
import '../widgets/countdown_card.dart';
import '../widgets/prayer_times_card.dart';

class PrayerTimesScreen extends StatelessWidget {
  final PrayerTimes? prayerTimes;
  final String city;
  final String district;
  final bool isLoading;
  final String? error;
  final String? tomorrowFajr;
  final NotificationPrefs notifPrefs;
  final void Function(String prayer, bool enabled) onNotifToggle;

  const PrayerTimesScreen({
    super.key,
    required this.prayerTimes,
    required this.city,
    required this.district,
    required this.isLoading,
    this.error,
    this.tomorrowFajr,
    required this.notifPrefs,
    required this.onNotifToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            const Text('Namaz vakitleri yükleniyor...'),
          ],
        ),
      );
    }

    if (error != null && prayerTimes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    if (prayerTimes == null) {
      return const Center(child: Text('Veri bulunamadı.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Hero: SVG cami arka planı + sayaç ──────────────────────────────
        AspectRatio(
          aspectRatio: 8 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.5,
                child: Transform.translate(
                  offset: const Offset(0, 18),
                  child: SvgPicture.asset(
                    isDark
                        ? 'assets/images/cami_dark.svg'
                        : 'assets/images/cami.svg',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              // Konum + tarih bilgisi (üst)
              Positioned(
                top: 10, left: 16, right: 16,
                child: _HeroInfoRow(city: city, district: district),
              ),
              // Sayaç (merkez)
              Center(
                child: CountdownCard(
                  prayerTimes: prayerTimes!,
                  tomorrowFajr: tomorrowFajr,
                  heroMode: true,
                ),
              ),
            ],
          ),
        ),
        // ── Namaz vakitleri listesi ─────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: PrayerTimesCard(
              prayerTimes:   prayerTimes!,
              notifPrefs:    notifPrefs,
              onNotifToggle: onNotifToggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero içi konum + tarih satırı ────────────────────────────────────────────

class _HeroInfoRow extends StatelessWidget {
  final String city;
  final String district;

  static const _hijriMonths = [
    'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir',
    'Cemaziyelevvel', 'Cemaziyelahir', 'Recep', 'Şaban',
    'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce',
  ];

  static const _days = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
    'Cuma', 'Cumartesi', 'Pazar',
  ];

  const _HeroInfoRow({required this.city, required this.district});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    final now = DateTime.now();
    final dayName = _days[now.weekday - 1];
    final h = HijriCalendar.fromDate(now);
    final hijriStr = '${h.hDay} ${_hijriMonths[h.hMonth - 1]} ${h.hYear}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sol: Hicri takvim
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayName,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hijriStr,
              style: TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Sağ: Konum
        if (city.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: cs.primary, size: 14),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    city,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (district.isNotEmpty)
                    Text(
                      district,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
