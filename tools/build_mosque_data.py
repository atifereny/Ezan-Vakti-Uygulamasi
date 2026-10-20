"""Türkiye cami listesini OSM'den indirip uygulamaya gömülen dosyayı yeniler.

Her release öncesi proje kökünden çalıştır:
  python tools/build_mosque_data.py

Ne yapar:
  1. Overpass'tan Türkiye'deki camileri indirir (mirror'ları sırayla dener)
  2. assets/data/tr_mosques.json dosyasını günceller
  3. Eski dosyayla karşılaştırır, release notuna yapıştırılacak satırı yazdırır

Güvenlik: yeni liste eskisinden %10'dan fazla küçükse (yarım kalmış indirme
olabilir) dosyaya dokunmaz. Bilerek yapmak istersen --force kullan.

Çıktı biçimi: [[ad, enlem, boylam], ...]  (adı olmayanlarda ad "")
"""
import json
import os
import sys
import urllib.parse
import urllib.request

MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]
QUERY = (
    '[out:json][timeout:250];'
    'area["ISO3166-1"="TR"][admin_level=2]->.t;'
    'nwr["amenity"="place_of_worship"]["religion"="muslim"](area.t);'
    'out center tags;'
)
DST = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "tr_mosques.json")
MAX_SHRINK = 0.10

# Windows konsolu (cp1252) Türkçe karakterlerde patlamasın
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def download():
    body = urllib.parse.urlencode({"data": QUERY}).encode()
    for url in MIRRORS:
        try:
            print(f"İndiriliyor: {url}")
            req = urllib.request.Request(
                url, data=body, headers={"User-Agent": "EzanVaktiApp/1.0"}
            )
            with urllib.request.urlopen(req, timeout=290) as r:
                return json.load(r)["elements"]
        except Exception as e:  # noqa: BLE001
            print(f"  başarısız: {e}")
    sys.exit("Hiçbir Overpass sunucusuna ulaşılamadı.")


def convert(elements):
    rows = []
    for e in elements:
        if e["type"] == "node":
            lat, lon = e["lat"], e["lon"]
        else:
            c = e.get("center")
            if not c:
                continue
            lat, lon = c["lat"], c["lon"]
        tags = e.get("tags", {})
        name = (tags.get("name") or tags.get("name:tr") or "").strip()
        rows.append([name, round(lat, 5), round(lon, 5)])
    rows.sort(key=lambda r: (r[1], r[2]))  # deterministik çıktı
    return rows


def counts(rows):
    return len(rows), sum(1 for r in rows if r[0])


def main():
    force = "--force" in sys.argv
    new = convert(download())
    new_total, new_named = counts(new)

    old_total = old_named = None
    if os.path.exists(DST):
        with open(DST, encoding="utf-8") as f:
            old_total, old_named = counts(json.load(f))

    if old_total and not force and new_total < old_total * (1 - MAX_SHRINK):
        sys.exit(
            f"Yeni liste ({new_total}) eskisinden ({old_total}) çok küçük; "
            "yarım indirme olabilir. Dosya değiştirilmedi. (--force ile zorla)"
        )

    with open(DST, "w", encoding="utf-8") as f:
        json.dump(new, f, ensure_ascii=False, separators=(",", ":"))

    print(f"\nYazıldı: {os.path.normpath(DST)} ({os.path.getsize(DST) / 1e6:.2f} MB)")
    print("\n--- Release notu için ---")
    def n(v, sign=False):  # Türkçe binlik ayırıcı: 47.358
        return format(v, "+," if sign else ",").replace(",", ".")

    if old_total is None:
        print(f"Cami verisi: {n(new_total)} cami ({n(new_named)} isimli)")
    else:
        print(
            f"Cami verisi güncellendi: {n(old_total)} → {n(new_total)} "
            f"({n(new_total - old_total, True)} cami, "
            f"{n(new_named - old_named, True)} isimli)"
        )


if __name__ == "__main__":
    main()
