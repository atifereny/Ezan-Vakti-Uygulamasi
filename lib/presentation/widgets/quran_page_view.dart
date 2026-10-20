import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/services/quran_service.dart';
import '../../domain/models/quran.dart';

enum QuranMode { mushaf, meal }

const kQuranFont = 'AmiriQuran';

/// Mushaf sayfasının tek bir sayfası: Arapça (akış) ya da ayet ayet Arapça + meal.
class QuranPageView extends StatefulWidget {
  final QuranData data;
  final int page; // 1..604
  final QuranMode mode;
  final void Function(QuranAyah ayah) onAyahTap;
  final QuranAyah? selected;

  const QuranPageView({
    super.key,
    required this.data,
    required this.page,
    required this.mode,
    required this.onAyahTap,
    this.selected,
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
                          )
                        : _MealBody(
                            data: data,
                            ayahs: ayahs,
                            onTap: widget.onAyahTap,
                            selected: widget.selected,
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

  const _SurahBanner({required this.surah, this.scale = 1});

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
                    fontFamily: kQuranFont,
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
                  fontFamily: kQuranFont,
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

  const _MushafBody({
    required this.data,
    required this.ayahs,
    required this.selected,
    required this.tapFor,
    required this.page,
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
      {bool interactive = true}) {
    final children = <InlineSpan>[];
    for (final a in list) {
      final isSel = selected != null &&
          selected!.surah == a.surah &&
          selected!.number == a.number;
      final bg = isSel ? (Paint()..color = accent.withValues(alpha: 0.22)) : null;
      children.add(TextSpan(
        text: '${a.arabic} ',
        recognizer: interactive ? tapFor(a) : null,
        style: bg == null ? null : TextStyle(background: bg),
      ));
      children.add(TextSpan(
        text: '﴿${QuranService.arabicDigits(a.number)}﴾ ',
        recognizer: interactive ? tapFor(a) : null,
        style: TextStyle(color: accent, fontSize: fs * 0.82),
      ));
    }
    return TextSpan(
      style: TextStyle(fontFamily: kQuranFont, color: color, fontSize: fs, height: 1.85),
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

        // Sayfaya sığan en büyük yazı boyutunu bul
        double chosen = 15;
        for (double fs = centered ? 32 : 30; fs >= 15; fs -= 1) {
          // Tahmin gerçek yerleşimden biraz sapabildiği için güvenlik payı bırak
          if (_height(segs, fs, w) + 24 <= h) {
            chosen = fs;
            break;
          }
        }

        final scale = chosen / 26;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            mainAxisAlignment:
                centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              for (final s in segs) ...[
                if (s.banner != null)
                  _SurahBanner(surah: s.banner!, scale: scale.clamp(0.6, 1.2)),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text.rich(
                      _spanFor(s.ayahs, chosen, cs.onSurface, cs.primary),
                      textAlign: centered ? TextAlign.center : TextAlign.justify,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Verilen yazı boyutunda sayfa içeriğinin toplam yüksekliği
  double _height(List<_Segment> segs, double fs, double width) {
    final scale = (fs / 26).clamp(0.6, 1.2);
    var total = 0.0;
    for (final s in segs) {
      if (s.banner != null) {
        // başlık şeridi + (varsa) besmele
        total += 10 * scale + 23 * scale * 1.5 + 6;
        if (s.banner!.hasBismillahHeader) total += 4 * scale + 22 * scale * 1.6;
      }
      final tp = TextPainter(
        text: _spanFor(s.ayahs, fs, Colors.black, Colors.black, interactive: false),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: width);
      total += tp.height;
      tp.dispose();
    }
    return total;
  }
}

// ── Meal modu: ayet ayet Arapça + Türkçe meal ─────────────────────────────────

class _MealBody extends StatelessWidget {
  final QuranData data;
  final List<QuranAyah> ayahs;
  final void Function(QuranAyah) onTap;
  final QuranAyah? selected;

  const _MealBody({
    required this.data,
    required this.ayahs,
    required this.onTap,
    required this.selected,
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
                child: _SurahBanner(surah: data.surahOf(first.surah), scale: 0.95),
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
                              fontFamily: kQuranFont,
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
