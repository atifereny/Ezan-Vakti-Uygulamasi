import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/storage_service.dart';

class KibleScreen extends StatefulWidget {
  const KibleScreen({super.key});

  @override
  State<KibleScreen> createState() => _KibleScreenState();
}

class _KibleScreenState extends State<KibleScreen> {
  StreamSubscription<CompassEvent>? _compassSub;
  double? _heading;
  double? _qiblaAngle;
  bool _locationLoaded = false;

  // Kâbe koordinatları
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLon = 39.8262;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _heading = event.heading);
      }
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final saved = await StorageService().loadLocation();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _qiblaAngle = _calculateQibla(saved.latitude, saved.longitude);
      }
      _locationLoaded = true;
    });
  }

  double _calculateQibla(double lat, double lon) {
    final userLat = lat * pi / 180;
    final userLon = lon * pi / 180;
    final kaabaLat = _kaabaLat * pi / 180;
    final kaabaLon = _kaabaLon * pi / 180;
    final dLon = kaabaLon - userLon;
    final y = sin(dLon) * cos(kaabaLat);
    final x = cos(userLat) * sin(kaabaLat) -
        sin(userLat) * cos(kaabaLat) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kıble')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_locationLoaded) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }

    if (_qiblaAngle == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Konum bulunamadı.\nÖnce ana ekranda konumu güncelleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 15),
          ),
        ),
      );
    }

    final heading = _heading ?? 0.0;
    // Kıble açısı sabit, pusula heading kadar ters döner
    final compassRotation = -heading * pi / 180;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Kıble yönü: ${_qiblaAngle!.toStringAsFixed(1)}°',
          style: const TextStyle(
            color: kPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Transform.rotate(
              angle: compassRotation,
              child: CustomPaint(
                painter: _CompassPainter(qiblaAngle: _qiblaAngle!),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          _heading != null
              ? 'Cihaz yönü: ${_heading!.toStringAsFixed(0)}°'
              : 'Pusula okunuyor...',
          style: const TextStyle(color: kMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double qiblaAngle;

  const _CompassPainter({required this.qiblaAngle});

  static const _brown = Color(0xFF7A5C2E);
  static const _surface = Color(0xFFFDF8EE);
  static const _outline = Color(0xFFDCC898);
  static const _muted = Color(0xFF8B7355);
  static const _red = Color(0xFFC62828);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    // Arka plan dairesi
    canvas.drawCircle(center, r, Paint()..color = _surface);
    canvas.drawCircle(center, r, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    // İkinci iç halka
    canvas.drawCircle(center, r * 0.82, Paint()
      ..color = _outline.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Derece çizgileri
    for (int i = 0; i < 360; i += 5) {
      final rad = i * pi / 180;
      final isCardinal = i % 90 == 0;
      final isMajor = i % 45 == 0;
      final tickLen = isCardinal ? 16.0 : (isMajor ? 10.0 : 5.0);
      final rOuter = r - 4;
      final outer = Offset(center.dx + rOuter * sin(rad), center.dy - rOuter * cos(rad));
      final inner = Offset(center.dx + (rOuter - tickLen) * sin(rad), center.dy - (rOuter - tickLen) * cos(rad));
      canvas.drawLine(outer, inner, Paint()
        ..color = isCardinal ? _brown : (isMajor ? _muted : _outline)
        ..strokeWidth = isCardinal ? 2.5 : 1
        ..strokeCap = StrokeCap.round);
    }

    // Ana yön harfleri
    _drawLabel(canvas, 'K', center, r * 0.65, 0, _red, fontSize: 16, bold: true);
    _drawLabel(canvas, 'G', center, r * 0.65, pi, _muted, fontSize: 14);
    _drawLabel(canvas, 'D', center, r * 0.65, pi / 2, _muted, fontSize: 14);
    _drawLabel(canvas, 'B', center, r * 0.65, -pi / 2, _muted, fontSize: 14);

    // Kuzey oku (kırmızı)
    _drawNorthArrow(canvas, center, r);

    // Kıble oku (altın-kahve)
    _drawQiblaArrow(canvas, center, r);

    // Merkez dairesi
    canvas.drawCircle(center, 8, Paint()..color = _brown);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  void _drawNorthArrow(Canvas canvas, Offset center, double r) {
    final tip = Offset(center.dx, center.dy - r * 0.78);
    final base = Offset(center.dx, center.dy + r * 0.2);
    final left = Offset(center.dx - 8, center.dy - r * 0.35);
    final right = Offset(center.dx + 8, center.dy - r * 0.35);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(base.dx, base.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _red.withAlpha(200));

    // Güney yarısı (gri)
    final southTip = Offset(center.dx, center.dy + r * 0.78);
    final southPath = Path()
      ..moveTo(southTip.dx, southTip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(base.dx, base.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(southPath, Paint()..color = _outline);
  }

  void _drawQiblaArrow(Canvas canvas, Offset center, double r) {
    final rad = qiblaAngle * pi / 180;
    final tip = Offset(
      center.dx + r * 0.55 * sin(rad),
      center.dy - r * 0.55 * cos(rad),
    );
    final baseX = center.dx - r * 0.1 * sin(rad);
    final baseY = center.dy + r * 0.1 * cos(rad);

    final perpX = cos(rad) * 7;
    final perpY = sin(rad) * 7;
    final left = Offset(
      baseX + perpX,
      baseY + perpY,
    );
    final right = Offset(
      baseX - perpX,
      baseY - perpY,
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _brown);

    // Ok gövdesi
    canvas.drawLine(
      Offset(center.dx, center.dy),
      tip,
      Paint()
        ..color = _brown
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Kâbe sembolü — küçük kare
    final kaabePaint = Paint()
      ..color = _brown
      ..style = PaintingStyle.fill;
    final kaabeRect = Rect.fromCenter(center: tip, width: 10, height: 10);
    canvas.drawRect(kaabeRect, kaabePaint);
    canvas.drawRect(kaabeRect, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawLabel(
    Canvas canvas, String text, Offset center, double r, double angle, Color color, {
    double fontSize = 14,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        center.dx + r * sin(angle) - tp.width / 2,
        center.dy - r * cos(angle) - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.qiblaAngle != qiblaAngle;
}
