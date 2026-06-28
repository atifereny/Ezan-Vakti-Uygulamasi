import 'package:geocoding/geocoding.dart';

class GeocodingService {
  /// Koordinatlardan şehir ve ilçe adını döner.
  /// Cihazın yerel geocoder'ını kullanır (ağ bağlantısı gerekebilir).
  Future<({String city, String district})?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;

      // administrativeArea → İl (örn. "İstanbul")
      // subAdministrativeArea → İlçe (örn. "Kadıköy")
      // locality → bazen alternatif şehir adı olarak gelir
      final city = place.administrativeArea?.isNotEmpty == true
          ? place.administrativeArea!
          : (place.locality ?? '');

      final district = place.subAdministrativeArea?.isNotEmpty == true
          ? place.subAdministrativeArea!
          : (place.locality ?? '');

      return (city: city, district: district);
    } catch (_) {
      return null;
    }
  }
}
