import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../data/services/dua_service.dart';
import '../../domain/models/dua.dart';
import 'dua_detail_screen.dart';

class DualarScreen extends StatefulWidget {
  const DualarScreen({super.key});

  @override
  State<DualarScreen> createState() => _DualarScreenState();
}

class _DualarScreenState extends State<DualarScreen> {
  DuaData? _data;
  DuaKind? _filter; // null = tümü
  String _query = '';

  @override
  void initState() {
    super.initState();
    DuaService.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  List<Dua> _visible(DuaData data) {
    final q = DuaService.fold(_query.trim());
    return [
      for (final d in data.duas)
        if ((_filter == null || d.kind == _filter) &&
            (q.isEmpty ||
                DuaService.fold(
                        '${d.title} ${d.meal} ${d.okunus} ${d.kaynak}')
                    .contains(q)))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: const Text('Dualar')),
      body: data == null
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : data.duas.isEmpty
              ? Center(
                  child: Text(
                    'Dua verisi bulunamadı.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                )
              : _body(context, cs, data),
    );
  }

  Widget _body(BuildContext context, ColorScheme cs, DuaData data) {
    final list = _visible(data);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Dua ara (ör. rızık, sığınmak, af)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              _chip('Tümü', null),
              _chip('Ayetlerden', DuaKind.ayet),
              _chip('Hadislerden', DuaKind.hadis),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Eşleşen dua bulunamadı.',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              for (final d in list) _tile(context, cs, d, data),
              const SizedBox(height: 16),
              _footer(cs, data),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, DuaKind? kind) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == kind,
      onSelected: (_) => setState(() => _filter = kind),
    );
  }

  Widget _tile(BuildContext context, ColorScheme cs, Dua d, DuaData data) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          d.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${d.kind == DuaKind.ayet ? 'Ayet' : 'Hadis'}  ·  ${d.kaynak}',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
        trailing: Icon(Icons.chevron_right,
            color: cs.onSurface.withValues(alpha: 0.4)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DuaDetailScreen(dua: d, data: data),
          ),
        ),
      ),
    );
  }

  Widget _footer(ColorScheme cs, DuaData data) {
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final yayin = data.sources['yayin'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in data.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(n,
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.4)),
            ),
          if (yayin != null)
            InkWell(
              onTap: () => launchUrl(Uri.parse(yayin.url),
                  mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Diyanet yayınını aç',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
