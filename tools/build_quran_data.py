"""Kur'an okuma ekranının veri dosyasını (assets/data/kuran.json) üretir.

Kullanım (proje kökünden, sadece veri değiştirmek/yenilemek istersen):
  python tools/build_quran_data.py

Kaynaklar (alquran.cloud API, Tanzil verisi):
  - Arapça: quran-uthmani (Medine mushafı, 604 sayfa)
  - Meal:   tr.diyanet (Diyanet İşleri Başkanlığı meali)

Çıktı biçimi:
  surahs: [[no, arapça ad, türkçe ad, "M"|"D", ayet sayısı, başlangıç sayfası], ...]
  juz:    [her cüzün başlangıç sayfası x30]
  pages:  [ [ [sure, ayet, arapça, meal, grup], ... ] x604 ]
          grup: 1 = meali kendine ait, n>1 = meali bu ayetle başlayan n ayetlik grup,
                negatif = meali önceki ayetle birlikte verilmiş (meal boş); değer, grubun
                          ilk ayetinin numarasının eksilisi.
          Tanzil'deki Diyanet meali bazı ayet gruplarını birleştirip aynı metni her
          ayete kopyalıyor; ardışık aynı metinler tek grup olarak yazılır.
"""
import datetime
import json
import os
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")

API = "https://api.alquran.cloud/v1"
DST = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "kuran.json")

TR_NAMES = [
    "Fâtiha", "Bakara", "Âl-i İmrân", "Nisâ", "Mâide", "En’âm", "A’râf", "Enfâl", "Tevbe", "Yûnus",
    "Hûd", "Yûsuf", "Ra’d", "İbrâhîm", "Hicr", "Nahl", "İsrâ", "Kehf", "Meryem", "Tâhâ",
    "Enbiyâ", "Hac", "Mü’minûn", "Nûr", "Furkân", "Şuarâ", "Neml", "Kasas", "Ankebût", "Rûm",
    "Lokmân", "Secde", "Ahzâb", "Sebe’", "Fâtır", "Yâsîn", "Sâffât", "Sâd", "Zümer", "Mü’min",
    "Fussilet", "Şûrâ", "Zuhruf", "Duhân", "Câsiye", "Ahkâf", "Muhammed", "Fetih", "Hucurât", "Kâf",
    "Zâriyât", "Tûr", "Necm", "Kamer", "Rahmân", "Vâkıa", "Hadîd", "Mücâdele", "Haşr", "Mümtehine",
    "Saf", "Cuma", "Münâfikûn", "Teğâbün", "Talâk", "Tahrîm", "Mülk", "Kalem", "Hâkka", "Meâric",
    "Nûh", "Cin", "Müzzemmil", "Müddessir", "Kıyâme", "İnsan", "Mürselât", "Nebe’", "Nâziât", "Abese",
    "Tekvîr", "İnfitâr", "Mutaffifîn", "İnşikâk", "Bürûc", "Târık", "A’lâ", "Gâşiye", "Fecr", "Beled",
    "Şems", "Leyl", "Duhâ", "İnşirâh", "Tîn", "Alak", "Kadir", "Beyyine", "Zilzâl", "Âdiyât",
    "Kâria", "Tekâsür", "Asr", "Hümeze", "Fîl", "Kureyş", "Mâûn", "Kevser", "Kâfirûn", "Nasr",
    "Tebbet", "İhlâs", "Felak", "Nâs",
]


def skeleton(s):
    """Harekesiz harf iskeleti (besmele tespiti için; harekelerin sırası sureden sureye değişebiliyor)"""
    out = []
    for ch in s:
        if "ً" <= ch <= "ٟ" or ch in "ٰـ ":
            continue
        out.append({"ٱ": "ا", "ى": "ي"}.get(ch, ch))
    return "".join(out)


def get(edition):
    with urllib.request.urlopen(f"{API}/quran/{edition}", timeout=120) as r:
        return json.load(r)["data"]["surahs"]


def main():
    assert len(TR_NAMES) == 114
    ar, tr = get("quran-uthmani"), get("tr.diyanet")
    assert len(ar) == len(tr) == 114
    surahs, pages = [], [[] for _ in range(604)]
    juz_start = {}
    for sa, st in zip(ar, tr):
        no = sa["number"]
        first_page = sa["ayahs"][0]["page"]
        surahs.append([no, sa["name"], TR_NAMES[no - 1],
                       "M" if sa["revelationType"] == "Meccan" else "D",
                       len(sa["ayahs"]), first_page])
        prev_meal, group_start = None, None
        for a, t in zip(sa["ayahs"], st["ayahs"]):
            text = a["text"].replace("﻿", "").strip()
            if a["numberInSurah"] == 1 and no not in (1, 9):
                words = text.split(" ")
                assert skeleton(" ".join(words[:4])) == "بسماللهالرحمنالرحيم", (no, text[:40])
                text = " ".join(words[4:]).strip()
            meal = t["text"].strip()
            if meal == prev_meal and group_start is not None:
                group_start[4] += 1
                rec = [no, a["numberInSurah"], text, "", -group_start[1]]
            else:
                rec = [no, a["numberInSurah"], text, meal, 1]
                group_start, prev_meal = rec, meal
            pages[a["page"] - 1].append(rec)
            juz_start.setdefault(a["juz"], a["page"])

    assert all(pages), "boş sayfa var"
    assert sum(len(p) for p in pages) == 6236
    juz = [juz_start[j] for j in range(1, 31)]

    with open(DST, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "updated": datetime.date.today().isoformat(),
                   "surahs": surahs, "juz": juz, "pages": pages},
                  f, ensure_ascii=False, separators=(",", ":"))
    groups = sum(1 for p in pages for r in p if r[4] > 1)
    print(f"{len(pages)} sayfa, 6236 ayet, {groups} ortak meal grubu -> {os.path.normpath(DST)} "
          f"({os.path.getsize(DST) / 1e6:.2f} MB)")


if __name__ == "__main__":
    main()
