import 'dart:convert';

class Dhikr {
  final String id;
  final String name;
  final int target;      // toplam hedef (faz * faz boyutu)
  int current;           // toplam sayılan
  final List<String>? phases; // çok fazlı zikir isimleri

  Dhikr({
    required this.id,
    required this.name,
    required this.target,
    this.current = 0,
    this.phases,
  });

  // ── Faz yardımcıları ──────────────────────────────────────────────────────

  bool get isPhased => phases != null && phases!.isNotEmpty;

  int get phaseSize => isPhased ? target ~/ phases!.length : target;

  int get currentPhaseIndex => isPhased
      ? (current ~/ phaseSize).clamp(0, phases!.length - 1)
      : 0;

  String get displayName =>
      isPhased ? phases![currentPhaseIndex] : name;

  /// Mevcut faz içindeki sayı (0'dan başlar)
  int get phaseCount =>
      isPhased ? current - currentPhaseIndex * phaseSize : current;

  bool get isCompleted => current >= target;

  double get progress => isPhased
      ? (phaseSize > 0 ? (phaseCount / phaseSize).clamp(0.0, 1.0) : 0.0)
      : (target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0);

  // ── JSON ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'current': current,
        if (phases != null) 'phases': phases,
      };

  factory Dhikr.fromJson(Map<String, dynamic> j) => Dhikr(
        id: j['id'] as String,
        name: j['name'] as String,
        target: j['target'] as int,
        current: (j['current'] as int?) ?? 0,
        phases: (j['phases'] as List?)?.cast<String>(),
      );

  static List<Dhikr> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Dhikr.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Dhikr> dhikrs) =>
      jsonEncode(dhikrs.map((d) => d.toJson()).toList());
}
