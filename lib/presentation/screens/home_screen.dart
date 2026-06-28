import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/location_utils.dart';
import '../../data/services/location_service.dart';
import '../../data/services/prayer_times_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/prayer_times.dart';
import '../../domain/models/saved_location.dart';
import '../widgets/location_update_dialog.dart';
import '../widgets/prayer_times_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  final _storageService = StorageService();
  final _prayerTimesService = PrayerTimesService();

  // Konum durumu
  bool _isLocationLoading = true;
  String _locationStatus = 'Konum kontrol ediliyor...';
  SavedLocation? _savedLocation;
  Position? _currentPosition;
  String? _locationError;

  // Namaz vakitleri durumu
  bool _isPrayerLoading = false;
  PrayerTimes? _prayerTimes;
  String? _prayerError;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  // ── Konum Akışı ─────────────────────────────────────────────────────────────

  Future<void> _checkLocation() async {
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
      _locationStatus = 'GPS konumu alınıyor...';
    });

    // 1) Mevcut GPS konumunu al
    final current = await _locationService.getCurrentPosition();
    if (current == null) {
      setState(() {
        _isLocationLoading = false;
        _locationError =
            'Konum alınamadı.\n\nLütfen konum iznini verdiğinizden '
            've GPS\'in açık olduğundan emin olun.';
      });
      return;
    }

    setState(() {
      _currentPosition = current;
      _locationStatus = 'Kayıtlı konum kontrol ediliyor...';
    });

    // 2) Kayıtlı konumu oku
    final saved = await _storageService.loadLocation();

    if (saved == null) {
      // İlk açılış: kaydet ve vakitleri çek
      await _storageService.saveLocation(current.latitude, current.longitude);
      final firstSaved = SavedLocation(
        latitude: current.latitude,
        longitude: current.longitude,
        savedAt: DateTime.now(),
      );
      setState(() {
        _isLocationLoading = false;
        _savedLocation = firstSaved;
        _locationStatus = 'Konum ilk kez kaydedildi.';
      });
      await _loadPrayerTimes(current.latitude, current.longitude);
      return;
    }

    setState(() => _savedLocation = saved);

    // 3) Mesafe kontrolü
    final distanceKm = LocationUtils.calculateDistanceKm(
      lat1: saved.latitude,
      lon1: saved.longitude,
      lat2: current.latitude,
      lon2: current.longitude,
    );

    setState(() => _isLocationLoading = false);

    if (distanceKm >= AppConstants.locationChangeThresholdKm) {
      // 4) Eşik aşıldı → kullanıcıya sor
      if (!mounted) return;
      _showLocationUpdateDialog(distanceKm, current);
    } else {
      setState(() {
        _locationStatus =
            'Konum değişikliği algılanmadı (${distanceKm.toStringAsFixed(1)} km).';
      });
      // Kayıtlı konuma göre vakitleri yükle
      await _loadPrayerTimes(saved.latitude, saved.longitude);
    }
  }

  void _showLocationUpdateDialog(double distanceKm, Position current) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationUpdateDialog(
        distanceKm: distanceKm,
        onUpdate: () async {
          // Kullanıcı "Evet" dedi: yeni konumu kaydet, cache'i temizle
          Navigator.of(context).pop();
          await _storageService.saveLocation(
            current.latitude,
            current.longitude,
          );
          await _prayerTimesService.clearCache();

          if (!mounted) return;
          final newSaved = SavedLocation(
            latitude: current.latitude,
            longitude: current.longitude,
            savedAt: DateTime.now(),
          );
          setState(() {
            _savedLocation = newSaved;
            _locationStatus = 'Konum başarıyla güncellendi.';
          });
          await _loadPrayerTimes(current.latitude, current.longitude);
        },
        onKeep: () async {
          // Kullanıcı "Hayır" dedi: eski konumla devam et
          Navigator.of(context).pop();
          setState(() => _locationStatus = 'Eski konum korundu.');
          await _loadPrayerTimes(
            _savedLocation!.latitude,
            _savedLocation!.longitude,
          );
        },
      ),
    );
  }

  // ── Namaz Vakitleri Akışı ───────────────────────────────────────────────────

  Future<void> _loadPrayerTimes(double lat, double lng) async {
    setState(() {
      _isPrayerLoading = true;
      _prayerError = null;
    });

    final times = await _prayerTimesService.getTodayPrayerTimes(lat, lng);

    setState(() {
      _isPrayerLoading = false;
      _prayerTimes = times;
      if (times == null) {
        _prayerError =
            'Namaz vakitleri yüklenemedi.\nİnternet bağlantınızı kontrol edin.';
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ezan Vakti'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _isLocationLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Konum kontrol ediliyor...'),
                ],
              ),
            )
          : _locationError != null
              ? _buildLocationErrorView()
              : _buildContentView(),
      floatingActionButton: !_isLocationLoading
          ? FloatingActionButton.extended(
              onPressed: _checkLocation,
              label: const Text('Yenile'),
              icon: const Icon(Icons.refresh),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildLocationErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ── Konum Bilgisi ──
        _InfoCard(
          title: 'Durum',
          value: _locationStatus,
          icon: Icons.info_outline,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),

        if (_currentPosition != null)
          _InfoCard(
            title: 'Mevcut Konum',
            value:
                'Enlem: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                'Boylam: ${_currentPosition!.longitude.toStringAsFixed(6)}',
            icon: Icons.my_location,
            color: Colors.green,
          ),
        const SizedBox(height: 12),

        if (_savedLocation != null)
          _InfoCard(
            title: 'Kayıtlı Konum',
            value:
                'Enlem: ${_savedLocation!.latitude.toStringAsFixed(6)}\n'
                'Boylam: ${_savedLocation!.longitude.toStringAsFixed(6)}\n'
                'Kaydedilme: ${_savedLocation!.savedAt.toLocal().toString().substring(0, 16)}',
            icon: Icons.bookmark,
            color: Colors.orange,
          ),
        const SizedBox(height: 20),

        // ── Namaz Vakitleri ──
        if (_isPrayerLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Namaz vakitleri yükleniyor...'),
                  ],
                ),
              ),
            ),
          )
        else if (_prayerError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _prayerError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_prayerTimes != null)
          PrayerTimesCard(prayerTimes: _prayerTimes!),

        const SizedBox(height: 80), // FAB ile çakışmaması için boşluk
      ],
    );
  }
}

// ── Yardımcı Widget ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
