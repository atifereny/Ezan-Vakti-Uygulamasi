import 'package:flutter/material.dart';

import '../../domain/models/prayer_times.dart';
import '../widgets/countdown_card.dart';
import '../widgets/prayer_times_card.dart';

class PrayerTimesScreen extends StatelessWidget {
  final PrayerTimes? prayerTimes;
  final String city;
  final String district;
  final bool isLoading;
  final String? error;

  const PrayerTimesScreen({
    super.key,
    required this.prayerTimes,
    required this.city,
    required this.district,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ezan Vakti'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text('Namaz vakitleri yükleniyor...'),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _InfoCard(city: city, district: district),
        const SizedBox(height: 12),
        CountdownCard(prayerTimes: prayerTimes!),
        const SizedBox(height: 12),
        PrayerTimesCard(prayerTimes: prayerTimes!),
      ],
    );
  }
}

// ── Tarih + Konum kartı ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String city;
  final String district;

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static const _days = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
    'Cuma', 'Cumartesi', 'Pazar',
  ];

  const _InfoCard({required this.city, required this.district});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _days[now.weekday - 1];
    final dateStr = '${now.day} ${_months[now.month - 1]} ${now.year}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Sol: Tarih
            const Icon(Icons.calendar_today,
                color: Color(0xFF1B5E20), size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),

            const Spacer(),

            // Ayraç
            Container(
              width: 1,
              height: 36,
              color: Colors.grey[300],
            ),
            const SizedBox(width: 14),

            // Sağ: Konum
            const Icon(Icons.location_on,
                color: Color(0xFF1B5E20), size: 22),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.isNotEmpty ? city : '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (district.isNotEmpty)
                  Text(
                    district,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
