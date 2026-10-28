import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/services/quran_service.dart';
import '../../domain/models/quran.dart';

enum QuranMode { mushaf, meal }

const kQuranFont = 'ScheherazadeNew';

/// Okuyucunun seçebileceği Kur'an yazı tipleri (hepsi açık lisanslı, uygulamaya gömülü).
class QuranFontOption {
  final String family;
  final String label;
  final String note;
  const QuranFontOption(this.family, this.label, this.note);
}

const kQuranFonts = <QuranFontOption>[
  QuranFontOption('ScheherazadeNew', 'Klasik nesih', 'Açık ve okunaklı (varsayılan)'),
  QuranFontOption('Amiri', 'Klasik matbaa', 'Geleneksel Arap matbaa hattı'),
  QuranFontOption('AmiriQuran', "Kur'an hattı", 'Kaligrafik, mushaf görünümü'),
  QuranFontOption('NotoNaskhArabic', 'Sade nesih', 'Modern ve sade'),
];
const _baseLineHeight = 1.85;

/// Mushaf sayfasının tek bir sayfası: Arapça (akış) ya da ayet ayet Arapça + meal.
class QuranPageView extends StatefulWidget {
  final QuranData data;
  final int page; // 1..604
  final QuranMode mode;
  final void Function(QuranAyah ayah) onAyahTap;
  final QuranAyah? selected;
  final String fontFamily;

  const QuranPageView({
    super.key,
    required this.data,
    required this.page,
    required this.mode,
    required this.onAyahTap,
    this.selected,
    this.fontFamily = kQuranFont,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tapFor(QuranAyah a) {
    final r = TapGestureRecognizer()..onTap = () => widget.onAyahTap(a);
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = widget.data;
    final ayahs = data.pages[widget.page - 1];
    final surah = data.surahOf(ayahs.first.surah);

    // Her build'de önceki tanıyıcıları at
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    return ColoredBox(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: cs.primary.withValues(alpha: 0.55), width: 1.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline, width: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  _Header(
                    juz: data.juzOnPage(widget.page),
                    surahName: surah.name,
                  ),
                  Expanded(
                    child: widget.mode == QuranMode.mushaf
                        ? _MushafBody(
                            data: data,
                            ayahs: ayahs,
                            selected: widget.selected,
                            tapFor: _tapFor,
                            page: widget.page,
                            fontFamily: widget.fontFamily,
                          )
                        : _MealBody(
                            data: data,
                            ayahs: ayahs,
                            onTap: widget.onAyahTap,
                            selected: widget.selected,
                            fontFamily: widget.fontFamily,
                          ),
                  ),
                  _Footer(page: widget.page),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Üst / alt bilgi ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int juz;
  final String surahName;
  const _Header({required this.juz, required this.surahName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: cs.primary,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(surahName, style: style),
          Text('$juz. Cüz', style: style),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int page;
  const _Footer({required this.page});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
        ),
        child: Text(
          '$page',
          style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Sure başlığı + besmele ────────────────────────────────────────────────────

class _SurahBanner extends StatelessWidget {
  final QuranSurah surah;
  final double scale; // 1.0 = normal
  final String fontFamily;

  const _SurahBanner({required this.surah, required this.fontFamily, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 5 * scale, horizontal: 10),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            border: Border.symmetric(
              horizontal: BorderSide(color: cs.primary.withValues(alpha: 0.6), width: 1.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${surah.ayahCount} ayet',
                style: TextStyle(color: cs.primary, fontSize: 11 * scale),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  surah.arabicName,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: cs.onSurface,
                    fontSize: 23 * scale,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                surah.meccan ? 'Mekki' : 'Medeni',
                style: TextStyle(color: cs.primary, fontSize: 11 * scale),
              ),
            ],
          ),
        ),
        if (surah.hasBismillahHeader)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: cs.onSurface,
                  fontSize: 22 * scale,
                  height: 1.6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Mushaf modu: akan Arapça metin ────────────────────────────────────────────

/// Sayfadaki ayetleri, sure başlıklarıyla bölünmüş paragraflara ayırır.
class _Segment {
  final QuranSurah? banner; // bu segmentten önce sure başlığı
  final List<QuranAyah> ayahs;
  _Segment(this.banner, this.ayahs);
}

class _MushafBody extends StatelessWidget {
  final QuranData data;
  final List<QuranAyah> ayahs;
  final QuranAyah? selected;
  final TapGestureRecognizer Function(QuranAyah) tapFor;
  final int page;
  final String fontFamily;

  const _MushafBody({
    required this.data,
    required this.ayahs,
    required this.selected,
    required this.tapFor,
    required this.page,
    required this.fontFamily,
  });

  List<_Segment> _segments() {
    final segs = <_Segment>[];
    for (final a in ayahs) {
      if (a.number == 1) {
        segs.add(_Segment(data.surahOf(a.surah), [a]));
      } else if (segs.isEmpty) {
        segs.add(_Segment(null, [a]));
      } else {
        segs.last.ayahs.add(a);
      }
    }
    return segs;
  }

  TextSpan _spanFor(List<QuranAyah> list, double fs, Color color, Color accent,
      {bool interactive = true,
      double lineHeight = _baseLineHeight,
      double? justifyWidth}) {
    final children = <InlineSpan>[];
    for (final a in list) {
      final isSel = selected != null &&
          selected!.surah == a.surah &&
          selected!.number == a.number;
      final bg = isSel ? (Paint()..color = accent.withValues(alpha: 0.22)) : null;
      children.add(TextSpan(
        // Ayet numarası kendi satırına düşmesin diye kırılmaz boşluk
        text: '${a.arabic} ',
        recognizer: interactive ? tapFor(a) : null,
        style: bg == null ? null : TextStyle(background: bg),
      ));
      children.add(TextSpan(
        text: '﴿${QuranService.arabicDigits(a.number)}﴾ ',
        recognizer: interactive ? tapFor(a) : null,
        style: TextStyle(color: accent, fontSize: fs * 0.82),
      ));
    }
    // Son satırı da iki yana yaslamak için, satırın sonuna tam genişlikte
    // boş bir öğe eklenir: öğe alt satıra düşer, metnin son satırı "kırılmış"
    // sayılıp yaslanır.
    if (justifyWidth != null) {
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: SizedBox(width: justifyWidth, height: 0),
      ));
    }
    return TextSpan(
      style: TextStyle(
          fontFamily: fontFamily, color: color, fontSize: fs, height: lineHeight),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final segs = _segments();
    final centered = page <= 2;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - 28;
        final h = c.maxHeight - 8;
        final fit = _solve(
            segs, w, h, centered, DefaultTextStyle.of(context).style);
        final scale = fit.fontSize / 26;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            mainAxisAlignment:
                centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              for (var i = 0; i < segs.length; i++) ...[
                if (segs[i].banner != null)
                  _SurahBanner(
                    surah: segs[i].banner!,
                    fontFamily: fontFamily,
                    scale: scale.clamp(0.6, 1.2),
                  ),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                    width: double.infinity,
                    // Yaslama öğesinin eklediği boş satır yer kaplamasın
                    height: fit.justifyLast[i] ? fit.textHeights[i] : null,
                    child: fit.justifyLast[i]
                        ? OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: _paragraph(segs[i], fit, w, cs, centered, true),
                          )
                        : _paragraph(segs[i], fit, w, cs, centered, false),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _paragraph(_Segment seg, _MushafFit fit, double w, ColorScheme cs,
      bool centered, bool justifyLast) {
    return Text.rich(
      _spanFor(
        seg.ayahs,
        fit.fontSize,
        cs.onSurface,
        cs.primary,
        lineHeight: fit.lineHeight,
        justifyWidth: justifyLast ? w : null,
      ),
      textAlign: centered ? TextAlign.center : TextAlign.justify,
    );
  }

  // Bir yazı boyutu için ölçüm: toplam yükseklik, satır sayısı, son satır doluluğu
  ({double height, int lines, List<double> lastFill, List<double> textHeights})
      _measure(List<_Segment> segs, double fs, double width, double lineHeight,
          TextStyle base) {
    final scale = (fs / 26).clamp(0.6, 1.2);
    var total = 0.0;
    var lines = 0;
    final fills = <double>[];
    final heights = <double>[];
    for (final s in segs) {
      if (s.banner != null) {
        // başlık şeridi + (varsa) besmele
        total += 10 * scale + 23 * scale * 1.5 + 6;
        if (s.banner!.hasBismillahHeader) total += 4 * scale + 22 * scale * 1.6;
      }
      final tp = TextPainter(
        // Text.rich ile aynı: varsayılan metin stili üstüne bizim stil
        text: TextSpan(
          style: base,
          children: [
            _spanFor(s.ayahs, fs, Colors.black, Colors.black,
                interactive: false, lineHeight: lineHeight),
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: width);
      final m = tp.computeLineMetrics();
      total += tp.height;
      heights.add(tp.height);
      lines += m.length;
      fills.add(m.isEmpty ? 1 : (m.last.width / width).clamp(0.0, 1.0));
      tp.dispose();
    }
    return (height: total, lines: lines, lastFill: fills, textHeights: heights);
  }

  // Yerleşim sonucu pahalı (çok sayıda metin ölçümü); sayfa çevirirken her karede
  // yeniden hesaplanmasın diye önbelleğe alınır.
  static final Map<String, _MushafFit> _fitCache = {};

  /// Sayfaya sığan en büyük yazıyı bulur; son satırı (neredeyse) dolu yapan bir
  /// boyut varsa onu seçer, kalan boşluğu satır aralığına dağıtır.
  _MushafFit _solve(List<_Segment> segs, double w, double h, bool centered,
      TextStyle base) {
    final key = '$fontFamily|$page|${w.round()}|${h.round()}';
    final cached = _fitCache[key];
    if (cached != null) return cached;
    final fit = _computeFit(segs, w, h, centered, base);
    if (_fitCache.length > 48) _fitCache.clear();
    return _fitCache[key] = fit;
  }

  _MushafFit _computeFit(List<_Segment> segs, double w, double h, bool centered,
      TextStyle base) {
    // Tahmin gerçek yerleşimden biraz sapabildiği için güvenlik payı bırak
    const margin = 24.0;
    final maxFs = centered ? 32.0 : 30.0;

    bool fits(double fs) =>
        _measure(segs, fs, w, _baseLineHeight, base).height + margin <= h;

    // Kaba arama: sığan ilk boyut, sonra 0,1'lik adımlarla en büyük sığanı bul
    var fs = maxFs;
    while (fs > 12 && !fits(fs)) {
      fs -= 0.5;
    }
    if (fs < maxFs) {
      for (var up = fs + 0.4; up >= fs + 0.1 - 1e-9; up -= 0.1) {
        if (up <= maxFs && fits(up)) {
          fs = up;
          break;
        }
      }
    }
    final bestFs = fs;

    if (!centered && bestFs > 12.5) {
      // Son paragrafın son satırı en dolu olan boyutu ara (en fazla ~iki satırlık
      // aralıkta); ≥%85 ilk bulunanı (en büyük) seç, yoksa en doluyu.
      var bestFill = _measure(segs, bestFs, w, _baseLineHeight, base).lastFill.last;
      var chosen = bestFs;
      if (bestFill < 0.85) {
        for (var cand = bestFs - 0.1; cand >= bestFs - 2.6 && cand >= 12; cand -= 0.1) {
          final f = _measure(segs, cand, w, _baseLineHeight, base).lastFill.last;
          if (f > bestFill + 1e-6) {
            bestFill = f;
            chosen = cand;
          }
          if (f >= 0.85) break;
        }
      }
      fs = chosen;
    }

    final m = _measure(segs, fs, w, _baseLineHeight, base);
    var lh = _baseLineHeight;
    if (!centered && m.lines > 0) {
      // Artan yüksekliği satır aralığına dağıt (mushaf gibi sayfayı doldurur)
      final extra = (h - margin) - m.height;
      if (extra > 0) lh += (extra / (m.lines * fs)).clamp(0.0, 0.45);
    }

    // Son satırı en az %55 dolu olan paragraflar iki yana yaslanır
    final justify = [
      for (final f in m.lastFill) !centered && f >= 0.55 && f < 0.995,
    ];
    final heights = _measure(segs, fs, w, lh, base).textHeights;
    return _MushafFit(fs, lh, justify, heights);
  }
}

class _MushafFit {
  final double fontSize;
  final double lineHeight;
  final List<bool> justifyLast;
  final List<double> textHeights; // yaslama öğesi hariç paragraf yükseklikleri
  const _MushafFit(this.fontSize, this.lineHeight, this.justifyLast, this.textHeights);
}

// ── Meal modu: ayet ayet Arapça + Türkçe meal ─────────────────────────────────

class _MealBody extends StatelessWidget {
  final QuranData data;
  final List<QuranAyah> ayahs;
  final void Function(QuranAyah) onTap;
  final QuranAyah? selected;
  final String fontFamily;

  const _MealBody({
    required this.data,
    required this.ayahs,
    required this.onTap,
    required this.selected,
    required this.fontFamily,
  });

  bool _isSel(QuranAyah a) =>
      selected != null && selected!.surah == a.surah && selected!.number == a.number;

  /// Ortak mealli ayet gruplarını tek blokta topla
  List<List<QuranAyah>> _blocks() {
    final blocks = <List<QuranAyah>>[];
    for (final a in ayahs) {
      final sameGroup = blocks.isNotEmpty &&
          a.isContinuation &&
          blocks.last.first.surah == a.surah &&
          data.groupStartOf(blocks.last.first).number == a.groupStart;
      if (sameGroup) {
        blocks.last.add(a);
      } else {
        blocks.add([a]);
      }
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blocks = _blocks();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        final first = block.first;
        final start = data.groupStartOf(first);
        final meal = start.meal;
        final rangeEnd = start.groupEnd;
        final label = rangeEnd == null
            ? '${first.surah}:${first.number}'
            : '${first.surah}:${start.number}-$rangeEnd';
        final continues = first.isContinuation;
        final selectedBlock = block.any(_isSel);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (first.number == 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _SurahBanner(
                  surah: data.surahOf(first.surah),
                  fontFamily: fontFamily,
                  scale: 0.95,
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTap(first),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selectedBlock
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontFamily: fontFamily,
                              color: cs.onSurface,
                              fontSize: 24,
                              height: 1.9,
                            ),
                            children: [
                              for (final a in block) ...[
                                TextSpan(text: '${a.arabic} '),
                                TextSpan(
                                  text:
                                      '﴿${QuranService.arabicDigits(a.number)}﴾ ',
                                  style: TextStyle(color: cs.primary, fontSize: 20),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      continues ? '$label  (devamı)' : label,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meal,
                      style: TextStyle(color: cs.onSurface, fontSize: 14.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
