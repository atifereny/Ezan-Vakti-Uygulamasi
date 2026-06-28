import 'package:flutter/material.dart';

import '../../domain/models/prayer_times.dart';

class PrayerTimesCard extends StatelessWidget {
  final PrayerTimes prayerTimes;

  const PrayerTimesCard({super.key, required this.prayerTimes});

  @override
  Widget build(BuildContext context) {
    final nextPrayer = prayerTimes.nextPrayer;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            const Row(
              children: [
                Icon(Icons.mosque, color: Color(0xFF1B5E20), size: 24),
                SizedBox(width: 8),
                Text(
                  'Bugünün Namaz Vakitleri',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Vakit satırları
            ...prayerTimes.entries.map(
              (entry) => _PrayerRow(
                entry: entry,
                isNext: entry.name == nextPrayer?.name,
              ),
            ),

            // Yatsı sonrası mesajı
            if (nextPrayer == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tüm vakitler geçti. Yarın İmsak: yeni gün başlıyor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final PrayerEntry entry;
  final bool isNext;

  const _PrayerRow({required this.entry, required this.isNext});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1B5E20);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: isNext
          ? BoxDecoration(
              color: const Color(0x1A1B5E20), // %10 yeşil arka plan
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        children: [
          // Vakit ikonu
          Icon(
            _iconFor(entry.name),
            size: 20,
            color: isNext ? green : Colors.grey,
          ),
          const SizedBox(width: 12),

          // Vakit adı
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                color: isNext ? green : null,
              ),
            ),
          ),

          // "Sonraki" etiketi
          if (isNext)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Sonraki',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),

          // Vakit saati
          Text(
            entry.time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: isNext ? green : null,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'İmsak':
        return Icons.nights_stay;
      case 'Güneş':
        return Icons.wb_sunny;
      case 'Öğle':
        return Icons.wb_sunny_outlined;
      case 'İkindi':
        return Icons.cloud_queue;
      case 'Akşam':
        return Icons.wb_twilight;
      case 'Yatsı':
        return Icons.dark_mode;
      default:
        return Icons.schedule;
    }
  }
}
