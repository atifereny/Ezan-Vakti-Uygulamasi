import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/location_utils.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/prayer_times_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/widget_service.dart';
import '../../domain/models/prayer_times.dart';
import '../../domain/models/saved_location.dart';
import '../widgets/location_update_dialog.dart';
import '../../domain/models/notification_prefs.dart';
import 'features_screen.dart';
import 'ayarlar_screen.dart';
import 'prayer_times_screen.dart';

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
  final _widgetService = WidgetService();

  // ── Paylaşılan State ──────────────────────────────────────────────────────────
  SavedLocation? _savedLocation;
  Position? _currentPosition;
  PrayerTimes? _prayerTimes;
  String? _tomorrowFajr;
  String _city = '';
  String _district = '';
  bool _isPrayerLoading = true;
  String? _prayerError;
  bool _isRefreshing = false;
  Timer? _midnightTimer;
  NotificationPrefs _notifPrefs = NotificationPrefs.defaults();
  List<PrayerTimes> _upcomingDays = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    NotificationService.stopLiveNotification();
    super.dispose();
  }

  // ── Başlatma: önce cache, sonra arka planda GPS ───────────────────────────────

  Future<void> _initialize() async {
    // 1. Yerel hafızadan kaydedilmiş veriyi anında yükle
    final saved      = await _storageService.loadLocation();
    final cityInfo   = await _storageService.loadCityInfo();
    final notifPrefs = await _storageService.loadNotifPrefs();

    if (mounted) {
      setState(() {
        if (saved != null) _savedLocation = saved;
        if (cityInfo != null) {
          _city     = cityInfo.city;
          _district = cityInfo.district;
        }
        _notifPrefs = notifPrefs;
      });
    }

    // 2. Kayıtlı konum varsa önce onun vakitlerini yükle (cache hit = hızlı)
    if (saved != null) {
      await _loadPrayerTimes(saved.latitude, saved.longitude);

      if (cityInfo == null) {
        await _fetchAndSaveCityInfo(saved.latitude, saved.longitude);
      }
    }

    // 3. Bildirim izni iste (Android 13+, ilk açılışta sistem dialogu gösterir)
    await NotificationService.requestPermission();

    // 4. Pil optimizasyonu muafiyeti iste (Doze modunda bildirimlerin gelmesi için)
    final isIgnoring = await NotificationService.isIgnoringBatteryOptimizations();
    if (!isIgnoring) {
      await NotificationService.requestIgnoreBatteryOptimizations();
    }

    // 5. GPS'i arka planda kontrol et (ağır iş, kullanıcıyı bekletmez)
    await _checkGpsInBackground(savedLocation: saved);
  }

  Future<void> _onNotifPrefsChanged(NotificationPrefs prefs) async {
    if (!mounted) return;
    setState(() => _notifPrefs = prefs);
    await _storageService.saveNotifPrefs(prefs);
    if (_upcomingDays.isNotEmpty) {
      await NotificationService.scheduleUpcoming(_upcomingDays, prefs: prefs);
    }
  }

  Future<void> _togglePrayerNotif(String prayer, bool enabled) =>
      _onNotifPrefsChanged(_notifPrefs.copyWithEnabled(prayer, enabled));

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

      // Yükleme başarılıysa widget'ı, bildirimleri ve yarınki vakti güncelle
      if (times != null) {
        _widgetService.updatePrayerWidget(times: times, city: _city);
        // Önümüzdeki günleri cache'den çek, state'e kaydet ve planla
        _prayerTimesService.getUpcomingDays(lat, lng).then((days) {
          if (mounted) setState(() => _upcomingDays = days);
          NotificationService.scheduleUpcoming(days, prefs: _notifPrefs);
        });
        NotificationService.startLiveNotification(times, tomorrowFajr: _tomorrowFajr);
        _loadTomorrowFajr(lat, lng);
        _scheduleMidnightReload();
      }
    }
  }

  Future<void> _loadTomorrowFajr(double lat, double lng) async {
    final tomorrow = await _prayerTimesService.getTomorrowPrayerTimes(lat, lng);
    if (!mounted) return;
    setState(() => _tomorrowFajr = tomorrow?.fajr);
    // tomorrowFajr geldi → canlı sayacı yeniden başlat (Yatsı sonrası için gerekli)
    if (_prayerTimes != null) {
      NotificationService.startLiveNotification(
        _prayerTimes!,
        tomorrowFajr: tomorrow?.fajr,
      );
    }
  }

  void _scheduleMidnightReload() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (mounted && _savedLocation != null) {
        _loadPrayerTimes(_savedLocation!.latitude, _savedLocation!.longitude);
      }
    });
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
      appBar: AppBar(
        title: const Text('Ezan Vakti'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshLocation,
          ),
        ],
      ),
      // IndexedStack sekme değişiminde state'i korur
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const FeaturesScreen(),
          PrayerTimesScreen(
            prayerTimes:   _prayerTimes,
            city:          _city,
            district:      _district,
            isLoading:     _isPrayerLoading,
            error:         _prayerError,
            tomorrowFajr:  _tomorrowFajr,
            notifPrefs:    _notifPrefs,
            onNotifToggle: _togglePrayerNotif,
          ),
          AyarlarScreen(
            savedLocation:        _savedLocation,
            currentPosition:      _currentPosition,
            city:                 _city,
            district:             _district,
            isRefreshing:         _isRefreshing,
            onRefresh:            _refreshLocation,
            notifPrefs:           _notifPrefs,
            onNotifPrefsChanged:  _onNotifPrefsChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Özellikler',
          ),
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque),
            label: 'Vakitler',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
