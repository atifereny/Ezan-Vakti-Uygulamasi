class AppConstants {
  // Bu mesafeden fazla sapma "konum değişikliği" sayılır (kilometre)
  static const double locationChangeThresholdKm = 50.0;

  // SharedPreferences anahtarları
  static const String savedLatKey = 'saved_latitude';
  static const String savedLngKey = 'saved_longitude';
  static const String savedAtKey = 'saved_at';

  // Güncelleme kontrolü için GitHub deposu: 'kullanıcı/depo'
  // Boşsa güncelleme kontrolü yapılmaz.
  static const String githubRepo = 'atifereny/Ezan-Vakti-Uygulamasi';
}
