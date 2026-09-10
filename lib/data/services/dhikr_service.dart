import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dhikr.dart';

class DhikrService {
  static const _key = 'dhikr_list';
  static const _tesbihatId = 'namaz_tesbihat';

  static Dhikr _buildTesbih({int current = 0}) => Dhikr(
        id: _tesbihatId,
        name: 'Namaz Tesbihati',
        target: 99,
        current: current,
        phases: ['Sübhanallah', 'Elhamdülillah', 'Allahu Ekber'],
      );

  Future<List<Dhikr>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<Dhikr> stored =
        raw != null && raw.isNotEmpty ? Dhikr.listFromJson(raw) : [];

    // Tesbih kaydı zaten varsa olduğu gibi kullan (ilerleme korunur)
    if (stored.any((d) => d.id == _tesbihatId)) return stored;

    // İlk açılış: başa ekle ve kaydet
    final list = [_buildTesbih(), ...stored];
    await saveAll(list);
    return list;
  }

  Future<void> saveAll(List<Dhikr> dhikrs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, Dhikr.listToJson(dhikrs));
  }
}
