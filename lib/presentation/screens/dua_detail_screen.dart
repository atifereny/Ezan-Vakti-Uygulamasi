import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../domain/models/dua.dart';

class DuaDetailScreen extends StatelessWidget {
  final Dua dua;
  final DuaData data;

  const DuaDetailScreen({super.key, required this.dua, required this.data});

  String get _copyText => [
        dua.title,
        dua.arabic,
        dua.okunus,
        if (dua.intro != null) dua.intro!,
        dua.meal,
        'Kaynak: ${dua.kaynak}',
      ].join('\n\n');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final mealSrc = data.sources[dua.mealKaynak];

    return Scaffold(
      appBar: AppBar(
        title: Text(dua.kind == DuaKind.ayet ? 'Ayet Duası' : 'Hadis Duası'),
        actions: [
          IconButton(
            tooltip: 'Kopyala',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copyText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dua kopyalandı'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            dua.title,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          // Arapça
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    dua.arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      height: 2.0,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _section(cs, 'Okunuşu', dua.okunus, italic: true),
          if (dua.intro != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(dua.intro!,
                  style: TextStyle(color: muted, fontSize: 13, height: 1.4)),
            ),
          _section(cs, 'Meali', dua.meal),
          const SizedBox(height: 20),
          Divider(color: cs.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text('Kaynak: ${dua.kaynak}',
              style: TextStyle(color: muted, fontSize: 12.5)),
          if (mealSrc != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => launchUrl(Uri.parse(mealSrc.url),
                  mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Meal: ${mealSrc.name}',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(ColorScheme cs, String label, String text,
      {bool italic = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            text,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15.5,
              height: 1.55,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
