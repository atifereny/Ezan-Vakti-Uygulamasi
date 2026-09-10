import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/dhikr_service.dart';
import '../../domain/models/dhikr.dart';
import 'zikir_olustur_screen.dart';

class ZikirmatikScreen extends StatefulWidget {
  const ZikirmatikScreen({super.key});

  @override
  State<ZikirmatikScreen> createState() => _ZikirmatikScreenState();
}

class _ZikirmatikScreenState extends State<ZikirmatikScreen>
    with SingleTickerProviderStateMixin {
  final _dhikrService = DhikrService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Dhikr> _dhikrs = [];
  Dhikr? _selected;

  late AnimationController _tapCtrl;
  late Animation<double> _tapAnim;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _tapAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeOut),
    );
    _loadDhikrs();
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDhikrs() async {
    final list = await _dhikrService.loadAll();
    if (!mounted) return;
    setState(() {
      _dhikrs = list;
      if (_selected == null && list.isNotEmpty) _selected = list.first;
    });
  }

  Future<void> _onTap() async {
    final sel = _selected;
    if (sel == null || sel.isCompleted) return;
    HapticFeedback.lightImpact();
    _tapCtrl.forward().then((_) => _tapCtrl.reverse());
    setState(() => sel.current++);

    if (sel.isPhased &&
        sel.current % sel.phaseSize == 0 &&
        !sel.isCompleted) {
      HapticFeedback.mediumImpact();
    }

    await _dhikrService.saveAll(_dhikrs);
  }

  Future<void> _reset() async {
    final sel = _selected;
    if (sel == null) return;
    setState(() => sel.current = 0);
    await _dhikrService.saveAll(_dhikrs);
  }

  void _selectDhikr(Dhikr d, BuildContext drawerCtx) {
    setState(() => _selected = d);
    Navigator.of(drawerCtx).pop();
  }

  Future<void> _deleteDhikr(Dhikr d, BuildContext drawerCtx) async {
    final confirmed = await showDialog<bool>(
      context: drawerCtx,
      builder: (_) => AlertDialog(
        title: const Text('Zikri Sil'),
        content: Text('"${d.name}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(drawerCtx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(drawerCtx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _dhikrs.remove(d);
      if (_selected?.id == d.id) {
        _selected = _dhikrs.isNotEmpty ? _dhikrs.first : null;
      }
    });
    await _dhikrService.saveAll(_dhikrs);
  }

  Future<void> _openCreate(BuildContext ctx) async {
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.of(ctx).pop();
    }
    final newDhikr = await Navigator.push<Dhikr>(
      context,
      MaterialPageRoute(builder: (_) => const ZikirOlusturScreen()),
    );
    if (newDhikr != null && mounted) {
      _dhikrs.add(newDhikr);
      await _dhikrService.saveAll(_dhikrs);
      setState(() => _selected = newDhikr);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_selected?.displayName ?? 'Zikirmatik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildEndDrawer(),
      body: _buildBody(context),
    );
  }

  // ── End Drawer ─────────────────────────────────────────────────────────────

  Widget _buildEndDrawer() {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);

    return Drawer(
      child: Builder(
        builder: (drawerCtx) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      'Zikirlerim',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: cs.primary),
                      tooltip: 'Zikir Oluştur',
                      onPressed: () => _openCreate(drawerCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_dhikrs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.countertops_outlined, size: 52, color: muted),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz zikir yok.',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Zikir Oluştur'),
                          onPressed: () => _openCreate(drawerCtx),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _dhikrs.length,
                    itemBuilder: (listCtx, i) {
                      final d = _dhikrs[i];
                      final isSelected = d.id == _selected?.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor:
                            cs.primary.withValues(alpha: 0.1),
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? cs.primary : muted,
                          size: 20,
                        ),
                        title: Text(
                          d.name,
                          style: TextStyle(
                            color: isSelected ? cs.onSurface : muted,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${d.current} / ${d.target}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: d.id == 'namaz_tesbihat'
                            ? null
                            : IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red.shade300),
                                onPressed: () => _deleteDhikr(d, drawerCtx),
                              ),
                        onTap: () => _selectDhikr(d, drawerCtx),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    if (_selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.countertops_outlined, size: 64, color: muted),
              const SizedBox(height: 16),
              Text(
                'Sağ üstteki menüden\nbir zikir seçin veya oluşturun',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 15),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Zikir Oluştur'),
                onPressed: () => _openCreate(ctx),
              ),
            ],
          ),
        ),
      );
    }

    final sel = _selected!;
    final completed = sel.isCompleted;

    // BeadPainter için tema renkleri
    final beadColor = isDark ? cs.primary : cs.primary;
    final ringTrackColor = isDark
        ? cs.onSurface.withValues(alpha: 0.18)
        : const Color(0xFFDCC898);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── "Hedefe Ulaşıldı" ─────────────────────────────────────────────
          SizedBox(
            height: 28,
            child: AnimatedOpacity(
              opacity: completed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                'Hedefe Ulaşıldı!',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Koleksiyon adı (faz modunda) ──────────────────────────────────
          if (sel.isPhased) ...[
            Text(
              sel.name,
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 2),
          ],

          // ── Sayaç ──────────────────────────────────────────────────────────
          Text(
            '${sel.isPhased ? sel.phaseCount : sel.current}',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 72,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Hedef: ${sel.phaseSize}',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 12),

          // ── Faz noktaları ─────────────────────────────────────────────────
          if (sel.isPhased) ...[
            _PhaseDots(
              total: sel.phases!.length,
              currentIndex: sel.currentPhaseIndex,
              completed: completed,
            ),
            const SizedBox(height: 32),
          ] else
            const SizedBox(height: 44),

          // ── Çekme butonu ──────────────────────────────────────────────────
          GestureDetector(
            onTap: completed ? null : _onTap,
            child: AnimatedBuilder(
              animation: _tapAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _tapAnim.value, child: child),
              child: SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: _BeadPainter(
                    progress: sel.progress,
                    completed: completed,
                    count: sel.isPhased ? sel.phaseCount : sel.current,
                    primaryColor: beadColor,
                    ringTrackColor: ringTrackColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Sıfırla butonu ────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            iconSize: 32,
            color: sel.current > 0 ? cs.primary : cs.outline,
            tooltip: 'Sıfırla',
            onPressed: sel.current > 0 ? _reset : null,
          ),
        ],
      ),
    );
  }
}

// ── Faz Noktaları ──────────────────────────────────────────────────────────

class _PhaseDots extends StatelessWidget {
  final int total;
  final int currentIndex;
  final bool completed;

  const _PhaseDots({
    required this.total,
    required this.currentIndex,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inactiveColor = cs.onSurface.withValues(alpha: 0.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isDone = completed || i < currentIndex;
        final isCurrent = !completed && i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isDone
                ? const Color(0xFF4CAF50)
                : isCurrent
                    ? cs.primary
                    : inactiveColor,
          ),
        );
      }),
    );
  }
}

// ── Bead CustomPainter ─────────────────────────────────────────────────────

class _BeadPainter extends CustomPainter {
  final double progress;
  final bool completed;
  final int count;
  final Color primaryColor;
  final Color ringTrackColor;

  static const _gold = Color(0xFFC8A020);

  const _BeadPainter({
    required this.progress,
    required this.completed,
    required this.count,
    required this.primaryColor,
    required this.ringTrackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    final beadR = outerR - 18;

    // İlerleme halkası — arka plan
    canvas.drawCircle(
      center,
      outerR - 8,
      Paint()
        ..color = ringTrackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // İlerleme halkası — dolu kısım
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR - 8),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = completed ? const Color(0xFF4CAF50) : primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    // Gölge
    canvas.drawCircle(
      center + const Offset(3, 6),
      beadR,
      Paint()..color = Colors.black.withAlpha(45),
    );

    // Bead dolgusu
    canvas.drawCircle(
      center,
      beadR,
      Paint()..color = completed ? _gold : primaryColor,
    );

    // Parlama (3D efekti)
    canvas.drawCircle(
      center + Offset(-beadR * 0.3, -beadR * 0.3),
      beadR * 0.25,
      Paint()..color = Colors.white.withAlpha(35),
    );

    // İçerik: tamamlandıysa tik, değilse sayı
    if (completed) {
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 24, center.dy + 2)
          ..lineTo(center.dx - 6, center.dy + 20)
          ..lineTo(center.dx + 26, center.dy - 18),
        paint,
      );
    } else {
      final text = '$count';
      final fontSize = text.length <= 2
          ? 72.0
          : text.length == 3
              ? 56.0
              : 42.0;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_BeadPainter old) =>
      old.progress != progress ||
      old.completed != completed ||
      old.count != count ||
      old.primaryColor != primaryColor;
}
