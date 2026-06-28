import 'package:home_widget/home_widget.dart';

import '../../domain/models/prayer_times.dart';

class WidgetService {
  static const String _androidWidgetName = 'PrayerWidget';

  /// Prayer times ve şehir bilgisini widget'a yazar ve yenileme tetikler.
  /// Hata olursa sessizce devam eder; widget güncellenemezse uygulama çalışmaya devam eder.
  Future<void> updatePrayerWidget({
    required PrayerTimes times,
    required String city,
  }) async {
    try {
      // Verileri native tarafın okuyacağı SharedPreferences'a yaz
      await HomeWidget.saveWidgetData('city', city);
      await HomeWidget.saveWidgetData('fajr', times.fajr);
      await HomeWidget.saveWidgetData('sunrise', times.sunrise);
      await HomeWidget.saveWidgetData('dhuhr', times.dhuhr);
      await HomeWidget.saveWidgetData('asr', times.asr);
      await HomeWidget.saveWidgetData('maghrib', times.maghrib);
      await HomeWidget.saveWidgetData('isha', times.isha);

      // Sonraki vakit bilgisi
      final next = times.nextPrayer;
      await HomeWidget.saveWidgetData(
        'next_prayer',
        next != null ? '${next.name}  ${next.time}' : '',
      );

      // Widget'ı yenile
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // Widget henüz eklenmemişse veya izin yoksa hata fırlatmaz
    }
  }
}
