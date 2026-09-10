import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/notification_prefs.dart';
import '../../domain/models/prayer_times.dart';

class PrayerTimesCard extends StatefulWidget {
  final PrayerTimes prayerTimes;
  final NotificationPrefs notifPrefs;
  final void Function(String prayer, bool enabled) onNotifToggle;

  const PrayerTimesCard({
    super.key,
    required this.prayerTimes,
    required this.notifPrefs,
    required this.onNotifToggle,
  });

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nextPrayer = widget.prayerTimes.nextPrayer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Icon(Icons.mosque, color: cs.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Bugünün Namaz Vakitleri',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 20),

            // Vakit satırları
            ...widget.prayerTimes.entries.map(
              (entry) => _PrayerRow(
                entry:    entry,
                isNext:   entry.name == nextPrayer?.name,
                notifOn:  widget.notifPrefs.isEnabled(entry.name),
                onToggle: () => widget.onNotifToggle(
                  entry.name,
                  !widget.notifPrefs.isEnabled(entry.name),
                ),
              ),
            ),

            // Yatsı sonrası mesajı
            if (nextPrayer == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tüm vakitler geçti. Yarın İmsak: yeni gün başlıyor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55),
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
  final bool notifOn;
  final VoidCallback onToggle;

  const _PrayerRow({
    required this.entry,
    required this.isNext,
    required this.notifOn,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: isNext
          ? BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        children: [
          // Vakit ikonu
          Icon(
            _iconFor(entry.name),
            size: 20,
            color: isNext ? cs.primary : muted,
          ),
          const SizedBox(width: 12),

          // Vakit adı
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                color: isNext ? cs.primary : cs.onSurface,
              ),
            ),
          ),

          // "Sonraki" etiketi
          if (isNext)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
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
              color: isNext ? cs.primary : cs.onSurface,
            ),
          ),

          const SizedBox(width: 4),

          // Bildirim toggle ikonu
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                notifOn
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                size: 18,
                color: notifOn ? cs.primary : muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'İmsak':  return Icons.nights_stay;
      case 'Güneş':  return Icons.wb_sunny;
      case 'Öğle':   return Icons.wb_sunny_outlined;
      case 'İkindi': return Icons.cloud_queue;
      case 'Akşam':  return Icons.wb_twilight;
      case 'Yatsı':  return Icons.dark_mode;
      default:       return Icons.schedule;
    }
  }
}
