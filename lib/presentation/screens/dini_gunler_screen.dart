import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../data/services/dini_gun_service.dart';
import '../../domain/models/dini_gun.dart';

class DiniGunlerScreen extends StatefulWidget {
  const DiniGunlerScreen({super.key});

  @override
  State<DiniGunlerScreen> createState() => _DiniGunlerScreenState();
}

class _DiniGunlerScreenState extends State<DiniGunlerScreen> {
  List<DiniGun>? _days;

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _weekdays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    DiniGunService.load().then((d) {
      if (mounted) setState(() => _days = d);
    });
  }

  String _dateText(DiniGun g) {
    final s = g.date;
    final e = g.endDate;
    if (e == null) {
      return '${s.day} ${_months[s.month - 1]} ${s.year}, ${_weekdays[s.weekday - 1]}';
    }
    if (e.month == s.month) {
      return '${s.day}-${e.day} ${_months[s.month - 1]} ${s.year}';
    }
    return '${s.day} ${_months[s.month - 1]} - ${e.day} ${_months[e.month - 1]} ${e.year}';
  }

  String _countdown(DiniGun g, DateTime now) {
    final today = DiniGunService.dayOnly(now);
    final inRange = !today.isBefore(g.date) && !today.isAfter(g.lastDate);
    if (inRange) {
      return g.endDate == null ? 'Bugün' : 'Devam ediyor';
    }
    final n = DiniGunService.daysUntil(now, g.date);
    return n == 1 ? 'Yarın' : '$n gün kaldı';
  }

  IconData _icon(DiniGunKind k) => switch (k) {
        DiniGunKind.kandil => Icons.nightlight_round,
        DiniGunKind.bayram || DiniGunKind.arefe => Icons.celebration_outlined,
        _ => Icons.event_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final days = _days;

    return Scaffold(
      appBar: AppBar(title: const Text('Dini Günler ve Geceler')),
      body: days == null
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _body(context, cs, now, DiniGunService.upcoming(now, days)),
    );
  }

  Widget _body(
      BuildContext context, ColorScheme cs, DateTime now, List<DiniGun> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Takvim verisi bulunamadı.\nUygulamayı güncellemeyi deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    final updated = DiniGunService.updated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i == 0 || list[i].date.year != list[i - 1].date.year)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                '${list[i].date.year}',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          _tile(cs, list[i], now, highlight: i == 0),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Kandil geceleri, yukarıda belirtilen günün akşamında idrak edilir.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => launchUrl(
            Uri.parse(DiniGunService.sourceUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'Kaynak: T.C. Diyanet İşleri Başkanlığı'
              '${updated == null ? '' : '  ·  veri tarihi $updated'}',
              style: TextStyle(
                color: cs.primary,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(ColorScheme cs, DiniGun g, DateTime now,
      {required bool highlight}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.primary, width: 1.2),
            )
          : null,
      child: ListTile(
        leading: Icon(_icon(g.kind), color: cs.primary),
        title: Text(
          g.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
        subtitle: Text(
          '${_dateText(g)}\n${g.hijri}',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        isThreeLine: true,
        trailing: Text(
          _countdown(g, now),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
