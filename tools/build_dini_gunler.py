"""Diyanet'in resmî dini gün/gece tablosunu uygulamaya gömülen JSON'a çevirir.

Her release öncesi proje kökünden çalıştır:
  python tools/build_dini_gunler.py

Kaynak: Diyanet İşleri Başkanlığı dini günler tablosu (birkaç yıl önceden yayınlanır)
  https://mobil.diyanet.gov.tr/mobile/dinigunler/dinigunler.html

Doğrulama: her satırdaki gün adı (Pazartesi, Salı...) tarihten hesaplanan gün adıyla
karşılaştırılır; uyuşmazlık varsa dosyaya YAZILMAZ.

Çıktı: assets/data/dini_gunler.json
"""
import datetime as dt
import html
import json
import os
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

SRC = "https://mobil.diyanet.gov.tr/mobile/dinigunler/dinigunler.html"
DST = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "dini_gunler.json")

MONTHS = {
    "Ocak": 1, "Şubat": 2, "Mart": 3, "Nisan": 4, "Mayıs": 5, "Haziran": 6,
    "Temmuz": 7, "Ağustos": 8, "Eylül": 9, "Ekim": 10, "Kasım": 11, "Aralık": 12,
}
# gün adı ön eki (ilk 3 harf) → weekday (Pazartesi=0)
WEEKDAYS = {"paz": None, "pzt": 0, "sal": 1, "çar": 2, "per": 3, "cum": 4, "cmt": 5}

RENAME = {
    "Ramazan": "Ramazan Başlangıcı",
    "Üç Aylar": "Üç Ayların Başlangıcı",
}


def weekday_of(token):
    """'Pazartesi'/'Pzt' → 0 ... 'Pazar' → 6 (Diyanet kısaltmaları: Çar/Çrş, Per/Perş)"""
    t = token.strip().lower()
    if t.startswith("pazartesi") or t.startswith("pzt"):
        return 0
    if t.startswith("pazar"):
        return 6
    if t.startswith("cumartesi") or t.startswith("cmt"):
        return 5
    for prefix, wd in (("sal", 1), ("çar", 2), ("çrş", 2), ("per", 3), ("cum", 4)):
        if t.startswith(prefix):
            return wd
    raise ValueError(f"Bilinmeyen gün adı: {token}")


def kind_of(name):
    if "Kandili" in name or name == "Kadir Gecesi":
        return "kandil"
    if "Arefesi" in name:
        return "arefe"
    if name.endswith("Bayramı"):
        return "bayram"
    if name in ("Ramazan Başlangıcı", "Hicri Yılbaşı", "Aşure Günü", "Üç Ayların Başlangıcı"):
        return "ozel"
    return "ay"


def clean(cell):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", cell))).strip()


def main():
    req = urllib.request.Request(SRC, headers={"User-Agent": "Mozilla/5.0"})
    page = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")

    out, errors, skipped = [], [], []
    for m in re.finditer(r'<table[^>]*id="icerik_(\d{4})"', page):
        year = int(m.group(1))
        end = page.find("</table>", m.end())
        for row in re.findall(r"<tr.*?</tr>", page[m.end():end], flags=re.S):
            cells = [clean(c) for c in re.findall(r"<t[dh].*?</t[dh]>", row, flags=re.S)]
            if len(cells) < 3 or not cells[0]:
                continue
            day_cell, name_cell, month_cell = cells[0], cells[1], cells[2]

            if "/" in day_cell:
                # "22/23 Salı/Çar": Diyanet kesin gün vermemiş (hesaplı tahmin); yazma
                skipped.append(f"{month_cell}: {name_cell} ({day_cell})")
                continue

            dm = re.match(r"^(\d+)(?:(?:-|\.\.)(\d+))?\s+(\S+?)(?:\.\.(\S+))?$", day_cell)
            nm = re.match(r"^(\D+?)\s+(\d.*)$", name_cell)
            mm = re.match(r"^([^\s\d-]+)(?:-\S+)?\s+(\d{4})$", month_cell)
            if not (dm and nm and mm):
                errors.append(f"Ayrıştırılamadı: {cells}")
                continue

            d1 = int(dm.group(1))
            d2 = int(dm.group(2)) if dm.group(2) else None
            month = MONTHS[mm.group(1)]
            y = int(mm.group(2))
            name = RENAME.get(nm.group(1).strip(), nm.group(1).strip())
            start = dt.date(y, month, d1)
            end_d = None
            if d2:
                # bitiş günü başlangıçtan küçükse bayram ertesi aya sarkıyor (28..01)
                ey, em = (y, month) if d2 >= d1 else (y + (month == 12), month % 12 + 1)
                end_d = dt.date(ey, em, d2)

            if start.weekday() != weekday_of(dm.group(3)):
                errors.append(f"Gün adı uyuşmuyor: {cells} (hesap: {start.strftime('%A')})")
            if end_d and dm.group(4) and end_d.weekday() != weekday_of(dm.group(4)):
                errors.append(f"Bitiş günü uyuşmuyor: {cells}")

            out.append({
                "date": start.isoformat(),
                "endDate": end_d.isoformat() if end_d else None,
                "name": name,
                "hijri": nm.group(2).strip(),
                "kind": kind_of(name),
            })

    if errors:
        sys.exit("Doğrulama hatası, dosya yazılmadı:\n  " + "\n  ".join(errors))
    if not out:
        sys.exit("Hiç satır bulunamadı; sayfa yapısı değişmiş olabilir.")

    out.sort(key=lambda d: (d["date"], d["name"]))
    keep_from = dt.date.today().year - 1
    out = [d for d in out if int(d["date"][:4]) >= keep_from]

    if skipped:
        print("Belirsiz tarih nedeniyle atlananlar (Diyanet henüz kesinleştirmemiş):")
        for s in skipped:
            print("  -", s)

    last_year = max(int(d["date"][:4]) for d in out)
    with open(DST, "w", encoding="utf-8") as f:
        json.dump(
            {
                "source": SRC,
                "updated": dt.date.today().isoformat(),
                "days": out,
            },
            f, ensure_ascii=False, indent=0, separators=(",", ":"),
        )
    print(f"{len(out)} kayıt yazıldı ({keep_from}-{last_year}) → {os.path.normpath(DST)}")
    if last_year <= dt.date.today().year:
        print("UYARI: Gelecek yıl için veri yok; Diyanet henüz yayınlamamış olabilir.")


if __name__ == "__main__":
    main()
