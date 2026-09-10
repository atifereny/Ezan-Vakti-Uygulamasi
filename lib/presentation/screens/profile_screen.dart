import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../domain/models/saved_location.dart';

class ProfileScreen extends StatefulWidget {
  final SavedLocation? savedLocation;
  final Position? currentPosition;
  final String city;
  final String district;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const ProfileScreen({
    super.key,
    required this.savedLocation,
    required this.currentPosition,
    required this.city,
    required this.district,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tema Modu ──
          Card(
            child: SwitchListTile(
              title: const Text('Koyu Tema'),
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: cs.primary,
              ),
              value: isDark,
              onChanged: _toggleTheme,
            ),
          ),

          const SizedBox(height: 12),

          // ── Şehir bilgisi ──
          if (widget.city.isNotEmpty)
            _InfoCard(
              title: 'Mevcut Şehir',
              icon: Icons.location_city,
              color: cs.primary,
              children: [
                _Row(label: 'Şehir', value: widget.city),
                if (widget.district.isNotEmpty)
                  _Row(label: 'İlçe', value: widget.district),
              ],
            ),

          const SizedBox(height: 12),

          // ── Kayıtlı konum ──
          if (widget.savedLocation != null)
            _InfoCard(
              title: 'Kayıtlı Konum',
              icon: Icons.bookmark,
              color: Colors.orange,
              children: [
                _Row(
                  label: 'Enlem',
                  value: widget.savedLocation!.latitude.toStringAsFixed(6),
                ),
                _Row(
                  label: 'Boylam',
                  value: widget.savedLocation!.longitude.toStringAsFixed(6),
                ),
                _Row(
                  label: 'Kaydedilme',
                  value: _formatDate(widget.savedLocation!.savedAt),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // ── Anlık GPS konumu ──
          _InfoCard(
            title: 'Anlık GPS Konumu',
            icon: Icons.my_location,
            color: Colors.blue,
            children: widget.currentPosition != null
                ? [
                    _Row(
                      label: 'Enlem',
                      value: widget.currentPosition!.latitude
                          .toStringAsFixed(6),
                    ),
                    _Row(
                      label: 'Boylam',
                      value: widget.currentPosition!.longitude
                          .toStringAsFixed(6),
                    ),
                    _Row(
                      label: 'Doğruluk',
                      value:
                          '±${widget.currentPosition!.accuracy.toStringAsFixed(0)} m',
                    ),
                  ]
                : [
                    const _Row(
                      label: 'Durum',
                      value: 'Henüz alınmadı',
                    ),
                  ],
          ),

          const SizedBox(height: 24),

          // ── Konumu Yenile butonu ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isRefreshing ? null : widget.onRefresh,
              icon: widget.isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                widget.isRefreshing ? 'Konum alınıyor...' : 'Konumu Yenile',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTheme(bool val) {
    setState(() {
      themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    });
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('dark_mode', val));
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Yardımcı Widgetlar ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
