import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/saved_location.dart';

class StorageService {
  static const _cityKey = 'saved_city';
  static const _districtKey = 'saved_district';

  // ── Konum ────────────────────────────────────────────────────────────────────

  Future<void> saveLocation(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.savedLatKey, latitude);
    await prefs.setDouble(AppConstants.savedLngKey, longitude);
    await prefs.setString(
      AppConstants.savedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<SavedLocation?> loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(AppConstants.savedLatKey);
    final lng = prefs.getDouble(AppConstants.savedLngKey);
    final savedAtStr = prefs.getString(AppConstants.savedAtKey);

    if (lat == null || lng == null) return null;

    return SavedLocation(
      latitude: lat,
      longitude: lng,
      savedAt: savedAtStr != null
          ? DateTime.parse(savedAtStr)
          : DateTime.now(),
    );
  }

  Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.savedLatKey);
    await prefs.remove(AppConstants.savedLngKey);
    await prefs.remove(AppConstants.savedAtKey);
  }

  // ── Şehir / İlçe ─────────────────────────────────────────────────────────────

  /// Reverse geocoding sonucunu cache'e yazar; her konum kaydında güncellenir
  Future<void> saveCityInfo(String city, String district) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
    await prefs.setString(_districtKey, district);
  }

  /// Cache'deki şehir/ilçe bilgisini döner; yoksa null
  Future<({String city, String district})?> loadCityInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString(_cityKey);
    final district = prefs.getString(_districtKey);
    if (city == null) return null;
    return (city: city, district: district ?? '');
  }

  Future<void> clearCityInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cityKey);
    await prefs.remove(_districtKey);
  }
}
