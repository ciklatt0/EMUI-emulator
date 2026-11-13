#!/usr/bin/env bash
# rcpatch'in awk'sini COKLU DOSYA modunda, gercek rc dosyalariyla test et.
#
# DIKKAT: 81-boot-zygote.sh icindeki surum /overlay-src -> /overlay-rc
# yaziyor ve mount ile bagliyor. Burada ayni mantigi /tmp altinda
# calistiriyoruz: gercek vendor.img + system.img rc dosyalari uzerinde.
# Amac: QEMU'da 15 dakika beklemeden 'awk coklu dosyada calisiyor mu,
# cikti dizinleri olusuyor mu, servis sayisi tutuyor mu' olcmek.
set -uo pipefail
P=/root/harmony-build/super-out/parts
SRC=/tmp/rctest-src
OVL=/tmp/rctest-out
rm -rf "$SRC" "$OVL"; mkdir -p "$SRC" "$OVL"

pull() { # $1=img  $2=yol
  local nid
  nid=$(dump.erofs --path="$2" "$1" 2>/dev/null | awk '/NID:/{print $2; exit}')
  [ -n "$nid" ] || return 1
  dump.erofs --cat --nid="$nid" "$1" 2>/dev/null
}

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
bad() { printf '\033[1;31m  [HATA]\033[0m %s\n' "$*"; }

# --- gercek rc dosyalarini topla -------------------------------------------
i=0
pull "$P/vendor.img" /etc/init/init.balong_modem.rc   > "$SRC/a.rc" && i=$((i+1))
pull "$P/vendor.img" /etc/init/init.hisi.rc           > "$SRC/b.rc" && i=$((i+1))
pull "$P/system.img" /system/etc/init/hw/init.rc     > "$SRC/c.rc" && i=$((i+1))
pull "$P/odm.img"    /etc/init/init.odm.rc           > "$SRC/d.rc" && i=$((i+1))
say "$i rc dosyasi toplandi"
[ "$i" -ge 3 ] || { bad "3'ten az rc dosyasi bulundu"; exit 1; }

sumsvc() { grep -rhcE '^[ \t]*service[ \t]' $1 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
SVCA=$(sumsvc "$SRC")
say "kaynakta $SVCA servis tanimi"

FILES=$(find "$SRC" -name '*.rc' | sort)

# --- AYNI awk: 81-boot-zygote.sh ICINDEN CIKARILIR ------------------------
# DIKKAT (2026-10-15): once burada awk'nin AYRI bir kopyasi vardi ve
# 81-boot-zygote.sh degistiginde buradaki KOPYA geride kaldi. Iki
# yerde bakilan bir seyin ayrismasi birkac kosudan sonra gercek bir
# hataya donustu (buradaki kopya reboot_on_failure kuralini hic
# bilmiyordu, o yuzden test yesil veriyordu). Artik kopy yok:
# program govdesi 81-boot-zygote.sh'ten metin olarak cekiliyor.
BOOT="$(dirname "$0")/81-boot-zygote.sh"
A0=$(grep -n 'awk -v OVL=' "$BOOT" | head -1 | cut -d: -f1)
A1=$(grep -n 'rclog\.stats' "$BOOT" | head -1 | cut -d: -f1)
if [ -z "$A0" ] || [ -z "$A1" ]; then
  bad "81-boot-zygote.sh icinde awk blogu bulunamadi (A0=$A0 A1=$A1)"
  exit 1
fi
# Govde: acilis tirnaginin ALTINDAN kapanis tirnaginin USTUNE kadar
sed -n "$((A0 + 1)),$((A1 - 1))p" "$BOOT" \
  | sed "1s/^ *'//" | sed '$s/'"'"' .*$//' > /tmp/rcpatch.awk
if [ ! -s /tmp/rcpatch.awk ]; then
  bad "awk govdesi bos cikti"
  exit 1
fi
say "awk govdesi 81-boot-zygote.sh'ten: $((A1 - A0 - 2)) satir"

awk -v OVL="$OVL" -v SRC="$SRC" -f /tmp/rcpatch.awk $FILES > /tmp/rctest.stats

STATS=$(cat /tmp/rctest.stats)
say "awk cikti satirlari : $(echo "$STATS" | awk '{print $1}')"
say "wait -> 0          : $(echo "$STATS" | awk '{print $2}')"
say "mount_all modem off: $(echo "$STATS" | awk '{print $3}')"
say "critical kaldirildi: $(echo "$STATS" | awk '{print $4}')"
say "critical kalan     : $(echo "$STATS" | awk '{print $5}')"
say "reboot_on_failure  : $(echo "$STATS" | awk '{print $6}')"
say "shutdown critical  : $(echo "$STATS" | awk '{print $7}')"
say "apexd.status bekl. : $(echo "$STATS" | awk '{print $8}')"
say "writepid yorumlandi: $(echo "$STATS" | awk '{print $9}')"
say "file fd yorumlandi : $(echo "$STATS" | awk '{print $10}')"
say "import yorumlandi  : $(echo "$STATS" | awk '{print $11}')"

SVCB=$(sumsvc "$OVL")
if [ "${SVCB:-0}" -ne "${SVCA:-0}" ]; then
  bad "servis sayisi tutmadi: $SVCA -> $SVCB"
  exit 1
fi
ok "servis sayisi korundu: $SVCB"

A=$(find "$SRC" -type f | wc -l); B=$(find "$OVL" -type f | wc -l)
[ "$A" = "$B" ] && ok "dosya sayisi korundu: $B" || bad "dosya sayisi $A -> $B"

# --- modem rc'sinde sonuc -----------------------------------------------
say ""
say "--- init.balong_modem.rc sonucu ---"
sed -n '1,12p' "$OVL/a.rc"

echo ""
say "--- kalan gercek 'wait' satirlari (hepsi 0 olmali) ---"
grep -rhE '^[ \t]*wait[ \t]' "$OVL" 2>/dev/null | sort -u | head -12

echo ""
say "--- kalan aktif 'mount_all ... modem' (0 olmali) ---"
# DIKKAT: filtre '[[:space:]]*#' olmali. '[ \t]' bir POSIX karakter
# KUMESI içinde TICK isareti DEGILDIR (backslash escape yok) -- literal
# backslash ve 't' demektir. Bu yuzden girintili yorum satirlari
# filtrelenmez ve test kendi tuzagina düşer.
n=$(grep -rhE 'mount_all.*modem' "$OVL" 2>/dev/null | grep -vE '^[[:space:]]*#' | wc -l)
if [ "${n:-0}" -eq 0 ]; then ok "temiz"; else bad "$n tane kaldi"; fi
echo "  (yorum satirinda gecen 'mount_all modem' metni sayilmadi)"