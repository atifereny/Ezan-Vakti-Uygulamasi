import 'package:flutter/material.dart';

import '../../data/services/dua_service.dart';
import '../../data/services/quran_service.dart';
import '../../domain/models/quran.dart';
import 'quran_reader_screen.dart';

/// Kur'an-ı Kerim ana sayfası: kaldığın yer, sûreler ve cüzler
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  QuranData? _data;
  Object? _error;
  int? _lastPage;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await QuranService.load();
      final last = await QuranService.lastPage();
      if (!mounted) return;
      setState(() {
        _data = d;
        _lastPage = last;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(int page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(data: _data!, startPage: page),
      ),
    );
    final last = await QuranService.lastPage();
    if (mounted) setState(() => _lastPage = last);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _data;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kur’an-ı Kerim'),
          bottom: data == null
              ? null
              : const TabBar(
                  tabs: [Tab(text: 'Sûreler'), Tab(text: 'Cüzler')],
                ),
        ),
        body: data == null
            ? Center(
                child: _error != null
                    ? Text('Kur’an verisi yüklenemedi.',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)))
                    : CircularProgressIndicator(color: cs.primary),
              )
            : TabBarView(
                children: [_surahTab(cs, data), _juzTab(cs, data)],
              ),
      ),
    );
  }

  // ── Sûreler ────────────────────────────────────────────────────────────────

  Widget _surahTab(ColorScheme cs, QuranData data) {
    final q = DuaService.fold(_query.trim());
    final list = [
      for (final s in data.surahs)
        if (q.isEmpty ||
            DuaService.fold(s.name).contains(q) ||
            '${s.no}' == q)
          s,
    ];

    return Column(
      children: [
        if (_lastPage != null) _resumeCard(cs, data, _lastPage!),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Sûre ara (ör. Bakara, 36)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            itemCount: list.length,
            itemBuilder: (_, i) => _surahTile(cs, list[i]),
          ),
        ),
      ],
    );
  }

  Widget _resumeCard(ColorScheme cs, QuranData data, int page) {
    final surah = data.surahOnPage(page);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(page),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.bookmark_outline, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kaldığın yerden devam et',
                          style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${surah.name}  ·  Sayfa $page',
                          style: const TextStyle(fontSize: 14.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _surahTile(ColorScheme cs, QuranSurah s) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _NumberBadge(number: s.no),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${s.meccan ? 'Mekki' : 'Medeni'}  ·  ${s.ayahCount} ayet  ·  Sayfa ${s.startPage}',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
        ),
        trailing: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            s.arabicName.replaceFirst('سُورَةُ ', ''),
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 21,
              color: cs.primary,
            ),
          ),
        ),
        onTap: () => _open(s.startPage),
      ),
    );
  }

  // ── Cüzler ─────────────────────────────────────────────────────────────────

  Widget _juzTab(ColorScheme cs, QuranData data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: 30,
      itemBuilder: (_, i) {
        final page = data.juzStartPages[i];
        final surah = data.surahOnPage(page);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: _NumberBadge(number: i + 1),
            title: Text('${i + 1}. Cüz', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${surah.name}  ·  Sayfa $page',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
            ),
            onTap: () => _open(page),
          ),
        );
      },
    );
  }
}

/// Sekizgen çerçeveli numara rozeti
class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: StarBorder.polygon(
          sides: 8,
          pointRounding: 0.15,
          side: BorderSide(color: cs.primary, width: 1.3),
        ),
        color: cs.primary.withValues(alpha: 0.08),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: cs.primary,
          fontSize: number > 99 ? 11.5 : 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
