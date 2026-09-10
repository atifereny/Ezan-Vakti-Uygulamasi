class NotificationPrefs {
  static const prayers = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
  static const kerahatKeys = ['sunrise', 'istiwa', 'sunset'];

  final Map<String, bool> _enabled;
  final Map<String, bool> _earlyEnabled;
  final Map<String, int>  _earlyMinutes;    // 5-60, 5'er adım
  final Map<String, bool> _kerahatEnabled;

  NotificationPrefs({
    required Map<String, bool> enabled,
    required Map<String, bool> earlyEnabled,
    required Map<String, int>  earlyMinutes,
    required Map<String, bool> kerahatEnabled,
  })  : _enabled        = enabled,
        _earlyEnabled   = earlyEnabled,
        _earlyMinutes   = earlyMinutes,
        _kerahatEnabled = kerahatEnabled;

  factory NotificationPrefs.defaults() => NotificationPrefs(
        enabled:        {for (final p in prayers)     p: true},
        earlyEnabled:   {for (final p in prayers)     p: true},
        earlyMinutes:   {for (final p in prayers)     p: 15},
        kerahatEnabled: {for (final k in kerahatKeys) k: true},
      );

  bool isEnabled(String prayer)         => _enabled[prayer]        ?? true;
  bool isEarlyEnabled(String prayer)    => _earlyEnabled[prayer]   ?? true;
  int  earlyMinutesOf(String prayer)    => _earlyMinutes[prayer]   ?? 15;
  bool isKerahatEnabled(String key)     => _kerahatEnabled[key]    ?? true;

  NotificationPrefs copyWithEnabled(String prayer, bool v) => NotificationPrefs(
        enabled:        {..._enabled, prayer: v},
        earlyEnabled:   Map.of(_earlyEnabled),
        earlyMinutes:   Map.of(_earlyMinutes),
        kerahatEnabled: Map.of(_kerahatEnabled),
      );

  NotificationPrefs copyWithEarlyEnabled(String prayer, bool v) => NotificationPrefs(
        enabled:        Map.of(_enabled),
        earlyEnabled:   {..._earlyEnabled, prayer: v},
        earlyMinutes:   Map.of(_earlyMinutes),
        kerahatEnabled: Map.of(_kerahatEnabled),
      );

  NotificationPrefs copyWithEarlyMinutes(String prayer, int v) => NotificationPrefs(
        enabled:        Map.of(_enabled),
        earlyEnabled:   Map.of(_earlyEnabled),
        earlyMinutes:   {..._earlyMinutes, prayer: v},
        kerahatEnabled: Map.of(_kerahatEnabled),
      );

  NotificationPrefs copyWithKerahat(String key, bool v) => NotificationPrefs(
        enabled:        Map.of(_enabled),
        earlyEnabled:   Map.of(_earlyEnabled),
        earlyMinutes:   Map.of(_earlyMinutes),
        kerahatEnabled: {..._kerahatEnabled, key: v},
      );
}
