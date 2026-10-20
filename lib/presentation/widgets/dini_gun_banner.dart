import 'package:flutter/material.dart';

import '../../data/services/dini_gun_service.dart';
import '../../domain/models/dini_gun.dart';
import '../screens/dini_gunler_screen.dart';

/// Ana ekran hero alanının altında, bugün/yarın bir dini gün varsa görünen şerit.
/// Bildirim yoksa hiçbir yer kaplamaz.
class DiniGunBanner extends StatefulWidget {
  const DiniGunBanner({super.key});

  @override
  State<DiniGunBanner> createState() => _DiniGunBannerState();
}

class _DiniGunBannerState extends State<DiniGunBanner> {
  List<DiniGun> _days = const [];

  @override
  void initState() {
    super.initState();
    DiniGunService.load().then((d) {
      if (mounted) setState(() => _days = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    // build her çağrıldığında güncel tarihe göre yeniden hesaplanır (gece yarısı geçişi)
    final notice = DiniGunService.noticeFor(DateTime.now(), _days);
    if (notice == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final icon = switch (notice.gun.kind) {
      DiniGunKind.kandil => Icons.nightlight_round,
      DiniGunKind.bayram || DiniGunKind.arefe => Icons.celebration_outlined,
      _ => Icons.event_outlined,
    };

    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      shape: StadiumBorder(
        side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DiniGunlerScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  notice.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
