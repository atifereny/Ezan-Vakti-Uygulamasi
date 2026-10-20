enum DiniGunKind { kandil, arefe, bayram, ozel, ay }

class DiniGun {
  final DateTime date; // ilk gün (yerel tarih, saat 00:00)
  final DateTime? endDate; // çok günlü ise son gün (bayramlar)
  final String name;
  final String hijri; // "26 Receb"
  final DiniGunKind kind;

  const DiniGun({
    required this.date,
    required this.endDate,
    required this.name,
    required this.hijri,
    required this.kind,
  });

  DateTime get lastDate => endDate ?? date;

  factory DiniGun.fromJson(Map<String, dynamic> j) {
    final end = j['endDate'] as String?;
    return DiniGun(
      date: DateTime.parse(j['date'] as String),
      endDate: end == null ? null : DateTime.parse(end),
      name: j['name'] as String,
      hijri: j['hijri'] as String,
      kind: switch (j['kind']) {
        'kandil' => DiniGunKind.kandil,
        'arefe' => DiniGunKind.arefe,
        'bayram' => DiniGunKind.bayram,
        'ozel' => DiniGunKind.ozel,
        _ => DiniGunKind.ay,
      },
    );
  }
}

/// Ana ekranda gösterilen kısa bildirim ("Yarın akşam Miraç Kandili")
class DiniGunNotice {
  final String text;
  final DiniGun gun;
  const DiniGunNotice(this.text, this.gun);
}
