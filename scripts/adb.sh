#!/bin/bash
# ============================================================================
# HARMONYOS EMULATOR - adb ARACI SETI (Linux/WSL tarafi)
#
# L5 (adb shell) 2026-10-16'da CALISIR hale geldi:
#     adb connect 127.0.0.1:5555  ->  connected, cihaz 'device'
#     adb shell id                 ->  uid=0(root) ... groups=3003(inet)
#
# Bu betik Windows adb.exe'yi WSL uzerinden cagirir; boylece komut
# satiri suruklemeden 'adb shell' yazabilirsin:
#     scripts/adb.sh shell id
#     scripts/adb.sh sh          (kisaltma)
# ============================================================================
set -u
ADB="${ADB:-adb}"
DEV=127.0.0.1:5555

[ -x "$ADB" ] || { echo "HATA: adb.exe bulunamadi ($ADB)"; exit 1; }

# --connect: baglantiyi kur, sonra cik
# --disconnect: baglantiyi kes
# --status: durumu goster
# --wait: adbd hazir olana kadar bekle (en fazla N sn), sonra baglan
# --wait 300 shell id  ->  once baglanir, sonra komutu calistirir
# --<herhangi bir sey> shell <komut>  ->  komutu cihazda calistirir

cmd="${1:-}"; shift 2>/dev/null || true

case "$cmd" in
  --connect)
    "$ADB" kill-server >/dev/null 2>&1
    sleep 1
    "$ADB" connect "$DEV" 2>&1 | tr -d '\r'
    "$ADB" devices 2>&1 | tr -d '\r'
    ;;
  --disconnect)
    "$ADB" disconnect "$DEV" 2>&1 | tr -d '\r'
    ;;
  --status)
    "$ADB" devices -l 2>&1 | tr -d '\r'
    ;;
  --wait)
    limit="${1:-300}"; shift
    waited=0
    # DIKKAT: Windows adb.exe satir sonuna CR (\r) koyuyor. Temizlemeden
    # 'device' ile karsilastirinca test hep BASARISIZ oluyor ve
    # baglanti varken bile "HATA: baglanmadi" diyordu.
    adb_st() { "$ADB" devices 2>/dev/null | tr -d '\r' | grep "$DEV" | awk '{print $2}'; }
    while [ "$waited" -lt "$limit" ]; do
      st=$(adb_st)
      [ "$st" = "device" ] && break
      "$ADB" connect "$DEV" >/dev/null 2>&1
      sleep 3
      waited=$((waited + 3))
    done
    st=$(adb_st)
    if [ "$st" != "device" ]; then
      echo "HATA: $limit sn icinde baglanmadi (durum: ${st:-yok})"
      [ $# -gt 0 ] && "$ADB" -s "$DEV" "$@" 2>&1 | tr -d '\r'
      exit 1
    fi
    echo "bagli (${waited}s)"
    [ $# -gt 0 ] && "$ADB" -s "$DEV" "$@" 2>&1 | tr -d '\r'
    exit 0
    ;;
  --*)
    echo "bilinmeyen secenek: $cmd"; exit 1 ;;
  sh|shell)
    # --wait kaliyla birlikte gelirse: --wait 300 shell id
    if [ "${1:-}" = "--wait" ]; then
      shift
      "$0" --wait "${1:-300}" shell "${@:2}"
      exit $?
    fi
    "$ADB" -s "$DEV" shell "$@" 2>&1 | tr -d '\r'
    ;;
  *)
    # Dogrudan komut: scripts/adb.sh ls -la /system
    if [ $# -eq 0 ]; then "$0" --status; exit 0; fi
    "$ADB" -s "$DEV" shell "$cmd" "$@" 2>&1 | tr -d '\r'
    ;;
esac