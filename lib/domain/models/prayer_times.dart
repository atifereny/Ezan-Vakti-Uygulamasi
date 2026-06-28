class PrayerEntry {
  final String name; // Türkçe vakit adı
  final String time; // "04:23" formatında

  const PrayerEntry({required this.name, required this.time});
}

class PrayerTimes {
  final int day;
  final String fajr;    // İmsak
  final String sunrise; // Güneş
  final String dhuhr;   // Öğle
  final String asr;     // İkindi
  final String maghrib; // Akşam
  final String isha;    // Yatsı

  const PrayerTimes({
    required this.day,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  // Vakitleri sıralı liste olarak döner (UI için)
  List<PrayerEntry> get entries => [
        PrayerEntry(name: 'İmsak', time: fajr),
        PrayerEntry(name: 'Güneş', time: sunrise),
        PrayerEntry(name: 'Öğle', time: dhuhr),
        PrayerEntry(name: 'İkindi', time: asr),
        PrayerEntry(name: 'Akşam', time: maghrib),
        PrayerEntry(name: 'Yatsı', time: isha),
      ];

  // Şu anki zamana göre bir sonraki vakti döner; Yatsı geçtiyse null
  PrayerEntry? get nextPrayer {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    for (final entry in entries) {
      final parts = entry.time.split(':');
      final entryMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (entryMinutes > nowMinutes) return entry;
    }
    return null; // Tüm vakitler geçmiş (Yatsı sonrası)
  }

  // Aladhan API ham yanıtından oluşturur; saat sonundaki timezone etiketini (TRT) temizler
  factory PrayerTimes.fromApiResponse(Map<String, dynamic> json) {
    final timings = json['timings'] as Map<String, dynamic>;
    final day = int.parse(
      (json['date']['gregorian']['day'] as String),
    );

    return PrayerTimes(
      day: day,
      fajr: _clean(timings['Fajr'] as String),
      sunrise: _clean(timings['Sunrise'] as String),
      dhuhr: _clean(timings['Dhuhr'] as String),
      asr: _clean(timings['Asr'] as String),
      maghrib: _clean(timings['Maghrib'] as String),
      isha: _clean(timings['Isha'] as String),
    );
  }

  // Cache'e kaydedilen minimal JSON'dan oluşturur
  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    return PrayerTimes(
      day: json['day'] as int,
      fajr: json['fajr'] as String,
      sunrise: json['sunrise'] as String,
      dhuhr: json['dhuhr'] as String,
      asr: json['asr'] as String,
      maghrib: json['maghrib'] as String,
      isha: json['isha'] as String,
    );
  }

  // Cache'e yazılacak minimal JSON formatı
  Map<String, dynamic> toJson() => {
        'day': day,
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
      };

  // "04:23 (TRT)" → "04:23"
  static String _clean(String raw) => raw.split(' ').first;
}
