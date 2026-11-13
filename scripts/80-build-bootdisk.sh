#!/usr/bin/env bash
# Zygote'yi ayaga kaldirmak icin OZEL BIR KERNEL DE IZLEMEK ZORUNDA
# (/dev/binder yalnizca Android cekirdegi tarafindan saglanir; WSL2'nin
#  host cekirdeginde CONFIG_ANDROID_BINDER_IPC "is not set").
#
# Bu script duzenlenebilir, OZEL BIR DISK imaji kurar ve 5 bolumu ayri
# partition olarak yerlestirir. Boylece kernel'e standart bir sey gecirilir:
#   root=PARTLABEL=system
#
# Neden super.raw calismaz?
#   super.raw, super'in ICINDEKI 5 bolumun ham halidir (LP metadata'ya
#   gore dilimlenmis). Gercek bir blok cihaz duzeni DEGILDIR: tek devnode'da
#   ust uste dururlar ve kernel'in mount edebilecegi ayri partition'lara
#   sahip degildirler.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTS="/root/harmony-build/super-out/parts"
DISK="/root/harmony-build/boot/system-disk.img"

command -v sgdisk >/dev/null || {
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gdisk >/dev/null 2>&1; }
command -v sgdisk >/dev/null || { echo "HATA: sgdisk yok"; exit 1; }

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m  [uyari]\033[0m %s\n' "$*"; }

[[ -d "$PARTS" ]] || { echo "HATA: bolumler yok -> 60-extract-partitions.py"; exit 1; }

ORDER=(system hw_product vendor odm cust)

# Boyutlar MiB cinsinden (= 2048 sektor). DIKKAT: 2048'nin KATI olmayan
# sektor sayisi vermek partition'i hizalamadan cikarir; sgdisk baslangici
# geriye kaydirir ve partition beklenenden cok kucuk kalir
# (denendi: 7.2M sektor -> 1.7 MiB). MiB birimi hizalamayi garanti eder.
# Gercek cihazdaki GPT'den: system 14,286,848 sektor (~6.8 GiB) -- burada
# yalnizca icerik sigan boyut yeterli.
declare -A MIB=(
  [system]=3516
  [hw_product]=2246
  [vendor]=1025
  [odm]=683
  [cust]=107
)
ALIGN=2048

# ---------------------------------------------------------------- yerlesim --
# DIKKAT: "partition olustur" ve "veri yaz" AYRI dongulerde kendi LBA
# sayacini tutsaydi ikisi ayrisirdi. Onceki kosuda GPT 2048/7610/... uretirken
# veri 7204096/11806144/... konumuna yazildi -> boot edilemez. Tek tablo,
# iki kullanim.
say "yerlesim hesaplaniyor"
# DIKKAT: bilesik diziye aritmetik ifade icinde erisirken SURNUN KENDISI
# degil ${...} formu kullanilmalidir. 'SECT[$b]' yazilirsa 0 gelir ve disk
# birkac MB'a dusur.
TOTAL_MIB=0
POS=1                                    # MiB cinsinden konum
NAMES=(); STARTS=(); ENDS=()
for b in "${ORDER[@]}"; do
  M=${MIB[$b]}
  TOTAL_MIB=$((TOTAL_MIB + M))
  [[ -f "$PARTS/$b.img" ]] || { warn "$b.img yok, atlandi"; continue; }
  NAMES+=("$b")
  STARTS+=($(( POS * ALIGN )))
  ENDS+=($(( (POS + M) * ALIGN - 1 )))
  POS=$((POS + M + 1))                   # 1 MiB bosluk ayir
done
TOTAL_LBA=$(( (TOTAL_MIB + 16) * ALIGN ))

say "APEX payload'leri diske ekleniyor"
# libc.so, libart.so, linker64 gibi kritik bilesenler APEX icinde gelir:
#   /apex/com.android.runtime/lib64/bionic/libc.so
#   /apex/com.android.runtime/bin/linker64
# apexd calismadan once bu dosyalar YOK -> "library libc.so not found".
# Biz initramfs'te elle mount ediyoruz; icin diske partition olarak
# yerlestiriyoruz.
APEXDIR="/root/harmony-build/apex"
APEX_NAMES=(); APEX_STARTS=(); APEX_ENDS=()
if [ -d "$APEXDIR" ]; then
  POS2=$(( POS + 1 ))
  for d in "$APEXDIR"/*/; do
    [ -f "$d/apex_payload.img" ] || continue
    n=$(basename "$d")
    sz=$(stat -c %s "$d/apex_payload.img")
    mib=$(( (sz / 1024 / 1024) + 2 ))          # 2 MiB bosluk pay
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

# ---------------------------------------------------------------- apexfiles --
# Faz 2.2: apexd'in KENDI mount'unu yapabilmesi icin orijinal .apex
# arsivlerinin /system/apex altinda gorunmesi gerekiyor. /system EROFS ve
# salt okunur, ama bir dizini UZERINE bind-mount edebiliriz. Arsivleri
# kendi partition'imizda tasiyoruz.
#
# DIKKAT: bu partition EN SONA ekleniyor ve adi 'apexfiles'. 81-boot-zygote.sh
# APEX listesini 6. partition'dan itibaren okuyup isim listesine bakarak
# devam ediyor; 'apexfiles' bir APEX modulu olmadigi icin listeden
# HARIC TUTULMALI (aksi halde mount denemesi yapip basarisiz olur).
#
# DIKKAT: 226 MB .apex arsivi icin ek disk yeri. Disk zaten 8.2 GB;
# WSL kokunde 899 GB bos var. Sorun degil.
#
# DIKKAT: APEXFILES=0 ile tamamen kapatilabilir. Yana baglama (eski yol)
# calistigi icin bu partition opsiyoneldir.
# DIKKAT: APEXFILES varsayilan olarak KAPALI. Deney sonucu: firmware'in
# /system/apex dizininde 22 .apex arsivi ZATEN var ve apexd onlari kendisi
# buluyor:
#     apexd: Scanning /system/apex for pre-installed ApexFiles
#     apexd: Found pre-installed APEX /system/apex/com.android.adbd.apex
# Yani ayri partition'a gerek yok. 72-extract-apex-files.sh hâlâ degerli
# (arsivleri disarida tutup incelemek/degistirmek icin) ama diske yazmiyoruz.
APEXFILES_DIR="/root/harmony-build/apexfiles"
APEXFILES_IMG="$PARTS/apexfiles.img"
if [[ "${APEXFILES:-0}" == "1" ]] && [[ -d "$APEXFILES_DIR" ]] \
   && compgen -G "$APEXFILES_DIR/*.apex" > /dev/null; then
  say "apexfiles imaji uretiliyor (orijinal .apex arsivleri)"
  NA=$(find "$APEXFILES_DIR" -maxdepth 1 -name '*.apex' | wc -l)
  B=$(du -sb "$APEXFILES_DIR" | cut -f1)
  # MiB: veri + bosluk payi. 'mke2fs -d' dizini imaja yerlestirir.
  MIBFILES=$(( (B / 1024 / 1024) + 64 ))
  rm -f "$APEXFILES_IMG"
  truncate -s $(( MIBFILES * 1024 * 1024 )) "$APEXFILES_IMG"
  mke2fs -q -t ext4 -F -d "$APEXFILES_DIR" -L apexfiles "$APEXFILES_IMG" 2>/dev/null \
    || { warn "apexfiles imaji uretilemedi, atlandi"; rm -f "$APEXFILES_IMG"; }
  if [[ -f "$APEXFILES_IMG" ]]; then
    ok "apexfiles: $NA arsiv, $MIBFILES MiB"
    APEX_NAMES+=("apexfiles")
    APEX_STARTS+=($(( POS2 * ALIGN )))
    APEX_ENDS+=($(( (POS2 + MIBFILES) * ALIGN - 1 )))
    POS2=$(( POS2 + MIBFILES + 1 ))
    TOTAL_MIB=$(( TOTAL_MIB + MIBFILES ))
    POS=$(( POS2 - 1 ))
    TOTAL_LBA=$(( (TOTAL_MIB + 16) * ALIGN ))
  fi
else
  say "apexfiles: kapali (APEXFILES=1 ile acilir). apexd /system/apex'i kendisi okuyor."
fi

# ---------------------------------------------------------------- /data ------
# DIKKAT (2026-10-15): vold ARIA SUREKLI cokuyordu:
#     vold: Check failed: android::vold::sBlkidContext != nullptr
#     init: starting service 'vold'...            (25 kez)
# Sebep: /data HIC YOK. 26 bolumun hicbiri userdata degil. vold blkid'de
# userdata ariyor ve CHECK FAIL ile oluyor; ardindan 'init_user0' basarisiz
# oluyor:
#     init: Failure (reboot suppressed): init_user0_failed
# ve zygote hic baslamiyor. Yani /data, zygotenin onundeki engellerden
# biri (belki en buyugu).
#
# Cozum: bos bir ext4 imaj uretip EN SON bolum olarak ekliyoruz. Gercek
# cihazdaki kullanici verisi degil; sadece vold'un ve init'in yazma yeri.
# Dlfs=Disable: Android'in encryption=Require olan /data mount'lari ancak
# FBE/FDE calisiyorsa acar; biz mount'u elle yaptigimiz icin bu bayrak
# sadece vold'un beklentisini karsilamak icin gerekli.
DATADIR="/root/harmony-build/data-root"
DATAIMG="$PARTS/data.img"
MIBDATA=${DATAMIB:-1024}
say "data imaji uretiliyor (vold + init_user0 icin)"
rm -rf "$DATADIR"; mkdir -p "$DATADIR/system/packages" "$DATADIR/misc/apexdata" "$DATADIR/user_de"
rm -f "$DATAIMG"
truncate -s $(( MIBDATA * 1024 * 1024 )) "$DATAIMG"
if mke2fs -q -t ext4 -F -L data -O ^has_journal -d "$DATADIR" "$DATAIMG" 2>/dev/null; then
  ok "data: $MIBDATA MiB, $(du -sh "$DATADIR" | cut -f1) icerik"
  APEX_NAMES+=("data")
  APEX_STARTS+=($(( POS2 * ALIGN )))
  APEX_ENDS+=($(( (POS2 + MIBDATA) * ALIGN - 1 )))
  say "  data bolumu: #$(( ${#NAMES[@]} + ${#APEX_NAMES[@]} )) LBA $(( POS2 * ALIGN ))..$(( (POS2 + MIBDATA) * ALIGN - 1 )) (POS2=$POS2 MIBDATA=$MIBDATA ALIGN=$ALIGN)"
  POS2=$(( POS2 + MIBDATA + 1 ))
  # DIKKAT (HATA 2026-10-15): disk boyutu TOTAL_MIB'den hesaplaniyordu:
  #     TOTAL_LBA=$(( (TOTAL_MIB + 16) * ALIGN ))
  # Ama TOTAL_MIB her bolume 1 MiB BOSLUK eklemezken POS2 ekliyor; bu
  # yuzden POS2 daima TOTAL_MIB'den BUYUK. Son bolum (data) POS2'den
  # basliyor ve diskin sonuna sigmiyordu:
  #     Could not create partition 29 from 16123904 to 18221055
  #     TOTAL_LBA=18192384   (gerekli: 18221055)
  #     Error encountered; not saving changes.
  # Duzeltme: disk boyutu POS2'den hesaplanir; POS2 zaten "bir sonraki
  # bos MiB" konumudur, yani en guvenli referanstir.
  TOTAL_MIB=$(( TOTAL_MIB + MIBDATA ))
  POS=$(( POS2 - 1 ))
  TOTAL_LBA=$(( (POS2 + 16) * ALIGN ))
else
  warn "data imaji uretilemedi -> /data yine olmayacak (vold cokmeye devam eder)"
fi

mkdir -p "$(dirname "$DISK")"
rm -f "$DISK"
say "  disk boyutu: TOTAL_LBA=$TOTAL_LBA (${#NAMES[@]} sistem + ${#APEX_NAMES[@]} apex)"
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

# DIKKAT: yine de sgdisk'in kaydirdigi baslangic var mi diye DOGRULAYIP
# gercek degeri geri okuyoruz. Veriyi kendi hesabimiza gore yazmayalim.
LBAS=()
for i in "${!NAMES[@]}"; do
  p=$((i + 1))
  st=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/First sector/{print $3}')
  en=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/Last sector/{print $3}')
  LBAS+=("${st:-0}")
  printf '  %-12s LBA %-10s .. %-10s (%s MB)\n' "${NAMES[$i]}" "$st" "$en" \
    "$(( (en - st + 1) * 512 / 1024 / 1024 ))"
done

# ------------------------------------------------------------------- yaz --
say "bolum icerikleri yaziliyor"
for i in "${!NAMES[@]}"; do
  b=${NAMES[$i]}; L=${LBAS[$i]}
  IMG="$PARTS/$b.img"
  sz=$(stat -c %s "$IMG")
  cap=$(( (ENDS[$i] - L + 1) * 512 ))
  if [ "$sz" -gt "$cap" ]; then
    warn "$b.img ($(numfmt --to=iec "$sz")) partitiona sigmiyor ($(numfmt --to=iec "$cap")), kirpiliyor"
    head -c "$cap" "$IMG" | dd of="$DISK" bs=512 seek="$L" conv=notrunc status=none
  else
    dd if="$IMG" of="$DISK" bs=512 seek="$L" conv=notrunc status=none
  fi
  ok "$b yazildi ($(stat -c %s "$IMG" | numfmt --to=iec)) @ LBA $L"
done

# --- APEX payload'lerini yaz -------------------------------------------------
say "APEX payload'leri yaziliyor"
for i in "${!APEX_NAMES[@]}"; do
  n=${APEX_NAMES[$i]}
  p=$(( ${#NAMES[@]} + i + 1 ))
  st=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/First sector/{print $3}')
  en=$(sgdisk -i "$p" "$DISK" 2>/dev/null | awk '/Last sector/{print $3}')
  # DIKKAT: 'apexfiles' bir APEX modulu DEGIL; icinde apex_payload.img
  # degil, orijinal .apex arsivleri var. Ayni dongude ele aliyoruz ki
  # ayri bir dongu yazmak disk imajini iki kez 8 GB'ta gezdirirdi.
  if [[ "$n" == "apexfiles" ]]; then
    SRCF="$APEXFILES_IMG"
  elif [[ "$n" == "data" ]]; then
    # DIKKAT: 'data' da bir APEX modulu DEGIL. Kendi ext4 imajimiz.
    SRCF="$DATAIMG"
  else
    SRCF="$APEXDIR/$n/apex_payload.img"
  fi
  [[ -f "$SRCF" ]] || { warn "$n: kaynak yok ($SRCF), atlandi"; continue; }
  # DIKKAT: kapasite kontrolu. 'dd ... conv=notrunc' OZELIKLE BIR SONRAKI
  # partition'in UZERINE yazmaya devam eder ve imaji sessizce bozar.
  # 5 sistem bolumunde bu kontrol var; APEX dongusunde ekliyoruz.
  SZ=$(stat -c %s "$SRCF")
  CAP=$(( (en - st + 1) * 512 ))
  if [[ "$SZ" -gt "$CAP" ]]; then
    warn "$n ($(numfmt --to=iec "$SZ")) partitiona sigmiyor ($(numfmt --to=iec "$CAP")), kirpiliyor"
    head -c "$CAP" "$SRCF" | dd of="$DISK" bs=512 seek="$st" conv=notrunc status=none
  else
    dd if="$SRCF" of="$DISK" bs=512 seek="$st" conv=notrunc status=none
  fi
  ok "$n ($(stat -c %s "$SRCF" | numfmt --to=iec)) @ LBA $st"
done
sync

# -------------------------------------------------------------- dogrulama --
say "dogrulama"
sgdisk -p "$DISK" 2>/dev/null | tail -12
echo ""
ok "disk: $(du -h "$DISK" | cut -f1)  -> $DISK"
echo ""
echo "Kernel'e gecirilecek mount'lar:"
for i in "${!NAMES[@]}"; do
  echo "  root=PARTLABEL=${NAMES[$i]}"
done