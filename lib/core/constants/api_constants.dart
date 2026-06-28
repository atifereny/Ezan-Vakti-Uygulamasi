class ApiConstants {
  // Aladhan aylık takvim endpoint'i: /v1/calendar/{yıl}/{ay}
  static const String aladhanBaseUrl = 'https://api.aladhan.com/v1/calendar';

  // Hesaplama metodu: 13 = Türkiye Diyanet İşleri Başkanlığı
  static const int diyanetMethod = 13;

  // API istek zaman aşımı
  static const Duration requestTimeout = Duration(seconds: 10);
}
