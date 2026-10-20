enum DuaKind { ayet, hadis }

class Dua {
  final String id;
  final String title;
  final DuaKind kind;
  final String arabic;
  final String okunus;
  final String meal;
  final String? intro; // meal öncesi açıklama (örn. "Hz. Peygamber (sas) ... derdi:")
  final String kaynak; // "Bakara sûresi, 2/201" / "Müslim, Zikir, 71"
  final String mealKaynak; // 'kuran' | 'yayin' → DuaData.kaynaklar anahtarı

  const Dua({
    required this.id,
    required this.title,
    required this.kind,
    required this.arabic,
    required this.okunus,
    required this.meal,
    required this.intro,
    required this.kaynak,
    required this.mealKaynak,
  });

  factory Dua.fromJson(Map<String, dynamic> j) => Dua(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: j['kind'] == 'ayet' ? DuaKind.ayet : DuaKind.hadis,
        arabic: j['arabic'] as String,
        okunus: j['okunus'] as String,
        meal: j['meal'] as String,
        intro: j['intro'] as String?,
        kaynak: j['kaynak'] as String,
        mealKaynak: j['mealKaynak'] as String,
      );
}

class DuaSource {
  final String name;
  final String url;
  const DuaSource(this.name, this.url);
}

class DuaData {
  final List<Dua> duas;
  final Map<String, DuaSource> sources;
  final List<String> notes;
  const DuaData(this.duas, this.sources, this.notes);
}
