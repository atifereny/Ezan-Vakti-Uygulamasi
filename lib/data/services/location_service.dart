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

  // Konum izninin verilip verilmediğini hızlıca kontrol eder
  Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
