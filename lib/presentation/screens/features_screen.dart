import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'kaza_screen.dart';
import 'kible_screen.dart';
import 'nearby_mosques_screen.dart';
import 'zikirmatik_screen.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  static const _comingSoon = <(IconData, String, String)>[];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _FeatureCard(
              icon: Icons.explore,
              title: 'Kıble',
              subtitle: 'Mekke yönünü bul',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KibleScreen()),
              ),
            ),
            _FeatureCard(
              icon: Icons.countertops_outlined,
              svgAsset: isDark
                  ? 'assets/images/zikirmatik_dark.svg'
                  : 'assets/images/zikirmatik.svg',
              title: 'Zikirmatik',
              subtitle: 'Zikir sayacı',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ZikirmatikScreen()),
              ),
            ),
            _FeatureCard(
              icon: Icons.assignment_outlined,
              title: 'Kaza Takibi',
              subtitle: 'Kaza namazı ve oruç',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KazaScreen()),
              ),
            ),
            _FeatureCard(
              icon: Icons.mosque_outlined,
              title: 'Yakınımdaki\nCamiler',
              subtitle: '2 km çevredeki camiler',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NearbyMosquesScreen()),
              ),
            ),
            ..._comingSoon.map(
              (f) => _FeatureCard(icon: f.$1, title: f.$2, subtitle: f.$3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String? svgAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    this.svgAsset,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ??
            () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$title çok yakında!'),
                    duration: const Duration(seconds: 2),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              svgAsset != null
                  ? SvgPicture.asset(svgAsset!, width: 44, height: 44)
                  : Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
