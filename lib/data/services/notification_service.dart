import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_prefs.dart';
import '../../domain/models/prayer_times.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _batteryChannel = MethodChannel('com.example.application/battery');
  static const _alarmChannel   = MethodChannel('com.example.application/alarms');
  static Timer? _liveTimer;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    await _createChannels();
    _initialized = true;
  }

  static Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'persistent_channel',
      'Namaz Vakitleri — Kalıcı',
      description: 'Bildirim çubuğunda her zaman görünen namaz vakitleri.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'prayer_channel',
      'Namaz Vakitleri',
      description: 'Her namaz vakti girdiğinde bildirim alırsınız.',
      importance: Importance.high,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'kerahat_channel',
      'Kerahat Vakitleri',
      description: 'Kerahat vakti başladığında uyarı alırsınız.',
      importance: Importance.high,
    ));
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _batteryChannel.invokeMethod('isIgnoringBatteryOptimizations') as bool;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
    return granted ?? false;
  }

  // ── Kalıcı bildirim ──────────────────────────────────────────────────────────

  static void startLiveNotification(PrayerTimes times, {String? tomorrowFajr}) {
    _liveTimer?.cancel();
    showPersistentNotification(times, tomorrowFajr: tomorrowFajr);

    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now  = DateTime.now();
      final next = times.nextPrayer;
      DateTime? nextDt;

      if (next != null) {
        nextDt = _toDateTime(DateTime(now.year, now.month, now.day), next.time);
      } else if (tomorrowFajr != null) {
        nextDt = _toDateTime(DateTime(now.year, now.month, now.day + 1), tomorrowFajr);
      }

      if (nextDt == null) {
        _liveTimer?.cancel();
        await showPersistentNotification(times, tomorrowFajr: tomorrowFajr);
        return;
      }
      final remaining = nextDt.difference(now);
      if (remaining.isNegative) {
        await showPersistentNotification(times, tomorrowFajr: tomorrowFajr);
        return;
      }

      final hh = remaining.inHours.toString().padLeft(2, '0');
      final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

      await showPersistentNotification(
        times, tomorrowFajr: tomorrowFajr, countdown: '$hh:$mm:$ss',
      );
    });
  }

  static void stopLiveNotification() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  static Future<void> showPersistentNotification(
    PrayerTimes times, {
    String? tomorrowFajr,
    String? countdown,
  }) async {
    if (!_initialized) return;

    final now  = DateTime.now();
    final nowM = now.hour * 60 + now.minute;
    final period = _currentPeriod(times, nowM);

    final next = times.nextPrayer;
    String? dative;

    if (next != null) {
      dative = _datives[next.name] ?? next.name;
    } else if (tomorrowFajr != null) {
      dative = "Yarın İmsak'a";
    }

    final String title;
    if (dative != null) {
      title = countdown != null
          ? '$period  ·  $dative  $countdown'
          : '$period  ·  $dative';
    } else {
      title = period;
    }

    final body =
        'İmsak ${times.fajr}  •  Güneş ${times.sunrise}  •  Öğle ${times.dhuhr}  •  '
        'İkindi ${times.asr}  •  Akşam ${times.maghrib}  •  Yatsı ${times.isha}';

    await _plugin.show(
      1,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'persistent_channel',
          'Namaz Vakitleri — Kalıcı',
          icon: '@drawable/ic_notification',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          showWhen: false,
          color: const Color(0xFF7A5C2E),
        ),
      ),
    );
  }

  // ── Test bildirimi ────────────────────────────────────────────────────────────

  static Future<void> scheduleTestNotification() async {
    if (!_initialized) return;

    await _plugin.show(
      98,
      'Test — Anlık',
      'Bildirim sistemi çalışıyor. 10 sn sonra exact alarm testi gelecek.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel',
          'Namaz Vakitleri',
          icon: '@drawable/ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF7A5C2E),
        ),
      ),
    );

    final dt = DateTime.now().add(const Duration(seconds: 10));
    await _schedule(
      id: 99,
      title: 'Test — Exact Alarm',
      body: 'Exact alarm çalışıyor! Namaz bildirimleri gönderilecek.',
      dateTime: dt,
      channelId: 'prayer_channel',
      channelName: 'Namaz Vakitleri',
      color: const Color(0xFF7A5C2E),
    );
  }

  // ── Alarm planlama ────────────────────────────────────────────────────────────

  static Future<void> scheduleUpcoming(
    List<PrayerTimes> days, {
    NotificationPrefs? prefs,
  }) async {
    await _cancelScheduled();

    final now        = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (final times in days) {
      final date      = DateTime(now.year, now.month, times.day);
      final dayOffset = date.difference(todayStart).inDays;
      if (dayOffset < 0 || dayOffset > 30) continue;

      // ID şeması (30 ID/gün): +0..5 tam vakit, +6..11 45dk öncesi, +12..14 kerahat
      final idBase      = 10 + dayOffset * 30;
      final earlyBase   = idBase + 6;
      final kerahatBase = idBase + 12;

      final prayerList = [
        ('İmsak',  times.fajr,     0),
        ('Güneş',  times.sunrise,  1),
        ('Öğle',   times.dhuhr,    2),
        ('İkindi', times.asr,      3),
        ('Akşam',  times.maghrib,  4),
        ('Yatsı',  times.isha,     5),
      ];
      for (final (name, timeStr, idx) in prayerList) {
        if (prefs != null && !prefs.isEnabled(name)) continue;
        final prayerDt = _toDateTime(date, timeStr);

        // 1) Tam vakitte bildirim
        if (prayerDt.isAfter(now)) {
          await _schedule(
            id: idBase + idx,
            title: '$name vakti girdi',
            body: 'Saat $timeStr — $name namazı kılınabilir.',
            dateTime: prayerDt,
            channelId: 'prayer_channel',
            channelName: 'Namaz Vakitleri',
            color: const Color(0xFF7A5C2E),
          );
        }

        // 2) X dk öncesi ek bildirim (kullanıcı tarafından ayarlanabilir)
        if (prefs == null || prefs.isEarlyEnabled(name)) {
          final minutes = prefs?.earlyMinutesOf(name) ?? 15;
          final earlyDt = prayerDt.subtract(Duration(minutes: minutes));
          if (earlyDt.isAfter(now)) {
            await _schedule(
              id: earlyBase + idx,
              title: '$name vaktine $minutes dk kaldı',
              body: '$name vakti saat $timeStr\'de girecek.',
              dateTime: earlyDt,
              channelId: 'prayer_channel',
              channelName: 'Namaz Vakitleri',
              color: const Color(0xFF7A5C2E),
            );
          }
        }
      }

      final kerahat = [
        ('sunrise', kerahatBase,     'Güneş doğuşu — Kerahat vakti',
          'Sonraki 45 dakika nafile namaz kılınmaz.',
          _toDateTime(date, times.sunrise)),
        ('istiwa',  kerahatBase + 1, 'Öğle öncesi — Kerahat vakti',
          'Öğle namazına 5 dakika kaldı, nafile kılınmaz.',
          _toDateTime(date, times.dhuhr).subtract(const Duration(minutes: 5))),
        ('sunset',  kerahatBase + 2, 'Akşam öncesi — Kerahat vakti',
          'Güneş batışına 45 dakika kaldı, nafile kılınmaz.',
          _toDateTime(date, times.maghrib).subtract(const Duration(minutes: 45))),
      ];
      for (final (key, id, title, body, dt) in kerahat) {
        if (prefs != null && !prefs.isKerahatEnabled(key)) continue;
        if (dt.isAfter(now)) {
          await _schedule(
            id: id, title: title, body: body, dateTime: dt,
            channelId: 'kerahat_channel', channelName: 'Kerahat Vakitleri',
            color: const Color(0xFFB71C1C),
          );
        }
      }
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    required String channelId,
    required String channelName,
    required Color color,
  }) async {
    try {
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id':          id,
        'title':       title,
        'body':        body,
        'epochMillis': dateTime.millisecondsSinceEpoch,
        'channelId':   channelId,
      });
    } catch (_) {}
  }

  static Future<void> _cancelScheduled() async {
    // Max ID: day 30 → idBase=910, kerahatBase=922, last kerahat=924
    try {
      await _alarmChannel.invokeMethod('cancelAlarmRange', {'from': 10, 'to': 930});
    } catch (_) {
      for (int id = 10; id <= 930; id++) {
        try { await _alarmChannel.invokeMethod('cancelAlarm', id); } catch (_) {}
      }
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────────

  static String _currentPeriod(PrayerTimes times, int nowM) {
    int m(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    if (nowM >= m(times.isha))    return 'Yatsı Vakti';
    if (nowM >= m(times.maghrib)) return 'Akşam Vakti';
    if (nowM >= m(times.asr))     return 'İkindi Vakti';
    if (nowM >= m(times.dhuhr))   return 'Öğle Vakti';
    if (nowM >= m(times.sunrise)) return 'Kuşluk';
    if (nowM >= m(times.fajr))    return 'Sabah Vakti';
    return 'Gece';
  }

  static const _datives = {
    'İmsak': "İmsak'a",
    'Güneş': "Güneş'e",
    'Öğle': "Öğle'ye",
    'İkindi': "İkindi'ye",
    'Akşam': "Akşam'a",
    'Yatsı': "Yatsı'ya",
  };

  static DateTime _toDateTime(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    return date.copyWith(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
  }
}
