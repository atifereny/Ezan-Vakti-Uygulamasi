import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/models/notification_prefs.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final NotificationPrefs prefs;
  final Future<void> Function(NotificationPrefs) onChanged;

  const NotificationSettingsScreen({
    super.key,
    required this.prefs,
    required this.onChanged,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late NotificationPrefs _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs;
  }

  void _update(NotificationPrefs newPrefs) {
    setState(() => _prefs = newPrefs);
    widget.onChanged(newPrefs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'Namaz Bildirimleri'),
            const SizedBox(height: 8),
            ...NotificationPrefs.prayers.map((prayer) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrayerNotifTile(
                  prayer:       prayer,
                  enabled:      _prefs.isEnabled(prayer),
                  earlyOn:      _prefs.isEarlyEnabled(prayer),
                  earlyMinutes: _prefs.earlyMinutesOf(prayer),
                  onToggle: (v) =>
                      _update(_prefs.copyWithEnabled(prayer, v)),
                  onEarlyToggle: (v) =>
                      _update(_prefs.copyWithEarlyEnabled(prayer, v)),
                  onMinutesChanged: (v) =>
                      _update(_prefs.copyWithEarlyMinutes(prayer, v)),
                ),
              );
            }),
            const SizedBox(height: 16),
            _SectionHeader(label: 'Kerahat Vakitleri'),
            const SizedBox(height: 8),
            _KerahatSection(
              prefs: _prefs,
              onChanged: _update,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: kMuted,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Prayer notification tile (stateful for wheel controller) ──────────────────

class _PrayerNotifTile extends StatefulWidget {
  final String prayer;
  final bool   enabled;
  final bool   earlyOn;
  final int    earlyMinutes;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onEarlyToggle;
  final ValueChanged<int>  onMinutesChanged;

  const _PrayerNotifTile({
    required this.prayer,
    required this.enabled,
    required this.earlyOn,
    required this.earlyMinutes,
    required this.onToggle,
    required this.onEarlyToggle,
    required this.onMinutesChanged,
  });

  @override
  State<_PrayerNotifTile> createState() => _PrayerNotifTileState();
}

class _PrayerNotifTileState extends State<_PrayerNotifTile> {
  static const _step  = 5;
  static const _min   = 5;
  static const _max   = 60;
  static const _count = (_max - _min) ~/ _step + 1; // 12

  late final FixedExtentScrollController _wheelCtrl;

  int _minutesToIndex(int m) => (m.clamp(_min, _max) - _min) ~/ _step;
  int _indexToMinutes(int i) => _min + i * _step;

  @override
  void initState() {
    super.initState();
    _wheelCtrl = FixedExtentScrollController(
      initialItem: _minutesToIndex(widget.earlyMinutes),
    );
  }

  @override
  void didUpdateWidget(_PrayerNotifTile old) {
    super.didUpdateWidget(old);
    if (old.earlyMinutes != widget.earlyMinutes) {
      final idx = _minutesToIndex(widget.earlyMinutes);
      if (_wheelCtrl.hasClients &&
          _wheelCtrl.selectedItem != idx) {
        _wheelCtrl.jumpToItem(idx);
      }
    }
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final earlyOn = widget.earlyOn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            // ── Master toggle ───────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 18, color: kMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.prayer,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kOnSurface,
                        ),
                      ),
                      const Text(
                        'Vakit girdiğinde bildirim',
                        style: TextStyle(color: kMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(value: enabled, onChanged: widget.onToggle),
              ],
            ),

            // ── Erken bildirim satırı (drum picker + switch) ────────────────
            if (enabled) ...[
              const Divider(height: 1, color: kOutline),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm_outlined, size: 18, color: kMuted),
                  const SizedBox(width: 10),

                  // Drum picker
                  SizedBox(
                    height: 84,
                    width: 72,
                    child: ListWheelScrollView.useDelegate(
                      controller: _wheelCtrl,
                      physics: const FixedExtentScrollPhysics(),
                      itemExtent: 28,
                      diameterRatio: 1.4,
                      onSelectedItemChanged: (i) =>
                          widget.onMinutesChanged(_indexToMinutes(i)),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _count,
                        builder: (context, i) {
                          final mins = _indexToMinutes(i);
                          final selected =
                              _minutesToIndex(widget.earlyMinutes) == i;
                          return Center(
                            child: Text(
                              '$mins dk',
                              style: TextStyle(
                                fontSize: selected ? 14 : 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected ? kPrimary : kMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'önce hatırlatma',
                      style: TextStyle(fontSize: 12, color: kOnSurface),
                    ),
                  ),
                  Switch(value: earlyOn, onChanged: widget.onEarlyToggle),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Kerahat section ───────────────────────────────────────────────────────────

class _KerahatSection extends StatelessWidget {
  final NotificationPrefs prefs;
  final void Function(NotificationPrefs) onChanged;

  const _KerahatSection({required this.prefs, required this.onChanged});

  static const _kerahat = [
    ('sunrise', 'Güneş Doğuşu', 'Doğuştan 45 dk sonrasına kadar'),
    ('istiwa',  'İstiva Vakti',  'Öğle namazından 5 dk önce'),
    ('sunset',  'Güneş Batışı',  'Batıştan 45 dk öncesinde'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < _kerahat.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, color: kOutline),
            _KerahatTile(
              label:     _kerahat[i].$2,
              sublabel:  _kerahat[i].$3,
              enabled:   prefs.isKerahatEnabled(_kerahat[i].$1),
              onChanged: (v) =>
                  onChanged(prefs.copyWithKerahat(_kerahat[i].$1, v)),
            ),
          ],
        ],
      ),
    );
  }
}

class _KerahatTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool   enabled;
  final ValueChanged<bool> onChanged;

  const _KerahatTile({
    required this.label,
    required this.sublabel,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.block_outlined, size: 18, color: kMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kOnSurface,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
