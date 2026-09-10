import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Veri modeli ───────────────────────────────────────────────────────────────

class _Log {
  final DateTime at;
  final int delta; // pozitif = eklendi, negatif = kılındı/sıfırlandı

  const _Log({required this.at, required this.delta});

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'delta': delta,
      };

  factory _Log.fromJson(Map<String, dynamic> j) => _Log(
        at: DateTime.parse(j['at'] as String),
        delta: j['delta'] as int,
      );
}

class _KazaItem {
  final String key;
  final String name;
  final IconData icon;
  List<_Log> logs;

  _KazaItem({
    required this.key,
    required this.name,
    required this.icon,
    List<_Log>? logs,
  }) : logs = logs ?? [];

  int get remaining =>
      logs.fold<int>(0, (s, l) => s + l.delta).clamp(0, 9999999);
}

// ── Ekran ─────────────────────────────────────────────────────────────────────

class KazaScreen extends StatefulWidget {
  const KazaScreen({super.key});

  @override
  State<KazaScreen> createState() => _KazaScreenState();
}

class _KazaScreenState extends State<KazaScreen> {
  static const _prefsKey = 'kaza_logs_v2';
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_KazaItem> _items = [
    _KazaItem(key: 'sabah',  name: 'Sabah',  icon: Icons.nights_stay),
    _KazaItem(key: 'ogle',   name: 'Öğle',   icon: Icons.wb_sunny_outlined),
    _KazaItem(key: 'ikindi', name: 'İkindi', icon: Icons.cloud_queue),
    _KazaItem(key: 'aksam',  name: 'Akşam',  icon: Icons.wb_twilight),
    _KazaItem(key: 'yatsi',  name: 'Yatsı',  icon: Icons.dark_mode),
    _KazaItem(key: 'vitr',   name: 'Vitr',   icon: Icons.brightness_3),
    _KazaItem(key: 'oruc',   name: 'Oruç',   icon: Icons.no_meals),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      for (final item in _items) {
        final list = map[item.key] as List<dynamic>?;
        if (list != null) {
          item.logs = list
              .map((e) => _Log.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      for (final i in _items)
        i.key: i.logs.map((l) => l.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  void _add(_KazaItem item) {
    setState(() => item.logs.add(_Log(at: DateTime.now(), delta: 1)));
    _save();
  }

  void _subtract(_KazaItem item) {
    if (item.remaining == 0) return;
    setState(() => item.logs.add(_Log(at: DateTime.now(), delta: -1)));
    _save();
  }

  void _addBulk(Map<String, int> additions) {
    setState(() {
      for (final item in _items) {
        final days = additions[item.key];
        if (days != null && days > 0) {
          item.logs.add(_Log(at: DateTime.now(), delta: days));
        }
      }
    });
    _save();
  }

  Future<void> _confirmReset(_KazaItem item) async {
    final remaining = item.remaining;
    if (remaining == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sıfırla'),
        content: Text(
          '${item.name} için ${item.remaining} kaza kaydını sıfırlamak '
          'istediğinize emin misiniz?\n\nGeçmiş kayıtlar silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sıfırla',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => item.logs.add(
          _Log(at: DateTime.now(), delta: -remaining),
        ));
    _save();
  }

  void _showHistory(_KazaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HistorySheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Kaza Takibi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Hesapla',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      drawer: _HesaplaDrawer(
        items: _items,
        onTransfer: (additions) {
          Navigator.pop(context); // drawer kapat
          _addBulk(additions);
          final days  = additions.values.first;
          final total = additions.values.fold(0, (a, b) => a + b);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$days günlük aktarım, $total vakit olarak eklendi.',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _items.length + 1,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == _items.length) return const _InfoSection();
          return _KazaRow(
            item: _items[i],
            onAdd:       () => _add(_items[i]),
            onSubtract:  () => _subtract(_items[i]),
            onTap:       () => _showHistory(_items[i]),
            onLongPress: () => _confirmReset(_items[i]),
          );
        },
      ),
    );
  }
}

// ── Hesapla Drawer ────────────────────────────────────────────────────────────

class _HesaplaDrawer extends StatefulWidget {
  final List<_KazaItem> items;
  final void Function(Map<String, int> additions) onTransfer;

  const _HesaplaDrawer({required this.items, required this.onTransfer});

  @override
  State<_HesaplaDrawer> createState() => _HesaplaDrawerState();
}

class _HesaplaDrawerState extends State<_HesaplaDrawer> {
  static const _turkishMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  final _fromYearCtrl = TextEditingController();
  final _toYearCtrl   = TextEditingController();
  int _fromMonth = 1;
  int _toMonth   = 1;

  late final Map<String, bool> _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromYearCtrl.text = now.year.toString();
    _toYearCtrl.text   = now.year.toString();
    _fromMonth = now.month;
    _toMonth   = now.month;
    _selected  = {for (final i in widget.items) i.key: true};
  }

  @override
  void dispose() {
    _fromYearCtrl.dispose();
    _toYearCtrl.dispose();
    super.dispose();
  }

  int? get _days {
    final fy = int.tryParse(_fromYearCtrl.text.trim());
    final ty = int.tryParse(_toYearCtrl.text.trim());
    if (fy == null || ty == null) return null;
    if (fy < 1900 || ty < 1900) return null;
    if (fy > ty || (fy == ty && _fromMonth > _toMonth)) return null;
    final from = DateTime(fy, _fromMonth, 1);
    final to   = DateTime(ty, _toMonth + 1, 0);
    return to.difference(from).inDays + 1;
  }

  Map<String, int> get _additions {
    final d = _days;
    if (d == null) return {};
    return {
      for (final i in widget.items)
        if (_selected[i.key] == true) i.key: d,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final days = _days;
    final canTransfer = days != null && _additions.isNotEmpty;

    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Hesapla',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Namaz kılmadığınız dönemi girin.\nToplam gün sayısı hesaplanacak.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 24),

              // Başlangıç
              _sectionLabel('Başlangıç', muted),
              const SizedBox(height: 8),
              _DateRow(
                yearCtrl:       _fromYearCtrl,
                month:          _fromMonth,
                onMonthChanged: (m) => setState(() => _fromMonth = m),
                months:         _turkishMonths,
              ),
              const SizedBox(height: 16),

              // Bitiş
              _sectionLabel('Bitiş', muted),
              const SizedBox(height: 8),
              _DateRow(
                yearCtrl:       _toYearCtrl,
                month:          _toMonth,
                onMonthChanged: (m) => setState(() => _toMonth = m),
                months:         _turkishMonths,
              ),
              const SizedBox(height: 20),

              // Sonuç
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: days != null
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Toplam  ${days ?? 0}  gün',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Namaz seçimi
              _sectionLabel('Eklenecek namazlar', muted),
              const SizedBox(height: 8),
              ...widget.items.map((item) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: cs.primary,
                    secondary: Icon(item.icon, color: cs.primary, size: 20),
                    title: Text(
                      item.name,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                    value: _selected[item.key] ?? true,
                    onChanged: (v) =>
                        setState(() => _selected[item.key] = v ?? false),
                  )),
              const SizedBox(height: 20),

              // Aktar butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.primary),
                  onPressed: canTransfer ? () => widget.onTransfer(_additions) : null,
                  child: const Text('Aktar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      );
}

class _DateRow extends StatelessWidget {
  final TextEditingController yearCtrl;
  final int month;
  final void Function(int) onMonthChanged;
  final List<String> months;

  const _DateRow({
    required this.yearCtrl,
    required this.month,
    required this.onMonthChanged,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Yıl
        Expanded(
          flex: 2,
          child: TextField(
            controller: yearCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Yıl',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Ay
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: month,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Ay',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(months[i], style: const TextStyle(fontSize: 13)),
              ),
            ),
            onChanged: (v) => onMonthChanged(v ?? month),
          ),
        ),
      ],
    );
  }
}

// ── Satır ─────────────────────────────────────────────────────────────────────

class _KazaRow extends StatelessWidget {
  final _KazaItem item;
  final VoidCallback onAdd;
  final VoidCallback onSubtract;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _KazaRow({
    required this.item,
    required this.onAdd,
    required this.onSubtract,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = item.remaining;
    final hasDebt = remaining > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Borç rozeti
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasDebt ? cs.primary : cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$remaining',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasDebt
                        ? cs.onPrimary
                        : cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _IconBtn(
                icon: Icons.remove,
                enabled: hasDebt,
                onTap: onSubtract,
              ),
              const SizedBox(width: 6),
              _IconBtn(
                icon: Icons.add,
                enabled: true,
                onTap: onAdd,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  const _IconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? cs.primary : cs.outline.withValues(alpha: 0.4))
              : Colors.transparent,
          border: filled
              ? null
              : Border.all(
                  color: enabled ? cs.primary : cs.outline,
                  width: 1.5,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled
              ? cs.onPrimary
              : (enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

// ── Geçmiş bottom sheet ───────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final _KazaItem item;

  const _HistorySheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logs = item.logs.reversed.toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(item.icon, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${item.name} — Geçmiş',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.remaining} kalan',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'Henüz kayıt yok.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _LogTile(log: logs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final _Log log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdd   = log.delta > 0;
    final count   = log.delta.abs();
    final isReset = !isAdd && count > 1;
    final color   = isAdd ? const Color(0xFFC0392B) : const Color(0xFF27AE60);
    final icon    = isAdd
        ? Icons.add_circle_outline
        : (isReset ? Icons.restart_alt : Icons.check_circle_outline);
    final label   = isAdd
        ? '$count kaza eklendi'
        : (isReset ? 'Sıfırlandı ($count)' : 'Kaza kılındı');

    final dt = log.at;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$dateStr  $timeStr',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kullanım kılavuzu ─────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                'Kullanım',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoLine(
            '+ ile tek tek kaza ekleyebilir, – ile kıldığınızı işaretleyebilirsiniz.',
            muted,
          ),
          _InfoLine(
            'Bir vakite uzun süre basılı tutarsanız o vakit için sıfırlama yapabilirsiniz.',
            muted,
          ),
          _InfoLine(
            'Sağ üst köşedeki menüden belirli bir dönemi hesaplayıp tüm namazlara tek seferde aktarabilirsiniz.',
            muted,
          ),
          _InfoLine(
            'Bir vakite kısa dokunursanız geçmiş kayıtları tarih ve saat ile görebilirsiniz.',
            muted,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoLine(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: color, fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
