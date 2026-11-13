#!/usr/bin/env bash
# Son (veya verilen) boot log'unu 15 saniyeye indirir.
#
# NEDEN: logs/boot-zygote.log 7000 satira ulasiyor ve kritik bilgi
# (apexd'nin neden oldugu, binder'in gelip gelmedigi) 5 satirlik bir
# blokun icinde kayboluyor. Her denemede 7000 satiri okumak yerine
# buradan 15 satira bakmak lazim.
#
# Kullanim:
#   bash scripts/91-log-summary.sh                # son kosu
#   bash scripts/91-log-summary.sh <log-dosyasi>
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${1:-$HERE/../logs/boot-zygote.log}"

[[ -f "$LOG" ]] || { echo "HATA: log yok: $LOG"; exit 1; }

c()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }
bad(){ printf '\033[1;31m%s\033[0m\n' "$*"; }
g()  { grep -aE "$1" "$LOG"; }

# DIKKAT: kernel logu [  87.123456] onekli. Sonucu kirpmadan once
# zaman damgasini atiyoruz, yoksa satir kayiyor.
last() { grep -aE "$1" "$LOG" | tail -1 | sed 's/^\[ *//; s/\] .*//'; }
hits() { grep -acE "$1" "$LOG"; }

c "==================================================================="
c "  HARMONYOS EMU - KOŞU ÖZETİ"
c "  $LOG"
c "==================================================================="

SZ=$(stat -c %s "$LOG")
LN=$(wc -l < "$LOG")
KEND=$(last '^\[ *[0-9]+\.[0-9]+\]')
c "satır: $LN   boyut: $((SZ/1024)) KB   son kernel zamanı: ${KEND:-?} s"

# --- 1) ASIL SORUN: reboot neden ------------------------------------------------
c ""
c "-- SONUC --"
REASON=$(grep -aoE "Rebooting system with command '[^']+'" "$LOG" | tail -1)
if [[ -n "$REASON" ]]; then
  bad "$REASON"
else
  ok "reboot kaydi yok (QEMU zaman aşımıyla kesilmiş olabilir)"
fi

# --- 2) kilometre taşları ------------------------------------------------------
c ""
c "-- KİLOMETRE TAŞLARI --"
mark() { # $1=etiket $2=desen
  local n; n=$(hits "$2")
  if [[ "$n" -gt 0 ]]; then
    printf '  %-34s \033[1;32mVAR\033[0m  (%s kez, son: %s s)\n' "$1" "$n" "$(last "$2")"
  else
    printf '  %-34s \033[1;31mYOK\033[0m\n' "$1"
  fi
}
mark "L2  EROFS bölümler"          'erofs: \(device vda[1-5]\): mounted'
mark "L2  APEXTen sonra init 2. aşama" 'init: init second stage started'
mark "L2  SELinux politikası"        'init: Loading SELinux policy'
mark "L2  Huawei vendor HAL'ları"    "init: starting service 'vendor\."
mark "L2  Huawei HISEC"              'HISEC:'
mark "G1  /init çıktısı log'da"     'HARMONYOS BOOT'
mark "G1  çıkış kanalı seçildi"      '/init cikti kanali'
mark "G2  rc dosyaları yamalandı"    'yamalandi : [0-9]+ rc dosyasi'
mark "H1  /dev/binder geri bağlandı" '/dev/binder geri baglandi'
mark "H2  sahte /dev/block yolları"  'sahte yollar uretildi'
mark "L3  apexd temiz çıktı"         'apexd: .*(Activated|Mounted|packages restored\.)'
mark "L4  servicemanager ayakta"     "init: starting service 'servicemanager'"
mark "L4  Zygote"                    "init: starting service 'zygote"
mark "L4  SystemServer"              'SystemServer|system_server'

# --- 3) apexd ------------------------------------------------------------------
c ""
c "-- APEXD --"
A=$(grep -aE '^.*apexd[: ]' "$LOG" | head -20)
if [[ -n "$A" ]]; then
  echo "$A" | sed 's/^/  /'
else
  c "  apexd tek satır bile yazmadı (rc yamalama çalışmamış olabilir)"
fi

# --- 4) linker -----------------------------------------------------------------
c ""
c "-- LINKER --"
grep -aE 'linkerconfig|CANNOT LINK|cannot execv|ld\.so' "$LOG" | tail -8 | sed 's/^/  /'

# --- 5) binder / device --------------------------------------------------------
c ""
c "-- CİHAZLAR --"
grep -aE "ProcessState|/dev/binder|binder" "$LOG" | grep -avE 'avc:.*permissive' | tail -8 | sed 's/^/  /'

# --- 6) DIAG -------------------------------------------------------------------
c ""
c "-- DIAG BLOKLARI --"
# DIKKAT: xargs shell FONKSIYONU cagiramaz; 'xargs -I{} c "{}"' hata verir
# ("c: No such file or directory"). Degiskeni atip fonksiyonu dogrudan
# cagiriyoruz.
NDIAG=$(hits '^.*--- (BOLUMLER|APEX|LINKER ZINCIRI|CIHAZLAR|SELINUX|SERVISLER)')
c "  ${NDIAG} bölüm başlığı bulundu"
grep -aE 'libc\.so COZULUYOR|/dev/binder   :|apex mount \(toplam\)|modul sayisi' "$LOG" \
  | sed 's/^\[[^]]*\] //' | sort -u | sed 's/^/  /'

# --- 7) init hataları ----------------------------------------------------------
c ""
c "-- INIT HATALARI (son 10) --"
grep -aE "init: (Failed|Could not|Service .* exited|cannot |Reboot|Sending signal)" "$LOG" \
  | tail -10 | sed 's/^\[[^]]*\] //' | sed 's/^/  /'

# --- 8) en uzun beklemeler -----------------------------------------------------
c ""
c "-- YAVA ADIMLAR (init komut zaman aşımı, en uzun 5) --"
grep -aoE "took [0-9]+ms" "$LOG" | grep -oE "[0-9]+" | sort -rn | head -5 \
  | while read -r ms; do printf '  %6s ms\n' "$ms"; done

echo ""
c "==================================================================="