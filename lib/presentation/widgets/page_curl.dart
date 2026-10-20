import 'dart:math' as math;

import 'package:flutter/material.dart';

class PageCurlController {
  _PageCurlState? _state;

  /// Animasyonsuz sayfaya atla
  void jumpTo(int index) => _state?._jumpTo(index);

  /// Sayfa çevirme animasyonuyla ileri (sonraki sayfa)
  void next() => _state?._flip(forward: true);

  /// Sayfa çevirme animasyonuyla geri
  void previous() => _state?._flip(forward: false);
}

/// Mushaf (sağdan sola okunan) kitap gibi sayfa çevirme.
///
/// Sırt sağ kenardadır. Sonraki sayfaya geçmek için parmak soldan sağa sürüklenir:
/// sayfa sol kenarından kalkıp sırta doğru katlanır ve altındaki sayfa görünür.
/// Geri dönerken önceki sayfa sırttan açılarak mevcut sayfanın üstüne kapanır.
class PageCurl extends StatefulWidget {
  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder builder;
  final ValueChanged<int>? onPageChanged;
  final PageCurlController? controller;
  final VoidCallback? onTap;

  const PageCurl({
    super.key,
    required this.itemCount,
    required this.builder,
    this.initialIndex = 0,
    this.onPageChanged,
    this.controller,
    this.onTap,
  });

  @override
  State<PageCurl> createState() => _PageCurlState();
}

class _PageCurlState extends State<PageCurl>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex.clamp(0, widget.itemCount - 1);

  /// -1..1. Pozitif: mevcut sayfa ileri doğru çevriliyor. Negatif: önceki sayfa geri geliyor.
  double _p = 0;
  double _width = 1;

  late final AnimationController _anim = AnimationController(vsync: this);
  double _from = 0;
  double _to = 0;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _anim.addListener(() {
      if (!_settling) return;
      final t = Curves.easeOutCubic.transform(_anim.value);
      setState(() => _p = _from + (_to - _from) * t);
    });
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed && _settling) _finishSettle();
    });
  }

  @override
  void didUpdateWidget(PageCurl old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _anim.dispose();
    super.dispose();
  }

  bool get _canForward => _index < widget.itemCount - 1;
  bool get _canBack => _index > 0;

  void _jumpTo(int index) {
    _anim.stop();
    _settling = false;
    setState(() {
      _index = index.clamp(0, widget.itemCount - 1);
      _p = 0;
    });
    widget.onPageChanged?.call(_index);
  }

  void _flip({required bool forward}) {
    if (forward ? !_canForward : !_canBack) return;
    if (_settling || _p != 0) return;
    _p = forward ? 0.0001 : -0.0001;
    _settle(forward ? 1 : -1, ms: 520);
  }

  void _settle(double target, {int? ms}) {
    _from = _p;
    _to = target;
    _settling = true;
    _anim.duration = Duration(
      milliseconds: ms ?? (120 + 330 * (target - _p).abs()).round(),
    );
    _anim.forward(from: 0);
  }

  void _finishSettle() {
    _settling = false;
    final moved = _to == 1 ? 1 : (_to == -1 ? -1 : 0);
    setState(() {
      _index += moved;
      _p = 0;
    });
    if (moved != 0) widget.onPageChanged?.call(_index);
  }

  void _onDragStart(DragStartDetails d) {
    _anim.stop();
    _settling = false;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final lo = _canBack ? -1.0 : 0.0;
    final hi = _canForward ? 1.0 : 0.0;
    setState(() => _p = (_p + d.delta.dx / _width).clamp(lo, hi));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    const fling = 700.0;
    double target = 0;
    if (_p > 0) {
      target = (_p > 0.5 || v > fling) && v > -fling ? 1 : 0;
    } else if (_p < 0) {
      target = (_p < -0.5 || v < -fling) && v < fling ? -1 : 0;
    }
    if (_p == 0) return;
    _settle(target);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _width = c.maxWidth <= 0 ? 1 : c.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: ClipRect(child: _content()),
        );
      },
    );
  }

  Widget _page(int i) => RepaintBoundary(
        child: KeyedSubtree(
          key: ValueKey('curl-page-$i'),
          child: widget.builder(context, i),
        ),
      );

  Widget _content() {
    if (_p == 0) return _page(_index);

    final forward = _p > 0;
    final q = _p.abs();
    // 0: sayfa düz ve üstte, pi/2: sayfa yandan (görünmez)
    final theta = (forward ? q : 1 - q) * math.pi / 2;
    final base = forward ? _index + 1 : _index;
    final turning = forward ? _index : _index - 1;

    return _TurnStack(
      base: _page(base),
      turning: _page(turning),
      theta: theta,
    );
  }
}

const double _perspective = 0.0009;

class _TurnStack extends StatelessWidget {
  final Widget base;
  final Widget turning;
  final double theta;

  const _TurnStack({
    required this.base,
    required this.turning,
    required this.theta,
  });

  @override
  Widget build(BuildContext context) {
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // Çevrilen sayfanın sol kenarının perspektifli x konumu (sırt sağda)
        final edgeX = w * (1 - cosT / (1 + _perspective * w * sinT));
        const shadowW = 46.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Alttaki sayfa
            base,
            // Alttaki sayfa, üstteki sayfanın gölgesiyle kararır
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.20 * cosT),
                ),
              ),
            ),
            // Kalkan kenarın alttaki sayfaya düşürdüğü gölge
            Positioned(
              left: math.max(0, edgeX - shadowW),
              width: shadowW,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.38 * sinT.clamp(0.25, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Çevrilen sayfa: sağ kenar (sırt) etrafında döner
            Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, _perspective)
                ..rotateY(theta), // sol kenar sırta doğru uzaklaşır, sayfa daralır
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  // Dönerken sol kenardan sırta doğru koyulaşan ışık/gölge
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.30 * sinT),
                      Colors.black.withValues(alpha: 0.02 * sinT),
                    ],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28 * sinT),
                        blurRadius: 16,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: turning,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
