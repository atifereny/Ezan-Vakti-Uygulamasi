import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/location_utils.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/prayer_times_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/prayer_times.dart';
import '../../domain/models/saved_location.dart';
import '../widgets/location_update_dialog.dart';
import 'prayer_times_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Başlangıçta merkez sekme (Vakitler)

  final _locationService = LocationService();
  final _storageService = StorageService();
  final _prayerTimesService = PrayerTimesService();
  final _geocodingService = GeocodingService();

  // ── Paylaşılan State ──────────────────────────────────────────────────────────
  SavedLocation? _savedLocation;
  Position? _currentPosition;
  PrayerTimes? _prayerTimes;
  String _city = '';
  String _district = '';
  bool _isPrayerLoading = true;
  String? _prayerError;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ── Başlatma: önce cache, sonra arka planda GPS ───────────────────────────────

  Future<void> _initialize() async {
    // 1. Yerel hafızadan kaydedilmiş veriyi anında yükle
    final saved = await _storageService.loadLocation();
    final cityInfo = await _storageService.loadCityInfo();

    if (saved != null && mounted) {
      setState(() => _savedLocation = saved);
    }
    if (cityInfo != null && mounted) {
      setState(() {
        _city = cityInfo.city;
        _district = cityInfo.district;
      });
    }

    // 2. Kayıtlı konum varsa önce onun vakitlerini yükle (cache hit = hızlı)
    if (saved != null) {
      await _loadPrayerTimes(saved.latitude, saved.longitude);

      // Şehir bilgisi hiç kaydedilmemişse kayıtlı koordinattan hemen türet.
      // (GPS beklenmez; geocoding genellikle network geocoder ile hızlı çalışır.)
      if (cityInfo == null) {
        await _fetchAndSaveCityInfo(saved.latitude, saved.longitude);
      }
    }

    // 3. GPS'i arka planda kontrol et (ağır iş, kullanıcıyı bekletmez)
    await _checkGpsInBackground(savedLocation: saved);
  }

  Future<void> _checkGpsInBackground({
    required SavedLocation? savedLocation,
  }) async {
    final current = await _locationService.getCurrentPosition();
    if (current == null || !mounted) {
      // GPS alınamadı: ilk açılışta prayer loading'i bitir
      if (savedLocation == null) {
        setState(() => _isPrayerLoading = false);
      }
      return;
    }

    setState(() => _currentPosition = current);

    if (savedLocation == null) {
      // İlk açılış: konumu kaydet, şehri bul, vakitleri çek
      await _storageService.saveLocation(current.latitude, current.longitude);
      final firstSaved = SavedLocation(
        latitude: current.latitude,
        longitude: current.longitude,
        savedAt: DateTime.now(),
      );
      if (mounted) setState(() => _savedLocation = firstSaved);

      await _fetchAndSaveCityInfo(current.latitude, current.longitude);
      await _loadPrayerTimes(current.latitude, current.longitude);
      return;
    }

    // Kayıtlı konumla mesafeyi karşılaştır
    final distance = LocationUtils.calculateDistanceKm(
      lat1: savedLocation.latitude,
      lon1: savedLocation.longitude,
      lat2: current.latitude,
      lon2: current.longitude,
    );

    if (distance >= AppConstants.locationChangeThresholdKm && mounted) {
      _showLocationUpdateDialog(distance, current);
    }
  }

  Future<void> _loadPrayerTimes(double lat, double lng) async {
    if (mounted) setState(() { _isPrayerLoading = true; _prayerError = null; });

    final times = await _prayerTimesService.getTodayPrayerTimes(lat, lng);

    if (mounted) {
      setState(() {
        _prayerTimes = times;
        _isPrayerLoading = false;
        _prayerError = times == null
            ? 'Namaz vakitleri yüklenemedi.\nİnternet bağlantınızı kontrol edin.'
            : null;
      });
    }
  }

  Future<void> _fetchAndSaveCityInfo(double lat, double lng) async {
    final address =
        await _geocodingService.getAddressFromCoordinates(lat, lng);
    if (address == null || !mounted) return;

    await _storageService.saveCityInfo(address.city, address.district);
    setState(() {
      _city = address.city;
      _district = address.district;
    });
  }

  // ── Konum Değişikliği Dialog'u ────────────────────────────────────────────────

  void _showLocationUpdateDialog(double distanceKm, Position current) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationUpdateDialog(
        distanceKm: distanceKm,
        onUpdate: () async {
          Navigator.of(context).pop();
          // Yeni konumu kaydet, eski cache'i temizle
          await _storageService.saveLocation(
            current.latitude,
            current.longitude,
          );
          await _prayerTimesService.clearCache();

          if (!mounted) return;
          setState(() {
            _savedLocation = SavedLocation(
              latitude: current.latitude,
              longitude: current.longitude,
              savedAt: DateTime.now(),
            );
          });

          await _fetchAndSaveCityInfo(current.latitude, current.longitude);
          await _loadPrayerTimes(current.latitude, current.longitude);
        },
        onKeep: () => Navigator.of(context).pop(),
      ),
    );
  }

  // ── Profil Ekranından Tetiklenen Manuel Yenileme ──────────────────────────────

  Future<void> _refreshLocation() async {
    setState(() => _isRefreshing = true);

    final current = await _locationService.getCurrentPosition();

    if (!mounted) {
      setState(() => _isRefreshing = false);
      return;
    }

    if (current == null) {
      setState(() => _isRefreshing = false);
      return;
    }

    setState(() => _currentPosition = current);

    final saved = _savedLocation;
    if (saved != null) {
      final distance = LocationUtils.calculateDistanceKm(
        lat1: saved.latitude,
        lon1: saved.longitude,
        lat2: current.latitude,
        lon2: current.longitude,
      );

      if (distance >= AppConstants.locationChangeThresholdKm && mounted) {
        setState(() => _isRefreshing = false);
        _showLocationUpdateDialog(distance, current);
        return;
      }
    }

    setState(() => _isRefreshing = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack sekme değişiminde state'i korur (yeniden build etmez)
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Sol sekme: ileride eklenecek özellik (Kıble vb.)
          const _PlaceholderScreen(
            title: 'Kıble',
            icon: Icons.explore,
            message: 'Kıble yönü özelliği yakında geliyor.',
          ),
          // Merkez sekme: Namaz Vakitleri
          PrayerTimesScreen(
            prayerTimes: _prayerTimes,
            city: _city,
            district: _district,
            isLoading: _isPrayerLoading,
            error: _prayerError,
          ),
          // Sağ sekme: Profil
          ProfileScreen(
            savedLocation: _savedLocation,
            currentPosition: _currentPosition,
            city: _city,
            district: _district,
            isRefreshing: _isRefreshing,
            onRefresh: _refreshLocation,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        indicatorColor: const Color(0xFF1B5E20).withAlpha(30),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Color(0xFF1B5E20)),
            label: 'Kıble',
          ),
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque, color: Color(0xFF1B5E20)),
            label: 'Vakitler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF1B5E20)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Sekme ─────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
