import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
/// sayfanın sol kenarı kalkıp bir silindir gibi sırta doğru kıvrılır, arkası
/// görünür ve altındaki sayfa ortaya çıkar. Geri dönerken önceki sayfa aynı
/// kıvrımla açılarak mevcut sayfanın üstüne kapanır.
///
/// Çevrilen sayfa bir kez görüntüye alınır ve ağ (mesh) olarak bükülerek çizilir.
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
  bool _flipping = false;
  Curve _curve = Curves.easeOutCubic;

  // Çevrilen sayfanın görüntüsü
  final Map<int, GlobalKey> _boundaryKeys = {};
  ui.Image? _img;
  int? _imgFor;
  int? _capturingFor;
  Completer<void>? _imgWaiter;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _anim.addListener(() {
      if (!_settling) return;
      final t = _curve.transform(_anim.value);
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
    _img?.dispose();
    super.dispose();
  }

  bool get _canForward => _index < widget.itemCount - 1;
  bool get _canBack => _index > 0;

  void _dropImage() {
    _img?.dispose();
    _img = null;
    _imgFor = null;
    _capturingFor = null;
  }

  void _jumpTo(int index) {
    _anim.stop();
    _settling = false;
    _flipping = false;
    _dropImage();
    setState(() {
      _index = index.clamp(0, widget.itemCount - 1);
      _p = 0;
    });
    widget.onPageChanged?.call(_index);
  }

  Future<void> _flip({required bool forward}) async {
    if (forward ? !_canForward : !_canBack) return;
    if (_settling || _p != 0 || _flipping) return;
    _flipping = true;
    setState(() => _p = forward ? 0.0001 : -0.0001);
    // Çevrilecek sayfanın görüntüsü hazır olana kadar bekle
    await _waitImage(forward ? _index : _index - 1);
    if (!mounted || !_flipping) return;
    _curve = Curves.easeInOutCubic;
    _settle(forward ? 1 : -1, ms: 680);
  }

  Future<void> _waitImage(int page) {
    if (_imgFor == page && _img != null) return Future.value();
    _imgWaiter ??= Completer<void>();
    return _imgWaiter!.future;
  }

  void _settle(double target, {int? ms}) {
    _from = _p;
    _to = target;
    _settling = true;
    _anim.duration = Duration(
      milliseconds: ms ?? (140 + 420 * (target - _p).abs()).round(),
    );
    _anim.forward(from: 0);
  }

  void _finishSettle() {
    _settling = false;
    _flipping = false;
    _curve = Curves.easeOutCubic;
    final moved = _to == 1 ? 1 : (_to == -1 ? -1 : 0);
    _dropImage();
    setState(() {
      _index += moved;
      _p = 0;
    });
    _boundaryKeys.removeWhere((k, _) => (k - _index).abs() > 1);
    if (moved != 0) widget.onPageChanged?.call(_index);
  }

  void _onDragStart(DragStartDetails d) {
    _anim.stop();
    _settling = false;
    _flipping = false;
    _curve = Curves.easeOutCubic;
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

  // Çevrilen sayfayı bir sonraki karede görüntüye alır
  void _ensureCapture(int page) {
    if (_capturingFor == page || (_imgFor == page && _img != null)) return;
    _capturingFor = page;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _capturingFor != page) return;
      final ro = _boundaryKeys[page]?.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        _capturingFor = null;
        return;
      }
      try {
        final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
        final img = await ro.toImage(pixelRatio: dpr);
        if (!mounted || _capturingFor != page) {
          img.dispose();
          return;
        }
        setState(() {
          _img?.dispose();
          _img = img;
          _imgFor = page;
          _capturingFor = null;
        });
        _imgWaiter?.complete();
        _imgWaiter = null;
      } catch (_) {
        _capturingFor = null;
      }
    });
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

  Widget _page(int i) => KeyedSubtree(
        key: ValueKey('curl-page-$i'),
        child: RepaintBoundary(
          key: _boundaryKeys.putIfAbsent(i, GlobalKey.new),
          child: widget.builder(context, i),
        ),
      );

  Widget _content() {
    if (_p == 0) {
      return Stack(fit: StackFit.expand, children: [_page(_index)]);
    }

    final forward = _p > 0;
    final q = _p.abs();
    final base = forward ? _index + 1 : _index;
    final turning = forward ? _index : _index - 1;
    _ensureCapture(turning);

    final ready = _img != null && _imgFor == turning;
    if (!ready) {
      // Görüntü alınırken sayfa değişmeden, çevrilen sayfa en üstte görünür
      return Stack(
        fit: StackFit.expand,
        children: forward
            ? [_page(base), _page(turning)]
            : [_page(turning), _page(base)],
      );
    }

    // 0: sayfa düz, 1: sayfa tamamen çevrilmiş
    final t = forward ? q : 1 - q;
    final paper = Theme.of(context).colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        _page(turning),
        _page(base),
        Positioned.fill(
          key: const ValueKey('curl-overlay'),
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CurlPainter(
                image: _img!,
                ratio: _img!.width / _width,
                t: t,
                paper: paper,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sayfa görüntüsünü silindire sararak çizer.
///
/// Koordinatlar sırttan olan uzaklık [u] ile verilir (sırt sağ kenarda, u = w - x).
/// Sırttan [f] kadar uzakta kıvrım çizgisi vardır; [f]'den ötesi yarıçapı R olan bir
/// silindire sarılır, ardından sayfanın arka yüzü düz biçimde geri döner.
class _CurlPainter extends CustomPainter {
  final ui.Image image;
  final double ratio;
  final double t;
  final Color paper;

  const _CurlPainter({
    required this.image,
    required this.ratio,
    required this.t,
    required this.paper,
  });

  static const _persp = 1 / 1600;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.10;
    final eMax = 2 * (w + r) - math.pi * r;
    final xc = _contactX(t.clamp(0.0, 1.0) * eMax, r, w + r);
    if (xc >= w + r - 0.5 || xc <= 0) return;

    final f = w - xc; // kıvrımın sırttan uzaklığı
    final halfArc = math.pi * r / 2;
    final fullArc = math.pi * r;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final shader = ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.medium,
    );
    final texPaint = Paint()..shader = shader;
    final solidPaint = Paint()..color = const Color(0xFFFFFFFF);

    final fade = (xc / (r * 3)).clamp(0.0, 1.0);

    // 1) Kıvrımın altta ortaya çıkan sayfaya düşürdüğü gölge
    final xLeft = xc - r;
    _shadow(canvas, Rect.fromLTRB(xLeft - 34, 0, xLeft, h), 0, 0.30 * fade, h);

    // 2) Düz kalan kısım
    if (f > 0) {
      _mesh(canvas, texPaint, [0, math.min(w, f)], w, h, r, xc, f, null);
      // Kıvrımın düz kısma düşürdüğü gölge
      _shadow(canvas, Rect.fromLTRB(xc, 0, math.min(w, xc + r * 3), h),
          0.34 * fade, 0, h);
    }
    // Arka yüzün kenarının düz kısma düşürdüğü gölge
    if (xc > fullArc) {
      final edge = 2 * xc - fullArc;
      if (edge < w) {
        _shadow(canvas, Rect.fromLTRB(edge, 0, math.min(w, edge + 16), h),
            0.26, 0, h);
      }
    }

    // 3) Kıvrılan ön yüz (φ: 0 → π/2)
    final frontLo = math.max(0.0, f);
    final frontHi = math.min(w, f + halfArc);
    if (frontHi > frontLo) {
      _mesh(canvas, texPaint, _range(frontLo, frontHi, 14), w, h, r, xc, f,
          (u) {
        final phi = (u - f) / r;
        final lum = 1 - 0.50 * math.sin(phi.clamp(0.0, math.pi / 2));
        return Color.fromARGB(255, (255 * lum).round(), (255 * lum).round(),
            (255 * lum).round());
      });
    }

    // 4) Kıvrılan arka yüz (φ: π/2 → π) ve geri dönen düz kısım
    final backLo = math.max(0.0, f + halfArc);
    final backHi = math.min(w, f + fullArc);
    if (backHi > backLo) {
      _paperMesh(canvas, solidPaint, texPaint, _range(backLo, backHi, 14), w,
          h, r, xc, f, (u) {
        final phi = ((u - f) / r).clamp(math.pi / 2, math.pi);
        return 0.58 + 0.40 * ((phi - math.pi / 2) / (math.pi / 2));
      });
    }
    final flapLo = math.max(0.0, f + fullArc);
    if (w > flapLo) {
      _paperMesh(canvas, solidPaint, texPaint, _range(flapLo, w, 4), w, h, r,
          xc, f, (u) {
        // Parlama: kenara doğru hafif aydınlanır
        final k = ((u - flapLo) / math.max(1.0, w - flapLo)).clamp(0.0, 1.0);
        return 0.97 - 0.05 * (1 - k);
      });
    }

    canvas.restore();
  }

  // Temas noktasını (kıvrımın ekrandaki x'i) kenar konumundan çözer.
  // Kenar: x ≤ πR için x - R·sin(x/R), sonrası için 2x - πR.
  static double _contactX(double e, double r, double hi) {
    double g(double x) =>
        x <= math.pi * r ? x - r * math.sin(x / r) : 2 * x - math.pi * r;
    var lo = 0.0;
    var up = hi;
    for (var i = 0; i < 28; i++) {
      final mid = (lo + up) / 2;
      if (g(mid) < e) {
        lo = mid;
      } else {
        up = mid;
      }
    }
    return (lo + up) / 2;
  }

  List<double> _range(double a, double b, int n) =>
      [for (var i = 0; i <= n; i++) a + (b - a) * i / n];

  void _shadow(Canvas canvas, Rect rect, double aLeft, double aRight, double h) {
    if (rect.width <= 0) return;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.centerLeft,
          rect.centerRight,
          [
            Colors.black.withValues(alpha: aLeft),
            Colors.black.withValues(alpha: aRight),
          ],
        ),
    );
  }

  // u için ekran konumu ve yükseklik (z)
  (double, double) _pos(double u, double r, double xc, double f, double w) {
    final s = u - f;
    if (s <= 0) return (w - u, 0);
    if (s < math.pi * r) {
      final phi = s / r;
      return (xc - r * math.sin(phi), r * (1 - math.cos(phi)));
    }
    return (xc + (s - math.pi * r), 2 * r);
  }

  void _mesh(Canvas canvas, Paint paint, List<double> us, double w, double h,
      double r, double xc, double f, Color Function(double u)? color) {
    final v = _vertices(us, w, h, r, xc, f, color);
    canvas.drawVertices(v, BlendMode.modulate, paint);
  }

  // Arka yüz: kağıt rengi + çok hafif yansıyan (ters) sayfa görüntüsü
  void _paperMesh(Canvas canvas, Paint solid, Paint tex, List<double> us,
      double w, double h, double r, double xc, double f,
      double Function(double u) lum) {
    final v = _vertices(us, w, h, r, xc, f, (u) {
      final l = lum(u).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF000000), paper, l)!;
    });
    canvas.drawVertices(v, BlendMode.modulate, solid);

    canvas.saveLayer(
      Offset.zero & Size(w, h),
      Paint()..color = const Color(0x24FFFFFF),
    );
    canvas.drawVertices(_vertices(us, w, h, r, xc, f, null), BlendMode.srcOver, tex);
    canvas.restore();
  }

  ui.Vertices _vertices(List<double> us, double w, double h, double r,
      double xc, double f, Color Function(double u)? color) {
    final n = us.length;
    final pos = Float32List(n * 4);
    final tex = Float32List(n * 4);
    final cols = color == null ? null : Int32List(n * 2);
    final cy = h / 2;
    for (var i = 0; i < n; i++) {
      final u = us[i];
      final (x, z) = _pos(u, r, xc, f, w);
      final sc = 1 / (1 - z * _persp);
      pos[i * 4] = x;
      pos[i * 4 + 1] = cy - cy * sc;
      pos[i * 4 + 2] = x;
      pos[i * 4 + 3] = cy + (h - cy) * sc;
      final tx = (w - u) * ratio;
      tex[i * 4] = tx;
      tex[i * 4 + 1] = 0;
      tex[i * 4 + 2] = tx;
      tex[i * 4 + 3] = h * ratio;
      if (cols != null) {
        final c = color!(u).toARGB32();
        cols[i * 2] = c;
        cols[i * 2 + 1] = c;
      }
    }
    return ui.Vertices.raw(
      ui.VertexMode.triangleStrip,
      pos,
      textureCoordinates: tex,
      colors: cols,
    );
  }

  @override
  bool shouldRepaint(_CurlPainter old) =>
      old.t != t || old.image != image || old.paper != paper;
}
