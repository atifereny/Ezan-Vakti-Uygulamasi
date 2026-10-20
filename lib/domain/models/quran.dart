class QuranAyah {
  final int surah;
  final int number;
  final String arabic;

  /// Meal. Boşsa ayet, önceki ayetle ortak bir mealin devamıdır (bkz. [group]).
  final String meal;

  /// 1: meali kendine ait, n>1: meali bu ayetle başlayan n ayetlik grup,
  /// negatif: meali önceki ayetle birlikte verilmiş (değer, grubun ilk ayetinin eksilisi)
  final int group;

  const QuranAyah(this.surah, this.number, this.arabic, this.meal, this.group);

  bool get isContinuation => group < 0;
  int get groupStart => isContinuation ? -group : number;
  int? get groupEnd => group > 1 ? number + group - 1 : null;
}

class QuranSurah {
  final int no;
  final String arabicName;
  final String name;
  final bool meccan;
  final int ayahCount;
  final int startPage;

  const QuranSurah(
    this.no,
    this.arabicName,
    this.name,
    this.meccan,
    this.ayahCount,
    this.startPage,
  );

  /// Besmele ile başlar mı (Fâtiha'da besmele 1. ayet, Tevbe'de yok)
  bool get hasBismillahHeader => no != 1 && no != 9;
}

class QuranData {
  final List<QuranSurah> surahs;
  final List<int> juzStartPages; // 30 eleman
  final List<List<QuranAyah>> pages; // 604 sayfa

  QuranData(this.surahs, this.juzStartPages, this.pages);

  int get pageCount => pages.length;

  QuranSurah surahOf(int no) => surahs[no - 1];

  /// Sayfadaki ilk ayetin suresi
  QuranSurah surahOnPage(int page) => surahOf(pages[page - 1].first.surah);

  /// 1..30
  int juzOnPage(int page) {
    var juz = 1;
    for (var i = 0; i < juzStartPages.length; i++) {
      if (juzStartPages[i] <= page) juz = i + 1;
    }
    return juz;
  }

  late final Map<int, QuranAyah> _groupStarts = {
    for (final page in pages)
      for (final x in page)
        if (!x.isContinuation) x.surah * 1000 + x.number: x,
  };

  /// Ayetin grubunun ilk ayeti (kendisi grup başı ya da tek ise kendisi)
  QuranAyah groupStartOf(QuranAyah a) =>
      a.isContinuation ? (_groupStarts[a.surah * 1000 + a.groupStart] ?? a) : a;

  /// Ayetin mealı (ortak mealin ait olduğu grup başından alınır)
  String mealOf(QuranAyah a) => groupStartOf(a).meal;
}
