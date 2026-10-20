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

  QuranData get _data => widget.data;

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
    final ctrl = TextEditingController(text: '$_page');
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfaya git'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '1 - ${_data.pageCount}',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Git'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (page != null && page >= 1 && page <= _data.pageCount) _jumpToPage(page);
  }

  void _openAyah(QuranAyah a) {
    setState(() => _selected = a);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _AyahSheet(data: _data, ayah: a),
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

  const _AyahSheet({required this.data, required this.ayah});

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
                fontFamily: kQuranFont,
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
