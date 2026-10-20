import 'package:geolocator/geolocator.dart';

class LocationService {
  // İzin kontrolü yaparak mevcut GPS konumunu döner; izin/servis yoksa null
  Future<Position?> getCurrentPosition() async {
    // Konum servisi (GPS) açık mı?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // İzin durumunu kontrol et
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    // Kalıcı olarak reddedildiyse sistem ayarlarına yönlendirmek gerekir
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Hızlı konum: önce son bilinen (taze ise), yoksa orta hassasiyetli ölçüm.
  /// Ölçüm zaman aşımına uğrarsa eski son bilinen konuma düşer; hiçbiri yoksa null.
  Future<Position?> getQuickPosition({
    Duration maxAge = const Duration(hours: 1),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    Position? last;
    try {
      last = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    if (last != null && DateTime.now().difference(last.timestamp) < maxAge) {
      return last;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return last;
    }
  }

  // Konum izninin verilip verilmediğini hızlıca kontrol eder
  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
