#!/usr/bin/env bash
# Amac: arm64 icin statik busybox derle.
# Neden busybox? initramfs'in tamami tek bir statik binary ile ayakta kalir.
# Boylece Aşama 1'de hicbir paylasilan kutuphaneye/dinamik loader'a bagimli olmayiz.
# Bu binary daha sonra HarmonyOS userspace'inin altina baglayacagimiz
# "kabuk / acilis ortami" olarak da kullanilacak.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need "$CC"
# busybox 1.37.0 secildi. 1.36.1, modern kernel header'lariyla CBQ uzerinde
# cakisiyor: networking/tc.c icindeki TCA_CBQ_* sabitleri linux/pkt_sched.h'den
# kaldirilmis, ama busybox'ta o kod kosulsuz derleniyor (config korumasi yok,
# dolayisiyla kapatilamiyor). 1.37.0 bu duzeltmeyi iceriyor.
BB_VER="1.37.0"
SRC="$BUILD_DIR/busybox-$BB_VER"
OUT="$PROJECT/phase1/rootfs/bin/busybox"

if [[ -x "$OUT" ]] && file "$OUT" | grep -q "ARM aarch64"; then
  ok "busybox zaten derli: $OUT"
  exit 0
fi

fetch "https://busybox.net/downloads/busybox-$BB_VER.tar.bz2" "$BUILD_DIR/busybox-$BB_VER.tar.bz2"

say "busybox $BB_VER kaynak aciliyor"
rm -rf "$SRC"; mkdir -p "$SRC"
tar -xjf "$BUILD_DIR/busybox-$BB_VER.tar.bz2" -C "$SRC" --strip-components=1

say "defconfig + uyumluluk duzeltmeleri"
make -C "$SRC" defconfig ARCH="$ARCH" CROSS_COMPILE="$CROSS" >/dev/null 2>&1

# busybox'te static linking CONFIG_STATIC ile kontrol edilir, LDFLAGS ile degil.
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$SRC/.config"
sed -i 's/^CONFIG_STATIC=.*/CONFIG_STATIC=y/'              "$SRC/.config"

# busybox'un 'defconfig' ciktisi Ubuntu 24.04 cross-toolchain'i ile derlenemiyor.
# Iki ayri sorun var, ikisi de mimari-spesifik config'lerin yanlis acilmasi:
#
# 1) CONFIG_TC
#    Ubuntu 24.04 linux-libc-dev header'larinda CBQ (Class-Based Queuing) netlink
#    tanimlari (TCA_CBQ_*, struct tc_cbq_*) tamamen kaldirilmis. busybox'taki
#    networking/tc.c bu kodu KOSULSUZ derliyor ve CBQ icin bir config secenegi
#    de kaldirilmis -- yani kapatilacak ayri bir anahtar yok. Tek yol tc.c'yi
#    hic derlememek, o da yalnizca CONFIG_TC ile derleniyor.
#
# 2) CONFIG_SHA1_HWACCEL
#    defconfig bunu aciyor; hash_md5_sha.c 'sha1_process_block64_shaNI' cagirir,
#    ama bu sembol busybox kaynaginda sadece bazi mimariler icin (SHA-NI) tanimli.
#    arm64'te tanimli degil -> derleme hatasi.
#
# Bu ikisi initramfs icin gereksiz: 'tc' araci ve SHA hizlandirmasi yok sayilir.
compat_fix() {
  local name="$1" why="$2"
  sed -i "s/^CONFIG_${name}=y/# CONFIG_${name} is not set/" "$SRC/.config"
  yes '' | make -C "$SRC" oldconfig ARCH="$ARCH" CROSS_COMPILE="$CROSS" >/dev/null 2>&1 || true
  if grep -q "^# CONFIG_${name} is not set" "$SRC/.config"; then
    ok "$name kapatildi  ($why)"
  else
    die "$name kapatilamadi -- busybox bu toolchain ile derlenemez"
  fi
}

grep -q '^CONFIG_STATIC=y' "$SRC/.config" || die "CONFIG_STATIC ayarlanamadi"
compat_fix TC         "CBQ netlink tanimlari header'dan kaldirilmis"
compat_fix SHA1_HWACCEL "sembol arm64'te tanimsiz"

say "cross derleme: arm64, static  (birkac dakika surebilir)"
make -C "$SRC" -j"$(nproc)" \
     CROSS_COMPILE="$CROSS" \
     ARCH="$ARCH" \
     >"$BUILD_DIR/busybox-build.log" 2>&1 || {
       warn "derleme basarisiz, gercek hatalar:"
       grep -nE 'error:|Error [0-9]|undefined reference' "$BUILD_DIR/busybox-build.log" | head -20
       exit 1;
     }

mkdir -p "$(dirname "$OUT")"
cp "$SRC/busybox" "$OUT"
"$STRIP" "$OUT" 2>/dev/null || true

file "$OUT" | grep -q "statically linked" \
  && ok "statik arm64 binary dogrulandi ($(du -h "$OUT" | cut -f1))" \
  || warn "statik degil gibi gorunuyor, kontrol et"