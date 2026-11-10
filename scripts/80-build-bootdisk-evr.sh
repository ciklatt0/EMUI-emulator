#!/usr/bin/env bash
# LIO-AN00 / EMUI 11 (Android 10) icin OZEL DISK imaji.
# EVR-L29 (P30 lite) icin uyarlandi.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTS="/root/harmony-build/evr-super-out/parts"
DISK="/root/harmony-build/evr-boot/system-disk.img"

command -v sgdisk >/dev/null || {
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gdisk >/dev/null 2>&1; }
command -v sgdisk >/dev/null || { echo "HATA: sgdisk yok"; exit 1; }

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m  [uyari]\033[0m %s\n' "$*"; }

[[ -d "$PARTS" ]] || { echo "HATA: bolumler yok -> 60-extract-partitions-evr.py"; exit 1; }

ORDER=(system hw_product vendor odm cust)

declare -A MIB=(
  [system]=3600
  [hw_product]=2300
  [vendor]=1300
  [odm]=300
  [cust]=200
)
ALIGN=2048

say "yerlesim hesaplaniyor"
TOTAL_MIB=0
POS=1
NAMES=(); STARTS=(); ENDS=()
for b in "${ORDER[@]}"; do
  M=${MIB[$b]}
  TOTAL_MIB=$((TOTAL_MIB + M))
  [[ -f "$PARTS/$b.img" ]] || { warn "$b.img yok, atlandi"; continue; }
  NAMES+=("$b")
  STARTS+=($(( POS * ALIGN )))
  ENDS+=($(( (POS + M) * ALIGN - 1 )))
  POS=$((POS + M + 1))
done
TOTAL_LBA=$(( (TOTAL_MIB + 16) * ALIGN ))

say "APEX payload'leri diske ekleniyor"
APEXDIR="/root/harmony-build/apex"
APEX_NAMES=(); APEX_STARTS=(); APEX_ENDS=()
if [ -d "$APEXDIR" ]; then
  POS2=$(( POS + 1 ))
  for d in "$APEXDIR"/*/; do
    [ -f "$d/apex_payload.img" ] || continue
    n=$(basename "$d")
    sz=$(stat -c %s "$d/apex_payload.img")
    mib=$(( (sz / 1024 / 1024) + 2 ))
    APEX_NAMES+=("$n")
    APEX_STARTS+=($(( POS2 * ALIGN )))
    APEX_ENDS+=($(( (POS2 + mib) * ALIGN - 1 )))
    POS2=$(( POS2 + mib + 1 ))
    TOTAL_MIB=$(( TOTAL_MIB + mib ))
    POS=$(( POS2 - 1 ))
  done
  say "  ${#APEX_NAMES[@]} APEX bulundu"
  TOTAL_LBA=$(( (TOTAL_MIB + 16) * ALIGN ))
fi

say "data imaji uretiliyor (vold + init_user0 icin)"
DATADIR="/root/harmony-build/evr-data-root"
DATAIMG="$PARTS/data.img"
MIBDATA=1024
rm -rf "$DATADIR"; mkdir -p "$DATADIR/system/packages" "$DATADIR/misc/apexdata" "$DATADIR/user_de"
rm -f "$DATAIMG"
truncate -s $(( MIBDATA * 1024 * 1024 )) "$DATAIMG"
if mke2fs -q -t ext4 -F -L data -O ^has_journal -d "$DATADIR" "$DATAIMG" 2>/dev/null; then
  ok "data: $MIBDATA MiB"
  APEX_NAMES+=("data")
  APEX_STARTS+=($(( POS2 * ALIGN )))
  APEX_ENDS+=($(( (POS2 + MIBDATA) * ALIGN - 1 )))
  POS2=$(( POS2 + MIBDATA + 1 ))
  TOTAL_LBA=$(( (POS2 + 16) * ALIGN ))
else
  warn "data imaji uretilemedi"
fi

mkdir -p "$(dirname "$DISK")"
rm -f "$DISK"
say "  disk boyutu: TOTAL_LBA=$TOTAL_LBA"
truncate -s $((TOTAL_LBA * 512)) "$DISK"
sgdisk --clear "$DISK" >/dev/null

for i in "${!NAMES[@]}"; do
  p=$((i + 1))
  sgdisk --new=${p}:${STARTS[$i]}:${ENDS[$i]} \
         --change-name=${p}:${NAMES[$i]} \
         "$DISK" >/dev/null
done

for i in "${!APEX_NAMES[@]}"; do
  p=$(( ${#NAMES[@]} + i + 1 ))
  sgdisk --new=${p}:${APEX_STARTS[$i]}:${APEX_ENDS[$i]} \
         --change-name=${p}:${APEX_NAMES[$i]} \
         "$DISK" >/dev/null
done

LBAS=()
for i in "${!NAMES[@]}"; do
  p=$((i + 1))
  st=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/First sector/{print $3}')
  en=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/Last sector/{print $3}')
  LBAS+=("${st:-0}")
  printf '  %-12s LBA %-10s .. %-10s (%s MB)\n' "${NAMES[$i]}" "$st" "$en" \
    "$(( (en - st + 1) * 512 / 1024 / 1024 ))"
done

say "bolum icerikleri yaziliyor"
for i in "${!NAMES[@]}"; do
  b=${NAMES[$i]}; L=${LBAS[$i]}
  IMG="$PARTS/$b.img"
  sz=$(stat -c %s "$IMG")
  cap=$(( (ENDS[$i] - L + 1) * 512 ))
  if [ "$sz" -gt "$cap" ]; then
    warn "$b.img sigmiyor, kirpiliyor"
    head -c "$cap" "$IMG" | dd of="$DISK" bs=512 seek="$L" conv=notrunc status=none
  else
    dd if="$IMG" of="$DISK" bs=512 seek="$L" conv=notrunc status=none
  fi
  ok "$b yazildi @ LBA $L"
done

say "APEX payload'leri yaziliyor"
for i in "${!APEX_NAMES[@]}"; do
  n=${APEX_NAMES[$i]}
  p=$(( ${#NAMES[@]} + i + 1 ))
  st=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/First sector/{print $3}')
  en=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/Last sector/{print $3}')
  if [[ "$n" == "data" ]]; then
    SRCF="$DATAIMG"
  else
    SRCF="$APEXDIR/$n/apex_payload.img"
  fi
  [[ -f "$SRCF" ]] || { warn "$n: kaynak yok ($SRCF), atlandi"; continue; }
  SZ=$(stat -c %s "$SRCF")
  CAP=$(( (en - st + 1) * 512 ))
  if [[ "$SZ" -gt "$CAP" ]]; then
    warn "$n sigmiyor, kirpiliyor"
    head -c "$CAP" "$SRCF" | dd of="$DISK" bs=512 seek="$st" conv=notrunc status=none
  else
    dd if="$SRCF" of="$DISK" bs=512 seek="$st" conv=notrunc status=none
  fi
  ok "$n @ LBA $st"
done
sync

say "dogrulama"
sgdisk -p "$DISK" 2>/dev/null | tail -12
echo ""
ok "disk: $(du -h "$DISK" | cut -f1)  -> $DISK"
