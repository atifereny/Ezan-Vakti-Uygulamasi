import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../data/services/location_service.dart';
import '../../data/services/mosque_service.dart';
import '../../domain/models/mosque.dart';

class NearbyMosquesScreen extends StatefulWidget {
  const NearbyMosquesScreen({super.key});

  @override
  State<NearbyMosquesScreen> createState() => _NearbyMosquesScreenState();
}

class _NearbyMosquesScreenState extends State<NearbyMosquesScreen> {
  final _mapCtrl = MapController();
  final _locationService = LocationService();
  final _mosqueService = MosqueService();

  List<Mosque> _mosques = [];
  bool _loading = true;
  String? _error;
  double? _userLat;
  double? _userLng;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _mosques = [];
      _selectedId = null;
    });

    final pos = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _error = 'Konum alınamadı.\nLütfen konum iznini açık olduğunu kontrol edin.';
        _loading = false;
      });
      return;
    }

    _userLat = pos.latitude;
    _userLng = pos.longitude;

    try {
      final mosques = await _mosqueService.fetchNearby(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _mosques = mosques;
        _loading = false;
      });
      // Haritayı konuma götür
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.5);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Camiler yüklenemedi.\nİnternet bağlantınızı kontrol edin.';
        _loading = false;
      });
    }
  }

  void _select(Mosque m) {
    setState(() => _selectedId = m.id);
    _mapCtrl.move(LatLng(m.lat, m.lng), 17.0);
  }

  Future<void> _openDirections(Mosque m) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${m.lat},${m.lng}'
      '&travelmode=walking',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Yakınımdaki Camiler'),
      ),
      body: Stack(
        children: [
          // ── Harita ────────────────────────────────────────────────────────
          if (_userLat != null)
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: LatLng(_userLat!, _userLng!),
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.application',
                ),
                MarkerLayer(
                  markers: [
                    // Kullanıcı konumu
                    Marker(
                      point: LatLng(_userLat!, _userLng!),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Cami pinleri
                    ..._mosques.map((m) {
                      final sel = m.id == _selectedId;
                      return Marker(
                        point: LatLng(m.lat, m.lng),
                        width: sel ? 46 : 36,
                        height: sel ? 46 : 36,
                        child: GestureDetector(
                          onTap: () => _select(m),
                          child: Container(
                            decoration: BoxDecoration(
                              color: sel
                                  ? cs.primary
                                  : cs.primary.withValues(alpha: 0.82),
                              shape: BoxShape.circle,
                              border: sel
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.mosque,
                                color: Colors.white, size: sel ? 24 : 18),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            )
          else if (!_loading)
            // Konum yok, hata göster
            const SizedBox.expand(),

          // ── Yükleniyor ────────────────────────────────────────────────────
          if (_loading)
            ColoredBox(
              color: cs.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Konum ve camiler yükleniyor...',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ),

          // ── Hata ─────────────────────────────────────────────────────────
          if (_error != null && !_loading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            ),

          // ── Alt liste ─────────────────────────────────────────────────────
          if (!_loading && _error == null)
            DraggableScrollableSheet(
              initialChildSize: 0.28,
              minChildSize: 0.12,
              maxChildSize: 0.72,
              builder: (_, ctrl) => Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Başlık
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.mosque, color: cs.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${_mosques.length} cami bulundu  ·  2 km içinde',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: cs.outline.withValues(alpha: 0.5)),
                    // Liste
                    Expanded(
                      child: _mosques.isEmpty
                          ? Center(
                              child: Text(
                                'Yakında isimli cami bulunamadı.',
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: ctrl,
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _mosques.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 68,
                                color: cs.outline.withValues(alpha: 0.4),
                              ),
                              itemBuilder: (_, i) {
                                final m = _mosques[i];
                                final sel = m.id == _selectedId;
                                return ListTile(
                                  selected: sel,
                                  selectedTileColor:
                                      cs.primary.withValues(alpha: 0.07),
                                  leading: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? cs.primary
                                          : cs.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mosque,
                                      size: 18,
                                      color: sel ? Colors.white : cs.primary,
                                    ),
                                  ),
                                  title: Text(
                                    m.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _fmtDist(m.distanceKm),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.directions,
                                        color: cs.primary, size: 22),
                                    tooltip: 'Yol Tarifi',
                                    onPressed: () => _openDirections(m),
                                  ),
                                  onTap: () => _select(m),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDist(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
