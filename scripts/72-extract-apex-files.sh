#!/usr/bin/env bash
# system.img icindeki /system/apex altindaki ORIJINAL .apex arsivlerini cikar.
#
# NEDEN GEREKLI (Faz 2.1):
#   Simdi APEX'i elle bagliyoruz: 21 adet apex_payload.img'i ayri partition
#   yapip /apex/<modul> altina mount ediyoruz. Bu, apexd'in ISINI
#   BAYTPASTIRIYOR:
#       apexd: Populating APEX database from mounts...
#       apexd: 0 packages restored.        <-- sonra LOG(FATAL) -> cokuyor
#   Gercek Android'de apexd, /system/apex/*.apex arsivlerini loop device'a
#   baglayip kendisi mount eder. Dogru yol o yoldur.
#
# BU SCRIPT ne yapar:
#   super-out/parts/system.img  ->  /root/harmony-build/apexfiles/*.apex
#
# DIKKAT: apex_payload.img'i yeniden paketlemiyoruz. ZIP'i byte-byte
# kopyaliyoruz; boylece apex_manifest.pb icindeki payload SHA256 degismez
# ve apexd'in imza/hash dogrulamasi gecer.
set -uo pipefail

IMG="${1:-/root/harmony-build/super-out/parts/system.img}"
OUT="${2:-/root/harmony-build/apexfiles}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  [uyari]\033[0m %s\n' "$*"; }

[[ -f "$IMG" ]] || { echo "HATA: system.img yok: $IMG"; exit 1; }
command -v dump.erofs >/dev/null || {
  echo "HATA: dump.erofs yok -> apt-get install -y erofs-utils"; exit 1; }

# DIKKAT: erofs-utils 1.9.1'de hedef inode AYRI bir secenekle veriliyor:
#     dump.erofs --ls --nid=<NID> <IMAGE>
# '--ls=<NID>' denince "option doesn't allow an argument", konumsal
# '<IMAGE> <NID>' denince "unexpected argument" veriyor. Yardim metnindeki
# "(INODE required)" ifadesi --nid secenegini kastediyor.
#
# DIKKAT: awk'da hedef alan 'NID' BUYUK harfle yaziliyor. '/nid/' deseni
# ESANLAMSIZ eslesir ve NID hep bos kalir; ilk denemede boyle oldu.
say "EROFS icerigi: /system/apex"
NID=$(dump.erofs --path=/system/apex "$IMG" 2>/dev/null | awk '/NID:/{print $2; exit}')
[[ -n "$NID" ]] || { warn "/system/apex bulunamadi"; exit 1; }
ok "/system/apex nid=$NID"

mkdir -p "$OUT"

say "arsivler cikariliyor -> $OUT"
dump.erofs --ls --nid="$NID" "$IMG" 2>/dev/null \
  | awk '/\.apex$/ {print $NF, $1}' \
  | while read -r name nid; do
      [[ -n "$name" && "$name" == *.apex ]] || continue
      if dump.erofs --cat --nid="$nid" "$IMG" > "$OUT/$name" 2>/dev/null \
         && [[ -s "$OUT/$name" ]]; then
        printf '  [ok] %-46s %s\n' "$name" \
          "$(stat -c %s "$OUT/$name" | numfmt --to=iec)"
      else
        printf '  [HATA] %s (nid %s)\n' "$name" "$nid" >&2
        rm -f "$OUT/$name"
      fi
    done

COUNT=$(find "$OUT" -maxdepth 1 -name '*.apex' | wc -l)
SZ=$(du -sh "$OUT" 2>/dev/null | cut -f1)
ok "$COUNT arsiv, toplam $SZ"

if [[ "$COUNT" -eq 0 ]]; then
  echo "HATA: hicbir .apex cikarilmadi. Liste:"
  dump.erofs --ls --nid="$NID" "$IMG" 2>&1 | head -30
  exit 1
fi

# --- dogrulama: ZIP olarak aciliyor mu? ------------------------------------
# DIKKAT: bu adim olmadan disk imajina yazarsak, boot sirasinda apexd
# "invalid apex" diye TUM APEX'i reddeder ve gecerli firmware'de calisan
# bir sistemi calismayan hale getiririz. Maliyeti yuksek, kontrolu ucuz.
say "dogrulama (zip butunlugu + payload varligi)"
BAD=0
for f in "$OUT"/*.apex; do
  n=$(basename "$f")
  if ! unzip -l "$f" >/dev/null 2>&1; then
    printf '  [HATA] %s: ZIP olarak acilmiyor\n' "$n"; BAD=$((BAD+1)); continue
  fi
  if ! unzip -l "$f" 2>/dev/null | grep -q 'apex_payload.img'; then
    printf '  [HATA] %s: apex_payload.img YOK\n' "$n"; BAD=$((BAD+1)); continue
  fi
done
[[ $BAD -eq 0 ]] && ok "hepsi gecerli ZIP, hepsinde apex_payload.img var"
exit $BAD