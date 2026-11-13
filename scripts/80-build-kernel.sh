#!/usr/bin/env bash
# Amac: HarmonyOS userspace'i calistirabilecek OZEL arm64 kernel derlemek.
#
# Neden Debian netboot kernel'i yetmez?
#   1) virtio_blk icinde degil ve kernel'de modul paketi de yok -> sistem.img'yi
#      disk olarak baglayamayiz.
#   2) EROFS yok -> sistem.img icerigini okuyamayiz.
#   3) binder yok -> Android'in IP altyapisi calismaz, Zygote ayaga kalkamaz.
#
# Bu kernel bizim kontrolumuzde: istedigimiz ozellikleri gomulu (=y) aliyoruz,
# modul sistemiyle ugrasmiyoruz.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KVER="6.6"
TARBALL="$BUILD_DIR/linux-$KVER.tar.xz"
SRC="$BUILD_DIR/linux-$KVER"
OUT="$PROJECT/phase1/kernel/Image"
STAMP="$PROJECT/phase1/kernel/.harmony-kernel.ok"
JOBS="$(nproc)"

URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KVER.tar.xz"

# DIKKAT: Onceki guard 'Image' dosyasinin .config'den yeni olmasina bakiyordu.
# Ama o Image Debian netboot'tan gelen ve daha yeni bir tarih tasiyor; derlemeyi
# hiccal calistirmadan atlatiyordu. Varlik yerine kendi derledigimizi isaretleyen
# bir damga dosyasi kullanilir.
if [[ -f "$STAMP" && -f "$OUT" ]]; then
  ok "ozel kernel zaten derli: $OUT"
  exit 0
fi

need "$CC"; need flex; need bc
fetch "$URL" "$TARBALL"

say "kernel $KVER kaynagi aciliyor (bir kez, sonra cache'de)"
if [[ ! -d "$SRC" ]]; then
  tar -xJf "$TARBALL" -C "$BUILD_DIR"
fi

say "defconfig + HarmonyOS gereksinimleri"
make -C "$SRC" ARCH="$ARCH" CROSS_COMPILE="$CROSS" defconfig >/dev/null 2>&1

# scripts/config ile tek tek ayarla. DIKKAT: ebeveyn secenekler once, cocuklar
# sonra acilir; olddefconfig en sonda bagimliliklari cozulecek.
cfg() { "$SRC/scripts/config" --file "$SRC/.config" "$@" >/dev/null 2>&1 || true; }

# --- HarmonyOS/Android icin zorunlu: dosya sistemleri -----------------------
for o in EROFS_FS EROFS_FS_LZ4 EROFS_FS_LZ4HC FS_POSIX_ACL \
         EROFS_FS_POSIX_ACL \
         EXT4_FS EXT4_USE_FOR_EXT23 EXT4_FS_POSIX_ACL \
         F2FS_FS F2FS_FS_POSIX_ACL F2FS_FS_XATTR \
         OVERLAY_FS TMPFS TMPFS_POSIX_ACL DEVTMPFS DEVTMPFS_MOUNT; do
  cfg --enable "$o"
done
# DIKKAT: APEX payload'leri ext4. SELinux bir dosyayi etiketlemek icin O
# dosya sisteminin "security" xattr handler'i olmasi gerekir. Yoksa kernel
# su hatayi verir ve tum APEX dosyalari "unlabeled" kaliyor:
#   SELinux: (dev vda6, type ext4) has no security xattr handler
#   avc: denied { execute } ... tcontext=u:object_r:unlabeled:s0
# ve init SELinux enforcing'e gecince Zygote'ye giden yolu kapatiyor.
# Yani SELinux + Android'de ext4 ucunu birlikte acmak ZORUNLU.
cfg --enable EXT4_FS_SECURITY
cfg --enable SECURITY_PATH
cfg --enable FS_SECURITY_EXT4
# DIKKAT: CONFIG_EXT4_FS_XATTR burada ACILMAMALI ve dogrulamaya
# eklenmemeli. Linux 6.6'da o ayri bir sembol DEGIL (eski kernel'larda
# vardi); ext4 artik xattr handler'i dogrudan EXT4_FS_SECURITY ile acar:
#     config EXT4_FS_SECURITY
#         depends on EXT4_FS
# Olmayan bir sembolu acmak no-op'tur; dogrulamaya eklenirse (yanyanlislikla)
# kernel hicbir zaman derlenemez.
cfg --set-val BLK_DEV_LOOP_MIN_COUNT 32

# --- QEMU sanal cihazlari ---------------------------------------------------
cfg --enable VIRTIO --enable VIRTIO_MENU --enable VIRTIO_MMIO \
    --enable VIRTIO_BLK --enable VIRTIO_NET --enable VIRTIO_CONSOLE \
    --enable VIRTIO_BALLOON --enable VIRTIO_RNG

# --- Android IP / ad alanlari ------------------------------------------------
cfg --enable ANDROID_BINDER_IPC --disable ANDROID_BINDERFS --enable ANDROID_BINDERFS_PRAM
# DIKKAT: ANDROID_BINDERFS KAPALI olmali.
#
# BinderFS acikken kernel binder'i /dev/binder/binder olarak sunar ve
# /dev/binder bir DIZIN olur. libbinder ise once '/dev/binder' yolunu
# karakter cihaz olarak acmayi deniyor ve EISDIR aliyor:
#     ProcessState: Opening '/dev/binder' failed: Is a directory
#     ProcessState: Binder driver '/dev/binder' could not be opened. Terminating.
#
# BINDERFS kapaliyken kernel klasik misc cihazlarini uretir
# (/dev/binder, /dev/hwbinder, /dev/vndbinder -- major 10, minor 0/1/2)
# ve devtmpfs bunlari /dev altinda olusturur. libbinder'in bekledigi de
# tam olarak budur.
#
# Not: Bu kernel'i uretmek icin gereken sey dongusel bir bagimlilik degil,
# sadece libbinder'in bekledigi erisim yolu.
for o in IPC_NS USER_NS NET_NS UTS_NS PID_NS CGROUPS CGROUP_SCHED \
         CGROUP_FREEZER CGROUP_BPF CPUSETS MEMCG NAMESPACES \
         FHANDLE SYSFS PROC_FS UNIX PACKET NET; do
  cfg --enable "$o"
done

# --- SELinux: sistem.img'de SELinux etiketleri var --------------------------
# Etiketler acilmazsa init bir noktada ACL hatasiyla durur.
#
# DIKKAT: SELinux bir choice parcasi degil, dogrudan bagimlilik zinciri var:
#   security/selinux/Kconfig:
#     config SECURITY_SELINUX
#         depends on SECURITY_NETWORK && AUDIT && NET && INET
#
# Yani yalnizca "--enable SECURITY_SELINUX" yazmak yetmez; arm64 defconfig'inde
# SECURITY_NETWORK kapali oldugu icin olddefconfig bunu sessizce dusurur.
# Zinciri SIRAYLA acmak sart (her biri bir sonrakini mumkun kilar):
#   SECURITY -> SECURITY_NETWORK -> AUDIT / NET / INET -> SECURITY_SELINUX
cfg --enable SECURITY
cfg --enable SECURITY_NETWORK
cfg --enable AUDIT
cfg --enable NET
cfg --enable INET
cfg --enable SECURITY_SELINUX
cfg --enable SECURITY_SELINUX_BOOTPARAM
cfg --enable SECURITY_SELINUX_DISABLE
# AppArmor Android ile ilgisiz, gereksiz yere yer tutmasin
cfg --disable SECURITY_APPARMOR

# --- Konsol / temel ----------------------------------------------------------
cfg --enable SERIAL_AMBA_PL011 --enable SERIAL_AMBA_PL011_CONSOLE \
    --enable SERIAL_AMBA_PL011_MMIO
cfg --enable BLK_DEV_INITRD --enable RD_GZIP --enable INITRAMFS_SOURCE ""

# --- Grafik / pencere --------------------------------------------------------
# DIKKAT: emulasyonu GORUNUR kilmak icin gerekli.
# QEMU tarafinda "-device virtio-gpu-device" kullaniyoruz.
# framebuffer olarak gosterir, ekran karti/DRM/GPU gerekmez. Konuk tarafta
# bunu /dev/fb0 olarak acariz ve kernel'in fbcon'u oraya yazar.
#
# Zincir:  -device virtio-gpu-device -> DRM_VIRTIO_GPU -> /dev/fb0 -> fbcon -> tty0
#
# Kernel komut satirinda 'console=tty0' EKLENIRSE kernel mesajlarini HEM
# seri konsole (ttyAMA0) HEM ekrana yazar. Boylece pencere canli boot
# gunlugu gosterirken log dosyasi da dolmaya devam eder -- hicbir sey

cfg --enable DRM
cfg --enable DRM_VIRTIO_GPU
cfg --enable FB
cfg --enable FB_DEV
cfg --enable FRAMEBUFFER_CONSOLE

cfg --disable MODULE_SIG --disable SECURITY_LOCKDOWN_LSM

# --- IPv6'yi GOMULU yap (2026-10-16) ------------------------------------------
# SORUN (olculdu): adbd "main.cpp:186] adbd listening on tcp:5555"
# ve "main.cpp:287] adbd started" diyor, mDNS kaydi bile basarili
# ("mdns.cpp:109] registered: 1") -- ama netstat -an icinde HICBIR
# TCP SOCKET YOK. Kesin olcum:
#     ### NS: adbd=4259 self=net:[4026531840] adbd_ns=net:[4026531840]
#     ### NS-adbd-tcp: (tablo tamamen bos)
# Namespace AYNI (farkli degil) ve adbd'nin KENDI namespace'inde de
# TCP socket yok. Huawei adbd'si 'tcp:PORT' argumanini IPv6 ONCELIKLI
# acmasiyla bu durum aciklanir.
#
# NEDEN calismiyor (olculdu):
#     CONFIG_IPV6=m      (modul)
#     CONFIG_IPV6_SIT=m
#     net/ipv6/ipv6.ko   -> DERLENMEMIS, dosya bile yok
#     init: Unable to open /lib/modules, skipping module loading
# Yani konukta IPv6 YOK -> bind/listen basarisiz, log yine basiliyor.
cfg --enable IPV6
cfg --enable IPV6_SIT

# DIKKAT (2026-10-17, L4 zygote): tracefs / ftrace acik degil.
# OLCULEN ETKI (kernel .config):
#     # CONFIG_FTRACE is not set
#     CONFIG_DEBUG_FS=y          (var ama icinde 'tracing' YOK)
# Konukta:
#     /sys/kernel/tracing        -> mkdir "Operation not permitted"
#                                  (sysfs, CONFIG_FTRACE yok)
#     mount -t tracefs           -> ENOENT
#     mount -t debugfs           -> BAGLANIYOR ama icinde 'tracing' yok
# Sonuc: iki ayri servis cokuyor ve zygote boyunca surekli hata:
#     F atrace@1.0-service: Check failed: stat(tracefs_event_root_)
#       tracefs must be mounted at either/sys/kernel/tracing or
#       /sys/kernel/debug/tracing
#     E cutils-trace: Error opening trace file: No such file or
#       directory (2)         (25 sn'de 21 kez)
# Android'in boot_progress izleri de trace_marker uzerinden yazilir
# (libandroid_runtime.so icinde /sys/kernel/debug/tracing/trace_marker
#  dizesi var), bu yuzden zygote teshisi icin de onemli.
# Ayrica simdi zygote tam olarak boot_progress_start'tan sonra
# oluyor; boot izlerinin yazilacagi dosya hic yok.
cfg --enable TRACING
cfg --enable FTRACE
cfg --enable FUNCTION_TRACER
cfg --enable TRACE_FS
cfg --enable EVENT_TRACING

make -C "$SRC" ARCH="$ARCH" CROSS_COMPILE="$CROSS" olddefconfig >/dev/null 2>&1

# DIKKAT: olddefconfig bazi secenekleri bagimlilik geregi dusurur.
# "config ettim" deyip gecmiyoruz -- dogruluyoruz (bkz. PLAN.md).
grep -q '^CONFIG_IPV6=y' "$SRC/.config" \
  || say "UYARI: CONFIG_IPV6=y olmadi (bagimlilik dusurdu)"
# DIKKAT (2026-10-17, HATA DUZELTMESI): onceki surum burada
# "grep -q CONFIG_TRACE_FS=y" ariyordu ve her zaman UYARI veriyordu
# -- oysa kernel 6.6'da CONFIG_TRACE_FS bir Kconfig SEMBOLU DEGIL.
# tracefs, CONFIG_TRACING acikken fs/tracefs/ altinda kosulsuz
# derleniyor. Yani o grep HICBIR ZAMAN tutamaz ve "tracefs mount
# edilemeyecek" diye yanlis alarm verir.
# Dogru olcut: TRACING + FTRACE acik mi VE derlenen Image icinde
# tracefs sembolleri var mi (kaynak degil, SONUC).
grep -q '^CONFIG_TRACING=y' "$SRC/.config" \
  || say "UYARI: CONFIG_TRACING=y olmadi (tracefs derlenmez)"
grep -q '^CONFIG_FTRACE=y' "$SRC/.config" \
  || say "UYARI: CONFIG_FTRACE=y olmadi (tracefs mount edilemeyecek)"
if strings "$OUT" 2>/dev/null | grep -q tracefs; then
  ok "tracefs Image icinde mevcut"
else
  say "UYARI: Image icinde tracefs yok - mount edilemeyecek"
fi

# --- SELinux'i PERMISSIVE baslat (kaynak yaması) ----------------------------
# SORUN: emulasyonda SELinux ENFORCING basliyor ve sistem kilitleniyor:
#     avc: denied { write } for pid=2040 comm="supervise" path="/dev/kmsg"
#         ... permissive=0
# Yani denetleyici /dev/kmsg'ye yazamiyor, apexd ciktisi kayboluyor.
#
# NEDEN komut satiriyla cozulmuyor: kernel'de 'enforcing=' parametresi
# `__setup("enforcing=", enforcing_setup)` ile isleniyor ve bu SADECE
# CONFIG_SECURITY_SELINUX_DEVELOP altinda derleniyor:
#     security/selinux/hooks.c
#     #ifdef CONFIG_SECURITY_SELINUX_DEVELOP
#     static int selinux_enforcing_boot __initdata;
#     static int __init enforcing_setup(char *str) { ... }
#     __setup("enforcing=", enforcing_setup);
#     #else
#     #define selinux_enforcing_boot 1
#     #endif
# Artik bir de `androidboot.selinux=permissive` yetmiyor: cihazin
# precompiled_sepolicy'si yuklenirken enforcement geri geliyor.
#
# COZUM: kaynaga bir satirlik yama. parametre ayrica calissin (ileride
# enforcing=1 denemek isteyen olursa), ama varsayilan 0.
PATCH="$SRC/security/selinux/hooks.c"
if ! grep -q 'HARMONY-EMU: permissif baslat' "$PATCH"; then
  say "SELinux permissive yamasi uygulaniyor"
  python3 - "$PATCH" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8', errors='surrogateescape').read()
old = """static int __init enforcing_setup(char *str)
{
\tunsigned long enforcing;
\tif (!kstrtoul(str, 0, &enforcing))
\t\tselinux_enforcing_boot = enforcing ? 1 : 0;
\treturn 1;
}"""
new = """static int __init enforcing_setup(char *str)
{
\tunsigned long enforcing;
\tif (!kstrtoul(str, 0, &enforcing))
\t\tselinux_enforcing_boot = enforcing ? 1 : 0;
\t/* HARMONY-EMU: permissif baslat.
\t * Cihazin kendi precompiled_sepolicy'si enforcement'i geri aciyor ve
\t * emulasyon kilitleniyor (bkz. avc ... permissive=0). Parametre yine
\t * calisiyor; sadece varsayilan degisti. */
\tselinux_enforcing_boot = 0;
\treturn 1;
}"""
if old not in s:
    print('UYARI: enforcing_setup bulunamadi, yama uygulanmadi')
    sys.exit(1)
open(p, 'w', encoding='utf-8', errors='surrogateescape').write(s.replace(old, new, 1))
print('yamalandi')
PYEOF
else
  say "SELinux permissive yamasi zaten var"
fi

# --- SELinux'i PERMISSIVE'de SABITLE (ikinci yama) ---------------------------
# SORUN: yukaridaki yama YALNIZCA boot anindaki varsayilani degistirir.
# Policy yuklendikten sonra init (veya vendor kutuphaneleri) enforcement'i
# geri AÇIYOR:
#     [ 24.8 s] permissive=1      (denetleyici calisiyor)
#     [ 25.2 s] permissive=0      (enforcing geri geldi)
# ve hemen ardindan surecler SELinux ihlaliyle OLDIYOR:
#     avc: denied { read } for comm="init"
#         scontext=u:r:vendor_init:s0
#         tcontext=u:object_r:default_prop:s0   permissive=0
#     init: Subcontext exited with status 1
#
# NEDEN boot yaması yetmiyor: enforcing'i degistiren tek yol
# /sys/fs/selinux/enforce'a yazmak:
#     security/selinux/selinuxfs.c  sel_write_enforce()
#         new_value = !!scan_value;
#         enforcing_set(new_value);
# yetki kontrolu SELINITSID_SECURITY'a bakar, yani policy "security"
# alanina setenforce verdigi surec her yazabilir.
#
# COZUM: sel_write_enforce cagirisinda new_value DAIMA 0 olsun. Boylece
# ne init ne vendor kutuphanesi enforcement'i geri acabilir. Parametre
# okunmaya devam eder (kullanici "1" yazarsa sessizce yok sayilir);
# emulasyon icin bu kasitlidir, uretim cihazi icin degildir.
PATCH2="$SRC/security/selinux/selinuxfs.c"
if ! grep -q 'HARMONY-EMU: enforcement kilitli' "$PATCH2"; then
  say "SELinux enforcement kilidi yaması uygulaniyor"
  python3 - "$PATCH2" <<'PYEOF2'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8', errors='surrogateescape').read()
old = "\tnew_value = !!scan_value;\n"
new = ("\t/* HARMONY-EMU: enforcement kilitli.\n"
       "\t * Boot yaması sadece varsayilani degistiriyordu; init ve vendor\n"
       "\t * kutuphaneleri policy yuklendikten sonra enforcement'i geri acip\n"
       "\t * vendor_init alt baglamini ve ueventd'i olduruyordu\n"
       "\t * (avc ... scontext=u:r:vendor_init:s0 ... permissive=0).\n"
       "\t * Burada ne yazilirsa yazilsin new_value DAIMA 0 kalir. */\n"
       "\tnew_value = 0;\n"
       "\t(void)scan_value;\n")
if old not in s:
    print('UYARI: sel_write_enforce bulunamadi, yama uygulanmadi')
    sys.exit(1)
open(p, 'w', encoding='utf-8', errors='surrogateescape').write(s.replace(old, new, 1))
print('yamalandi')
PYEOF2
else
  say "SELinux enforcement kilidi yamasi zaten var"
fi

# security= parametresi verilmezse SELinux kapali baslar. Android'in
# etiketleri cozebilmesi icin kernel'e security=selinux yazilir.
# (bkz. 90-boot-harmony.sh append satiri)

# --- Gercekten gomulu mu? Dogrula, umma -------------------------------------
echo ""
say "kritik ozellikler dogrulaniyor"
missing=0
check() {
  if grep -qx "$1" "$SRC/.config"; then
    printf '  \033[1;32m[ok]\033[0m   %s\n' "$1"
  else
    printf '  \033[1;31m[EKSIK]\033[0m %s\n' "$1"
    missing=$((missing+1))
  fi
}
for o in CONFIG_EROFS_FS CONFIG_EXT4_FS CONFIG_VIRTIO_BLK CONFIG_VIRTIO_MMIO \
         CONFIG_ANDROID_BINDER_IPC \
         CONFIG_SECURITY_SELINUX CONFIG_TMPFS CONFIG_DEVTMPFS \
         CONFIG_FHANDLE CONFIG_SERIAL_AMBA_PL011_CONSOLE \
         CONFIG_EXT4_FS_SECURITY CONFIG_SECURITY_PATH \
         CONFIG_DRM CONFIG_DRM_VIRTIO_GPU CONFIG_FB CONFIG_FRAMEBUFFER_CONSOLE; do
  check "$o=y"
done
# BinderFS'in KAPALI oldugunu da dogrula (acik olmasi libbinder'i EISDIR ile
# olduruyor -- yukaridaki aciklamaya bakin).
if grep -qx "CONFIG_ANDROID_BINDERFS=y" "$SRC/.config"; then
  printf '  \033[1;31m[EKSIK]\033[0m CONFIG_ANDROID_BINDERFS y KAPALI olmali\n'
  missing=$((missing+1))
else
  printf '  \033[1;32m[ok]\033[0m   CONFIG_ANDROID_BINDERFS kapali (/dev/binder misc cihaz)\n'
fi

if [[ $missing -gt 0 ]]; then
  die "$missing ozellik gomulu degil - kernel bu haliyle HarmonyOS'u tasimaz"
fi

say "derleniyor: Image  (-j$JOBS)"
make -C "$SRC" ARCH="$ARCH" CROSS_COMPILE="$CROSS" -j"$JOBS" Image \
     >"$BUILD_DIR/kernel-build.log" 2>&1 || {
       warn "derleme basarisiz:"; grep -nE 'error:|Error [0-9]' \
            "$BUILD_DIR/kernel-build.log" | head -20; exit 1; }

mkdir -p "$(dirname "$OUT")"
cp "$SRC/arch/arm64/boot/Image" "$OUT"
ok "kernel: $OUT ($(du -h "$OUT" | cut -f1))"
touch "$STAMP"
"$PROJECT/scripts/40-boot.sh" --test 2>&1 | tail -25