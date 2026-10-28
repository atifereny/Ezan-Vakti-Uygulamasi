import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../data/services/quran_service.dart';
import '../../domain/models/quran.dart';
import '../widgets/page_curl.dart';
import '../widgets/quran_page_view.dart';

class QuranReaderScreen extends StatefulWidget {
  final QuranData data;
  final int startPage; // 1..604

  const QuranReaderScreen({super.key, required this.data, required this.startPage});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _curl = PageCurlController();
  late int _page = widget.startPage;
  QuranMode _mode = QuranMode.mushaf;
  QuranAyah? _selected;
  String _font = kQuranFont;

  QuranData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    QuranService.savedFont().then((f) {
      if (!mounted || f == null) return;
      if (kQuranFonts.any((o) => o.family == f)) setState(() => _font = f);
    });
  }

  void _pickFont() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => _FontSheet(
        selected: _font,
        onSelected: (family) {
          Navigator.pop(ctx);
          setState(() => _font = family);
          QuranService.saveFont(family);
        },
      ),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _page = index + 1;
      _selected = null;
    });
    QuranService.saveLastPage(_page);
  }

  void _jumpToPage(int page) {
    _curl.jumpTo(page - 1);
  }

  Future<void> _showJumpDialog() async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => _JumpDialog(initial: _page, pageCount: _data.pageCount),
    );
    if (page != null && page >= 1 && page <= _data.pageCount) _jumpToPage(page);
  }

  void _openAyah(QuranAyah a) {
    setState(() => _selected = a);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _AyahSheet(data: _data, ayah: a, fontFamily: _font),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surah = _data.surahOnPage(_page);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(surah.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
              'Sayfa $_page  ·  ${_data.juzOnPage(_page)}. Cüz',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _mode == QuranMode.mushaf ? 'Meali göster' : 'Mushaf görünümü',
            icon: Icon(
              _mode == QuranMode.mushaf ? Icons.translate : Icons.menu_book_outlined,
            ),
            onPressed: () => setState(() {
              _mode = _mode == QuranMode.mushaf ? QuranMode.meal : QuranMode.mushaf;
              _selected = null;
            }),
          ),
          IconButton(
            tooltip: 'Yazı tipi',
            icon: const Icon(Icons.text_fields),
            onPressed: _pickFont,
          ),
          IconButton(
            tooltip: 'Sayfaya git',
            icon: const Icon(Icons.pin_outlined),
            onPressed: _showJumpDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PageCurl(
                      controller: _curl,
                      itemCount: _data.pageCount,
                      initialIndex: widget.startPage - 1,
                      onPageChanged: _onPageChanged,
                      builder: (context, i) => QuranPageView(
                        fontFamily: _font,
                        data: _data,
                        page: i + 1,
                        mode: _mode,
                        selected: _selected,
                        onAyahTap: _openAyah,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _PageSlider(
              page: _page,
              pageCount: _data.pageCount,
              onChanged: (p) => _jumpToPage(p),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yazı tipi seçim sayfası: her seçenek kendi yazı tipiyle önizlenir.
class _FontSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FontSheet({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Yazı tipi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final o in kQuranFonts)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: o.family == selected
                    ? cs.primary.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: o.family == selected
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(o.family),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: o.label,
                                  style: const TextStyle(
                                      fontSize: 14.5, fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: '  ${o.note}',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: cs.onSurface.withValues(alpha: 0.6)),
                                ),
                              ])),
                            ),
                            if (o.family == selected)
                              Icon(Icons.check_circle, color: cs.primary, size: 20),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: o.family, fontSize: 21, height: 1.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Sayfaya git" diyaloğu. Kontrolcüyü kendisi yönetir; diyalog kapanış
/// animasyonu bitmeden dispose edilmesin diye State içinde tutulur.
class _JumpDialog extends StatefulWidget {
  final int initial;
  final int pageCount;

  const _JumpDialog({required this.initial, required this.pageCount});

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sayfaya git'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: '1 - ${widget.pageCount}',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_ctrl.text)),
          child: const Text('Git'),
        ),
      ],
    );
  }
}

/// Alt çubuk: mushaf gibi sağdan sola (1. sayfa sağda) sayfa kaydırıcısı
class _PageSlider extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  const _PageSlider({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Text('1', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                min: 1,
                max: pageCount.toDouble(),
                value: page.toDouble(),
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            Text('$pageCount', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Ayet bilgi sayfası ────────────────────────────────────────────────────────

class _AyahSheet extends StatelessWidget {
  final QuranData data;
  final QuranAyah ayah;
  final String fontFamily;

  const _AyahSheet({required this.data, required this.ayah, required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surah = data.surahOf(ayah.surah);
    final start = data.groupStartOf(ayah);
    final range = start.groupEnd;
    final meal = data.mealOf(ayah);
    final ref = '${surah.name} ${ayah.number}';
    final mealLabel =
        range == null ? 'Meal' : 'Meal (${start.number}-$range. ayetler birlikte)';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ref,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kopyala',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                    text: '${ayah.arabic}\n\n$meal\n\n($ref)',
                  ));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ayet kopyalandı'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(
              '${ayah.arabic} ﴿${QuranService.arabicDigits(ayah.number)}﴾',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 27,
                height: 2.0,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            mealLabel,
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SelectableText(
            meal,
            style: TextStyle(color: cs.onSurface, fontSize: 15.5, height: 1.55),
          ),
          const SizedBox(height: 20),
          // Tefsir: Diyanet içeriğin toplu aktarımına izin vermediği için uygulamaya
          // gömülmez; ayetin tefsiri Diyanet Kur'an Portalı'nda açılır.
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Tefsiri Diyanet Kur’an Portalı’nda oku'),
            onPressed: () => launchUrl(
              Uri.parse(
                'https://kuran.diyanet.gov.tr/tefsir/sure/${ayah.surah}/ayet/${ayah.number}',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tefsir, T.C. Diyanet İşleri Başkanlığı’nın sitesinde açılır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55), fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Divider(color: cs.outline.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          Text(
            'Arapça metin: Tanzil (Medine mushafı)  ·  Meal: Diyanet İşleri Başkanlığı',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
