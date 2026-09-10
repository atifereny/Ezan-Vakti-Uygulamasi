import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/app_theme.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone veritabanını başlat, Türkiye saatini ayarla
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  await NotificationService.initialize();

  // Kayıtlı tema tercihini yükle
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const EzanVaktiApp());
}
