#!/usr/bin/env bash
# Ozel kernel + gercek bolumlerle HarmonyOS init -> apexd -> Zygote.
#
# !!! CALISIRKEN BU DOSYAYI DUZENLEME !!!
# bash bir betigi satir satir okur ve KONUM bayt offset'ini hatirlar.
# Calisirken dosyayi duzenlersen, sonraki okuma eski offset'ten devam eder
# ve satirlar yarim kalir:
#     81-boot-zygote.sh: line 1064: l: command not found
#     81-boot-zygote.sh: line 1120: syntax error near unexpected token `else'
# Gozlemci bir hatadan cok yanlis teÅŸhis uretir. Duzeltme yapacaksan once
# bekle, sonra duzelt.
#
# Neden chroot degil? /dev/binder yalnizca Android cekirdegi tarafindan
# saglanir. WSL2'nin host cekirdeginde CONFIG_ANDROID_BINDER_IPC "is not set";
# bizim derledigimiz kernel'de ise:
#   CONFIG_ANDROID_BINDER_IPC=y
#   CONFIG_ANDROID_BINDERDEVICES="binder,hwbinder,vndbinder"
# Zygote -> servicemanager -> binder ZORUNLU. Chroot yolu yapisal olarak kapanir.
#
# Zincir:  bizim /init  ->  Android init  ->  init.rc early-init
#            -> mount_apex  ->  apexd  ->  servicemanager  ->  Zygote
#
# KRITIK MIMARI KARAR: APEX mount'lari /init icinde DEGIL, init'in kendi
# /init.rc'sindeki bir servis olarak yapilir. Sebebi: Android init birinci
# asamada /apex'in USTUNE kendi tmpfs'sini mount eder. Biz /init icinde mount
# edersek init bunlarin USTUNE mount eder ve hepsi gizlenir -- 12. saniyede
# "libc.so BULUNDU" yazarken 34. saniyede apexd "libc.so not found" der.
# init.rc'deki bir servis early-init tetiklemesiyle, init'in mount'lari
# BITTIKTEN SONRA calisir; boylece siralamayi init garanti eder.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="$HERE/../phase1/kernel/Image"
DISK="/root/harmony-build/boot/system-disk.img"
ROOT="/root/harmony-build/initramfs-boot"
OUT="$HERE/../phase1/out/initramfs-boot.img"
BUSYBOX="$HERE/../phase1/rootfs/bin/busybox"
LOG="$HERE/../logs/boot-zygote.log"
LOCK="/tmp/harmony-emulator.lock"
RUNLOG="/tmp/harmony-emulator.$$.log"

# --- TEK ORNEK KILIDI (2026-10-15) -----------------------------------------
# SORUN: iki kopya ayni anda calistirilirsa ASIL BOZULMA bu olur:
#   a) initramfs yarim yazilirken okunur -> QEMU birkac saniyede kapanir
#   b) ayni system-disk.img'ye IKI yazici, cache=unsafe -> disk bozulur
#   c) ayni seri log dosyasina iki QEMU -> olcumler birbirine karisir
# (c) en kotusu: elimize GECEN 3 kosunun olcumleri bu yuzden SUPHEYLI.
# Bu bir "ayar" degil, olcum aracinin kendisinin bozulmasiydi.
#
# KILIT davranisi:
#   - Normal calisma: kilit alinir, bitince temizlenir.
#   - FORCE=1: mevcut ornegi devirir (bilerek).
#   - Baska bir ornek varken: net mesla ile DURUR, sessizce binmez.
if [ -f "$LOCK" ]; then
  OLDPID=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then
    if [ "${FORCE:-0}" != "1" ]; then
      echo ""
      echo "HATA: zaten calisan bir emulasyor var (pid $OLDPID)."
      echo "      Iki ornek ayni disk imajini ve seri logunu paylasirsa"
      echo "      hem disk bozulur hem de log birbirine karisir; ayrica"
      echo "      biri initramfs'i yeniden yazarken digeri yarim dosyayi"
      echo "      okuyup birkac saniyede kapanir."
      echo ""
      echo "      Yapmak istediginize gore:"
      echo "        mevcut ornegi durdurmak : scripts/stop-emulator.sh"
      echo "        bilerek devretmek      : FORCE=1 bash $0"
      echo ""
      exit 1
    fi
    echo "[uyari] FORCE=1 -- onceki ornek (pid $OLDPID) devrediliyor"
  else
    rm -f "$LOCK"   # ucuzmus ornek: kilit artik gecersiz
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }

for f in "$KERNEL" "$DISK" "$BUSYBOX"; do
  [[ -f "$f" ]] || { echo "HATA: eksik: $f"; exit 1; }
done
PARTCOUNT=$(sgdisk -p "$DISK" 2>/dev/null | grep -cE '^ +[0-9]+ ')
[[ "$PARTCOUNT" -ge 5 ]] || { echo "HATA: disk'te 5 bolum yok"; exit 1; }
ok "disk: $PARTCOUNT partition, $(du -h "$DISK" | cut -f1)"

# --- APEX partition sirasi: diskten okunur ----------------------------------
# Elle yazmak kırılgan; 80-build-bootdisk.sh apex_payload.img dosyalarini
# alfabetik isler, ama bu bir kural degil bir tesaduf.
#
# DIKKAT: sgdisk -i ciktisi bolum adini TIRNAK icinde verir:
#     Partition name: 'com.android.adbd'
# Tirnaksiz almazsak mount hedefi /apex/'com.android.adbd' olur.
APEX_LIST=""
APEXFILES_PART=""
DATA_PART=""
N=6
while true; do
  nm=$(sgdisk -i "$N" "$DISK" 2>/dev/null | awk '/Partition name/{print $3}' | tr -d "'")
  [[ -n "$nm" ]] || break
  # DIKKAT: 'apexfiles' bir APEX modulu degil; orijinal .apex arsivlerini
  # tasiyan ext4 partition. Onu APEX listesine koyarsak mount denemesi
  # yapip basarisiz olur (dosya sistemi mount edilir ama /apex/apexfiles
  # diye bir modul belirir).
  #
  # DIKKAT (2026-10-15): 'data' bolumu de APEX modulu DEGIL; bizim
  # urettigimiz /data partition'imiz. Listeye girerse denetleyici onu
  # /apex/data diye mount ediyor ve apexd hata veriyor:
  #     libapexutil: Failed to read manifest file: /apex/data/apex_manifest.pb
  if [[ "$nm" == "apexfiles" ]]; then
    APEXFILES_PART="$N"
  elif [[ "$nm" == "data" ]]; then
    DATA_PART="$N"
  else
    APEX_LIST="$APEX_LIST $N:$nm"
  fi
  N=$((N+1))
done
ok "APEX: $(echo $APEX_LIST | wc -w) modul, ilk: $(echo $APEX_LIST | tr ' ' '\n' | sed -n 2p | cut -d: -f2)"
if [[ -n "$APEXFILES_PART" ]]; then
  ok "apexfiles partition: vda$APEXFILES_PART (apexd kendi mount'unu yapabilir)"
fi
if [[ -n "$DATA_PART" ]]; then
  ok "data partition: vda$DATA_PART (vold + init_user0 icin)"
fi

# --- iskelet ----------------------------------------------------------------
say "initramfs hazirlaniyor"
rm -rf "$ROOT"
mkdir -p "$ROOT"/{bb,dev,proc,tmp,r,apex,vendor,odm,hw_product,cust,data}
# Android init'in bekledigi mount noktalari (BOS olmali, init doldurur).
# /mnt, /debug_ramdisk, /second_stage_resources yoksa FirstStageMount basarisiz
# olur ve init "Init encountered errors starting first stage" ile olur.
mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali: init birinci
# asamada sysfs'i kendisi mount ediyor. Dizin yoksa "No such file or
# directory"; biz mount edersek "Device or resource busy".
mkdir -p "$ROOT/sys/fs/selinux"

cp "$BUSYBOX" "$ROOT/bb/busybox"

# ---------------------------------------------------------------------------
# /bb/dltrace.so -- app_process64'un dlopen() cagrilarini GORUNUR kilar.
#
# SORUN (olculdu): app_process64 libart.so'yu HIC yuklemiyor
#   libart.so 8 zaman noktasinda (0.2s..5s) hep 0
#   libartbase.so hep 0, libandroid_runtime.so 8 (yuklenmis)
#   ama linker /data yolundan libart'in 31 bagimliligini SORUNSUZ
#   cozuyor (linker64 --list /data/zz-libart.so -> hata=0)
# Yani yapilandirma saglam; ya dlopen denenmiyor ya da
# cevrimici bir yerde kiriliyor. IZLEMEKTE ZOR.
#
# COZUM: LD_PRELOAD ile dlopen'u yakalayan 68 KB'lık bir .so.
# Derleme (NDK'siz, bionic uyumlu):
#   aarch64-linux-gnu-gcc -shared -fPIC -nostdlib -O2 \
#       -o scripts/dltrace.so scripts/dltrace.c
# DT_NEEDED = 0 (hiçbir bağımlılığı yok), bu yüzden her yere
# yüklenebilir. dlsym BİLİNÇLİ tanımlanmıyor; bionic global
# namespace'ten çözüyor. RTLD_NEXT = (void*)-1.
#
# DIKKAT: zorunlu degil -- dosya yoksa sessizce gecilir, sistem
# normal calisir. Sadece teşhis araci.
if [ -f "$HERE/dltrace.so" ]; then
  cp "$HERE/dltrace.so" "$ROOT/bb/dltrace.so" 2>/dev/null \
    && echo "  [ok] /bb/dltrace.so (dlopen izleyici) initramfs'e eklendi"
fi
# DIKKAT: 'rmdir' LISTEDE OLMALI. /system gibi mount noktalarini temizlemek
# icin kullaniliyor; applet yoksa komut bulunamaz ve symlink yeniden
# /system/system icine yazilir, /system bomuk kalir.
for a in sh ls cat head tail mount umount mkdir rmdir ps dmesg poweroff reboot sleep \
         grep echo uname df free ln cp mv rm touch du date env stat readlink \
         od xxd find sed wc sort awk cut tr expr test true false basename \
         dirname tee strings cmp chmod mknod setsid nohup mountpoint \
         ip route ifconfig ping netstat ss nc; do
  ln -sf busybox "$ROOT/bb/$a"
done

# --- /bb/mountapex ----------------------------------------------------------
# init.rc'deki servis. init'in mount'lari bittikten SONRA calisir.
cat >"$ROOT/bb/mountapex" <<'APEX_EOF'
#!/bb/sh
# HarmonyOS: APEX modullerini bagla + linker yapilandirmasini uret.
# init tarafindan 'on early-init' ile tetiklenir.
#
# DIKKAT (cift yazim onlemi): bu script init'in SERVISI olarak calistiginda
# stdout /dev/null'a duser. Oysa ayni script /init icinde de dogrudan
# cagriliyor ve orada stdout zaten /dev/kmsg. Iki durumu da tek komutla
# karsilamak icin stdout'u KENDIMIZ /dev/kmsg'ye ceviriyoruz; boylece
# sonra her satiri ayrica kmsg'ye yazmaya gerek kalmaz (cift satir olmazdi).
exec >/dev/kmsg 2>&1
/bb/echo "--- APEX mount (init early-init) ---"

APEX_OK=0; APEX_FAIL=0
for entry in __APEX_LIST__; do
  n=${entry%%:*}; name=${entry#*:}
  dev=/dev/vda$n
  [ -b "$dev" ] || continue
  mkdir -p /apex/$name
  if mount -t ext4 -o ro $dev /apex/$name 2>/dev/null; then
    APEX_OK=$((APEX_OK+1))
  else
    APEX_FAIL=$((APEX_FAIL+1)); /bb/echo "  [$name] mount basarisiz"
  fi
done
/bb/echo "  APEX: $APEX_OK basarili, $APEX_FAIL basarisiz"

# --- /dev KALICI KOPYASI ----------------------------------------------------
# DIKKAT: init /dev'in UZERINE kendi tmpfs'ini mount edip ueventd'yi
# calistirir. ueventd yalnizca Android'in standart dugumlerini olusturdugu
# icin virtio blok dugumleri KAYBOLUR:
#     ls: /dev/vda*: No such file or directory
# O andan sonra /apex'i tazelemeye calisan denetleyici mount edecek cihazi
# bulamaz ve hicbir sey baglanamaz.
#
# Cozum: dugumleri /dev disinda kalici bir yola (/devblk) bind-mount etmek.
# Bag mount noktasi kok dizinde oldugu icin /dev'in degistirilmesinden
# ETKILENMEZ -- init /dev'i ne yaparsa yapsin, /devblk/vda* yerinde kalir.
mkdir -p /devblk
BLK=0
# DIKKAT: bind mount HEDEFIN var olmasini gerektirir. Once bos dosya
# yaratiyoruz, sonra uzerine bagliyoruz. (Yoksa "0" cikiyor ve
# /devblk/vda6: Can't lookup blockdev hatasi aliniyor.)
for n in 1 2 3 4 5; do
  : > /devblk/vda$n 2>/dev/null
  mount -o bind /dev/vda$n /devblk/vda$n 2>/dev/null && BLK=$((BLK+1))
done
for entry in __APEX_LIST__; do
  n=${entry%%:*}
  : > /devblk/vda$n 2>/dev/null
  mount -o bind /dev/vda$n /devblk/vda$n 2>/dev/null && BLK=$((BLK+1))
done
# DIKKAT (2026-10-15): /data bolumu de kalici dugume sahip OLMALI.
# Yoksa /init'teki mount denemesi sessizce basarisiz oluyor ve /data
# gercek partition yerine initramfs'te bir dizin kaliyor; vold yine
# "sBlkidContext == nullptr" ile cokuyor:
#     vold: Check failed: android::vold::sBlkidContext != nullptr
#     init: Failure (reboot suppressed): init_user0_failed
if [ -n "__DATADEV_PART__" ]; then
  : > /devblk/vda__DATADEV_PART__ 2>/dev/null
  mount -o bind /dev/vda__DATADEV_PART__ /devblk/vda__DATADEV_PART__ 2>/dev/null \
    && BLK=$((BLK+1))
fi
/bb/echo "  /devblk kalici cihaz dugumleri: $BLK"

# --- loop cihazlari ----------------------------------------------------------
# DIKKAT: apexd APEX dosyalarini acmak icin /dev/loop-control UZERINDE
# LOOP_CTL_GET_FREE cagirir. Yoksa 50 saniye bekleyip pes ediyor:
#     apexd: Failed to pre-allocate loop devices : wait for '/dev/loop-control' timed out
# Sonrasi: apexd-bootstrap 'critical' oldugu icin init sistemi kapatiyor.
#
# DIKKAT: bu dugumler de /dev'in altinda oldugu icin init /dev'i degistirince
# kaybolurlar. Ayni /devblk cozumu: kalici kopyala, sonra geri bagla.
LOOPN=0
if [ -e /dev/loop-control ]; then
  : > /devblk/loop-control 2>/dev/null
  mount -o bind /dev/loop-control /devblk/loop-control 2>/dev/null && LOOPN=$((LOOPN+1))
fi
for l in /dev/loop*; do
  b=$(basename "$l")
  : > /devblk/$b 2>/dev/null
  mount -o bind "$l" /devblk/$b 2>/dev/null && LOOPN=$((LOOPN+1))
done
/bb/echo "  /devblk loop dugumleri: $LOOPN"

# --- adbd icin APEX'e ozel linker config -------------------------------------
# DIKKAT (2026-10-15, ONEMLI): adbd bir APEX ikilisi. Linker, /apex/ icindeki
# bir ikiliyi calistirirken GLOBAL /linkerconfig/ld.config.txt yerine
#     /apex/<apex>/etc/ld.config.txt
# dosyasini okumaya calisir ve dosya yoksa linki KURAMAZ:
#     linker: Warning: couldn't read config file
#             "/apex/com.android.adbd/etc/ld.config.txt"
#     CANNOT LINK EXECUTABLE "/apex/com.android.adbd/bin/adbd":
#            library "libadb_protos.so" not found: needed by main executable
#
# Dolayisiyla bu dosya OLMAK ZORUNDA. APEX'in kendi /etc dizininde yalnizca
# init.rc var (olculdu: 1 dosya). Dizin APEX'te salt okunur oldugu icin
# UZERINE dizin bind-mount ediyoruz; altindaki init.rc'i kopyalayarak
# gizlemiyoruz.
#
# Arama yollari readelf -d ve erofs listesiyle OLCULDU:
#   /apex/com.android.adbd/lib64 -> libadb_protos, libbase, libc++,
#                                   libcrypto, libcutils, protobuf
#   /system/lib64                -> libadbd_fs.so, libadbd_auth.so,
#                                   liblog.so, libselinux.so
#   /apex/com.android.runtime/lib64/bionic -> libc, libm, libdl
# (/system/lib64'teki karsiliklari da var; siralama onemsiz, ilk bulan
#  kazanir.)
ADBD_LD=/apex/com.android.adbd/etc/ld.config.txt
if [ -d /apex/com.android.adbd/etc ] && [ ! -f "$ADBD_LD" ]; then
  mkdir -p /bb/nb/adbdetc
  {
    echo "dir.system = /system/bin/:/system/lib64/:/apex/com.android.runtime/lib64/bionic/:/apex/com.android.adbd/bin/:/apex/com.android.adbd/lib64/"
    echo "dir.apex_com.android.adbd = /apex/com.android.adbd/bin/:/apex/com.android.adbd/lib64/"
    echo ""
    echo "[system]"
    echo "namespace.default.search.paths = /system/bin:/system/lib64:/apex/com.android.runtime/lib64/bionic:/apex/com.android.adbd/lib64"
    echo "namespace.default.links = /system/bin:/system/lib64"
    echo "namespace.default.interpreter = /system/bin/linker64"
    echo "namespace.default.isolated = false"
    echo "namespace.default.per_library_path = false"
    echo ""
    echo "[apex_com.android.adbd]"
    echo "namespace.default.search.paths = /apex/com.android.adbd/bin:/apex/com.android.adbd/lib64:/system/lib64:/apex/com.android.runtime/lib64/bonic"
    echo "namespace.default.links = /system/bin:/system/lib64"
    echo "namespace.default.interpreter = /system/bin/linker64"
    echo "namespace.default.isolated = false"
    echo "namespace.default.per_library_path = false"
  } > /bb/nb/adbdetc/ld.config.txt
  cp /apex/com.android.adbd/etc/init.rc /bb/nb/adbdetc/init.rc 2>/dev/null
  if mount -o bind /bb/nb/adbdetc /apex/com.android.adbd/etc 2>/dev/null; then
    /bb/echo "  adbd: /apex/com.android.adbd/etc/ld.config.txt hazir"
  else
    /bb/echo "  adbd: ld.config.txt bind BASARISIZ"
  fi
else
  /bb/echo "  adbd: ld.config.txt $([ -f "$ADBD_LD" ] && echo zaten || echo 'yok (etc dizini yok)')"
fi

# --- apexfiles: apexd'in kendi mount'unu yapabilmesi icin -------------------
# Faz 2.3. Mantik:
#   apexd, /system/apex/*.apex arsivlerini loop device'a baglayip KENDISI
#   mount eder ve veritabanini doldurur. Su an /system/apex BOS oldugu icin
#   "0 packages restored" diyor.
#   /system EROFS (salt okunur) ama bir dizini UZERINE bind-mount
#   edebiliriz. Orijinal arsivlar kendi partition'imizda (/devblk/vda<N>).
#
# DIKKAT: bu adim yalnizca apexfiles partition'i diskte varsa calisir
# (80-build-bootdisk.sh, APEXFILES=1). Yoksa yana baglama yolu devrede.
if [ -n "__APEXFILES_PART__" ]; then
  mkdir -p /devblk /apexfiles
  : > /devblk/vda__APEXFILES_PART__ 2>/dev/null
  if mount -o bind /dev/vda__APEXFILES_PART__ /devblk/vda__APEXFILES_PART__ 2>/dev/null \
     || mount -o bind /devblk/vda__APEXFILES_PART__ /devblk/vda__APEXFILES_PART__ 2>/dev/null; then
    if mount -t ext4 -o ro /devblk/vda__APEXFILES_PART__ /apexfiles 2>/dev/null; then
      AF=$(/bb/ls /apexfiles/*.apex 2>/dev/null | /bb/wc -l)
      /bb/echo "  /apexfiles: $AF arsiv (vda__APEXFILES_PART__)"
      # /system/apex'in UZERINE bagliyoruz. EROFS olmasi engel degil:
      # bind-mount yazma gerektirmez, sadece hedefi degistirir.
      if mount -o bind /apexfiles /system/apex 2>/dev/null; then
        /bb/echo "  /system/apex -> /apexfiles  baglandi (apexd karsilayacak)"
      else
        /bb/echo "  /system/apex baglanamadi -- apexd yine 0 paket gorecek"
      fi
    else
      /bb/echo "  /apexfiles mount basarisiz (vda__APEXFILES_PART__)"
    fi
  else
    /bb/echo "  /devblk/vda__APEXFILES_PART__ baglanamadi"
  fi
fi

# --- binder dugumleri --------------------------------------------------------
# DIKKAT: Zygote, app_process, servicemanager ve Huawei HAL'larinin TAMAMI
# binder uzerinden konusur. Binder olmadan hicbiri calismaz:
#     ProcessState: Opening '/dev/binder' failed: No such file or directory
#     ProcessState: Binder driver '/dev/binder' could not be opened. Terminating.
# Binder dugumleri de /dev'in altinda oldugu icin init /dev'i degistirince
# kaybolurlar; ayni /devblk cozumu kullanilir.
# --- binder -----------------------------------------------------------------
# DIKKAT: kernel'imiz CONFIG_ANDROID_BINDERFS=n ile derlendi. Binder artik
# klasik MISC cihazidir: /dev/binder bir KARAKTER CIHAZI (major 10, minor 0).
# BinderFS acikken /dev/binder bir DIZIN olur ve libbinder EISDIR alir:
#     ProcessState: Opening '/dev/binder' failed: Is a directory
# Bu yuzden binderfs mount EDMIYORUZ; /dev/binder'i oldugu gibi bagliyoruz.
#
# DIKKAT: onceki denemede binderfs icin /devblk/binder DIZINI olusturulmusdu.
# Artik gerekmiyor ve bind'i bozuyor:
#     mountapex: can't create /devblk/binder: Is a directory
# O yuzuden onu temizliyoruz: karakter cihaz baglayabilmek icin HEDEF
# dosya olmali.
/bb/echo "  /dev binder: $(/bb/ls -d /dev/binder /dev/hwbinder /dev/vndbinder 2>&1 | /bb/tr '\n' ' ')"
rm -rf /devblk/binder 2>/dev/null
BIND=0
for b in /dev/binder /dev/hwbinder /dev/vndbinder; do
  name=$(basename "$b")
  [ -e "$b" ] || continue
  rm -rf "/devblk/$name" 2>/dev/null
  : > "/devblk/$name" 2>/dev/null
  mount -o bind "$b" "/devblk/$name" 2>/dev/null && BIND=$((BIND+1))
done
/bb/echo "  /devblk binder dugumleri: $BIND"

# VNDK takma adi. linkerconfig VNDK modulunu SABIT isimle arar:
#   Unable to access VNDK APEX at path: /apex/com.android.vndk.v31
# Bizim partition'in adi com.android.vndk.current; ayni cihazi v31 adiyle
# de bagliyoruz.
mkdir -p /apex/com.android.vndk.v31
for entry in __APEX_LIST__; do
  case "$entry" in
    *:com.android.vndk.current)
      if mount -t ext4 -o ro /dev/vda${entry%%:*} /apex/com.android.vndk.v31 2>/dev/null; then
        /bb/echo "  [+] /apex/com.android.vndk.v31 (takma ad)"
      fi ;;
  esac
done

# --- /apex/apex-info-list.xml ----------------------------------------------
# DIKKAT (GERI ALMA 2026-10-16, KRITIK): bu dosyayi URETMEK sistemi
# bozuyor. Onceki gerekce "linkerconfig APEX yollarini yazmiyor"
# idi; bu dogruydu ama COZU DEGILDI:
#
#   - linkerconfig bu dosyayi /apex/apex-info-list.xml olarak okuyor
#   - hw/init.rc early-init blogunda init onu "exec" ile calistiriyor:
#       exec -- /system/bin/bootstrap/linkerconfig
#            --target /linkerconfig/bootstrap
#   - Dosya YOKSA linkerconfig ANINDA abort ediyor ve exec hizla
#     donuyor; early-init biter, class core baslar. (HIZLI YOL)
#   - Dosya VARSA linkerconfig CALISIYOR, tam config uretiyor ve
#     init onu BEKLER. TCG emulasyonunda bu dakikalarca suruyor ve
#     su sonucu veriyor:
#         init: starting service ueventd... -> exited status 1
#         (hicbir servis baslamiyor, adbd bile calismiyor)
#   - Ayrica uretilen config APEX kutuphane yollarini zaten
#     icermiyor (olculdu: grep -c apex -> 4, sadece runtime).
#
# Yani dosyanin YOKLUZU bir hata degil, hizli yoldur. Asil kaynak
# zaten bizim fix_ldconfig (search.paths + permitted.paths +
# vendor bolumu). Dosya bilerek URETILMEZ.

# --- linker yapilandirmasi --------------------------------------------------
# DIKKAT (KRITIK HATA DUZELTMESI 2026-10-16): bu cagri KOSULSUZDU ve
# mountapex supervisor dongusunde TEKRAR cagriliyor. Her cagrida
# /linkerconfig/ld.config.txt UZERINE yaziliyor; o da bizim
# yamalanmis configimizi SIFIRLIYOR:
#     W linker: failed to find generated linker configuration from
#               "/linkerconfig/ld.config.txt"
#     F linker: CANNOT LINK EXECUTABLE "/r/system/bin/init":
#               library "libc.so" not found
# linkerconfig'in KENDISI basarisiz (asagida gorulecek) ama yine de
# dosyayi bozuyor. Biz configi kendimiz uretiyoruz (fix_ldconfig).
# COZUM: sadece config HENUZ YOKSA calistir.
mkdir -p /linkerconfig
if [ -f /linkerconfig/ld.config.txt ]; then
  /bb/echo "  ld.config.txt: zaten var, linkerconfig TEKRAR CALISTIRILMADI"
else
  /system/bin/linkerconfig --target /linkerconfig 2>&1 | while read l; do /bb/echo "  $l"; done
fi
N_APEX=$(/bb/grep -c '/apex/' /linkerconfig/ld.config.txt 2>/dev/null)
/bb/echo "  ld.config.txt: ${N_APEX:-0} APEX yolu"

/bb/echo "--- bitti ---"
APEX_EOF
sed -i "s|__APEX_LIST__|$APEX_LIST|g" "$ROOT/bb/mountapex"
sed -i "s|__APEXFILES_PART__|${APEXFILES_PART:-}|g" "$ROOT/bb/mountapex"
sed -i "s|__DATADEV_PART__|${DATA_PART:-}|g" "$ROOT/bb/mountapex"
chmod +x "$ROOT/bb/mountapex"

# --- /bb/rclog --------------------------------------------------------------
# G2 DUZELTMESI: servislerin stdout/stderr'ini gorunur kil.
#
# SORUN: Android init, 'console' tanimlanmayan servislerin stdout/stderr'ini
# /dev/null'a yonlendirir. Sonuc:
#     init: starting service 'apexd-bootstrap'...     gorunur
#     apexd: <hata mesaji>                           ASLA GORUNMEZ
# apexd'in neden critical olarak oldugunu bilmek projenin kilidi; su an bu
# tek bilgi yolda. Script'teki dogru ama yetersiz not:
#     "init servis ciktisini oldugu icin (servis 'console' degil) init'in
#      calistirdigi ueventd'nin ciktisini GOREMIYORUZ."
#
# COZUM: init rc dosyalarini ONCEDEN (/init icinde, exec init'TEN once)
# yamalayip UZERLERINE bind-mount ediyoruz. init ayni dosyalari okuyunca
# yamalimis halini gorur.
#
# NEDEN BIND-MOUNT: /system ve /vendor EROFS -> SALT OKUNUR. Ama bind-mount
# yazma gerektirmez; sadece hedefi degistirir. Dizin agacinin tamamini
# (/overlay-rc) kopyaliyoruz ki 'import' yonlendirmeleri ve goreli yollar
# bozulmasin.
#
# DIKKAT: 'service' taniminin hemen ardina stdout/stderr ekliyoruz. init'in
# ServiceParser'i secenekleri servis satirindan sonra bos satira kadar
# okudugu icin buraya yazmak dogru; ayrica zaten tanimli olanlarda ikinci
# kez yazmak hatĞ° DEGIL (ayni secenek iki kez verilirse sonuncusu gecerli).
cat >"$ROOT/bb/rclog" <<'RC_EOF'
#!/bb/sh
# rc dosyalarini yamalayip servis stdout/stderr'ini /dev/kmsg'ye bagla.
# init'ten ONCE calisir. Kanit ciktisi /dev/kmsg'ye girer.
OVL=/overlay-rc
SRC=/overlay-src
ROOTS=/overlay-roots
# DIKKAT: /init bu scripti exec etmeden ONCE cagirir; /init'in stdout'u
# zaten /dev/kmsg. Yine de kendimiz ceviriyoruz (cift yazimi onler).
exec >/dev/kmsg 2>&1
log() { /bb/echo "$1"; }

log "--- RC YAMALAMA (servis loglari + Kirin modem blokajini kaldirma) ---"
rm -rf "$OVL" "$SRC" 2>/dev/null
mkdir -p "$OVL" "$SRC"
: > "$ROOTS"
# --- VENDORRC anahtari (2026-10-15) ----------------------------------------
# SORUN: vendor_init alt baglami /vendor/etc/init dizinini PARSE ediyor ve
# ~40 ms icinde status 1 ile oluyor. 102 dosyanin HICBIRINI parse etmiyor
# ("Parsing file /vendor" sayisi 0). Yani ilk dosyadan once bir sey
# patliyor. Import yorumunu kaldirmak duzelmedi.
#
# DIKKAT: alt baglam HER KEZ basarisiz oldugunda init '/system/bin/init'i
# 'subcontext' argumanlariyla yeniden fork+exec ediyor. TCG emulasyonunda
# 2.9 MB'lik bir ikiliyi exec etmek pahalI; andinit olay dongusu bu
# yuzden hicbir sey yapamiyor:
#     init: init second stage started!        12.79
#     init: Restarting subcontext ...          17.81  (4.6 sn bosluk)
#     init: starting service 'ueventd'...      39.40
# 'start hwservicemanager' hic olmuyor, o yuzden
#     on fs: wait_for_prop hwservicemanager.ready true
# asili kalir ve post-fs-data HIC BASLAMAZ.
#
# DENEY: VENDORRC=0 ile /vendor/etc/init dizinini BOS olarak bind-mount
# ediyoruz. Alt baglam hicbir sey parse etmeden basarili olmali. Basarili
# olursa sorunun rc ICERIGINDE oldugu kesinlesir; olmazsa sorun init'in
# alt baglam mekanizmasinda demektir.
#
# KAYIP: vendor servisleri (audio, sensor, wifi...) tanimlanmaz. Bu
# Zygote/SystemServer hedefi icin kabul edilebilir; asil yol bu anahtari
# 1 yapip alt baglamin neden patladigini bulmak.
VRC=__VENDORRC__
log "  VENDORRC=$VRC (0 = vendor rc agaci bilerek bos)"
# --- ADIM 1: rc agacini kopyala (dizin seviyesinde) -------------------------
# DIKKAT: dosya dosya bind-mount 216 ayri 'mount' demek; her biri busybox
# fork'u, TCG altinda ~0.3 sn -> 80 saniye. Butun rc agacini kopyalayip
# DIZIN olarak bind-mount ediyoruz: 216 mount -> ~7 mount.
for d in /system/etc/init /vendor/etc/init /odm/etc/init /cust/etc/init \
         /system_ext/etc/init /product/etc/init /hw_product/etc/init; do
  [ -d "$d" ] || continue
  if [ "$VRC" = "0" ] && [ "$d" = "/vendor/etc/init" ]; then
    # Dizin yine de baglanir ama BOS olur: firmware'in vendor rc'si
    # gizlenir, alt baglam hicbir sey bulamaz.
    mkdir -p "$OVL$d" 2>/dev/null
    echo "$d" >> "$ROOTS"
    continue
  fi
  mkdir -p "$SRC$d" 2>/dev/null
  cp -a "$d/." "$SRC$d/" 2>/dev/null || continue
  echo "$d" >> "$ROOTS"
done

# --- ADIM 2: TEK awk gecisi -------------------------------------------------
# DIKKAT: awk'ye dosyalari ARGUMAN olarak veriyoruz (boru hatti degil).
# Boru hattinda FILENAME 'stdin' olur ve cikti dosyasi kaybolur.
# Dosya adlarinda bosluk yok; yalnizca EROFS yollari.
FILES=$(find "$SRC" -name '*.rc' | sort)
NFILE=$(/bb/echo "$FILES" | /bb/grep -c '\.rc$')

#  (1) service satirlarindan sonra stdout/stderr -> /dev/kmsg
#  (2) 'wait <yol> [sures]'  -> 'wait <yol> 0'   (tek seferlik kontrol)
#  (3) 'mount_all ... modem' -> yorum satiri
#
# DIKKAT (2) NEDEN: init'in 'wait' komutu dosya belirinceye kadar bekler.
# QEMU'da Kirin modem yolu ASLA belirmiyor:
#     init: wait for '/sys/devices/platform/balong_mloader/modem_start'
#           timed out and took 30010ms
#     init: Command 'mount_all /vendor/etc/fstab.modem --early' ...
#           took 80257ms and succeeded
# Yani 110 saniye modem olmayan cihaz icin gidiyordu ve init 'post-fs'
# asamasini bitiremedigi icin class main (Zygote) hic baslamiyordu.
# 'wait ... 0' tek bir kontrol demek: dosya yoksa ANINDA basarisiz olur.
#
# DIKKAT (2b) 'wait' satirinin timeout'u OLMADIGI durumda (orn
# 'wait /dev/rfile') sifir ekliyoruz; yoksa sonsuza kadar bloklar.
#
# DIKKAT (3) NEDEN: /vendor/etc/fstab.modem dort wait bayrakli partition
# tanimliyor. formattable oldugu icin fs_mgr once mount, sonra format
# deniyor ve 80 saniye harcıyor. Modem QEMU'da hicbir zaman calismayacak.
#
# DIKKAT: awk "print expr > dosya" ile yazarken dosya ilk acildiginda
# KIRPILIR, sonraki yazmalarda EKLENIR -- istedigimiz sey. Ama cikti dizini
# olusturulmazsa yazma sessizce basarisiz olur; o yuzden dizin degistiginde
# bir kez mkdir -laniyor (dosya sirali oldugu icin ~7 kez).
#
# !!! DIKKAT: BU BLOKTAN SONRAKI YORUMDA TEK TIRNAK KULLANMA !!!
# awk programi shell'in TEK tirnakli dizisi icinde yaziliyor. Yorum
# satirindaki bir kesme isareti diziyi ERKEN kapatir ve uretilen betik
# sozdizimi hatasi verir:
#     bb/rclog: line 104: syntax error near unexpected token `$0'
# Bu tuzak iki kez basina geldi (bind-mount'lari, apexd-yi).
#
# This block is part of the same awk program: no apostrophes allowed.
# !!! DIKKAT: -v OVL=$OVL TEK BASINA YETMEZ !!!
# FILENAME $SRC ile BASLIYOR (/overlay-src/system/etc/init/hw/init.rc).
# "out = OVL FILENAME" yazarsak cikti su adrese gider:
#     /overlay-rc/overlay-src/system/etc/init/hw/init.rc
# ama mount etmeye calistigimiz yer:
#     /overlay-rc/system/etc/init/hw/init.rc
# Aradaki /overlay-src farki tum bind-mountlari sessizce basarisiz
# yapiyor (kosuda "baglanan : 0 rc dizini, 3 basarisiz" olarak gorduk).
# Duzeltme: once SRC onekini kirp, sonra OLV ekle.
# --- DEGISKENLI IMPORT'LARI SOMUTLASTIR (2026-10-16, L4 KOK NEDENI) ----------
# SORUN: asagidaki awk kurali, '${' iceren BUTUN import satirlarini
# yorumluyordu. Bu kural vendor connectivity ALT BAGLAMI oldurmek icin
# konulmusdu (satir 655-672), ama yan tesir olarak su satirlari da
# oldurdurdu:
#     import /system/etc/init/hw/init.${ro.zygote}.rc     <-- ZYGOTE!
#     import /init.${ro.hardware}.rc
#     import /vendor/etc/init/hw/init.${ro.hardware}.rc
# OLCULEN SONUC (adb shell uzerinden, 2026-10-16):
#     [ro.zygote]: [zygote64_32]
#     ls /system/etc/init/hw/init.zygote64_32.rc  -> VAR
#     setprop ctl.start zygote
#       -> "Failed to set property 'ctl.start' to 'zygote'"
# Yani init 'zygote' SERVISINI TANIYAMIYOR, cunku tanimi hic yuklenmedi.
# Daha once sadece ust duzey *.rc dosyalarina bakildigi icin (hw/ bir
# ALT DIZIN) bu import'un yorumlandigi fark edilmemisti.
#
# COZUM: init'in cozumleme zamanina birakmayip degeri prop dosyalarindan
# OKUYUP yolu somutlastiriyoruz. Boylece zamanlama belirsizligi kalir.
#
# DIKKAT: ozelligin hangi DOSYADA oldugunu varsaymiyoruz. Ilk denemede
# yalnizca /system/build.prop'a baktik ve 'ro.zygote=YOK' cikti; oysa
# getprop 'ro.zygote=zygote64_32' donuyor. Olcum:
#     grep -rn "ro.zygote" /system/etc/prop.default /system/etc/*.prop \
#         /vendor/build.prop /system/build.prop
#     /vendor/build.prop:146:ro.zygote=zygote64_32
# Yani deger /vendor/build.prop'ta. Asagidaki tarama sirayla hepsine
# bakar ve ILK tanimi alir -- init ile ayni kural ('ro.' salt-okunur,
# ilk tanim kazanir).
propof() {
  for f in /system/build.prop /vendor/build.prop /odm/etc/build.prop \
           /cust/build.prop /r/system/build.prop /r/vendor/build.prop \
           /system/etc/prop.default ; do
    [ -f "$f" ] || continue
    v=$(/bb/sed -n "s/^$1=//p" "$f" 2>/dev/null | /bb/head -1)
    if [ -n "$v" ]; then echo "$v"; return 0; fi
  done
  # DIKKAT (COZUM 2026-10-16, L4 8. KOK NEDEN): 'ro.hardware'
  # prop DOSYALARINDA YOK; cekirdek komut satirindan geliyor:
  #     Kernel command line: ... androidboot.hardware=qemu
  #     getprop ro.hardware -> qemu
  # Ama donanima ozel rc dosyasi kirin9000:
  #     /vendor/etc/init/hw/init.kirin9000.rc   VAR
  #     /vendor/etc/init/hw/init.qemu.rc        YOK
  # Yani ${ro.hardware} -> qemu -> olmayan dosya -> import
  # basarisiz ve TUM donanim rc agaci yuklenmiyor:
  #     7: import /init.environ.rc
  #     9: # RCYAMALAMA: import /init.${ro.hardware}.rc
  #    10: # RCYAMALAMA: import /vendor/etc/init/hw/init.${ro.hardware}.rc
  #    12: import /system/etc/init/hw/init.zygote64_32.rc
  # Olcut: stok ust servis 122, init tarafindan TANImlanan 38.
  # servicemanager, ueventd, hwservicemanager ve yuzlerce servis
  # hic yuklenmemisti.
  # COZUM: degeri tahmin etmeyelim; diskteki dosyadan TURETILIM.
  if [ "$1" = "ro.hardware" ]; then
    for f in /vendor/etc/init/hw/init.*.rc; do
      [ -f "$f" ] || continue
      b=${f##*/}; b=${b#init.}; b=${b%.rc}
      [ "$b" = "zygote32" ] && continue
      echo "$b"; return 0
    done
  fi
  return 1
}
RO_ZYG=$(propof ro.zygote)
RO_HW=$(propof ro.hardware)
log "  cozulen    : ro.zygote=${RO_ZYG:-YOK} ro.hardware=${RO_HW:-YOK}"
# Yalnizca hedefi GERCEKTEN var olan importlari etkinlestir; yoksa init
# 'Failed to import' der (zararsiz ama gurultu yaratir).
[ -n "$RO_ZYG" ] && [ -f "$SRC/system/etc/init/hw/init.$RO_ZYG.rc" ] || RO_ZYG=""
log "  zygote.rc  : ${RO_ZYG:-yok} (hedef var mi: $([ -n "$RO_ZYG" ] && echo EVET || echo HAYIR))"
/bb/awk -v OVL="$OVL" -v SRC="$SRC" -v ZYG="$RO_ZYG" -v HW="$RO_HW" '
  function iswait(l) { return (l ~ /^[ \t]*wait[ \t]+/) && (l !~ /^[ \t]*#/) }
  function ismodem(l) { return (l ~ /mount_all/) && (l ~ /modem/) && (l !~ /^[ \t]*#/) }
  FNR == 1 {
    rel = FILENAME
    sub("^" SRC, "", rel)
    out = OVL rel
    dir = out
    sub(/\/[^\/]*$/, "", dir)
    if (dir != prevdir) { system("mkdir -p \"" dir "\""); prevdir = dir }
    apexd = 0
  }
  ismodem($0)          { print "# RCYAMALAMA: " $0 > out; nm++; next }
  # DIKKAT (COZUM 2026-10-15): DIKKAT once AYRI YAZILMISTI ve sadece
  # apexd=1 diyordu -- satiri basmiyordu. Sonuc: apexd-bootstrap
  # tanimi PATCHED rc dosyasinda HIC BELIRMIYORDU, init bu servisi
  # tanimlamiyor ve servis hic baslamiyordu (logda starting service
  # satiri yok).
  # Tek kural, iki is: satiri bas + stdio ekle + apexd isaretle.
  #
  # DIKKAT (HATA 2026-10-15): "stdout /dev/kmsg" + "stderr /dev/kmsg"
  # YAZIYORDUK. Bu init surumunde BOYLE BIR SECENEK YOK:
  #     init: /vendor/etc/init/android.hardware.atrace@1.0-service.rc: 20:
  #           Invalid keyword [stdout]
  #     init: /vendor/etc/init/android.hardware.bluetooth@1.1-service.rc: 2:
  #           Invalid keyword [stdout]
  #     init: Subcontext exited with status 1
  # Alt baglam (vendor_init) parse hatasinda CIKIYOR, yani
  # /vendor/etc/init altindaki HICBIR servis tanimlanmiyor. Zincir:
  #     vendor_init olmuyor -> start hwservicemanager calismiyor
  #     -> on fs: wait_for_prop hwservicemanager.ready asili kalir
  #     -> post-fs-data hic baslamaz -> class main tetiklenmez
  #     -> zygote hic baslamaz
  # Yani "gorusurluk icin ekledim" dedigimiz satirlar hicbir seyi
  # gostermiyormus, sadece alt baglami komple dusuruyormus.
  #
  # DOGRU SECENEK: stdio_to_kmsg. init ikilisindeki string listesinde var
  # (satir 2025) ve FIRMWAREIN KENDI rc dosyalari kullaniyor
  # (hw/init.rc -> boringssl_self_test32). Logda bu anahtar icin
  # [Invalid keyword] cikmiyor. Tek satirla stdout VE stderr ikisini birden
  # kmsg uzerine bagliyor.
  /^[ \t]*service[ \t]+/ {
    apexd = ($0 ~ /service[ \t]+apexd-bootstrap[ \t]/)
    svc = $2
    print > out
    print "    stdio_to_kmsg" > out
    # DIKKAT (COZUM 2026-10-16, L4 4. KOK NEDEN): app_process
    # calistiren HER servisin ortamina ANDROID_* ekleniyor.
    #
    # OLCULEN HATA: zygote su mesajla ABORT ediyor:
    #   F DEBUG: Abort message: ANDROID_DATA environment variable unset
    # Elle baslatilip cikti yakalandiginda
    #   (export ANDROID_DATA=/data ANDROID_ROOT=/system) ile
    #   app_process64 -Xzygote ... HATASIZ calisiyor
    # yani zygote saglam, sadece ortam eksik.
    #
    # OLCUM (setenv kapsami): init.environ.rc icinde
    #   on early-init
    #       setenv ANDROID_DATA /data
    # yazmistik ve ISLE YAPMADI. Cunku init "setenv" komutunu
    # SERVIS BLOGUNUN ICINDE kullanir; orada o servisin ortamina
    # eklenir. Kanit ayni dosyada duruyor:
    #   service adbd ...
    #       setenv LD_LIBRARY_PATH /apex/com.android.adbd/lib64
    # ve adbd gercekten
    #   LD_LIBRARY_PATH=/apex/com.android.adbd/lib64
    # ile calisiyor. Buna karsi "on" aksiyonundaki setenv
    # servis ortamina GECMIYOR:
    #   tr \0 \n < /proc/<logd>/environ
    #   -> PATH, CUST_POLICY_DIRS, DOWNLOAD_CACHE, ANDROID_SOCKET_*
    #      ama LD_LIBRARY_PATH ve ANDROID_DATA YOK.
    #
    # Kapsam: satiri app_process gecen her servis (zygote,
    # zygote_secondary, arkinit, mygote vb.). Hepsi ayni hatayi
    # veriyordu: logcat icinde hem "--socket-name=zygote" hem
    # "--socket-name=arkinit" icin ANDROID_DATA abortu vardi.
    if ($0 ~ /app_process/) {
      print "    setenv ANDROID_DATA /data" > out
      print "    setenv ANDROID_ROOT /system" > out
      print "    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art" > out
      print "    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata" > out
      print "    setenv ANDROID_IOTA_ROOT /apex/com.android.iota" > out
      nenv++
    }
    next
  }
  # DIKKAT: apexd-bootstrap "critical" idi. Servicemanager bir sebepten
  # 127 ile cikip onrestart ile apexd servisini yeniden baslatiyor; apexd
  # de bizim mount ettigimiz /apex gorunce "0 packages" deyip kapaniyor ve
  # critical oldugu icin init TUM sistemi kapatiyor:
  #     init: Service "servicemanager" (pid 1009) exited with status 127
  #     apexd: Unmount all subcommand detected
  #     apexd: 0 packages restored.
  #     reboot: "bootloader,bootstrap-apexd-failed"
  # Emulatorda APEX KENDIMIZ bagliyoruz; apexd olmadan da sistem ayaga
  # kalkiyor. Bu bayragi kaldirmak, apexd coktugunde sistemin geri
  # kalaninin yasamaya devam etmesini sagliyor.
  #
  # DIKKAT: BU YORUMDA TEK TIRNAK KULLANMA. awk programi shell TEK
  # tirnakli dizisi icinde; bir kesme isareti diziyi erken kapatir ve
  # uretilen betik sozdizimi hatasi verir:
  #     bb/rclog: line 99: syntax error near unexpected token dollar-0
  # DIKKAT (COZUM 2026-10-15): rebootun GERCEK kaynagi bulundu.
  # Firmware rc dosyasi (system/etc/init/apexd.rc) soyle diyor:
  #     service apexd-bootstrap /system/bin/apexd --bootstrap
  #         oneshot
  #         disabled
  #         reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
  # ve hw/init.rc de:
  #     on early-init
  #         exec_start apexd-bootstrap
  # Yani init, apexd-bootstrap bir sey dondurunce KENDISI sistemi
  # kapatiyor. Daha once bu yuzden apexd-bootstrap tanimindaki
  # "critical" bayragini kaldirmistik; BU YANLIS KADRAI YARIMDI,
  # cunku kritik degil, reboot_on_failure tetikliyordu.
  # init kaynakli oldugu icin bu bayrak kalinca reboot KACINILMAZ.
  #
  # Emulator politikasi: TEK bir servisin cokmesi butun emulatoru
  # dusurmesin. reboot_on_failure satirlari yorum haline getirilir
  # ve hangi servisler icin kaldirildigi RAPORLANIR. Boylece
  # gozlem yapabiliriz; uretim cihazinda bu kural gecerli degildir.
  /^[ \t]*reboot_on_failure[ \t]/ {
    print "# RCYAMALAMA(reboot kapali): " $0 > out
    print "    # servis: " svc > out
    nrf++; next
  }
  # "shutdown critical" de ayni kapiyi acar (shutdown sirasinda
  # kritik servisler varsa init onlari da durdurup bekler).
  /^[ \t]*shutdown[ \t]+critical[ \t]*$/ {
    print "# RCYAMALAMA(shutdown kapali): " $0 > out
    print "    # servis: " svc > out
    nsc++; next
  }
  # DIKKAT: "writepid" satirlari /dev/cpuset, /dev/blkio, /dev/cpuctl,
  # /dev/stune gibi cgroup dugumlerine yaziyor. BU CEKIRDEKTE O DUGUMLER
  # YOK (cgroup: Unknown subsys name schedtune). Satiri yoruma almak
  # zararsiz; servis kaydi bozulmaz, sadece surec yazma izni kaybolur.
  /^[ \t]*writepid[ \t]/ {
    print "# RCYAMALAMA(cgroup yok): " $0 > out
    nwp++; next
  }
  # DIKKAT (COZUM 2026-10-15): BU SATIR vendor_init alt baglamini
  # OLDURUYOR.
  #   import /vendor/etc/init/connectivity/init.connectivity.${ro.boot.odm.conn.chiptype}.rc
  # init bu yolu ozellikle COZER. ro.boot.odm.conn.chiptype bir BOOTLOADER
  # ozelligi; firmwarein bes bolumundeki TUM .prop dosyalari tarandi ve
  # HICBIR YERDE tanimli degil (bkz. _erofs-findprop.sh). Yani genisleme
  # bos stringe duser ve init şu dosyayi arar:
  #     /vendor/etc/init/connectivity/init.connectivity..rc
  # o da yok -> "Failed to import" -> ALT BAGLAM CIKIYOR:
  #     init: Subcontext exited with status 1
  # ve /vendor/etc/init altindaki 102 dosyanin hicbiri tanimlanmiyor.
  # (Bu dizinde 7 cip-spesifik dosya var: bcm43455, bcm4359, bcm43xx,
  #  gps, hi1103, hi1105, hisi -- hangisinin dogru oldugunu firmware
  #  bize SOVMUYOR, o yuzden tahmin etmiyoruz.)
  #
  # Bizim icin bu servislerin hicbir anlami yok: QEMU altinda ne WiFi ne
  # Bluetooth ne GPS donanimi yok. Import satiri yorumlanir; kaybettigimiz
  # sadece connectivity servisleri.
  # DIKKAT (COZUM 2026-10-16): Bu kural YALNIZCA gercekten cozulemeyen
  # degiskenli import satirlarini yorumlar. Once bilinen iki ozelligi
  # SOMUT yola ceviriyoruz (ro.zygote, ro.hardware) -- bunlar
  # build.prop dosyasinda GERCEKTEN tanimli ve hedef dosyalar diskte var
  # (olculerek dogrulandi). Satir 12 deki zygote import satiri bu
  # sayede KURTARILDI; oncesi durum:
  #     setprop ctl.start zygote -> "Failed to set property"
  /^[ \t]*import[ \t]+.*[$][{]/ {
    ln = $0
    if (ZYG != "") { gsub(/[$][{]ro\.zygote[}]/, ZYG, ln) }
    if (HW  != "") { gsub(/[$][{]ro\.hardware[}]/, HW, ln) }
    # DIKKAT (DUZELTME 2026-10-16): vendor tarafi bilerek BOS
    # birakilir. Satiri basinda not: "VENDORRC=0 (0 = vendor rc agaci
    # bilerek bos)". Once donanim import u COZULMEDIGI icin bu
    # gecerliydi; simdi cozulunca vendor alt baglami 100+ dosyayi
    # PARSE etmeye calisiyor ve sistemi cokertiyor:
    #     init: Subcontext exited with status 1
    #     init: Service ueventd (pid 4173) exited with status 1
    #     init: critical process ueventd exited 4 times before
    #           boot completed  -> boot DONUYOR
    # System tarafi (/init.kirin9000.rc) ACIK kalir; servicemanager,
    # hwservicemanager ve yuzlerce servis oradan geliyor.
    if (ln ~ /^[ \t]*import[ \t]+\/vendor\//) {
      print "# RCYAMALAMA(vendor rc bilerek bos): " $0 > out
      nimp++; next
    }
    if (ln !~ /[$][{]/) {
      print ln > out
      nimpok++; next
    }
    print "# RCYAMALAMA(import cozulemedi, yorumlandi): " $0 > out
    nimp++; next
  }
  # "file <yol> <mod>" servise acilis fd verir. /dev/kmsg erisimi
  # SELinux erisimine tabi; alt baglamda sorun cikarabilir. Bizim ihtiyacimiz
  # yok, cunku zaten stdio_to_kmsg ile her servisin ciktisini aliyoruz.
  /^[ \t]*file[ \t]+\// {
    print "# RCYAMALAMA(fd kaldirildi): " $0 > out
    nfl++; next
  }
  # DIKKAT: BU SATIR BOGU ACIYOR. init, APEX verisi yuklendi bayragini
  # SADECE perform_apex_config komutuyla kaldirir ve o komut yalnizca
  # burada, "apexd.status == activated" olduktan SONRA cagrilir:
  #     on post-fs-data
  #         wait_for_prop apexd.status activated
  #         perform_apex_config
  # apexd normal modda kendini baslatip APEXleri aktiflestirmeye
  # calisiyor ama QEMU altinda "0 packages restored" deyip basarisiz
  # oluyor.
  # Biz APEXleri KENDIMIZ bagladik ve ld.config.txt dosyasini 26 yolla
  # yamladik, yani istenen durum zaten saglandi; beklemenin bir
  # anlami yok. Bu yuzden bekleme yerine durumu elle veriyoruz. Sonuc:
  # init, netd gibi updatable servisleri "Queued for execution"
  # diye birakmak yerine BASLATIYOR:
  #     init: Cannot start an updatable service netd before configs
  #           from APEXes are all loaded.
  /^[ \t]*wait_for_prop[ \t]+apexd\.status[ \t]+activated[ \t]*$/ {
    print "    setprop apexd.status activated  # RCYAMALAMA: bekleme yerine elle" > out
    nap++; next
  }
  apexd && /^[ \t]*critical[ \t]*$/ { nc++; next }
  /^[ \t]*$/ { apexd = 0 }
  # DIKKAT: kalan critical servisleri RAPORLA. init, critical bir servis
  # coktugunde sys.powerctl ayarlar ve sistem KAPANIR:
  #     init: Got shutdown_command reboot,bootloader,bootstrap-apexd-failed
  # Bu blok bize hangi servis oldugunu soyler. Onceki kosuda
  # apexd-bootstrap satiri temizlendikten SONRA da shutdown gelmeye
  # devam etti; demek ki BASKA bir critical servis var.
  # Satiri SILMIYORUZ (bu blok yalnizca sayar), sadece yorum olarak
  # isaretliyoruz ki logda hangileri kaldigini gorelim.
  # DIKKAT (2026-10-16, DENEME #1 BAŞARISIZ): once init in KENDI
  # linkerconfig calistirmasini tumden yorumlamayi denedik. SONUC:
  # config HIC OLUSMADI --
  #     ### DGN global adbd: grep: /linkerconfig/ld.config.txt:
  #       No such file or directory
  # ve adbd dusersiz kaldi (CANNOT LINK / CANNOT CONNECT).
  # Sebep: bizim yamamiz ORIJINAL dosyayi okuyup ustune yaziyor;
  # dosyayi URETEN sey init in linkerconfig iydi. Yorumlayinca
  # kaynak da yok oldu.
  # GERI ALINDI. Dogru yol: init yazsin, biz yedek alip kendi
  # halimizi geri yukleyelim (fix_ldconfig).
  # DIKKAT (DUZELTME 2026-10-16): bu kural YANLISLIKLA silinmisti;
  # geri konuldu. Sonra da dar kaldi: yalnizca TAM OLARAK "critical"
  # yazan satirlari yakaliyordu. Parametreli olanlar KACIYORDU:
  #     critical window=${zygote.critical_window.minute:-4}
  #                          target=zygote-fatal
  # Logda 11 servis critical olarak kaliyordu.
  #
  # ETKI (olculdu): critical bir servis 4 kez coktugunda init TUM
  # bootu BIRAKIYOR:
  #     init: Service ueventd (pid 3574) exited with status 1
  #     init: critical process ueventd exited 4 times before
  #           boot completed
  # ve sistem NABIZ#0 da DONUYOR (supervise disinda hicbir surec).
  # Bu, projenin en bastan beri kabul edilen politikaya aykiridir:
  # hicbir servis tek basina sistemi kapatmamali.
  # COZUM: tum critical bayraklarini kaldir. Servis yine
  # yeniden baslatilir, ama init vazgecip bootu BIRAKMAZ.
  # DIKKAT (COZUM 2026-10-16, L4 10. KOK NEDEN): /linkerconfig
  # UZERINE baglanan satiri iptal et.
  #
  # /system/etc/init/hw/init.rc:68
  #     mount none /linkerconfig/bootstrap /linkerconfig bind rec
  #
  # OLCULEN ETKI: /proc/mounts icinde /linkerconfig IKINCI KEZ
  # mount edilmis gorunuyor:
  #     tmpfs /linkerconfig tmpfs rw,seclabel,...
  #     tmpfs /linkerconfig tmpfs rw,seclabel,...   <- ustunu kapatti
  # Biz dosyayi IKINCI mountun kokune yaziyoruz; ama daha eski bir
  # mount namespaceinde calisan surecler (ornegin vendor alt
  # baglami) BIRINCI, yani BOS mountu goruyor. Sonuc:
  #     W linker : failed to find generated linker configuration
  #                from "/linkerconfig/ld.config.txt"
  #     F linker : CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #                library "libc.so" not found
  # Dosya diskte VAR ve dogru (ls + head ile dogrulandi, 15 sn
  # boyunca degismiyor) ama linker acamiyor.
  #
  # DIKKAT: "bind rec" OZYINULEMELI oldugu icin /linkerconfig
  # kendi alt dizinine baglanir. Bu yuzden iptal ediyoruz.
  # Biz zaten /linkerconfig/ld.config.txt, /linkerconfig/bootstrap/
  # ve /linkerconfig/default/ altina ATOMIK olarak yaziyoruz.
  /^[ \t]*mount[ \t]+none[ \t]+\/linkerconfig/ {
    print "# RCYAMALAMA(linkerconfig bind rec iptal): " $0 > out
    nbind++; next
  }
  # DIKKAT (HATA DUZELTMESI 2026-10-17, L4): bu kural satiri
  # YORUMLAMIYORDU, sadece altina bir yorum ekliyordu:
  #     print > out                    <- satir AKTIF kalir
  # OLCULEN ETKI (init ciktisi):
  #     init: critical process ZYGOTE exited 4 times before boot
  #            completed
  # Yani critical bayragi hala gecerliydi. init.zygote*.rc icinde:
  #     critical window=${zygote.critical_window.minute:-4}
  #              target=zygote-fatal
  # 4 dakika siniri dolunca zygote-fatal hedefi tetiklenir
  # (guc kesme). Emulator politikamiz: HICBIR servis tek basina
  # sistemi kapatmamali. Bu yuzden satiri gercekten yorumluyoruz.
  /^[ \t]*critical([ \t]|$)/ {
    print "    # RCYAMALAMA(critical kaldirildi): " $0 > out
    print "    # CRITICAL-KALIYOR: " svc > out
    crit++; next
  }
  iswait($0) {
    l = $0
    sub(/[ \t]+$/, "", l)
    if (l ~ /[ \t][0-9]+$/) sub(/[ \t][0-9]+$/, "", l)
    print l " 0" > out
    nw++
    next
  }
  { print > out }
  END { printf "%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", NR, nw, nm, nc, crit, nrf, nsc, nap, nwp, nfl, nimp, nimpok, nenv, nbind }
' $FILES > /tmp/rclog.stats 2>/dev/null

STATS=$(/bb/cat /tmp/rclog.stats 2>/dev/null)
NOWAIT=$(/bb/echo "$STATS" | /bb/awk '{print $2+0}')
NOMODEM=$(/bb/echo "$STATS" | /bb/awk '{print $3+0}')
NOCRIT=$(/bb/echo "$STATS" | /bb/awk '{print $4+0}')
NCRIT2=$(/bb/echo "$STATS" | /bb/awk '{print $5+0}')
NREBOOT=$(/bb/echo "$STATS" | /bb/awk '{print $6+0}')
NSHUT=$(/bb/echo "$STATS" | /bb/awk '{print $7+0}')
NAPEXW=$(/bb/echo "$STATS" | /bb/awk '{print $8+0}')
NWPID=$(/bb/echo "$STATS" | /bb/awk '{print $9+0}')
NFLD=$(/bb/echo "$STATS" | /bb/awk '{print $10+0}')
NIMP=$(/bb/echo "$STATS" | /bb/awk '{print $11+0}')
NIMPOK=$(/bb/echo "$STATS" | /bb/awk '{print $12+0}')
# DIKKAT: NIMPOK 0 ise zygote import'u YINE yorumlanmis demektir.
# Bu sayac sifirken "cozulen ro.zygote" logu yalan soyleyebilir.
[ "${NIMPOK:-0}" -eq 0 ] && log "  [UYARI] hicbir import somutlastirilamadi (zygote yine yok)"
NENV=$(/bb/echo "$STATS" | /bb/awk '{print $13+0}')
# DIKKAT: NENV 0 ise hicbir app_process servisine ANDROID_DATA
# verilmedi demektir; zygote "ANDROID_DATA environment variable
# unset" ile abort eder. Sayac olcum aracinin parcasidir.
log "  android_env: $NENV app_process servisi icin eklendi"
NBIND=$(/bb/echo "$STATS" | /bb/awk '{print $14+0}')
# DIKKAT: linkerconfig bind rec iptal edilmediyse /linkerconfig
# iki kez mount edilir ve bazi surecler bos olani gorur.
[ "${NBIND:-0}" -eq 0 ] || log "  linkerconfig bind rec: $NBIND satirda iptal EDILDI (dogru)"

# --- ADIM 3: dogrula ve dizin olarak bagla ---------------------------------
# DIKKAT: init ilk asamada rc parse edemezse TUM sistem duser. Yedek ag:
#  - kopyalanan agac ozgulinin TAMAMI olmali (eksik dosya = eksik servis)
#  - servis sayisi degismemis olmali
#  - sonra bind-mount
sumsvc() { /bb/grep -rhcE '^[ \t]*service[ \t]' $1 2>/dev/null | /bb/awk '{s+=$1} END{print s+0}'; }
SVCA=$(sumsvc "$SRC")
SVCB=$(sumsvc "$OVL")
if [ "${SVCB:-0}" -ne "${SVCA:-0}" ] || [ "${SVCA:-0}" -eq 0 ]; then
  log "  [HATA] servis sayisi uyusmadi (kaynak=$SVCA yamalimis=$SVCB) -> BIND-MOUNT YAPILMADI"
  exit 1
fi

PATCHED=0; FAILED=0
while read -r d; do
  [ -n "$d" ] || continue
  if [ ! -d "$OVL$d" ]; then
    log "  [HATA] $d: yamalimis agac yok ($OVL$d) -> bind-mount yapilmadi"
    FAILED=$((FAILED+1)); continue
  fi
  a=$(find "$d" -type f | wc -l)
  b=$(find "$OVL$d" -type f | wc -l)
  if [ "$a" -ne "$b" ]; then
    log "  [HATA] $d: dosya sayisi tutmadi (kaynak=$a yamalimis=$b) -> atlandi"
    FAILED=$((FAILED+1)); continue
  fi
  # DIKKAT: mount hatasinin metnini yaziyoruz. '2>/dev/null' ile yutulursa
  # neden basarisiz oldugunu ogrenmenin YOLU kalmaz; bir sonraki kosu
  # ayni seyi ayni sekilde basarisiz yapar.
  if e=$(mount -o bind "$OVL$d" "$d" 2>&1); then
    PATCHED=$((PATCHED+1))
  else
    log "  [HATA] $d: mount -o bind basarisiz -> ${e:-bilinmiyor}"
    FAILED=$((FAILED+1))
  fi
done < "$ROOTS"

log "  rc dosyasi : $NFILE ($SVCA servis)"
log "  baglanan   : $PATCHED rc dizini, $FAILED basarisiz"
log "  wait->0    : $NOWAIT (Kirin modem beklemesi kaldirildi)"
log "  modem off  : $NOMODEM (mount_all ... modem yorum satiri)"
log "  critical-  : $NOCRIT (apexd-bootstrap critical bayragi kaldirildi)"
log "  critical?  : $NCRIT2 servis daha critical (yorum olarak isaretli)"
log "  reboot_kpl : $NREBOOT reboot_on_failure satiri yorumlandi (emulator)"
log "  shutdown_k : $NSHUT shutdown critical satiri yorumlandi"
log "  apexd.stat : $NAPEXW adet bekleme -> setprop apexd.status activated"
log "  writepid   : $NWPID satır yorumlandi (cgroup dugumu yok)"
log "  file fd    : $NFLD satır yorumlandi (/dev/kmsg erisimi)"
log "  import     : $NIMP degiskenli import yorumlandi (alt baglami olduruyordu)"
if [ "${NCRIT2:-0}" -gt 0 ]; then
  # DIKKAT: bu listeyi satir satir basmak YANLIS. 11 satir ardisik
  # yazildiginda kernel bunlari toplu "suppressed" diye yutuyor:
  #     printk: rclog: 10 output lines suppressed due to ratelimiting
  # ve hicbir servis adini goremiyorduk. Tek satir, kesilmis.
  CL=$(/bb/grep -rh 'CRITICAL-KALIYOR' "$OVL" 2>/dev/null \
       | /bb/sed 's/^ *# *CRITICAL-KALIYOR: *//' \
       | /bb/sort -u | /bb/tr '\n' ' ')
  log "  kritik    : ${CL:0:300}"
fi
log "--- RC YAMALAMA HAZIR ---"
RC_EOF
chmod +x "$ROOT/bb/rclog"
# DIKKAT (DUZELTME 2026-10-16): varsayilan 1 idi (vendor rc agaci
# ACIK). Ama vendor alt baglami OZGUNDEKI ~100 dosyayi parse
# edemiyor ve SESSIZCE status 1 ile oluyor:
#     init: Forked subcontext for u:r:vendor_init:s0 with pid N
#     init: Subcontext exited with status 1
# ve bundan gelen sistem komutlari HEPSI basarisiz oluyor:
#     init: Command 'chown media media /dev/soundtrigger_dma_drv'
#           (/vendor/etc/init/init.audio.rc:15) failed:
#           Failed to receive result from subcontext
# Bu, emulasyonda isimize yaramaz (Kirin ses/gps/wifi donanimi
# yok) ama sistem komutlarini bozuyor. Tasarimdaki NIYET zaten
# bos birakmakti; varsayilan yanlislikla 1 birakilmis.
# COZUM: varsayilan 0. Istenirse VENDORRC=1 ile geri acilir.
sed -i "s|__VENDORRC__|${VENDORRC:-0}|g" "$ROOT/bb/rclog"

# --- /bb/supervise ----------------------------------------------------------
# Arka planda calisan denetleyici. Iki isi var:
#
# 1) SELinux'u kalici PERMISSIVE birakmak.
#    DIKKAT: selinuxfs'i /init icinde mount ETMEK yanlis -- init birinci
#    asamada "Device or resource busy" alip OLUR:
#      init: Init encountered errors starting first stage, aborting
#    Dogru zaman, selinuxfs hazir olur olmaz. enforce dosyasi SELinux
#    pseudo-dosyasi; duz bir dosyaya bind mount edince init'in "1" yazmasi
#    cekirdege ulasmaz.
#
# 2) /apex'i TAZELEMEK -- asil sorun bu. init (apexd-bootstrap) /apex'in
#    UZERINE bos bir tmpfs mount ediyor; 22 APEX mount'u altta kaliyor ama
#    gizleniyor:
#      gozlem: apex=0   ama /proc/mounts'ta 22 apex mount'u
#    Sonuc: /system/lib64/libc.so -> /apex/com.android.runtime/lib64/bionic/
#    libc.so symlink'i kirilir ve init'in baslattigi HER sey baglanamaz:
#      apexd: CANNOT LINK ... library "libc.so" not found
#      init:  cannot execv('/system/bin/app_process64')      â† ZYGOTE
#    Bir sefer yapip birakmak yetmez; /apex her bosaldiginda yeniden
#    mount ediyor.
cat >"$ROOT/bb/supervise" <<'SUP_EOF'
#!/bb/sh
# HarmonyOS emu: /apex ve SELinux denetleyicisi.
#
# DIKKAT: bu script /init'ten setsid ile baslatilir, yani /init'in
# stdout'unu (artik /dev/kmsg) devralir. Yine de KENDIMIZ ceviriyoruz:
# script'i elle calistirmak istedigimizde (/bb/supervise) stdout duz
# ekrana gider ve teÅŸhis kaybolur.
exec >/dev/kmsg 2>&1
m() { /bb/echo "$1"; }

# --- adbd: L5'e en kisa yol (2026-10-15) -------------------------------------
# DIKKAT: zygote/SystemServer yolu çok uzun ve vendor_init'a bagli.
# Ama adbd TAMAMEN BAGIMSIZ bir ikilidir: framework, zygote, SurfaceFlinger
# hicbiri gerekmez. Firmware rc'sinde tanimi:
#     service adbd /apex/com.android.adbd/bin/adbd --root_seclabel=u:r:su:s0
#         class core
#         socket adbd seqpacket 660 system system
#         disabled
# Yani 'disabled' ve USB tetikleyicilerine bagli; QEMU'da USB gadget
# olmadigi icin HICBIR ZAMAN baslamaz. Ama adbd'nin TCP modu var:
#     adbd tcp:5555
# APEX'i biz bagliyoruz (/apex/com.android.adbd) ve QEMU'ya
# 'hostfwd=tcp::5555-:5555' ekledik. Windows tarafinda adb.exe zaten
# var (Android\Sdk\platform-tools), yani:
#     adb connect 127.0.0.1:5555
#     adb shell
# ile GERCEK BIR SHELL acilir.
#
# DIKKAT: adbd ro.debuggable/ro.secure degerlerine bakar. Kernel komut
# satirimizda androidboot.debuggable=1 ve androidboot.secure=0 var, yani
# root erisimi mumkun olmali.
# DIKKAT (COZUM 2026-10-15, adbd'nin ONCEKI ENGELI "libadb_protos.so"):
#
# Gozlem:
#   linker: Warning: couldn't read config file
#           "/apex/com.android.adbd/etc/ld.config.txt"
#           for "/apex/com.android.adbd/bin/adbd"
#   CANNOT LINK EXECUTABLE ...: library "libadb_protos.so" not found
#
# Yani link icindeki ikililer icin linker GLOBAL /linkerconfig/ld.config.txt
# dosyasini DEGIL, APEX'e ozel <apex>/etc/ld.config.txt dosyasini okuyor.
# Bizim 58 APEX yolu ekledigimiz global dosya bu yuzden adbd'ye hic yaramadi.
# APEX'in kendi etc/ dizininde ld.config.txt YOK (yalnizca init.rc var) --
# dogrulandi: com.android.adbd.apex acilip listelendi.
#
# Olcutulen arama yollari (readelf -d + erofs listesi):
#   /apex/com.android.adbd/lib64  -> libadb_protos, libbase, libc++,
#                                   libcrypto, libcutils, protobuf
#   /system/lib64                 -> libadbd_fs.so, libadbd_auth.so,
#                                   liblog.so, libselinux.so
#   /apex/com.android.runtime/lib64/bonic -> libc, libm, libdl
# Yani global config'i okuyan linkerde bu yolun TAMAMI zaten vardi ve
# linker adbd icin sadece /apex/com.android.adbd/lib64'i kaybediyordu.
adbd_ldconfig() {
  # DIKKAT (ZAMANLAMA, 2026-10-15): bu fonksiyon supervisor'in
  # dongusunde n>=3'te cagriliyor ama /apex/com.android.adbd O AN
  # henuz mount edilmemis olabiliyor; o durumda '[ -x .../bin/adbd ]'
  # kontrolu gecer ama 'mount -o bind .../etc' BAŞARISIZ olur ve
  # fonksiyon bir daha DENEMEZ (dosya olmadigi icin ust satirdaki
  # koruma da gecmez -- aslinda gecer, ama bind hatasini gordukten
  # sonra surec cokmus oluyor).
  # Olcut: "### adbd ld.config: bind BASARISIZ" n=3'te, sonraki
  # kosularda da hep ayni. Cozum: APEX mount'unu bekle.
  if [ ! -x /apex/com.android.adbd/bin/adbd ]; then
    ld_wait=$(( ${ld_wait:-0} + 1 ))
    return 0
  fi
  [ -f /apex/com.android.adbd/etc/ld.config.txt ] && return 0
  mkdir -p /bb/nb/adbdld /bb/nb/adbdetc 2>/bb/null || return 0
  {
    echo "dir.system = /system/bin/:/system/lib64/:/apex/com.android.runtime/lib64/bionic/:/apex/com.android.adbd/bin/:/apex/com.android.adbd/lib64/"
    echo "dir.apex_com.android.adbd = /apex/com.android.adbd/bin/:/apex/com.android.adbd/lib64/"
    echo ""
    echo "[system]"
    echo "namespace.default.search.paths = /system/bin:/system/lib64:/apex/com.android.runtime/lib64/bionic:/apex/com.android.adbd/lib64"
    echo "namespace.default.links = /system/bin:/system/lib64"
    echo "namespace.default.interpreter = /system/bin/linker64"
    echo "namespace.default.isolated = false"
    echo "namespace.default.per_library_path = false"
    echo ""
    echo "[apex_com.android.adbd]"
    echo "namespace.default.search.paths = /apex/com.android.adbd/bin:/apex/com.android.adbd/lib64:/system/lib64:/apex/com.android.runtime/lib64/bionic"
    echo "namespace.default.links = /system/bin:/system/lib64"
    echo "namespace.default.interpreter = /system/bin/linker64"
    echo "namespace.default.isolated = false"
    echo "namespace.default.per_library_path = false"
  } > /bb/nb/adbdld/ld.config.txt 2>/bb/null
  [ -s /bb/nb/adbdld/ld.config.txt ] || return 0
  # DIKKAT (2026-10-15 TEK SEFERLIK TEŞHİS): config yazildi ama linker
  # uygulamiyor gibi. Elimizde sadece "ilk bulunamayan = libadb_protos.so"
  # olgusu var ve bu IKI hipotezi ayirt edemiyor:
  #   (a) linker config'i okumuyor/uygulamiyor (built-in default yollar:
  #       /system/bin:/system/lib64:/apex/.../bonic)
  #   (b) config uygulaniyor ama /apex/com.android.adbd/lib64 bos
  # Ayirt edici olcut: /system/lib64'te libadbd_fs, liblog, libselinux,
  # libbase, libc++, libcrypto, libcutils VAR; libadb_protos.so YOK.
  # Yani "(a) dogrudan kanitli" -- ama emin olmak icin asagidakileri
  # bir kez basilip bir daha silinmiyor (adbd_diag bayragi).
  if [ "${adbd_diag:-0}" != "1" ]; then
    adbd_diag=1
    m "### DGN apex lib64 : $(/bb/ls /apex/com.android.adbd/lib64 2>&1 | /bb/tr '\n' ' ')"
    m "### DGN libadb_pro: $(/bb/ls -l /apex/com.android.adbd/lib64/libadb_protos.so /system/lib64/libadb_protos.so 2>&1 | /bb/tr '\n' ' ')"
    m "### DGN bizim cfg  : $(/bb/head -3 /bb/nb/adbdld/ld.config.txt 2>&1 | /bb/tr '\n' '|')"
    m "### DGN global adbd: $(/bb/grep -n 'com.android.adbd' /linkerconfig/ld.config.txt 2>&1 | /bb/tr '\n' '|')"
    m "### DGN apex etc   : $(/bb/ls /apex/com.android.adbd/etc 2>&1 | /bb/tr '\n' ' ')"
  fi
  # DIKKAT: /apex/com.android.adbd/etc dizini APEX'te SALT OKUNUR. Onun
  # USTUNE dizin bind-mount edebiliriz (alt yazi sistemine yazmadan),
  # ama o zaman altindaki init.rc gizlenir -- onu kopyaliyoruz.
  cp /bb/nb/adbdld/ld.config.txt /bb/nb/adbdetc/ld.config.txt 2>/bb/null
  cp /apex/com.android.adbd/etc/init.rc /bb/nb/adbdetc/init.rc 2>/bb/null
  if mount -o bind /bb/nb/adbdetc /apex/com.android.adbd/etc 2>/bb/null; then
    m "### adbd ld.config: /apex/com.android.adbd/etc/ld.config.txt bind ile hazir (bekleme=${ld_wait:-0})"
  else
    ld_bad=$(( ${ld_bad:-0} + 1 ))
    # DIKKAT: hata kalici degil. mount n=3'te basarisiz olabiliyor
    # (APEX henuz bagli degil); bir sonraki turda tekrar deniyoruz.
    [ "$ld_bad" -le 3 ] && m "### adbd ld.config: bind BASARISIZ (#$ld_bad, tekrar denenecek)"
  fi
  return 0
}

ensure_net() {
  # DIKKAT: konukta eth0 var mi? /sys/class/net altinda arariz.
  found=""
  for i in /sys/class/net/*/; do
    iname=${i#/sys/class/net/}; iname=${iname%/}
    [ "$iname" = "lo" ] && continue
    found="$iname"
    break
  done
  if [ -z "$found" ]; then
    [ "${net_said:-0}" = "1" ] && return 0
    net_said=1
    m "### net: /sys/class/net bos -- eth0 YOK, hostfwd calisamaz"
    return 0
  fi
  # IP zaten varsa bir sey yapma (sadece bir kez yaz).
  if [ "${net_ok:-0}" != "1" ]; then
    /bb/ip addr add 10.0.2.15/24 dev "$found" 2>/bb/null
    /bb/ip link set "$found" up 2>/bb/null
    /bb/ip route add default via 10.0.2.2 dev "$found" 2>/bb/null
    /bb/ip addr show "$found" 2>/bb/null | /bb/head -3 > /bb/nb/net.out 2>/bb/null
  fi
  # Her turda dogrula; IP kaybolursa (link down) yeniden kur.
  if /bb/ip -o addr show "$found" 2>/bb/null | /bb/grep -q '10.0.2.15'; then
    net_ok=1
    return 0
  fi
  net_ok=0
  /bb/ip addr add 10.0.2.15/24 dev "$found" 2>/bb/null
  /bb/ip link set "$found" up 2>/bb/null
  /bb/ip route add default via 10.0.2.2 dev "$found" 2>/bb/null
  [ "${net_said2:-0}" = "1" ] && return 0
  net_said2=1
  m "### net: $found hazirlandi 10.0.2.15/24 gw 10.0.2.2"
  return 0
}

# --- L4: /data dizinleri + zygote -------------------------------------------
# DIKKAT (OLCUM KAPANISI 2026-10-16): zygote elle baslatildiginda
#     Error creating cache dir /data/dalvik-cache/arm64
#         : No such file or directory
#     Aborted
# /data bizim tmpfs'imiz (2.0G) ve BOS. vold her 5 saniyede
#     cokuyor: Check failed: android::vold::sBlkidContext != nullptr
# ve icerigi kurulmuyor. Dalvik cache olmadan zygote ABORT ediyor.
#
# DIKKAT (neden init rc'sinde degil): 'on post-fs-data' tetigi
# init'in fs_manager'indan gelir; /data'yi INIT degil BIZ mount
# ettigimiz icin tetik HIC gelmiyor. Kanit: init.environ.rc'deki
# 'on early-init' calisiyor (ro.crypto.state yazildi) ama
# 'on post-fs-data' hicbir iz birakmiyor ve /data BOS kaliyor.
# Bu yuzden dizinleri mount ettigimiz yere kuruyoruz.
DATA_DIRS="dalvik-cache dalvik-cache/arm dalvik-cache/arm64
dalvik-cache/x86 dalvik-cache/x86_64 system system/packages
misc local local/tmp app media media/0 user user/0"
ensure_data_dirs() {
  # DIKKAT (DUZELTME 2026-10-16): bir kez "yapildi" bayragi koyuyorduk.
  # Ama /data tmpfs'i sonradan yeniden baglanirsa dizinler SILINIYOR ve
  # bayrak sayesinde bir daha kurulmuyordu:
  #   bootfail: open [/data/system/dropbox] failed!
  #   bootfail: open [/data/tombstones] failed!
  # Artık her turda VARLIK kontrolu yapiyoruz (ucuz: tek test).
  #
  # -------------------------------------------------------------------
  # DIKKAT (KOK NEDEN DUZELTMESI 2026-10-17): /data GERCEK BOLUMU
  # ASLA GORMUYORDU; her zaman gecici bir tmpfs idi.
  #
  # /init'te (satir ~3300) gercek bolumu deniyoruz ama O AN
  # /devblk/vda29 BIR BLOK CIHAZ DEGIL:
  #     : > /devblk/vda29                       # /init'te duz dosya
  #     mount -o bind /dev/vda29 /devblk/vda29 # /dev/vda29 YOK
  # Gercek blok dugumunu UEVENTD koyuyor (olculdu:
  #     brw------- 1 0 0 259, 13), yani /init'in /data blogundan
  # SONRA. O blogu TEK SEFER calistigi icin asla denenmiyor.
  # OLCULEN GERCEK /data (elle mount edilince):
  #     /devblk/vda29 on /data type ext4 (rw,seclabel,relatime)
  #     icerik: lost+found  misc  system  user_de
  # ve elle mount BASARILI. Yani bolum saglam; sadece zamanlama
  # yuzunden baglanmiyor.
  #
  # COZUM: bu fonksiyon supervisor DONGUSUNDE her tur calisiyor;
  # gecici tmpfs'i gordugumuzde gercek bolumle degistiriyoruz.
  # __DATADEV_PART__ yalnizca bb/mountapex'e ikame edildigi icin
  # (bb/supervise'e EDILMEYDI) bu fonksiyona DA ikame ekliyoruz
  # -- yoksa var olmayan bir yol aranir ve sessizce basarisiz olur.
  # -------------------------------------------------------------------
  if [ -b /devblk/vda__DATADEV_PART__ ] \
     && /bb/grep " /data " /proc/mounts 2>/dev/null | /bb/grep -q tmpfs; then
    if mount -t ext4 -o rw /devblk/vda__DATADEV_PART__ /data 2>/dev/null; then
      dd_ok=0
      m "### /data: gecici tmpfs -> GERCEK BOLUM (/devblk/vda__DATADEV_PART__) ###"
    fi
  fi
  # DIKKAT (2026-10-18): arkprobe servisi /data/dltrace.so ile
  # baslatiliyor (bkz. init.environ.rc). dosyayi buraya kopyaliyoruz.
  # DIKKAT: /bb/ hicbir linker namespace'ine uymuyor; oradan
  # LD_PRELOAD edildiginde "libnativeloader.so not found" veriyor.
  # /data dogru namespace'e dustugu icin calisiyor (olculdu).
  if [ -f /bb/dltrace.so ] && [ ! -f /data/dltrace.so ]; then
    /bb/cp /bb/dltrace.so /data/dltrace.so 2>/dev/null \
      && m "### /data/dltrace.so hazir (arkprobe icin) ###"
  fi
  # DIKKAT (2026-10-18): izlenen suren hersey /data/dltrace.log'a
  # yaziyor. Dosyayi HER TURDE temizliyoruz ki yalnizca son
  # calistirmayi gormek icin gereksiz log birikmesin.
  if [ -f /bb/dltrace.so ] && [ -f /data/dltrace.so ]; then
    /bb/cp /bb/dltrace.so /data/dltrace.so 2>/dev/null
  fi
  [ -d /data/dalvik-cache/arm64 ] && [ -d /data/tombstones ] \
    && [ "${dd_ok:-0}" = "1" ] && return 0
  mountpoint -q /data 2>/dev/null || return 0
  for d in $DATA_DIRS; do mkdir -p "/data/$d" 2>/dev/null; done
  if [ -d /data/dalvik-cache/arm64 ]; then
    if [ "${dd_ok:-0}" != "1" ]; then
      dd_ok=1
      m "### /data dizinleri kuruldu (${n:-0}. tur) ###"
    fi
  else
    dd_ok=0
  fi
}
# DIKKAT: zygote'yi elle baslatmak yerine init'e ctl.start ile
# yolluyoruz; boylece SELinux baglami (u:r:zygote:s0) dogru oluyor.
# Elle calistirilip cikti yakalandiginda AVC'ler su sekildeydi:
#     denied { execute } name="app_process64" tcontext=u:object_r:zygote_exec:s0
# yani baglam dogru, sorun yalnizca /data idi.
ensure_zygote() {
  ensure_data_dirs
  [ "${dd_ok:-0}" = "1" ] || return 0
  # on koşul: linker'in APEX yollari [system] bolumunde olmali
  [ "${ld_ok:-0}" = "1" ] || return 0
  # DIKKAT (HATA DUZELTMESI 2026-10-16): eskiden "bir kez dene" bayragi
  # vardi (zyg_tried). Tek deneme basarisiz olunca bir daha ASLA
  # denenmiyordu ve zygote hic kalkmiyordu:
  #     pid=14386 state=Z ppid=1 threads=1
  #     pid=14393 state=Z ppid=1 threads=1
  #     logcat'te zygote izi YOK
  # init.svc.zygote ise "running" gorunuyordu -- init olmus
  # sureci temizlememis, bayrak bayat kalmisti.
  #
  # DIKKAT: "running" OZELLIGI YETERLI DEGIL. Gercek yasamayi
  # olcuyoruz: HICBIR zygote64 surucu ZOMBI olmamali. kill -0
  # gibi yontemlar bu tuzagi verir; ps ciktisindaki koseli
  # parantez ve /proc/<pid>/stat 3. alani (Z) ayirt edicidir.
  zstate="yok"
  for p in $(/bb/ps -A 2>/dev/null | /bb/grep zygote64 | /bb/tr -s ' ' | /bb/cut -d' ' -f1); do
    st=$(/bb/cut -d' ' -f3 "/proc/$p/stat" 2>/dev/null)
    [ "$st" = "Z" ] && continue
    zstate="yasaniyor(pid=$p,st=$st)"
    break
  done
  case "$zstate" in
    yasaniyor*) return 0 ;;
  esac
  # Deneme araligi: her 20 turda bir (yaklasik 20 saniye).
  ztries=$(( ${ztries:-0} + 1 ))
  [ $((ztries % 20)) -ne 1 ] && return 0
  # DIKKAT: init.svc.zygote "running" gorunuyor ama canli surec
  # yoksa init ctl.start i ISLEMEZ ("servis zaten calisiyor").
  # Bu durumda once durduruyoruz:
  #     pid=14386 state=Z ppid=1   <- zombi, init onu reaper olarak
  #                                     tutuyor, bayrak bayat "running"
  svc=$(/system/bin/getprop init.svc.zygote 2>/dev/null)
  case "$svc" in
    running)
      /system/bin/setprop ctl.stop zygote 2>/dev/null
      sleep 2
      ;;
  esac
  /system/bin/setprop ctl.start zygote 2>/dev/null
  sleep 8
  m "### ctl.start zygote #$ztries -> svc=$(/system/bin/getprop init.svc.zygote 2>/dev/null) dcache=$([ -d /data/dalvik-cache/arm64 ] && echo VAR || echo YOK) ###"
  sleep 5
  m "### zygote durumu: $zstate | app_process=$(/bb/ps -A 2>/dev/null | /bb/grep -c app_process) adet ###"
  return 0
}

ensure_adbd() {
  # DIKKAT (2026-10-16): adbd TEK BIR kez elle denenir ve stderr'i
  # kmsg'ye basilir. init in adbd'si hicbir cikti yazmadan status 1
  # ile oluyordu; elimizde HICBIR ipucu yoktu:
  #     init: Service 'adbd' (pid 6248) exited with status 1
  # Bu bir teşhis yolu; init in adbd'sini DURDURMAZ, sadece ikinci
  # bir kopya dener (5555 zaten tutuldugu icin baglanamaz ama
  # baslama loglari basilir).
  #
  # DIKKAT: bayrak adi 'adbd_once' -- 'adbd_diag' DEGIL. Diger bir
  # fonksiyon (satir 1043) ayni adi kullaniyor ve ensure_adbd'den
  # ONCE calisip bayragi 1 yapiyordu; bizim blogumuz hic girmedi:
  #     ### ADBD-DIAG ... (logda hic gorunmedi)
  if [ "${adbd_once:-0}" != "1" ]; then
    adbd_once=1
    mkdir -p /bb/nb 2>/bb/null
    LD_LIBRARY_PATH=/apex/com.android.adbd/lib64 HOME=/tmp TMPDIR=/tmp \
      /apex/com.android.adbd/bin/adbd tcp:5555 \
        > /bb/nb/adbd-diag.out 2> /bb/nb/adbd-diag.err &
    sleep 6
    m "### ADBD-DIAG out: $(/bb/cat /bb/nb/adbd-diag.out 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 400)"
    m "### ADBD-DIAG err: $(/bb/cat /bb/nb/adbd-diag.err 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 900)"
  fi
  # DIKKAT (2026-10-15): adbd'yi INIT baslatmali, elle degil. Sebep:
  # APEX'in kendi init.rc'si soyle diyor
  #     service adbd /apex/com.android.adbd/bin/adbd --root_seclabel=u:r:su:s0
  #         socket adbd seqpacket 660 system system
  #         seclabel u:r:adbd:s0
  # 'socket' satiri: init bir SEQPACKET unix socketu acar ve surece
  # ANDROID_SOCKET_adbd=fd verir. Elle baslatinca o fd YOK:
  #     adbd E auth.cpp:203] Failed to get adbd socket: Operation not permitted
  # ve adbd 5555'i DINLEMEZ (tcp5555=0) -- surec yasayip sessizce
  # ise yaramaz bir durumda kalir.
  #
  # DIKKAT (ZAMANLAMA, 2026-10-15): 'class core' servisleri
  # class_start core aninda baslatir; bu supervisor'un 20. turundan
  # ONCE olur. Bizim /apex/com.android.adbd/etc/ld.config.txt bind
  # mount'umuz ancak ensure_adbd (n>=20) icinde kuruluyor -- yani
  # init'in baslattigi adbd linker hatasina dustugu icin surec
  # olup olup duruyor (svc=restarting).
  # COZUM: ld.config.txt'i daha erken kur. ensure_net'in yanina
  # (n>=15) cagiriyoruz.
  case "$(/system/bin/getprop init.svc.adbd 2>/bb/null)" in
    running)
      adbd_ok=1
      adbd_pid=$(find_adbd)
      return 0 ;;
  esac
  # DIKKAT (2026-10-16, KRITIK DÜZELTME): Olcut artık SUREC DEGIL,
  # DİNLEYİCİ. 'svc=restarting' durumunda adbd sureci aslinda yasiyor
  # (nabiz iki kez ayni pid'i gosteriyor: "svc=restarting pid=2670")
  # ama 5555'i DINLEMIYOR. Onceki surumde yasayan pid gorulunce
  # sayac sifirlaniyor ve 40'a hic ulasilamadigi icin AUTOPSY
  # CALISAMIYORDU (AUTOPSY sayisi: 0 olculdu).
  # Dogru olcut: /proc/net/tcp'te 5555 (0x15B3) var mi?
  #   yok -> adbd ise yaramaz, elle baslatip AUTOPSY'yi dene
  #   var -> L5'e giden yol acik, bir sey yapma
  # DIKKAT (OLCUM ARACI DOGRULANDI, 2026-10-16): once '/proc/net/tcp
# icinde :15B3 var mi' diye bakıyorduk ve hep 0 cikti. Test
# gosterdi ki BU TABLO BU NAMESPACE'DE HIC BOS DEGIL, TAMAMEN BOS:
#     nc -l -p 5599  ->  netstat: tcp 0.0.0.0:5599 LISTEN
#                       /proc/net/tcp: 0 satir
# Yani /proc/net/tcp bize gosterilmiyor (init kendi /proc mount'unu
# yapiyor, supervisor eski mount'u goruyor). DOGRULENMIS olcut bu
# yuzden netstat'a gecildi.
if /bb/netstat -ltn 2>/bb/null | /bb/grep -q ':5555'; then
    adbd_ok=1
    adbd_pid=$(find_adbd)
    return 0
  fi
  ctl_tries=$(( ${ctl_tries:-0} + 1 ))
  # DIKKAT (2026-10-16, OLÇUM DÜZELTMESİ): 'netstat -ltn | grep :5555'
  # yerine once KARSILASTIRMALI (probe) sonra AUTOPSY. Sebep:
  # dışarıdan bağlantı denemesi "TCP KURULDU + RST" veriyor --
  # bu, iki olasılıktan biri:
  #   (a) adbd dinliyor ve baglantıyı reddediyor
  #   (b) adbd hiç dinlemiyor, SLIRP guest'in RST'ini bize yansıtıyor
  # netstat -an/-ltn6 (düz ve IPv6) ikisini de ayirt ediyor.
  if [ $((ctl_tries % 4)) -eq 1 ]; then
    /system/bin/setprop ctl.start adbd 2>/bb/null
    /bb/sleep 1
    m "### ctl.start adbd #$ctl_tries -> svc=$(/system/bin/getprop init.svc.adbd 2>/bb/null) L4=$(/bb/netstat -an 2>/bb/null | /bb/grep -c 5555) L6=$(/bb/netstat -ltn6 2>/bb/null | /bb/grep -c 5555)"
  fi
  # DIKKAT (2026-10-16, GERI ALMA): AUTOPSY artik KAPALI.
  # O bir teshis aracidir: init in adbd servisini ctl.stop ile
  # DURDURUP adbd'yi elle baslatiyordu. Elle baslatilan adbd
  # TCP dinleyicisini ACMIYOR (init in socket aktivasyonu ve
  # u:r:adbd:s0 baglami gerekiyor), yani bizim elimizi baglamistik:
  #   ### adbd=ayakta svc=stopped pid=6464 tcp5555=0
  #   adb connect -> device not found
  # L5 artik init in adbd'si ile calisiyor; AUTOPSY sadece L5 i
  # bozuyor. Fonksiyon kodda duruyor (yeniden gerekirse).
  if [ "${AUTOPSY:-0}" = "1" ] && [ "$ctl_tries" -ge 12 ]; then
    adbd_autopsy
    return 0
  fi
  # DIKKAT (2026-10-16, AUTOPSY KAPALI): ayirt edici probu net oldu:
  #     5900 (bos port) -> Connection refused  (QEMU guest'e ULASIR)
  #     5555            -> TCP KURULDU, sonra RST
  # Yani adbd 5555'te DINLIYOR ve baglantiyi KABUL ediyor, hemen
  # kapatiyor. Sebebi auth: ANDROID_SOCKET_adbd fd'si olmadigi icin
  #     adbd E auth.cpp:203] Failed to get adbd socket: Operation not permitted
  # ve baglanti reddediliyor. Elle baslatilan adbd bu fd'yi HICBIR
  # zaman alamaz -- yalnizca init verebilir.
  # Cozum: gereken property'ler hazirlandi, simdi sadece init'in
  # baslattigi adbd kullaniliyor:
  #   ro.adb.secure=0                          (build.prop yamasi)
  #   persist.adb.tls_server.enable=0          (init.environ.rc, early-init)
  #   setenv LD_LIBRARY_PATH .../lib64         (init.environ.rc service adbd)
  #   /apex/com.android.adbd/etc/ld.config.txt (mountapex, init'ten once)
  # Onceki denemelerde bu dortu de EKSIKTI; simdi tamam.
  # AUTOPSY (adbd_autopsy) teşhis araci olarak yazili kalir ama
  # ÇAĞRILMAZ: elle baslatilan adbd calistigi halde reddediyor.
  return 0
  [ -x /apex/com.android.adbd/bin/adbd ] || return 0
  # DIKKAT (HATA 2026-10-15): gunluk /bb/adbd.log idi. init 'on post-fs'
  # kok dosya sistemini salt okunur yaptigi icin o andan sonra OLUSTURULAMIYOR
  # ve ensure_adbd her denemede daha adbd'yi calistirmadan cokuyordu:
  #     can't create /bb/adbd.log: Read-only file system
  # Yani o denemeler linker hatasi DEGIL, bizim dosya hatamizdi.
  # Cozum: gunlugu /bb/nb altina yaz; /bb/nb uzerinde kalici tmpfs var.
  LOGF=/bb/nb/adbd.log
  adbd_ldconfig
  # ---------------------------------------------------------------------
  # BELIRLEYICI DENEY (2026-10-15).
  #
  # Olcutulen durum:
  #   - /apex/com.android.adbd/lib64/libadb_protos.so DOSYA OLARAK VAR
  #   - /linkerconfig/ld.config.txt icinde /apex/com.android.adbd/lib64 YOLU VAR
  #   - bizim yazdigimiz config dogru ve LD_CONFIG_FILE ile veriliyor
  #   - ama linker yine "libadb_protos.so not found" diyor ve BILDIRMIYOR
  #     ki o an config'i okuyup okumadi (hicbir parser hatasi basilmadi).
  #
  # Ayirt edici olcut: adbd'nin NEEDED sirasi sirasiyla
  #   libadbd_fs liblog libselinux libbase libadb_protos libadbd_auth ...
  # Bu SIRANIN ilk dortu /system/lib64'te VAR, libadb_protos.so SADECE
  # /apex/com.android.adbd/lib64'te var. Linker sirayla cozuyor ve ilk
  # bulamadigini yaziyor. Demek /system/lib64 arama yolunda, ama
  # /apex/com.android.adbd/lib64 DEGIL.
  #
  # Yani elimizde su an iki hipotez var ve TEK ACILISTA ayirt edilebilir:
  #   H1: linker config'i hic kullanmiyor  -> LD_LIBRARY_PATH ise yarar
  #   H2: linker config'i kullaniyor ama APEX yolu eleniyor
  #       -> config'in KENDISINI (globali) apex/etc altina kopyalamak ise yarar
  # Asagidaki 5 varyant sirayla denenir; ilk ayakta kalan kazanir.
  # ---------------------------------------------------------------------
  if [ -n "${adbd_win:-}" ]; then
    try_adbd "$adbd_win" "$adbd_we1" "$adbd_we2" "$adbd_wf"
    res=$(/bb/cat /bb/nb/adbd.res 2>/bb/null)
    adbd_pid=""
    case "$res" in "ok "*) adbd_pid=${res#ok }; adbd_ok=1 ;; *) adbd_ok=0 ;; esac
    return 0
  fi
  for v in ldpathP ldpath apexcfg plain ldcfg both apexcfg2; do
    f4=""
    case "$v" in
      ldpath)  e1="LD_LIBRARY_PATH=/apex/com.android.adbd/lib64"; e2="" ;;
      ldpathP) e1="LD_LIBRARY_PATH=/apex/com.android.adbd/lib64"; e2=""; f4="-P" ;;
      apexcfg)
              /bb/cp /linkerconfig/ld.config.txt \
                     /apex/com.android.adbd/etc/ld.config.txt 2>/bb/null
              m "### VARYANT apexcfg: global config apex/etc altina kopyalandi ($(wc -c < /apex/com.android.adbd/etc/ld.config.txt 2>/dev/null) bayt)"
              e1=""; e2="" ;;
      apexcfg2)
              /bb/cp /linkerconfig/ld.config.txt \
                     /apex/com.android.adbd/etc/ld.config.txt 2>/bb/null
              /bb/cp /linkerconfig/ld.config.txt \
                     /bb/nb/adbdld/ld.config.txt 2>/bb/null
              e1="LD_CONFIG_FILE=/bb/nb/adbdld/ld.config.txt"; e2="" ;;
      plain)  e1=""; e2="" ;;
      ldcfg)  e1="LD_CONFIG_FILE=/bb/nb/adbdld/ld.config.txt"; e2="" ;;
      both)   e1="LD_LIBRARY_PATH=/apex/com.android.adbd/lib64"
              e2="LD_CONFIG_FILE=/bb/nb/adbdld/ld.config.txt" ;;
    esac
    adbd_flag="$f4"
    try_adbd "$v" "$e1" "$e2" "$f4"
    res=$(/bb/cat /bb/nb/adbd.res 2>/bb/null)
    adbd_pid=""
    case "$res" in
      "ok "*)
        adbd_pid=${res#ok }
        adbd_win="$v"; adbd_we1="$e1"; adbd_we2="$e2"; adbd_wf="$f4"; adbd_ok=1
        m "### adbd AYAKTA (pid $adbd_pid, varyant=$v) tcp:5555 -> adb connect 127.0.0.1:5555"
        m "###   $(/bb/head -c 300 "$LOGF" 2>/bb/null | /bb/tr '\n' ' ')"
        return 0 ;;
      *)
        adbd_ok=0
        m "### VARYANT $v TAM LOG: $(/bb/cat /bb/nb/adbd.log 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 700)" ;;
    esac
  done
  return 0
}

# Bir adbd denemesi yapar. Sonucu /bb/nb/adbd.res dosyasina yazar:
#   "ok <pid>"  -> adbd ayakta
#   "fail"      -> olmedi
# DIKKAT: sonucu stdout'a DEGIL dosyaya yaziyoruz. Supervisor'un stdout'u
# /dev/kmsg; m() fonksiyonu da oraya yaziyor, yani $() ile alirsak adbd_pid
# kutusu log satirlariyla kirlenir.
# DIKKAT: alt kabuk kullaniliyor cunku exec ile degistirilirse $& job pid
# degil, alt kabugun pid'si olur; bu yuzden $$ pid dosyasina once yazilir.
# Calisan gercek adbd surecini bul. DIKKAT: adbd kendini arka plana
# cikarir (fork + parent cikar), yani $& ile aldigimiz pid COCUK kabuk
# olup cokebilir. Asil adbd sureci /proc taramasiyla bulunur.
# Bunu yapmadigimizda "AYAKTA" dedigimiz sey 5 saniye sonra olmus bir
# zombie idi -- nabiz listesinde hic gorunmedi.
find_adbd() {
  for pd in /proc/[0-9]*; do
    [ "$(/bb/cat "$pd/comm" 2>/bb/null)" = "adbd" ] || continue
    /bb/echo "${pd#/proc/}"
    return 0
  done
  return 1
}

# ---------------------------------------------------------------------
# adbd OLUM TEŞHİSİ (2026-10-15)
#
# Durum: init adbd'yi dogru tanimla baslatiyor --
#     init: starting service 'adbd'...
#     init: Created socket '/dev/socket/adbd', mode 660, user 1000, group 1000
# -- ama svc=restarting: surec cokup init yeniden baslatiyor ve
# /proc/net/tcp'te 5555 hic gorunmuyor.
#
# Gozlemimiz TEK: init.svc.adbd=restarting. Adbd'nin NEDEN oldugu
# gorunmuyor cunku:
#   (a) adbd hatasi logd'ye yaziyor; bizim logcat -d cagrimiz BOS
#       donuyor ("### logcat/adb:" bos) -> logd tamponu bize acik degil
#   (b) init'in stdout/stderr yonlendirmesi (/bb/nb/adbd-init.log)
#       HIC YAZILMIYOR -> bu init surumu stdout/stderr komutunu
#       desteklemiyor olabilir ya da dosya acilamiyor
#
# Bu yuzden bagimsiz bir yol kuruyoruz: adbd'yi supervisor'in
# KENDI surecimiz icinde, kontrol sifresiz, stdout/stderr dosyaya
# yonlendirilmis olarak calistirip 10 sn sonra hayatta olup olmadigini
# ve dosyada ne yazdigini olceriz. Init'in baslattigi adbd'yi once
# durduruyoruz ki iki adbd cakismasin.
adbd_autopsy() {
  [ "${autopsy:-0}" = "1" ] && return 0
  autopsy=1
  # init'in baslattigi adbd'yi durdur: ayni anda iki adbd, ayni
  # 5555 portu -> biri digerini reddeder ve olcum bulaniklasir.
  # DIKKAT: ctl.stop YETERLI DEGIL -- init servisi "disabled" olmadigi
  # icin (biz kaldirdik) hemen yeniden baslatir ve yeni surec
  # otomatik olarak 5555'i kapar. Bu yuzden iki yontem de deneniyor:
  # once ctl.stop, sonra pid'i dogrudan kill.
  /system/bin/setprop ctl.stop adbd 2>/bb/null
  /bb/sleep 2
  for k in 1 2 3; do
    kp=$(find_adbd)
    [ -z "$kp" ] && break
    kill -9 "$kp" 2>/bb/null
    /bb/sleep 1
  done
  m "### AUTOPSY basliyor (init'in adbd'si durduruldu, kalan=$(find_adbd))"
  # DIKKAT: elle baslatinca da bu ozellik gerekli. AUTOPSY'nin
  # bulgusu: adbd TCP oncesi 'persist.adb.tls_server.enable=1'
  # bekliyor ve ozellik tanimsiz oldugu icin asili kalip 5555'i
  # acmiyor. setprop init'in property service'ine yaziyor.
  /system/bin/setprop persist.adb.tls_server.enable 0 2>/bb/null
  m "### AUTOPSY tls_server=$(/system/bin/getprop persist.adb.tls_server.enable 2>/bb/null)"
  LD_LIBRARY_PATH=/apex/com.android.adbd/lib64 \
  /apex/com.android.adbd/bin/adbd tcp:5555 \
    > /bb/nb/autopsy.out 2> /bb/nb/autopsy.err &
  apid=$!
  /bb/sleep 10
  if kill -0 "$apid" 2>/bb/null; then
    m "### AUTOPSY: adbd 10 sn sonra AYAKTA (pid $apid)"
  else
    st=$(/bb/awk '{print $3}' "/proc/$apid/stat" 2>/bb/null)
    m "### AUTOPSY: adbd OLDU (durum=${st:-yok}, pid $apid)"
  fi
  m "### AUTOPSY stdout: $(/bb/cat /bb/nb/autopsy.out 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 500)"
  # DIKKAT: 500 bayt yetersiz kaldi -- 'main.cpp:182] Setup mdns on
  # port= 5555' satiri bu esigin hemen sonunda geliyor ve kesiliyordu.
  m "### AUTOPSY stderr: $(/bb/cat /bb/nb/autopsy.err 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 1400)"
  m "### AUTOPSY tcp5555: L4=$(/bb/netstat -an 2>/bb/null | /bb/grep -c 5555) L6=$(/bb/netstat -ltn6 2>/bb/null | /bb/grep -c 5555)"
  m "### AUTOPSY netstat4: $(/bb/netstat -an 2>/bb/null | /bb/tr '\n' '|')"
  m "### AUTOPSY netstat6: $(/bb/netstat -ltn6 2>/bb/null | /bb/tr '\n' '|')"
  # -------------------------------------------------------------------
  # KESIF (2026-10-16): Adbd 'main.cpp:186] adbd listening on
  # tcp:5555' ve 'main.cpp:287] adbd started' DIYOR, mDNS kaydi bile
  # basarili ('mdns.cpp:109] registered: 1') -- ama netstat -an
  # icinde HICBIR TCP SOCKET YOK. Tek dinleyici UNIX socket
  # (/dev/socket/property_service).
  # Iki hipotez:
  #   H1) adbd KENDI NETWORK NAMESPACE'INE girdi (unshare). QEMU'nun
  #       hostfwd'i ana namespace'teki 10.0.2.15'e gider, adbd'yi
  #       GOREMEZ. '5900 refused / 5555 RST' tam da bunun gorunumu.
  #   H2) adbd socket'i acmadi, log yalan soyluyor.
  # AYIRT EDICI: /proc/<pid>/net/tcp O SURECIN KENDI namespace'ini
  # gosterir + /proc/<pid>/ns/net inode'i.
  # -------------------------------------------------------------------
  ap=$(find_adbd)
  if [ -n "$ap" ]; then
    m "### NS: adbd=$ap self=$(/bb/readlink /proc/self/ns/net 2>/bb/null) adbd_ns=$(/bb/readlink "/proc/$ap/ns/net" 2>/bb/null)"
    m "### NS-adbd-tcp: $(/bb/cat "/proc/$ap/net/tcp" 2>/bb/null | /bb/head -3 | /bb/tr '\n' '|')"
    m "### NS-self-tcp: $(/bb/cat /proc/self/net/tcp 2>/bb/null | /bb/head -3 | /bb/tr '\n' '|')"
    # ---------------------------------------------------------
    # KESIF (2026-10-16): 'netstat' ile '/proc/net/tcp' BIRBIRINI
    # DOGRULAMIYOR ve bu ihtilafi cozmek icin 1-2 KAYIT birbiriyle
    # karsilastiriliyor:
    #   (1) nc -l 5599 acar -> netstat LISTEN gosteriyor, ama
    #       /proc/net/tcp 0 satir. Yani /proc/net/tcp bu namespace'te
    #       BOZUK gorunuyor; netstat guvenilir.
    #   (2) adbd'nin ACIK FD listesi (/proc/<pid>/fd) -> socket girdisi
    #       varsa socket GERCEKTEN aciktir.
    # Bu ucuncu olcum belirleyici.
    # ---------------------------------------------------------
    fds=""
    for f in /proc/$ap/fd/*; do
      t=$(/bb/readlink "$f" 2>/bb/null)
      case "$t" in
        socket:*) fds="$fds $t" ;;
      esac
    done
    m "### FD-adbd-socket: $(/bb/echo ${fds:-YOK} | /bb/head -c 200)"
    nfd=$(/bb/ls /proc/$ap/fd 2>/bb/null | /bb/wc -l)
    m "### FD-adbd-toplam: $nfd  ls=$(/bb/ls -l /proc/$ap/fd 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 400)"
  fi
  m "### AUTOPSY socket: $(/bb/ls -l /dev/socket/ 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 300)"
  # DIKKAT: adbd 'listening on tcp:5555' demis olabilir ama
  # /proc/net/tcp'te 5555 gorunmuyor. Iki olasilik:
  #   (a) adbd IPv6 dinleyicisini acti (/proc/net/tcp6)
  #   (b) bind basarisiz olup adbd bunu sadece logluyor
  # Ayirt etmek icin TCP tablosunun tamamini doktoruz.
  m "### AUTOPSY tcp-tablosu: $(/bb/cat /proc/net/tcp 2>/bb/null | /bb/head -4 | /bb/tr '\n' '|')"
  m "### AUTOPSY tcp6-tablosu: $(/bb/cat /proc/net/tcp6 2>/bb/null | /bb/head -4 | /bb/tr '\n' '|')"
  # DIKKAT (OLCUM ARACI DOGRULAMASI): 'tcp5555: 0' ve tamamen bos
  # tcp tablosu, adbd'nin gercekten bind OLMADIGI yorumuna
  # yol aciyor -- ama ya tablo bizim mount namespace'imizde
  # gorunmuyorsa? (/init kendi /proc'sini mount ediyor.)
  # KONTROL: supervisor'in KENDI busybox'ile bir port ac. Gorunurse
  # tablo saglamdir ve adbd gercekten dinlemiyor demektir.
  /bb/nc -l -p 5599 > /bb/null 2>&1 &
  ncpid=$!
  /bb/sleep 1
  m "### OLCUM TESTI: nc -l 5599 pid=$ncpid durum=$(/bb/awk '{print $3}' /proc/$ncpid/stat 2>/bb/null) tcp4-satir=$(/bb/grep -c ':15C7' /proc/net/tcp 2>/bb/null) netstat=$(/bb/netstat -ltn 2>/bb/null | /bb/tr '\n' '|')"
  kill -9 "$ncpid" 2>/bb/null
  # Adbd gercekten ayakta kaldiysa BIRAKMA: L5'e giden yol budur.
  if kill -0 "$apid" 2>/bb/null; then
    adbd_pid=$apid
    adbd_ok=1
    adbd_win=autopsy
    m "### AUTOPSY BASARILI: adbd bizim surecimiz, elle baslatildi"
  else
    m "### AUTOPSY BASARISIZ: elle baslatma da olmuyor"
  fi
  return 0
}

try_adbd() {
  (
    [ -n "$2" ] && export "$2"
    [ -n "$3" ] && export "$3"
    echo $$ > /bb/nb/adbd.pid
    # DIKKAT: '-a' = adbd arka planda kendini cogaltmaz (nodaemon) ve
    # TUM loglarini stdout'a yazar. Varsayilan modda adbd kendi
    # gorunmez cocugunu acar ve baglanti basina olaylari /dev/kmsg
    # UZERINE yazmiyor -- logda hicbir iz yoktu, elimizde tek bilgi
    # "offline" idi. -a ile her baglanti denemesi adbd.log'a duser.
    exec /apex/com.android.adbd/bin/adbd $4 tcp:5555
  ) > /bb/nb/adbd.log 2>&1 &
  /bb/sleep 5
  # DIKKAT: basari olcutu "kabuk pid'i yasiyor" DEGIL, /proc'da comm=adbd
  # olan GERCEK bir surec var mi. Adbd arka plana cikiyor; $& pid'i
  # (alt kabuk) cokebiliyor ve kill -0 zombie'a da basarili donuyordu.
  rp=$(find_adbd)
  if [ -n "$rp" ]; then
    /bb/echo "ok $rp" > /bb/nb/adbd.res
    return 0
  fi
  /bb/echo "fail" > /bb/nb/adbd.res
  m "### VARYANT $1 basarisiz (adbd sureci yok) : $(/bb/head -c 300 /bb/nb/adbd.log 2>/bb/null | /bb/tr '\n' ' ')"
  return 1
}
adbd_pid=""
adbd_ok=0

# --- /init gunlugunu kmsg'e BOSALT -----------------------------------------
# DIKKAT (2026-10-15): /init artik dogrudan kmsg'e yazmiyor, /bb/init.out
# dosyasina yaziyor. Sebep: kmsg cikislari printk limitine takiliyor ve
# /init'in butun ciktisi kayboluyordu:
#     printk: init: 40 output lines suppressed due to ratelimiting
# Limit 5 sn / 10 satir. Bizim surec adimiz "init" oldugu icin (betigin
# adi /init) baskilan cagri noktasi bize yaziliyor.
#
# Burada her saniye en fazla 3 satiri aktariyoruz: 3/saniye = 15/5sn,
# tam sinirin ALTINDA (10/5sn) kalmiyor... aslinda tam sinirda; bu
# yuzden 2/saniye (10/5sn) kullaniliyor ve kalan bir sonraki turda.
drain_init() {
  D=/bb/init.out
  [ -f "$D" ] || return 0
  tot=$(/bb/wc -l < "$D" 2>/bb/null)
  tot=${tot:-0}
  [ "$tot" -gt "${idone:-0}" ] 2>/bb/null || return 0
  sed -n "$((idone + 1)),$((idone + 4))p" "$D" 2>/bb/null | while read -r l; do
    [ -n "$l" ] || continue
    /bb/echo "$l"
  done
  idone=$tot
  return 0
}
idone=0

ensure_apex() {
  # DIKKAT (GERI ALMA 2026-10-16): /apex/apex-info-list.xml'i
  # supervisor dongusunde yeniden uretmeyi denedim ve sistemi
  # BOZDUM. Sebep zor bir denklem:
  #
  #   apex-info-list.xml YOKSA -> linkerconfig ANINDA abort ediyor
  #       I/O warning: failed to load external entity
  #       init in "exec -- linkerconfig" komutu HIZLA donuyor,
  #       early-init biter, class core baslar. (BU IYI HAL)
  #
  #   apex-info-list.xml VARSA  -> linkerconfig CALISIYOR ve tam
  #       config uretiyor (300 satir). Ama init bunu "exec" ile
  #       cagirdigi icin early-initi BLOKE ediyor; TCG emulasyonunda
  #       bu dakikalarca suruyor. Sonuc:
  #       init: starting service ueventd... -> status 1
  #       (hicbir sey baslamiyor, adbd bile calismiyor)
  #
  # Ayrica linkerconfig'un urettigi config APEX kutuphane
  # yollarini zaten ICERMIYOR (olculdu: grep -c apex -> sadece 4,
  # sadece com.android.runtime). Yani bizim fix_ldconfig zaten
  # asil kaynak; bu dosyadan hicbir fayda gelmiyor.
  #
  # KARAR: dosyayi uretmeyelim. Dosyanin YOKLUZU burada bir
  # ozellik, bir hata degil.
  true
  # Her APEX icin: mount noktasi degilse bagla.
  # DIKKAT: "Device or resource busy" burada NORMALDIR. Supervisor her saniye
  # calisiyor; zaten mount'lu olan bir APEX'i yeniden mount etmeye calisirsa
  # iste bu hatayi verir. Bu yuzden once mountpoint'e bakip karar veriyoruz.
  added=0; busy=0
  for entry in __APEX_LIST__; do
    # DIKKAT (HATA 2026-10-15): burada dongu degiskeni 'n' idi ve
    # DENETLEYICININ DONGU SAYACINI EZIYORDU:
    #     n=${entry%%:*}
    # supervisor govdesindeki 'n' dongu sayaci. ensure_apex her cagrildiginda
    # 'n' APEX bolum numarasina donusuyor ve BIR DAHA ARTMIYORDU:
    #     [  4.01] ### iter=0
    #     [  5.84] ### iter=27
    #     [  9.54] ### iter=27
    #     ... 361 kez hep 27
    # Sonuc: n'e bagli TUM tetikleyiciler sessizce hic calismadi --
    #     n >= 45   -> ensure_adbd (L5'in anahtari)   HIC BASLAMADI
    #     n == 25   -> /bb/diag2                       hic
    #     n == 40   -> ueventd elle calistirma          hic
    #     n % 15    -> nabiz satirlari                   hic
    # Olcum (nabiz satiri) eklemek bu hatayi ANLADI; o olmasa
    # denetleyici "calisiyor" sanilirdi.
    # COZUM: ayri isim. Sayac 'n' kaliyor.
    apn=${entry%%:*}; apname=${entry#*:}
    mountpoint -q /apex/$apname 2>/dev/null && continue
    mkdir -p /apex/$apname 2>/dev/null
    # DIKKAT: /dev/vda* init tarafindan siliniyor; kalici kopyalar /devblk'de.
    if e=$(mount -t ext4 -o ro /devblk/vda$apn /apex/$apname 2>&1); then
      added=$((added+1))
    else
      busy=$((busy+1))
      [ -n "$e" ] && m "###   [$apname] /devblk/vda$apn: $e"
    fi
  done
  # linkerconfig VNDK modulunu sabit isimle arar; takma ad olmazsa
  # "Unable to access VNDK APEX" verip APEX yollarini hic yazmiyor.
  if ! mountpoint -q /apex/com.android.vndk.v31 2>/dev/null; then
    mkdir -p /apex/com.android.vndk.v31 2>/dev/null
    for entry in __APEX_LIST__; do
      case "$entry" in
        *:com.android.vndk.current)
          mount -t ext4 -o ro /devblk/vda${entry%%:*} /apex/com.android.vndk.v31 2>/dev/null ;;
      esac
    done
  fi
  if [ $added -gt 0 ] || [ $busy -gt 0 ]; then
    m "### /apex tazelendi: $added yeni mount, $busy basarisiz ###"
    m "###   /dev/vda*: $(/bb/ls /dev/vda* 2>&1 | /bb/tr '\n' ' ')"
    m "###   /apex    : $(/bb/ls /apex 2>&1 | /bb/tr '\n' ' ' | /bb/cut -c1-160)"
    fix_ldconfig
  fi
}

# --- ld.config.txt: APEX arama yollarini yeniden yaz ------------------------
# DIKKAT BU ADIM ZIGOTE'UN ONUNDEKI SON ENGELDI.
#
# Dinamik linker, DT_NEEDED'daki 'libc.so'yu calistirilan programin
# dizininde DEGIL, ld.config.txt icindeki
# namespace.default.search.paths icinde arar. Bizim /init LD_LIBRARY_PATH
# export ediyor ama init kendi sureclerine TEMIZ bir cevre gecirir:
#     apexd: CANNOT LINK EXECUTABLE "/system/bin/apexd":
#            library "libc.so" not found: needed by main executable
#
# NEDEN 0 APEX YOLU: linkerconfig APEX modul listesini
# /apex/apex-info-list.xml dosyasindan okuyor. init kendi /apex'inin
# UZERINE bos bir tmpfs mount edince dosya kayboluyor:
#     linkerconfig: Failed to scan APEX modules :
#                   Can't read /apex/apex-info-list.xml
#     ld.config.txt: 0 APEX yolu
#
# DIKKAT (HATA DUZELTMESI): bu fonksiyon YALNIZCA ensure_apex mount yaptiginda
# cagriliyordu. Denetleyici cogu kosuda 'added=0' gordugu icin HIC CAGRILMIYOR
# ve ld.config.txt 0 APEX yolunda kaliyordu. Artik supervisor dongusunun
# govdesinden HER saniye cagriliyor (kendisi idempotent).
fix_ldconfig() {
  CFG=/linkerconfig/ld.config.txt
  [ -d /apex/com.android.runtime ] || return 0
  # DIKKAT (COZUM 2026-10-16, L4 6. KOK NEDEN): config KAYBOLUYOR.
  #
  # OLCULEN HALI (onceki kosu):
  #   ### DGN global adbd: grep: /linkerconfig/ld.config.txt:
  #     No such file or directory
  # ve surekli:
  #   F linker: CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #             library "libc.so" not found
  #   F linker: CANNOT LINK EXECUTABLE "/system/bin/ueventd":
  #             library "libc.so" not found
  #
  # KIM SILIYOR: /linkerconfig bir tmpfs. hw/init.rc early-init
  # blogunda birden fazla kez yeniden baglaniyor:
  #     mount tmpfs /linkerconfig 0755
  #     ...
  #     mount none /linkerconfig/bootstrap /linkerconfig bind rec
  # Her yeni tmpfs ESKI ICERIGI SIFIRLAR. Config'in kaybolmasi bu
  # yuzden oluyor.
  #
  # DENEME #1 (BASARISIZ): init in linkerconfig calistirmasini
  # yorumladim -> dosya hic olusmadi, cunku bizim yamamiz
  # ORIJINAL dosyayi okuyup ustune yaziyor.
  #
  # DENEME #2 (BU): yedek al. Ilk okumada stok configi
  # /bb/nb/ld.stock olarak sakla; sonraki her turda dosya yoksa
  # yedekten geri yukle. Boylece kim silerse silsin, 1 saniye
  # icinde duzelir ve hicbir surec kalici olarak bozuk config
  # gormez (atomik yazim sayesinde).
  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    fi
  fi
  [ -f "$CFG" ] || return 0
  # ---------------------------------------------------------------------
  # DIKKAT (HATA DUZELTMESI 2026-10-16, L4 12. KOK NEDEN): config'in
  # icerigi yamanin YAPILDIGI ANDAKI /apex durumuna bagliydi ve bir
  # daha tazelenmiyordu.
  #
  # OLCULEN BOZULMA:
  #     30:[system]  535:[vendor]  852:[unrestricted]
  #     1165:[postinstall]  1176:[isolated]  1455:[vendor]  <- IKINCI!
  #     36: search.paths += /apex/com.android.i18n/lib64   <- i18n'den basliyor
  # Yani adbd/appsearch/ART/conscrypt/extservices YOKTI:
  #     F linker: CANNOT LINK EXECUTABLE "/system/bin/app_process64":
  #                library "libnativeloader.so" not found
  # (libnativeloader.so /apex/com.android.art/lib64 altinda)
  #
  # NEDEN: yama, /apex/*/lib64 dizinlerini ANLIK GOREREK yaziyor.
  # Ilk yamada saniyeler daha az APEX mount edilmis oluyor; sonra
  # mount tamamlaniyor ama config bir daha yeniden uretilmiyor
  # (isaret satiri gorunce "yamalama tamam" saniyorduk).
  # Ayrica [vendor] bolumu iki kez yazilmis.
  #
  # COZUM: her turda "config yeterli mi" OLC. Monteli APEX sayisi ile
  # configdeki [system] arama yolu sayisi karsilastirilir; eksikse
  # STOK dosyadan BASINDAN yeniden uretilir (idempotent).
  # ---------------------------------------------------------------------
  napex_mt=0
  for a in /apex/*/; do [ -d "$a/lib64" ] && napex_mt=$((napex_mt + 1)); done
  napex_cfg=$(/bb/awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/ && /apex\//{n++} END{print n+0}' "$CFG" 2>/bb/null)
  if [ "${napex_mt:-0}" -gt 0 ] && [ "${napex_cfg:-0}" -lt "${napex_mt:-0}" ] \
     && [ -s /bb/nb/ld.stock ]; then
    m "### config eksik: $napex_cfg < $napex_mt APEX; stoktan yeniden uretiliyor ###"
    /bb/cp /bb/nb/ld.stock "$CFG" 2>/bb/null
    ld_ok=0
  fi
  # Yedek al: sadece bizim isaretimiz YOKSA (stok kalsin).
  if ! /bb/grep -q 'HARMONY-EMU apex yollari' "$CFG" 2>/bb/null; then
    [ -s /bb/nb/ld.stock ] || /bb/cp "$CFG" /bb/nb/ld.stock 2>/bb/null
  fi
  # DIKKAT (HATA 2026-10-15): once tek seferlik bir bayrak vardi ve
  # bir kez yamayinca bir daha bakmiyordu. Ama init KENDI linkerconfig
  # calistirmasinda dosyayi SIFIRLIYOR:
  #     linkerconfig: Failed to scan APEX modules
  #     ld.config.txt: 0 APEX yolu
  # ve bizim yama 5 saniye sonra gecersiz kaliyordu:
  #     apexd: CANNOT LINK EXECUTABLE "/system/bin/apexd":
  #            library "libc.so" not found
  # Duzeltme: bayrak yok. Her saniye TEK bir grep ile kontrol edip
  # APEX yolu yoksa yeniden yaziyoruz. grep ucuz, yamayla pahal.
  # DIKKAT (HATA DUZELTMESI): kontrol "herhangi bir /apex/ yolu var mi"
  # degil, "BIZIM ISARETIMIZ duruyor mu" olmali. Aksi halde init'in
  # KISM yazdigi bir config kontrolu pozitif gecirir ve biz hic yazmayiz:
  #     CANNOT LINK EXECUTABLE "/apex/com.android.adbd/bin/adbd":
  #            library "libadb_protos.so" not found
  # (Dosya APEX icinde var; arama yolunda degildi.)
  if /bb/grep -q 'HARMONY-EMU apex yollari' "$CFG" 2>/bb/null; then
    [ "${ld_ok:-0}" = "1" ] || ld_ok=1
    return 0
  fi
  if [ "${ld_ok:-0}" = "1" ]; then
    m "### DIKKAT: init linkerconfig'u ld.config.txt'i SIFIRLADI, yeniden yaziliyor ###"
    ld_ok=0
  fi

  # DIKKAT: '/system/bin/linkerconfig' calistirmak TAVUK-YUMURTA sorunudur.
  # linkerconfig'in KENDISI APEX kutuphanelerine baglanmak zorunda
  # (libc.so -> /apex/com.android.runtime/lib64/bionic/), ama o yollari
  # senin yazman gerekiyor:
  #     linkerconfig: Failed to scan APEX modules
  # DENENDI ve calismadi. Bu yuzden ld.config.txt'i KENDIMIZ yaziyoruz.
  #
  # DIKKAT: dosyanin SONUNA eklemek ISLEMEYEN bolume duser (README'de
  # belgelendigi gibi [postinstall]). Dogru yer ilk
  # 'namespace.default.search.paths' satirinin ARKASI.
  PATHS=""
  PERTM=""
  # DIKKAT (COZUM 2026-10-16, L4 7. KOK NEDEN): [vendor] bolumu YOK.
  # Configte SADECE 4 bolum var:
  #     14:[system] 217:[unrestricted] 235:[postinstall] 246:[isolated]
  # Oysa:
  #     init: Forked subcontext for 'u:r:vendor_init:s0' with pid 10937
  #     F linker : CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #                library "libc.so" not found
  # Vendor alt baglami VENDOR namespace inde calisiyor ve o bolumun
  # arama yollari BOS oldugu icin hicbir kutuphane bulamiyor.
  # "libc.so not found" bunun sonucu. Dosyada bionic yolu ve libc.so
  # MEVCUT (olculdu) ama [system] bolumu vendor surecine UYGULANMIYOR.
  #
  # NEDEN uretilmedi: linkerconfig /apex/apex-info-list.xml okuyor,
  # dosya firmware de HIC YOK, linkerconfig ABORT ediyor:
  #     I/O warning : failed to load external entity
  #       "/apex/apex-info-list.xml"
  # Biz kendimiz uretiyoruz.
  #
  # VPATHS tek satirlik "=" degeri (":" ayracli). Boylece "+=" ve
  # siralama sorunu olmuyor. Bolum dosyanin SONUNA eklenir ama
  # kendi "[vendor]" basligiyla yeni bolum acar -- onceki korku
  # ("dosya sonu [postinstall] bolumune duser") yalnizca basligsiz
  # namespace satirlari icin gecerliydi.
  VPATHS="/vendor/\${LIB}"
  VPERM=""
  # DIKKAT (COZUM 2026-10-16): vendor bolumunde SISTEM yollari da
  # olmali. liblog.so YALNIZCA /system/lib64 altinda:
  #     ls /system/lib64/liblog.so   -> VAR
  #     ls /vendor/lib64/liblog*     -> YOK
  #     find / -name liblog.so       -> sadece /system/lib64
  # [vendor] bolumunde sistem yolu olmayinca vendor ikilileri
  # baglanamiyor (olculdu):
  #     F linker: CANNOT LINK EXECUTABLE
  #               "/vendor/bin/vndservicemanager":
  #               library "liblog.so" not found
  #     F linker: "/vendor/bin/hw/vendor.huawei.hardware.audio.service"
  #               library "liblog.so" not found
  VPATHS="$VPATHS:/system/\${LIB}:/system/bin:/system/lib64"
  VPERM="/system/\${LIB}:/system/lib64"
  for a in /apex/*/; do
    # DIKKAT: 'n' DENETLEYICININ DONGU SAYACI. Burada da kullanilirsa
    # sayac ezilir (bkz. ensure_apex icindeki ayni hata ve NOTU).
    # DIKKAT: 'n' sayac olmaya devam ediyor; asagida geri atiyoruz ki
    # dongu sayaci bozulmasin.
    lname=${a#/apex/}; case "$lname" in */) lname=${lname%/} ;; esac
    if [ -d "$a/lib64" ]; then
      PATHS="$PATHS
namespace.default.search.paths += /apex/$lname/lib64"
      PERTM="$PERTM
namespace.default.permitted.paths += /apex/$lname/lib64"
      VPATHS="$VPATHS:/apex/$lname/lib64"
      VPERM="$VPERM:/apex/$lname/lib64"
    fi
    # DIKKAT BU SATIR OLMAZSA HICBIR SEY BAGLANMIYOR.
    # libc.so /apex/com.android.runtime/lib64/ icinde DEGIL,
    # lib64/bionic/ ALTINDA:
    #     /apex/com.android.runtime/lib64/bionic/libc.so
    # Biz yalnizca lib64 ekledigimizde linker aramayi bosuna yapiyor:
    #     apexd: CANNOT LINK EXECUTABLE "/system/bin/apexd":
    #            library "libc.so" not found: needed by main executable
    if [ -d "$a/lib64/bionic" ]; then
      PATHS="$PATHS
namespace.default.search.paths += /apex/$lname/lib64/bionic"
      PERTM="$PERTM
namespace.default.permitted.paths += /apex/$lname/lib64/bionic"
      VPATHS="$VPATHS:/apex/$lname/lib64/bionic"
      VPERM="$VPERM:/apex/$lname/lib64/bionic"
    fi
    if [ -d "$a/lib" ]; then
      PATHS="$PATHS
namespace.default.search.paths += /apex/$lname/lib"
      PERTM="$PERTM
namespace.default.permitted.paths += /apex/$lname/lib"
    fi
  done
  # DIKKAT (COZUM 2026-10-16, L4 5. KOK NEDEN): permitted.paths de
  # ekleniyor. bionic linker'da bu liste BOS DEGILSE beyaz listedir:
  # arama yolunda dosya bulunsa bile izinli olmayan dizinden yuklemez.
  # OLCULEN HALI (onceki surum):
  #   namespace.default.search.paths  += /apex/com.android.i18n/lib64
  #   namespace.default.permitted.paths = /system/${LIB}/drm
  #   namespace.default.permitted.paths += /system/${LIB}/extractors
  #   namespace.default.permitted.paths += /system/${LIB}/hw
  # Yani i18n ARANABILIYOR ama IZINLI DEGILDI. Belirtiler:
  #   F linker: CANNOT LINK EXECUTABLE "/system/bin/mediaserver":
  #             library "libandroidicu.so" not found
  #   F linker: "/system/bin/audioserver": libandroidicu.so not found:
  #             needed by /r/system/lib64/libmedia.so in namespace
  #   F linker: "/system/bin/cameraserver": ayni
  # libandroidicu.so YALNIZCA /apex/com.android.i18n/lib64 altinda
  # (olculdu: find /system /vendor /apex -name libandroidicu*).
  #
  # DIKKAT: permitted eklemesi AYRI bir ekleme noktasi gerektirir.
  # Satir 1630-1632 uyarisi gecerli: dosyanin SONU isleyen bolume duser
  # ve [system] icinde sonradan gelen bir "=" ATAMASI bastakileri
  # SILER. Iki ayri bayrak kullanmak zorunlu.
  # ---------------------------------------------------------------------
  # DIKKAT (COZUM 2026-10-18, L4 19. KOK NEDEN): Ark kutuphaneleri
  # ALT DIZINDE ve linker config'te YOLU YOK.
  #
  # OLCULEN GERCEK (adb shell uzerinden):
  #     /system/lib64/ark/libarkruntime.so   5412832 bayt  VAR
  #     /system/lib64/ark/libarkbase.so       312472 bayt  VAR
  #     /system/lib64/ark/libarkfile.so       431408 bayt  VAR
  #     /system/lib64/ark/libarkcompiler.so  1897168 bayt  VAR
  #     /system/framework/framework.abc     30980368 bayt  VAR
  #     /system/framework/core-oj.abc                     VAR
  #     (64 adet .abc dosyasi)
  # Yani Ark runtime'inin TAMAMI ROM'DA MEVCUT.
  #
  # AMA config'te bu yol sayimi sifir:
  #     grep -c "lib64/ark" /linkerconfig/ld.config.txt   ->  0
  # ve linker bu kutuphaneyi cozemiyor:
  #     $ linker64 --list /system/lib64/ark/libarkruntime.so
  #       CANNOT LINK EXECUTABLE: library "libarkbase.so" not found
  #
  # NEDEN: /system/lib64 config'te VAR ama /system/lib64/ark BIR
  # ALT DIZIN. Arama yollari alt dizinleri otomatik kapsamaz.
  #
  # NEDEN ONEMLI: bu ROM'da zygote/arkinit AYNI ikili:
  #     service arkinit /system/bin/app_process64 -Xzygote /system/bin
  #                 --zygote --nice-name=arkinit
  # ve /apex/com.android.art/bin/ icinde ikinci bir app_process
  # YOK (stok AOSP'de vardir). Yani HarmonyOS'ta VM'yi Ark
  # sagliyor; bu dizin eklenmeden hicbir Ark kutuphanesi
  # bagimligini cozemez.
  #
  # COZUM: [system] bolumune search.paths VE permitted.paths
  # ekliyoruz (permitted olmadan arama yolunda olsa bile
  # yuklenmez -- bionic beyaz listesi, olculdu).
  # ---------------------------------------------------------------------
  if [ -d /system/lib64/ark ]; then
    PATHS="$PATHS
namespace.default.search.paths += /system/lib64/ark"
    PERTM="$PERTM
namespace.default.permitted.paths += /system/lib64/ark"
  fi
  [ -n "$PATHS" ] || return 0
  # DIKKAT: PATHS'in BASINA isaret satiri koyuyoruz. Boylece "dosyada
  # /apex/ yolu var mi" kontrolu yerine "BIZIM TAM YAMAMIZ duruyor mu"
  # kontrolu yapilabiliyor.
  #
  # DIKKAT (HATA 2026-10-15): eski kontrol buydu:
  #     if /bb/grep -q '/apex/' "$CFG"; then return 0; fi
  # Yani "herhangi bir /apex/ yolu varsa" dosyaya dokunmuyorduk. Init
  # KISM bir config yazdiginda (bootstrap ld.config) kontrol pozitif
  # veriyor, biz hic yazmiyorduk ve bazi APEX yollari hic eklenmiyordu.
  # Belirti tam olarak buydu:
  #     CANNOT LINK EXECUTABLE "/apex/com.android.adbd/bin/adbd":
  #            library "libadb_protos.so" not found
  # Dosya APEX icinde VARDI (/apex/com.android.adbd/lib64/libadb_protos.so)
  # ama arama yolunda degildi.
  # DIKKAT (HATA DUZELTMESI 2026-10-16, L4 KOK NEDENI): ekleme ISLEMI
  # ONCE yapilir, isaret satiri SONRA eklenir. Oncekiden farkli olarak:
  #     /bb/cat /tmp/ld.head "$CFG" | awk ... > /tmp/ld.new
  # yaziliyordu; yani isaret + PATHS dosyanin EN BASINA gidiyordu ve
  # awk ilk 'namespace.default.search.paths' satirini ARAIYORDU. Bu satir
  # bizim kendi basligimizdi -> PATHS yine basa yazildi, yani ASLA
  # [system] bolumune girmedi.
  #
  # OLCULEN ETKI (adb shell uzerinden dogrulandi):
  #     cat /linkerconfig/ld.config.txt | head -3
  #       # HARMONY-EMU apex yollari basliyor
  #       (bos)
  #       namespace.default.search.paths += /apex/com.android.adbd/lib64
  #     cat ... | tail -3
  #       namespace.system.asan.permitted.paths += /data/asan/product/${LIB}
  # Yani bizim yollarimiz basta, stok [system] bolumu sonda.
  # Stok bolumdeki 'namespace.default.search.paths = ...' bir ATAMADIR
  # (+= degil) ve bastaki tum degerleri SILER. Sonuc:
  #     F linker: CANNOT LINK EXECUTABLE "/system/bin/app_process64":
  #                library "libnativeloader.so" not found
  # LD_CONFIG_FILE=/linkerconfig/ld.config.txt ile ZORLAYINCA da ayni
  # hata -> sorun arama sirasi degil, eklemenin YERININ yanlis olmasi.
  # Duzeltme: PATHS'i ORIJINAL dosyanin icine, ilk
  # 'namespace.default.search.paths' satirindan hemen sonraya yaz.
  /bb/awk -v ins="$PATHS" -v per="$PERTM" '
    { print }
    !done1 && /^namespace\.default\.search\.paths/ { printf "%s\n", ins; done1=1 }
    !done2 && /^namespace\.default\.permitted\.paths/ { printf "%s\n", per; done2=1 }
  ' "$CFG" > /tmp/ld.new 2>/bb/null
  # ---------------------------------------------------------------------
  # DIKKAT (COZUM 2026-10-18, L4 21. KOK NEDEN): [apex] BOLUMU,
  # link.default VE link.public config'te HIC YOKTU.
  #
  # OLCULEN BELIRTILER:
  #   grep -c "^\[apex\]" /linkerconfig/ld.config.txt   -> 0
  #   grep -c "^apex\." /linkerconfig/ld.config.txt    -> 0
  #   grep -c "^link\."  /linkerconfig/ld.config.txt   -> 0
  #   namespace.com_android_art.* satiri               -> 137 (TANIMLI)
  #   link.default icinde com_android_art               -> 0 (BAGLI DEGIL)
  # Stok yedekte (/bb/nb/ld.stock) de 0 -- yani config URETIMINDEN
  # geliyor, bizim yamamizdan degil.
  #
  # BELIRTI: ART /apex/com.android.art/bin/dalvikvm64 ile
  # DOGRUDAN calistirilinca:
  #     Error finding namespace of apex:
  #         no namespace called com_android_art
  #     RC=134 (SIGABRT)
  # ve bu hatada ART su dosyalari yukluyor (dltrace kaniti):
  #     EXT "libnativehelper.so" -> TAMAM
  #     DLOPEN "libartbase.so"  -> TAMAM
  #     DLOPEN "libartpalette-system.so" -> TAMAM
  # ve ucu de /apex/com.android.art/lib64/ ALTINDA:
  #     -rwxr-xr-x /apex/com.android.art/lib64/libnativehelper.so 27200
  # Yani linker /apex/<ad>/ altindan bir kutuphane cozdugunde
  # namespace turetmesi gerekiyor; [apex] bolumu olmadigi icin
  # tutamiyor.
  #
  # COZUM: [apex] bolumunu ve link.default / link.public
  # satirlarini yaziyoruz.
  #
  # DIKKAT (HATA, DUZELTILDI): ilk denemede namespace listesini
  # config'in kendisinden (awk ile namespace.* satirlarini
  # tarayarak) uretmistik. Ama fix_ldconfig /apex TAM MOUNT
  # EDILMEDEN bir kez cagriliyor ve o anda config'te sadece 2
  # namespace vardu -- seri log kaniti:
  #     ### link.default: 2 namespace baglandi ###
  # Yani dogru kaynak config degil, mount noktasinda elimizde olan
  # APEX listesi (GPT bolum adlari).
  # ---------------------------------------------------------------------
  #
  # DIKKAT (HATA #1, DUZELTILDI): APEX adi com.android.art iken
  # hem '.'->'_' cevirisi hem de 'com_android_' oneki
  # UYGULANIYORDU -> com_android_com_android_art. Olculmus:
  #     link.default = default,system com_android_com_android_adbd
  #                     com_android_com_android_art ...
  # Bu ad config'te TANIMLI DEGIL.
  #
  # DIKKAT (HATA #2, DUZELTILDI): adlar BOSLUKLA ayriliyordu.
  # bionic listeleri VIRGULLE ayirir, boslukle degil. Olculmus:
  #     virgul: 1   bosluk: 25
  # Dolayisiyla linker satiri "default,system" diye okuyup
  # gerisini TUMDEN yok sayiyordu -- com_android_art hic baglanmiyordu.
  #
  # DIKKAT (HATA #3, DUZELTILDI): configte yalnizca 17 namespace
  # TANIMLI:
  #     ark com_android_adbd com_android_appsearch com_android_art
  #     com_android_conscrypt com_android_i18n com_android_media
  #     com_android_neuralnetworks com_android_os_statsd
  #     com_android_resolv com_android_runtime com_android_tethering
  #     default rs sphal system vndk
  # link.default icinde TANIMSIZ bir ad olursa bionic config'i
  # TAMAMEN REDDEDIP dahili varsayilana duser. O yuzden yalnizca
  # configte gercekten tanimli olanlar baglaniyor.
  # ---------------------------------------------------------------------
  DEFN=" $(/bb/awk '/^namespace\.[A-Za-z0-9_]+(\.isolated|\.search|\.permitted)/ { n=$0; sub(/^namespace\./,"",n); sub(/\..*$/,"",n); print n }' "$CFG" 2>/bb/null | /bb/sort -u | /bb/tr '\n' ' ')"
  APEXNS=""
  NSOK=0; NSNO=0
  : > /tmp/ld.apex
  /bb/echo "[apex]" >> /tmp/ld.apex
  for entry in __APEX_LIST__; do
    nm=${entry##*:}
    nm=${nm%%@*}
    [ -n "$nm" ] || continue
    /bb/echo "apex.$nm = /apex/$nm" >> /tmp/ld.apex
    ns=${nm//./_}
    case "$ns" in com_android_*) ;; *) ns="com_android_$ns";; esac
    case "$DEFN" in
      *" $ns "*) APEXNS="$APEXNS,$ns"; NSOK=$((NSOK+1));;
      *) NSNO=$((NSNO+1));;
    esac
  done
  APEXNS=${APEXNS#,}
  # DIKKAT: link.default / link.public satirlarini [apex] bolumunden
  # ONCE yazmalidir. Bionic config parse edicisi [section] basligi
  # gordugunde o bolum baglamina gecer; sonradan yazilan link.*
  # satirlarini section icinde sayip yok sayabilir. En surekli calisma
  # icin dosyanin en bastan (dir.* satirlarindan sonra, ilk [section]
  # oncesinde) yazilmasi gerekir. /tmp/ld.link dosyasina yazip sonra
  # orijinal configin onune ekliyoruz.
  : > /tmp/ld.link
  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link
  [ -n "$APEXNS" ] && /bb/echo "link.public = $APEXNS" >> /tmp/ld.link
  m "### link.default/public: $NSOK namespace baglandi ($NSNO tanimsiz atlandi) ###"
  /bb/cat /tmp/ld.link /tmp/ld.new > /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new
  NAP=$(/bb/grep -c "^apex\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new

  { /bb/echo "# HARMONY-EMU apex yollari basliyor"; \
    /bb/echo "dir.vendor = /vendor/bin/"; \
    /bb/echo "dir.vendor = /vendor/lib64/"; \
    /bb/echo "dir.vendor = /vendor/lib64/hw/"; \
    /bb/cat /tmp/ld.new; \
    /bb/echo ""; \
    /bb/echo "[vendor]"; \
    /bb/echo "namespace.default.isolated = false"; \
    /bb/echo "namespace.default.visible = true"; \
    /bb/echo "namespace.default.search.paths = $VPATHS"; \
    /bb/echo "namespace.default.permitted.paths = $VPERM"; \
    } > /tmp/ld.marked 2>/bb/null
  # DIKKAT (KRITIK HATA DUZELTMESI 2026-10-16): config'i cp ile
  # yaziyorduk. cp ATOMIK DEGIL: once hedefi kirpar, sonra yazar.
  # O pencere (21 KB, birkac ms) icinde baslayan HER surec bozuk
  # config goruyor.
  #
  # OLCULEN BELIRTI (bastan bozuk, sonra duzeliyor gibi):
  #   13:44:50  CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #             library "libc.so" not found
  #   13:44:56  CANNOT LINK EXECUTABLE "/system/bin/ueventd":
  #             libc.so not found
  #   13:44:57  CANNOT LINK EXECUTABLE "/system/bin/audioserver":
  #             libandroidicu.so not found
  #   13:45:01  CANNOT LINK EXECUTABLE "/r/system/bin/init": libc.so
  # init alt baglami (vendor_init) her 5 saniyede yeniden basliyor
  # ve HER denemede ayni hatayi aliyordu. Oysa ayni ikili elle
  # calistirilince baglaniyor:
  #   audioserver --help -> "I/O warning: failed to load external
  #                          entity .../default_volume_tables.xml"
  # yani ikili degil, dosya ANLIK GORUNMUYOR.
  #
  # COZUM: ayni dosya sisteminde gecici dosya + mv (rename).
  # rename(2) atomiktir: okuyucular ya eski ya yeni dosyayi gorur,
  # hicbir zaman yarim dosya gormez. Gecici dosya MUTLAKA ayni
  # dizinde olmali (/tmp ayri tmpfs ise mv kopyalama yapar ve
  # atomiklik kaybolur).
  if [ -s /tmp/ld.marked ]; then
    if /bb/cp /tmp/ld.marked "${CFG}.tmp" 2>/bb/null \
       && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null; then
      :
    else
      /bb/rm -f "${CFG}.tmp" 2>/bb/null
      m "### [HATA] ld.config.txt atomik yazilamadi ###"
    fi
  fi
  # DIKKAT: dogrulama ARTIK 'dosyada /apex/ var mi' degil, 'APEX yollari
  # [system] bolumune girdi mi' olmali. Aksi halde hatanin kendisi
  # (dosyada yol var, ama yanlis bolumde) tekrar uretilir.
  NLD=$(/bb/awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/ && /apex\//{n++} END{print n+0}' "$CFG" 2>/bb/null)
  NPERM=$(/bb/awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /permitted\.paths/ && /apex\//{n++} END{print n+0}' "$CFG" 2>/bb/null)
  # DIKKAT: izinli yol sayisi arama yolundan AZ ise APEX kutuphaneleri
  # bulunur ama YUKLENEMEZ (beyaz liste). Bu sessiz hatayi yakalar.
  [ "${NPERM:-0}" -lt "${NLD:-0}" ] \
    && m "### [UYARI] permitted($NPERM) < search($NLD): APEX libleri IZINSIZ ###"
  # DIKKAT (olcum araci, 2026-10-16): [vendor] bolumu olmadan vendor
  # alt baglami baglanamaz. Yoksa "libc.so not found" gelir ve
  # UYARI basmamiz gerekir -- bu bir sessiz hatadir.
  NVEN=$(/bb/grep -c '^\[vendor\]' "$CFG" 2>/bb/null)
  [ "${NVEN:-0}" -eq 0 ] \
    && m "### [UYARI] [vendor] bolumu YOK, vendor alt baglami baglanamaz ###"
  # DIKKAT (OLCUM ARACI, 2026-10-16, KRITIK): linker config'de TEK
  # bir gecersiz satir TUM dosyayi reddediyor ve her surec "default
  # configuration"a duser. Bunu yaptigimizda:
  #     W linker: couldn't read '/linkerconfig/ld.config.txt'
  #       (using default configuration instead):
  #       ld.config.txt:371: error: undefined namespace:
  #         /system/bin:/system/lib64
  # ve MUSTERI koptu:
  #     F linker: CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #                library "libc.so" not found
  #     F linker: CANNOT LINK EXECUTABLE "/system/bin/ueventd":
  #                library "libc.so" not found
  # Sebep: "namespace.default.links" bir YOL degil, bir NAMESPACE
  # ADIDIR. Stok [system] bolumunde nasil yazildi:
  #     namespace.default.links = ark
  # Biz yollari yazmisitk (/system/bin:/system/lib64) -> bolum
  # tanimsiz namespace diye sayildi.
  #
  # Buraya DOGRULAMA koyuyoruz: gecersiz olabilecek anahtarlar
  # listesinde mi? Stok bolumde GECERLI olanlar:
  #     namespace.default.isolated / visible / search.paths /
  #     permitted.paths / links(AD) / link.<ad>.shared_libs
  # Bizim ekledigimiz ve GECERSIZ olanlar:
  #     namespace.default.linksystem, linkshared, interpreter,
  #     per_library_path
  NDBAD=$(/bb/grep -cE 'namespace\.[a-z_]+\.(linksystem|linkshared|interpreter|per_library_path)' "$CFG" 2>/bb/null)
  if [ "${NDBAD:-0}" -gt 0 ]; then
    m "### [HATA] configte $NDBAD gecersiz anahtar var; linkeri TUM configi reddedecek ###"
    m "### [HATA] satirlar: $(/bb/grep -E 'namespace\.[a-z_]+\.(linksystem|linkshared|interpreter|per_library_path)' "$CFG" 2>/bb/null | /bb/head -3 | /bb/tr '\n' ' ')"
  else
    m "### config anahtar kontrolu OK ($NVEN bolum, 0 gecersiz anahtar)"
  fi
  NADB=$(/bb/grep -c '/apex/com.android.adbd/lib64' "$CFG" 2>/bb/null)
  if [ "${NLD:-0}" -gt 0 ]; then
    ld_ok=1
    m "### ld.config.txt yamalandi: search=$NLD izinli=$NPERM (adbd=$NADB) ###"
    # DIKKAT (COZUM 2026-10-16): config'i HER APEX'in etc/ dizinine
    # kopyala. /apex/<apex>/bin/ altindaki ikililer (crash_dump64,
    # vdc, arktigen vb.) linker'a o APEX'in KENDI config'ini verir:
    #   W linker: Warning: couldn't read config file
    #             "/apex/com.android.runtime/etc/ld.config.txt"
    #             for "/apex/com.android.runtime/bin/crash_dump64"
    # Dosya yoksa o surec APEX kutuphanelerini GOREMEZ -- yani
    # crash_dump64 calisirken bile baglanamaz.
    napexc=0
    for ad in /apex/*/; do
      [ -d "$ad/etc" ] || continue
      # DIKKAT: burada da ATOMIK yaziyoruz. Aksi halde /apex/*/bin
      # altindaki ikililer (crash_dump64, vdc, arktigen) kirpik
      # config goruyor:
      #   W linker: couldn't read config file
      #             "/apex/com.android.runtime/etc/ld.config.txt"
      if /bb/cp "$CFG" "${ad}etc/ld.config.txt.tmp" 2>/bb/null \
         && /bb/mv -f "${ad}etc/ld.config.txt.tmp" "${ad}etc/ld.config.txt" 2>/bb/null
      then napexc=$((napexc + 1)); fi
    done
    m "### ld.config.txt ${napexc} apex/etc dizinine atomik kopyalandi ###"
    # DIKKAT: hw/init.rc'de bootstrap dizini /linkerconfig USTUNE bind
    # mount ediliyor:
    #     mount none /linkerconfig/bootstrap /linkerconfig bind rec
    # O satiri yorumladik ama dizinler yine de hazir olsun; linker
    # arama sirasinda bootstrap/ ve default/ altina da bakiyor.
    for sub in bootstrap default; do
      mkdir -p "/linkerconfig/$sub" 2>/bb/null
      /bb/cp "$CFG" "/linkerconfig/$sub/ld.config.txt.tmp" 2>/bb/null \
        && /bb/mv -f "/linkerconfig/$sub/ld.config.txt.tmp" \
                  "/linkerconfig/$sub/ld.config.txt" 2>/bb/null
    done
  else
    m "### ld.config.txt yamalanamadi ###"
  fi
  return 0
}

echo -n "0" > /bb/enforce0
pin_selinux() {
  E=/sys/fs/selinux/enforce
  [ -e "$E" ] || return 0
  # DIKKAT (HATA 2026-10-15): burada once bind-mount vardi:
  #     mount -o bind /bb/enforce0 /sys/fs/selinux/enforce
  # SELinux ENFORCING oldugu an bu mount REDDEDI LIYOR:
  #     avc: denied { mounton } for comm="mount"
  #         path="/sys/fs/selinux/enforce" ... permissive=0
  # yani koruma hic kurulamiyordu. Ve init politikayi yukledikten sonra
  # enforcement'i geri A C I Y O R D U (25. saniyede olcduk):
  #     [24.8 s] permissive=1
  #     [25.2 s] permissive=0
  # Sonrasi dogrudan ve olculur: vendor_init alt baglami OLDI:
  #     avc: denied { read } scontext=u:r:vendor_init:s0
  #         tcontext=u:object_r:default_prop:s0   permissive=0
  #     init: Subcontext exited with status 1
  #
  # NEDEN dogrudan yazmak calisir (bind-mount neden calismaz):
  # security/selinux/selinuxfs.c -> sel_write_enforce()
  #     length = avc_has_perm(current_sid(), SECINITSID_SECURITY,
  #                           SECCLASS_SECURITY, SECURITY__SETENFORCE, NULL);
  #     if (length) goto out;          // -EACCES -> yazma BASARISIZ
  #     enforcing_set(new_value);
  # Yetki kontrolu CAGIRANIN degil "security" alaninin yetkisine bakar.
  # Politika o alana setenforce verdigi icin yazma ENFORCING modunda da
  # gecer. mount ise selinuxfs uzerinde "mounton" yetkisi ister; policy
  # vermiyor.
  v=$(/bb/cat "$E" 2>/bb/null)
  [ "$v" = "0" ] && return 0
  echo -n 0 > "$E" 2>/bb/null
  v2=$(/bb/cat "$E" 2>/bb/null)
  if [ "$v" != "$v2" ]; then
    m "### SELinux enforce $v -> $v2 (0 = permissive)"
  fi
  return 0
}

# --- printk susturmayi kapat ------------------------------------------------
# DIKKAT: kernel komut satirina 'printk_ratelimit=1000000' yaziyoruz ama
# init'in mesajlari yine de yutuluyor:
#     printk: init: 32 output lines suppressed due to ratelimiting
# ve tam da EN ONEMLI kisim kayboluyor:
#     on init -> start servicemanager / hwservicemanager / vndservicemanager
# Bu satirlari gormedigimiz icin "servisler hic baslamiyor" dedik; oysa
# basliyorlar. Komut satiri parametresi bu cekirdekte (ya da bu
# surumde) uygulanmiyor. CANLI ayar sysctl uzerinden:
#     /proc/sys/kernel/printk_ratelimit
#     /proc/sys/kernel/printk_ratelimit_burst
# Bunlar var degilse sessizce geciliyor; etkisizlik olcumla anlasilir.
pin_printk() {
  for f in /proc/sys/kernel/printk_ratelimit /proc/sys/kernel/printk_ratelimit_burst; do
    [ -w "$f" ] || continue
    echo 1000000 > "$f" 2>/bb/null
  done
}

ensure_fake_blocks() {
  # DIKKAT: init, /dev ve /sys altindaki YOLLARI bekliyor:
  #     init: wait for '/dev/nve0' timed out and took 5012ms
  #     init: wait for '/dev/block/bootdevice/by-name/secure_storage' timed out
  #     init: wait for '/sys/devices/platform/balong_mloader/modem_start' took 30002ms
  # Bu yollar bizde YOK (sadece 5 sistem + 21 APEX partition'imiz var), ama
  # init rc'leri onlari bekliyor. Her eksik yol icin 5-30 saniye bekleniyor;
  # mount_all tek basina 80 saniye kaybetti.
  #
  # DIKKAT: bu yollar fstab dosyalarindan degil, rc dosyalarindaki 'wait'
  # komutlarindan geliyor (/vendor/etc/init/init.hisi.rc:8 gibi). Bu yuzden
  # hem fstab'lari hem de TUM rc dosyalarini taramak gerekiyor.
  #
  # Cozum: referans verilen tum /dev/... yollarini dizin olarak ONCEDen
  # olusturmak. wait_for_file ANINDA basarili olur, mount ise cihaz
  # bulamadigi icin hizli basarisiz olur. Bekleme yok, sonuc ayni.
  # DIKKAT: SADECE /dev/block/... ve bir kac Huawei dugumu. Daha genis bir
  # filtre denendi ve SISTEMI KIRDI: rc dosyalarinda '/dev/null' da gectigi icin
  # onu dizin olarak olusturduk ve init'in birinci asamasi mknod ile patladi:
  #     init: mknod("/dev/null", S_IFCHR | 0666, makedev(1, 3)) failed File exists
  #     init: Init encountered errors starting first stage, aborting
  # Yani /dev'in standart dugumlerine ASLA dokunmuyoruz.
  created=0; skipped=0
  for d in /vendor/etc/init /system/etc/init /odm/etc/init /cust/etc/init \
           /vendor/etc/init/charger /system/etc/init/hw; do
    [ -d "$d" ] || continue
    for p in $(/bb/grep -rhoE '/dev/block/[a-zA-Z0-9_./-]+' "$d" 2>/dev/null | /bb/sort -u); do
      [ -e "$p" ] && continue
      # DIKKAT (REGRESYON DUZELTMESI 2026-10-15): 'modem' iceren yollari
      # OLUSTURMUYORUZ. Onceki kosuda bu dizinler olustugu icin fs_mgr
      # mount'u denemeye calisti, 'check,formattable' bayraklari yuzunden
      # format denedi ve /vendor/etc/fstab.modem 80 SANIYE bekletti.
      # 'on fs' -> 80s, 'on post-fs' -> 30s; toplam 110 saniye, ve init
      # post-fs'i bitiremedigi icin class main (Zygote) hic baslamadi.
      # Modem QEMU'da zaten calisamaz; sahte yol olusturmak sadece
      # zaman kaybiydi.
      case "$p" in
        *modem*) skipped=$((skipped+1)); continue ;;
      esac
      mkdir -p "$p" 2>/dev/null && created=$((created+1))
    done
  done
  # Huawei'ye ozgu guvenlik/yonlendirme dugumleri (init.hisi.rc bunlari bekliyor)
  for p in /dev/nve0 /dev/nve1 /dev/hw_bfm /dev/hwcrypto /dev/pmom /dev/rfile /dev/zipdev; do
    [ -e "$p" ] && continue
    mkdir -p "$p" 2>/dev/null && created=$((created+1))
  done
  [ $created -gt 0 ] && m "### /dev/block sahte yollar: $created olusturuldu, $skipped modem (atlandi) ###"
}

# --- MISC cihazlarini mknod ile KENDIMIZ olustur ----------------------------
# DIKKAT BU ADIM apexd'i SESSIZCE OLDUREN YARIŞI KALDIRIR.
#
# Olcum (onceki kosu):
#   [31.03] avc: denied { create } for pid=429 comm="supervise"
#                 name="loop-control" tcontext=u:object_r:tmpfs:s0
# Denetleyici once `: > /dev/loop-control` ile DUZ BIR DOSYA yaratiyor,
# sonra bind-mount etmeye calisiyor. O 1 saniyelik pencerede
# apexd-bootstrap /dev/loop-control'i acar:
#
#   * duz dosya acilir (open() BASARILI olur)
#   * ioctl(LOOP_CTL_GET_FREE) FAILED olur (karakter cihaz degil)
#   * apexd bootstrap'ta LOG(FATAL) -> SIGABRT
#
# apexd'in kendi hata mesaji /dev/kmsg'ye tasmiyor; init "starting
# service 'apexd-bootstrap'" yaziyor ama 5 saniye icinde sistem
# kapaniyor ve sebep gorunmuyor. Tam da bu yuzden 'apexd-bootstrap
# hic baslamiyor' sanildi.
#
# COZUM: bind-mount'a HIC GEREK YOK. /proc/misc her misc cihazin
# minor numarasini veriyor; major sabit 10. Biz dogrudan karakter
# cihazi mknod'luyoruz -- yarisi yok, bind yok, /devblk gerekmiyor.
#
# DIKKAT: minor'lar boot'ta DYNAMIC olarak atanir; sabit yazmiyoruz.
#   /proc/misc ornegi:
#       237 loop-control
#         7 loop
#        10 binder
mknod_misc() {   # $1=hedef yol  $2=/proc/misc'teki isim
  [ -c "$1" ] && return 0
  [ -e "$1" ] && rm -f "$1" 2>/bb/null      # duz dosya kalmasi olabilir
  MIN=$(/bb/grep -E "^[ ]+$2\$" /proc/misc 2>/bb/null | /bb/head -1 | /bb/awk '{print $1}')
  [ -n "$MIN" ] || return 1
  /bb/mknod "$1" c 10 "$MIN" 2>/bb/null || return 1
  [ -c "$1" ]
}

ensure_misc_devs() {
  # DIKKAT: $(( )) ARITMETIGI KULLANILMIYOR. Onceki surumde made=$((made+1))
  # vardi ve busybox ash her dongude
  #     sh: vndbinder: bad number
  # diye hata basiyordu (3 kez/saniye, logu kirletiyordu). Kosede
  # nereden geldigi bulunamadi; sayac yerine DIZI kullaniyoruz.
  made=""
  mknod_misc /dev/loop-control loop-control && made="${made}l "
  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 \
           16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
    [ -e "/dev/loop$i" ] && continue
    /bb/mknod "/dev/loop$i" c 10 "$i" 2>/bb/null && made="${made}l "
  done
  mknod_misc /dev/binder binder && made="${made}b "
  mknod_misc /dev/hwbinder hwbinder && made="${made}h "
  mknod_misc /dev/vndbinder vndbinder && made="${made}v "
  if [ -n "$made" ]; then
    m "### misc yeniden olusturuldu:$made"
    m "###   $(/bb/ls -l /dev/loop-control /dev/binder 2>&1 | /bb/tr '\n' ' ')"
  fi
  return 0
}

draw_screen() {
  # --- DURUM EKRANI ---------------------------------------------------------
  # DIKKAT: kernel'e 'console=tty0' verdigimiz icin /dev/tty0 framebuffer
  # konsolumuzdur. Yani buraya yazdigimiz her sey EKRANA cikar. Bu, ayri bir
  # yazi ciftisi (font) gerektirmeden ekrana metin basmanin en kisa yolu.
  #
  # DIKKAT: once kernel'in kendi boot gunlugunu gosteriyordu; simdi kendi
  # durum panomuzu yaziyoruz. Boylece ekrana bakarak teÅŸhis yapabiliyoruz:
  # APEX kac modul, binder ayakta mi, Zygote basladi mi, ueventd ne yapti.
  #
  # DIKKAT: ESC dizileri busybox 'echo -e' ile yorumlanir:
  #   \033[H  imleci sol ustĞµ gotur   \033[2J  ekrani temizle
  #   \033[K  satir sonunu temizle
  [ -c /dev/tty0 ] || return 0
  t0() { /bb/echo -e "$1" > /dev/tty0 2>/dev/null; }
  t0 "\033[H\033[2J"
  t0 "  HARMONYOS EMULATOR - ARM64 / Kirin 9000 firmware'\''i\033[K"
  t0 "  ==============================================================\033[K"
  t0 "\033[K"
  t0 "  Sure        : $((n)) s\033[K"
  t0 "  Kernel      : $(uname -r)\033[K"
  t0 "\033[K"
  t0 "  --- APEX ---\033[K"
  t0 "  modul       : $(/bb/ls /apex 2>/dev/null | /bb/grep -c apex)\033[K"
  t0 "  bionic libc  : $([ -f /apex/com.android.runtime/lib64/bionic/libc.so ] && /bb/echo VAR || /bb/echo YOK)\033[K"
  t0 "  vndk.v31    : $([ -d /apex/com.android.vndk.v31 ] && /bb/echo VAR || /bb/echo YOK)\033[K"
  t0 "\033[K"
  t0 "  --- CIHAZLAR ---\033[K"
  t0 "  /dev/binder : $([ -c /dev/binder ] && /bb/echo VAR || /bb/echo YOK)\033[K"
  t0 "  /dev/fb0    : $([ -c /dev/fb0 ] && /bb/echo VAR || /bb/echo YOK)\033[K"
  t0 "\033[K"
  t0 "  --- SERVISLER ---\033[K"
  t0 "  calisan     : $(/bb/ps 2>/dev/null | /bb/grep -vc '^[[:space:]]*PID')\033[K"
  t0 "\033[K"
  t0 "  Son 5 saniye icin seri cikti icin:\033[K"
  t0 "  logs/boot-zygote.log\033[K"
}

n=0
# DIKKAT: ensure_apex'in KAPALI KALMASI DENENDI VE BOZDU.
# Olcum (SUPERVISE_APEX=0 kosusu): supervisor /apex'i hic yenilemiyor,
# /apex bos kaliyor ve linker hicbir seyi baglayamiyor:
#     apexd: CANNOT LINK EXECUTABLE "/system/bin/apexd":
#            library "libc.so" not found
# Yani supervisor'in mount'u ZORUNLU; apexd kendi mount'unu yapsa bile
# bizimki lazim (once baglayip sonra devrediyoruz).
SUPERVISE_APEX="${SUPERVISE_APEX:-1}"
while [ $n -lt 900 ]; do
  # DIKKAT (OLCUM 2026-10-15): denetleyici 15.6 saniyede sessize dondu;
  # sonrasi hicbir sey yazmadi. Nerede durdugu ANLAILAMAZDI. Bu tek
  # satirlik isaret dongunun BASINDA oldugu icin, logda gorulen son
  # 'iter=' hangi asamada takildigini gosterir.
  m "### iter=$n"
  pin_selinux
  pin_printk
  drain_init
  # DIKKAT (2026-10-15): adbd TCP'de calisiyor ama Windows adb tarafinda
  # cihaz "offline" kaliyor ve adbd HICBIR baglanti mesaji yazmiyor.
  # Bu, konugun AGI olmadigi anlamina gelir: QEMU'nun hostfwd kurali
  # (tcp::5555-:5555) ana makinede baglantiyi kabul eder, sonra guest'in
  # 10.0.2.15:5555 adresine ulasmaya calisir. Konakta eth0 yoksa/kapali
  # ise bu asla olmaz ve adb istemcisi zaman asimina ugrar.
  # Biz agi kendimiz kuruyoruz (QEMU user-mode networking varsayilanlari:
  # guest 10.0.2.15/24, ag gecidi 10.0.2.2, DNS 10.0.2.3).
  [ "$n" -ge 15 ] && ensure_net
  # DIKKAT (2026-10-15): adbd icin APEX'e ozel ld.config.txt simdiden
  # kurulmali. Init adbd'yi class core aninda baslatiyor (n<20) ve o
  # anda dosya yoksa linker "libadb_protos.so not found" deyip adbd
  # olup duruyor -> svc=restarting.
  [ "$n" -ge 3 ] && adbd_ldconfig
  # adbd'yi erken baslat: framework'den bagimsiz, L5'in anahtarI.
  # DIKKAT: eskiden n>=45 idi. Sayac ensure_apex tarafindan ezildigi icin
  # (bkz. NOT) 45'e hic ulasilamiyordu ve adbd HIC BASLAMADI. Simdi
  # sayac duzgun arttigi icin 20 yeterli (~30 saniye).
  [ "$n" -ge 20 ] && ensure_adbd
  fix_ldconfig
  # DIKKAT (2026-10-16, L4 3. KOK NEDEN): /data dizinleri + zygote.
  # 'on post-fs-data' CALISMIYOR: post-fs-data tetigini init'in
  # fs_manager uretir, ama /data'yi INIT degil BIZ mount ediyoruz
  # (mountapex tmpfs). OLCUM: init.environ.rc'deki 'on early-init'
  # calisiyor (ro.crypto.state=unencrypted yazildi) ama
  # 'on post-fs-data' bloklarinin hicbiri iz birakmiyor ve
  # /data tamamen BOS kaliyor.
  # Zygote de otomatik baslamiyor: tetikleyici
  #     on zygote-start && property:ro.crypto.state=unencrypted
  # hic tetiklenmiyor (ro.crypto.state'i biz erken set ediyoruz).
  [ "$n" -ge 30 ] && ensure_zygote
  # DIKKAT: asama takip isareti. Sadece TEK bir tur icin (n=60) yazilir,
  # yoksa logu doyurur. 'iter=60' gorulup 'iter=61' gorulmezse denetleyici
  # tam olarak bu asamada takilmistir.
  [ "$n" -eq 60 ] && m "### iter=60 -> ldconfig bitti, apexe gidiyor"
  [ "$SUPERVISE_APEX" = "1" ] && ensure_apex
  [ "$n" -eq 60 ] && m "### iter=60 -> apex bitti"
  # --- apexfiles teyidi (Faz 2.3) -------------------------------------------
  # DIKKAT: apexd kendi mount'unu yapacaksa /system/apex altindaki arsivleri
  # GORMESI gerekiyor. mountapex bunu bir kez kurar; ama init bazi
  # durumlarda /system uzerine yeniden mount ederse bag kopar. Idempotent
  # bir tekrar zararsiz ve ucuz.
  if [ -n "__APEXFILES_PART__" ]; then
    if ! mountpoint -q /apexfiles 2>/dev/null; then
      mkdir -p /apexfiles 2>/dev/null
      mount -t ext4 -o ro /devblk/vda__APEXFILES_PART__ /apexfiles 2>/dev/null \
        && m "### /apexfiles yeniden baglandi ###"
    fi
    if mountpoint -q /apexfiles 2>/dev/null; then
      mountpoint -q /system/apex 2>/dev/null || \
        mount -o bind /apexfiles /system/apex 2>/dev/null
    fi
  fi
  # DIKKAT: ensure_fake_blocks SADECE BIR KEZ calisir. Tum rc dosyalarini
  # grep -r ile taramak EROFS uzerinde saniyeler suruyor; her saniye
  # calistirilirsa denetleyici o sureyle dolar ve asil onemi olan ise
  # (/dev/binder'i geri baglamak) hicbir zaman siraya gelmez:
  #     ProcessState: Opening '/dev/binder' failed: No such file or directory
  #
  # DIKKAT (HATA DUZELTMESI 2026-10-15): 'n=8' yanlistikti. supervise,
  # 'exec /system/bin/init'TEN HEMEN ONCE setsid ile arka plana
  # atiliyor; yani n=8 aninda init /dev'i HENUZ degistirmemisti. Olusan
  # sahte dugumler init /dev'in UZERINE kendi tmpfs'ini mount ederken
  # yok oluyordu. Dogru tetikleyici init'in /dev'i degistirmesidir:
  # init kendi tmpfs'ini mount edince virtio blok dugumleri (/dev/vda*)
  # kaybolur. Kaybolma anini bekleyip sahte yollari ONDAN sonra uretiyoruz.
  if [ "${fb_done:-0}" = "0" ] && [ ! -e /dev/vda1 ]; then
    fb_done=1
    ensure_fake_blocks
    m "### /dev vda* kayboldu -> sahte yollar uretildi (init /dev'i degistirdi) ###"
  fi
  # init /dev'in UZERINE kendi tmpfs'ini mount edip ueventd calistirir;
  # ueventd yalnizca Android standartlarini olusturur, virtio blok ve loop
  # dugumleri KAYBOLUR.
  #
  # DIKKAT: ONCEDEN ': > /dev/$b' ile DUZ DOSYA yaratip bind-mount
  # ediliyordu. O 1 saniyelik pencerede apexd-bootstrap duz dosyayi
  # acabiliyor ve ioctl(LOOP_CTL_GET_FREE) sessizce basarisiz oluyordu
  # -> apexd SIGABRT -> bootstrap-apexd-failed.
  # Artik dogrudan karakter cihazi mknod'luyoruz (/proc/misc'ten
  # minor okuyarak). Yarisi yok, bind yok.
  ensure_misc_devs
  # Binder: Zygote, servicemanager, HAL'lar ve uygulama sureclerinin tamami
  # binder uzerinden konusur; olmazsa hicbiri calismaz.
  #
  # DIKKAT: kernel'imiz CONFIG_ANDROID_BINDERFS=n ile derlendi, yani binder
  # klasik MISC cihazidir: /dev/binder bir karakter cihaz (major 10, minor 0).
  # BinderFS acikken /dev/binder bir DIZIN olur ve libbinder EISDIR alir:
  #     ProcessState: Opening '/dev/binder' failed: Is a directory
  # Binder: Zygote, servicemanager, HAL'lar ve uygulama sureclerinin tamami
  # binder uzerinden konusur; olmazsa hicbiri calismaz.
  # Binder geri baglama artiki mknod ile yapiliyor (ensure_misc_devs).
  # DIKKAT: asagidaki bind-mount YEDEK yol olarak duruyor. Ensure_misc_devs
  # calistiyorsa hicbiri gerekmiyor; /dev/binder karakter cihaz olarak
  # zaten varsa dongu 'continue' eder ve dokunmaz.
  #
  # DIKKAT: '[ -f "/devblk/$f" ]' yazilirsa test /devblk//devblk/binder'a
  # duser ve daima false olur (H1 hatasinin kaynagi). Dogru: /devblk/$b.
  BINDERMOUNT=0
  for f in /devblk/binder /devblk/hwbinder /devblk/vndbinder; do
    b=$(basename "$f")
    [ -c "/dev/$b" ] && continue
    [ -f "/devblk/$b" ] || continue
    : > "/dev/$b" 2>/dev/null
    mount -o bind "/devblk/$b" "/dev/$b" 2>/dev/null && BINDERMOUNT=$((BINDERMOUNT+1))
  done
  # DIKKAT: bu olcu HER SANIYE yazilirsa logu doldurur. Sadece ilk
  # basarili baglamada ve sonra durum degisirse bir kez yaziyoruz.
  if [ $BINDERMOUNT -gt 0 ] && [ "${binder_ok:-0}" = "0" ]; then
    binder_ok=1
    m "### /dev/binder geri baglandi ($BINDERMOUNT): $(/bb/ls -l /dev/binder /dev/hwbinder /dev/vndbinder 2>&1 | /bb/tr '\n' ' ')"
  fi

  # --- DIAG: apexd'yi ELLE calistir ------------------------------------------
  # DIKKAT NEDEN: apexd-bootstrap kendi hata mesajini /dev/kmsg'ye
  # tasirmiyor; init sadece "bootstrap-apexd-failed" diyor ve 5 saniyede
  # sistem kapaniyor. Sebebi gormenin TEK yolu apexd'yi elle calistirmak.
  #
  # DIKKAT: bu bir teşhis adimidir, müdahale DEGIL. Yalnizca kendi PID'imize
  # dokunuruz (init'in kendi apexd'sine dokunmaz).
  if [ $n -eq 14 ]; then
    m "### DIAG: /system/bin/apexd -b elle calistiriliyor (25 sn) ###"
    /system/bin/apexd -b > /tmp/apexd.out 2>&1 &
    ap=$!
    /bb/sleep 25
    kill -9 $ap 2>/bb/null
    wait $ap 2>/bb/null
    m "### --- apexd ciktisi ($( /bb/wc -l < /tmp/apexd.out 2>/bb/null ) satir) ---"
    /bb/head -60 /tmp/apexd.out 2>/dev/null | while read -r l; do m "### apexd| $l"; done
    m "### --- apexd ciktisi bitti ---"
  fi

  # DIKKAT: BURADA ASLA '/system/bin/ueventd' calistirma veya pkill ile
  # oldurme. ueventd, init binary'sinin AYNISI:
  #     /system/bin/ueventd -> init
  # Bu yuzden hem elle calistirmak hem de 'pkill -f /system/bin/ueventd'
  # yapmak init'in KENDI ueventd surecini olduruyor. Yani bizim teÅŸhis
  # aracimiz, araÅŸtirdigimiz Ã§Ã¶kmenin bir parÃ§asiydi:
  #     init: starting service 'ueventd'...              (54.9s)
  #     init: Service 'ueventd' (pid 2086) exited status 1  (142.9s)
  # Once testimiz onu olduruyor, sonra init yeniden baslatip
  # "critical process 'ueventd' exited 4 times" diyordu. Yanlis olcum
  # yapmak, dogru olcumu gizliyordu.
  #
  # Dogru yol: ueventd'ye HIC dokunmadan, onun ciktisini init'in seri
  # konolundan okumak (init servis ciktisini konsola yazar).
  # --- ueventd TEHLIKESINI (sadece kendi PID'imizi oldurerek) ---------------
  # init servis ciktisini oldugu icin (servis 'console' degil) init'in
  # calistirdigi ueventd'nin ciktisini GOREMIYORUZ. Tek yol elle calistirmak.
  #
  # DIKKAT: ASLA 'pkill -f /system/bin/ueventd' KULLANMA.
  #   /system/bin/ueventd -> init
  # oldugu icin bu desen init'in KENDI gercek ueventd surecini de oldurur
  # ve bizim testimiz, arastirdigimiz cokmenin bir parcasi olur.
  # Yalnizca $up PID'ini olduruyoruz.
  if [ $n -eq 40 ]; then
    m "### ueventd elle calistiriliyor (12 sn, yalnizca kendi PID'imiz) ###"
    /system/bin/ueventd > /tmp/uev.out 2>&1 &
    up=$!
    /bb/sleep 12
    kill -9 $up 2>/dev/null
    wait $up 2>/dev/null
    m "### --- ueventd ciktisi ---"
    /bb/cat /tmp/uev.out 2>/dev/null | while read -r l; do m "### uev| $l"; done
    m "### --- ueventd ciktisi bitti ($( /bb/wc -l < /tmp/uev.out 2>/dev/null ) satir) ---"
  fi

  # DIKKAT: /bb/diag2 denetleyicinin DEGIL, sistemin durumunu olcer.
  # n=25 biraz rastgele secildi: init 2. asamaya gecmis (/dev'i
  # degistirmis), supervisor da /dev'i onarmis olmali. init'in early-init
  #'indeki /bb/diag ile ARASINDAKI FARK teÅŸhisin konusu.
  [ $n -eq 25 ] && /bb/diag2

  # --- NABIZ (pulse) --------------------------------------------------------
  # DIKKAT: buradaki amacimiz TAHMIN ETMEK degil OLCMEK. Olcum su:
  #     logdaki 39 "starting service" satirinin TAMAMI "ueventd"
  # Yani init "on post-fs-data" icinde kilitli; zygote/netd/servicemanager
  # hic baslamiyor, class main hic tetiklenmiyor.
  #
  # AOSP'de "exec" komutu alt sureci bitene kadar init'i BEKLETIR. Yani
  # post-fs-data'daki tek bir "exec" sonsuza kadar asili kalabilir ve
  # butun boot orada durur. Bu, tahmin ettigimiz en olasi neden.
  #
  # Olcum yontemi: init'in DOGRUDAN cocuklarini (ppid == 1) listele ve
  # kernel'in onlari nerede beklettigini /proc/<pid>/wchan'den oku.
  # Takilan alt surecin adi ve wchan dogrudan gorunur.
  #
  # DIKKAT: /proc/<pid>/stat'ta comm parantez icinde ve BOSLUK icerebilir.
  # Bu yuzden alan sayisiyla degil, "son )'den sonraki kismi" ayirarak
  # cozuyoruz; aksi halde ppid yanlis okunur ve hicbir cocuk gorunmez.
  if [ $((n % 15)) -eq 0 ]; then
    KIDS=""
    for pd in /proc/[0-9]*; do
      pp=${pd#/proc/}
      [ "$pp" = "1" ] && continue
      st=$(/bb/cat "$pd/stat" 2>/bb/null) || continue
      rr=${st##*) }
      tt=${rr#* }
      ppid1=${tt%% *}
      [ "$ppid1" = "1" ] || continue
      nm=$(/bb/cat "$pd/comm" 2>/bb/null)
      wq=$(/bb/cat "$pd/wchan" 2>/bb/null)
      [ -n "$wq" ] || wq=${rr%% *}
      KIDS="$KIDS $nm:$wq"
    done
    m "### nabiz#$n cocuk[$KIDS]"
    m "###   apexd.status=$(/system/bin/getprop apexd.status 2>/bb/null) sys.boot=$(/system/bin/getprop sys.boot_completed 2>/bb/null) /system=$(/bb/mountpoint /system >/bb/null 2>&1 && echo var || echo YOK) apex=$(/bb/ls /apex 2>/bb/null | /bb/wc -l) ro.secure=$(/system/bin/getprop ro.secure 2>/bb/null)/$(/system/bin/getprop ro.adb.secure 2>/bb/null)"
    # adbd durumu da her nabzda gorunur olsun.
    m "###   net: [$(/bb/ls /sys/class/net 2>/bb/null | /bb/tr '\n' ' ')] ip=$(/bb/ip -o -4 addr show 2>/bb/null | /bb/tr '\n' ' ' | /bb/head -c 160) L4=$(/bb/netstat -an 2>/bb/null | /bb/grep -c 5555) L6=$(/bb/netstat -ltn6 2>/bb/null | /bb/grep -c 5555)"
    m "###   adbd=$([ "${adbd_ok:-0}" = "1" ] && echo ayakta || echo yok) svc=$(/system/bin/getprop init.svc.adbd 2>/bb/null) pid=${adbd_pid:-yok} tcp5555=$(/bb/grep -c ':15B3' /proc/net/tcp 2>/bb/null) /dev/loop-control=$([ -e /dev/loop-control ] && echo var || echo YOK)"
    # DIKKAT: init'in adbd stdout/stderr'i. Adbd calisiyor gibi gorunse
    # bile svc=restarting ise burada cokum sebebi yaziyor.
    isz=$(/bb/wc -c < /bb/nb/adbd-init.log 2>/bb/null); isz=${isz:-0}
    if [ "$isz" -gt "${iseen:-0}" ]; then
      m "### adbdi+$(/bb/tail -c +$(( ${iseen:-0} + 1 )) /bb/nb/adbd-init.log 2>/bb/null | /bb/tr '\n' '|' | /bb/head -c 300)"
      iseen=$isz
    fi
    # DIKKAT (2026-10-15): adbd TCP'ye baglaniyor ama Windows adb tarafinda
    # cihaz "offline" kaliyor. Adbd'nin baglanti aninda yazdigi mesajlar
    # OZEL log dosyasina ekleniyor ama biz onu sadece BASLANGICTA
    # basiyorduk, sonrasinda hic okumuyorduk. Bu blok /bb/nb/adbd.log
    # dosyasindaki YENI kismi (dosya buyudukce) kmsg'e tasiyor.
    asz=$(/bb/wc -c < /bb/nb/adbd.log 2>/bb/null); asz=${asz:-0}
    if [ "$asz" -gt "${adbd_seen:-0}" ]; then
      m "### adbd+$(/bb/tail -c +$(( ${adbd_seen:-0} + 1 )) /bb/nb/adbd.log 2>/bb/null | /bb/tr '\n' ' ' | /bb/head -c 240)"
      adbd_seen=$asz
    fi
    # DIKKAT (2026-10-15): adbd TCP DINLEYICISINI ACMIYOR. Surec yasiyor
    # (pid=2565) ama /proc/net/tcp'te 5555 (0x15B3) YOK, yani QEMU'nun
    # hostfwd'i guest'e ulasamiyor ve RST donuyor -> Windows adb "offline".
    # Adbd'nin hatasi logd'ye yaziliyor; logcat tamponunu bosaltiyoruz.
    # logcat asili kalabilir diye arka planda calistirip 4 sn sonra olduruyoruz.
    if [ ! -f /bb/nb/lc.pid ] && [ -x /system/bin/logcat ]; then
      ( /system/bin/logcat -d -t 400 > /bb/nb/lc.txt 2>/bb/null ) &
      echo $! > /bb/nb/lc.pid
      /bb/sleep 4
      lcp=$(/bb/cat /bb/nb/lc.pid 2>/bb/null)
      [ -n "$lcp" ] && kill -9 "$lcp" 2>/bb/null
      rm -f /bb/nb/lc.pid
      m "### logcat/adb: $(/bb/grep -i 'adbd' /bb/nb/lc.txt 2>/bb/null | /bb/tail -5 | /bb/tr '\n' '|' | /bb/head -c 420)"
      m "### logcat/son: $(/bb/grep -vi 'adbd' /bb/nb/lc.txt 2>/bb/null | /bb/tail -3 | /bb/tr '\n' '|' | /bb/head -c 260)"
    fi
    # DIKKAT: apexd-bootstrap artik /system/apex'teki 22 arsivi BULUYOR
    # ("Found pre-installed APEX /system/apex/com.android.adbd.apex" ...),
    # yani gercek APEX aktivasyonu yapilabilir durumda. Tek eksik
    # sey loop cihazi:
    #     apexd: Failed to pre-allocate loop devices :
    #            wait for '/dev/loop-control' timed out and took 50004ms
    # Bu yuzden varligini olcuyoruz; yoksa yeniden mknod ediyoruz.
    if [ ! -e /dev/loop-control ]; then
      mknod_misc /dev/loop-control loop-control
      m "### loop-control YOKTU -> yeniden olusturuldu"
    fi
  fi

  # Durum ekranini 2 saniyede bir tazele.
  [ $((n % 2)) -eq 0 ] && draw_screen

  /bb/sleep 1
  n=$((n+1))
done
SUP_EOF
sed -i "s|__APEX_LIST__|$APEX_LIST|g" "$ROOT/bb/supervise"
sed -i "s|__APEXFILES_PART__|${APEXFILES_PART:-}|g" "$ROOT/bb/supervise"
# DIKKAT (2026-10-17, HATA DUZELTMESI): ensure_data_dirs artik
# /devblk/vda__DATADEV_PART__ yolunu ariyor (gecici tmpfs'i gercek
# ext4 bolumuyle degistirmek icin). Ama bu placeholder YALNIZCA
# bb/mountapex'e ikame ediliyordu; bb/supervise'de kalirsa fonksiyon
# var OLMAYAN bir yolu arar ve sessizce basarisiz olur -- tam da
# ilk denemede oldugu gibi. O yuzden buraya da ikame ediyoruz.
sed -i "s|__DATADEV_PART__|${DATA_PART:-}|g" "$ROOT/bb/supervise"
chmod +x "$ROOT/bb/supervise"

# --- /bb/diag ---------------------------------------------------------------
# init'in early-init aurasinda durumu olcer.
#
# DIKKAT (2026-10-15): bu eskiden 5 satir yaziyordu ve SADECE pencereye
# gidiyordu (bkz. /init icindeki G1 notu). Simdi /dev/kmsg'ye de yaziyor
# ve bolum bölüm ('--- BOLUMLER ---' gibi) rapor veriyor.
#
# DIKKAT: bu bir TANI araci; hicbir seyi mount etmez, degistirmez.
cat >"$ROOT/bb/diag" <<'DIAG_EOF'
#!/bb/sh
# Ciktiyi /dev/kmsg'e yaz. kmsg TUM konsollara yazilir (seri log + pencere).
# DIKKAT: stdout'u kendimiz ceviriyoruz; init bu scripti bir SERVIS olarak
# calistirir ve o zaman stdout /dev/null'a dusuyor.
exec >/dev/kmsg 2>&1
TAG="${1:-init oncesi}"
emit() { /bb/echo "$1"; }
sec() { emit ""; emit "--- $1 ---"; }
emit ""
emit "==========================================================="
emit "  DIAG  [$TAG]   $(/bb/date 2>/dev/null)"
emit "==========================================================="

sec "BOLUMLER"
/bb/grep -E ' /(system|apex|vendor|odm|cust|hw_product|data|postinstall)[/ ]' /proc/mounts 2>/dev/null | while read -r l; do emit "  $l"; done

sec "APEX"
emit "  modul sayisi      : $(/bb/ls /apex 2>/dev/null | /bb/grep -c apex)"
emit "  runtime modulu    : $([ -d /apex/com.android.runtime ] && /bb/echo VAR || /bb/echo YOK)"
emit "  vndk.v31 takmasi  : $([ -d /apex/com.android.vndk.v31 ] && /bb/echo VAR || /bb/echo YOK)"
emit "  apex-info-list.xml: $([ -f /apex/apex-info-list.xml ] && /bb/echo VAR || /bb/echo YOK)"
emit "  apex mount (toplam): $(/bb/grep -c ' /apex/' /proc/mounts 2>/dev/null)"

sec "LINKER ZINCIRI  (apexd hatasi burada baslar)"
emit "  /system/lib64/libc.so -> $(/bb/readlink /system/lib64/libc.so 2>&1)"
if /bb/ls -lL /system/lib64/libc.so >/dev/null 2>&1; then
  emit "  libc.so COZULUYOR   : EVET ($( /bb/ls -lL /system/lib64/libc.so | /bb/awk '{print $5}') bayt)"
else
  emit "  libc.so COZULUYOR   : HAYIR   <-- 'library libc.so not found'"
fi
emit "  ld.config.txt       : $([ -f /linkerconfig/ld.config.txt ] && /bb/echo VAR || /bb/echo YOK)"
emit "  APEX arama yollari  : $(/bb/grep -c '/apex/' /linkerconfig/ld.config.txt 2>/dev/null)"
/bb/grep -E '^namespace.default.search.paths' /linkerconfig/ld.config.txt 2>/dev/null | while read -r l; do emit "    $l"; done

sec "CIHAZLAR  (init /dev'i degistirince bunlar kayboluyor)"
for d in binder hwbinder vndbinder loop-control vda1 vda6; do
  emit "  /dev/$d      : $(/bb/ls -ld /dev/$d 2>&1 | /bb/sed 's#^/dev/##')"
  emit "  /devblk/$d   : $(/bb/ls -ld /devblk/$d 2>&1 | /bb/sed 's#^/devblk/##')"
done
emit "  /dev toplam   : $(/bb/ls /dev 2>/dev/null | /bb/wc -l) dugum"
emit "  /dev/binder   : $([ -c /dev/binder ] && /bb/echo 'KARAKTER CIHAZI' || (/bb/echo 'yok/dizi' ))"

sec "SELINUX"
emit "  enforce : $(/bb/cat /sys/fs/selinux/enforce 2>&1)"

sec "SERVISLER (calisan ilk 25)"
/bb/ps 2>/dev/null | /bb/head -25 | while read -r l; do emit "  $l"; done

emit ""
emit "==========================================================="
DIAG_EOF
chmod +x "$ROOT/bb/diag"

# --- /bb/diag2 --------------------------------------------------------------
# Supervisor'in cagirdigi ikinci olcum. /bb/diag init'in early-init'inde bir
# kez calisir; o an supervisor henuz /dev'i onarmamis ve /apex'i tazelememis
# olabilir. Tek anlik goruntu, iki farkli durumu gormeyi saglamaz.
cat >"$ROOT/bb/diag2" <<'DIAG2_EOF'
#!/bb/sh
exec /bb/diag "supervisor sonrasi"
DIAG2_EOF
chmod +x "$ROOT/bb/diag2"

# --- /init.environ.rc -------------------------------------------------------
# DIKKAT NEREDEN ENJEKTE EDIYORUZ: /system/etc/init/hw/init.rc'nin en ustunde
#     import /init.environ.rc
# yaziyor. Bu SABIT bir yoldur (degisken icermez), ramdisk kokunden okunur
# ve BIRINCI ASAMADA islenir -- yani /system/build.prop henuz yuklenmeden,
# SELinux uygulanmadan calisir.
#
# DIKKAT: '/init.${ro.hardware}.rc' yolu ise BIRINCI ASAMADA calismaz:
# ro.hardware /system/build.prop'tan gelir ve o dosya ancak IKINCI asamada
# yuklenir. Import sirasinda ${ro.hardware} BOS oldugu icin '/init..rc'
# aranir ve sessizce basarisiz olur. androidboot.hardware=qemu vermek
# yeterli DEGIL.
#
# DIKKAT SIRALAMA: import'lar hw/init.rc'nin satir 7-14'unde, yani kendi
# 'on early-init' blogundan ONCE islenir: once bizim komutlarimiz, sonra
# sistemin linkerconfig'i (satir 62) ve apexd-bootstrap'i (satir 75).
# Bu siralama kritik: linkerconfig uretmeden once APEX bagli olmali.
cat >"$ROOT/init.environ.rc" <<'RC_EOF'
# HarmonyOS emu: APEX'leri init'in kendi zamanlamasinda bagla.
#
# Neden init icinde degil de burada? Android init birinci asamada /apex'in
# UZERINE kendi tmpfs'sini mount edebilir. /init (bizim initramfs init'i)
# icinde mount edersek gizlenir. Burada 'on early-init' tetiklemesi,
# init'in mount'lari bittikten sonra calisir.
#
# DIKKAT: 'exec -- /bb/diag' birinci asamada calismiyor (stok init.rc'de de
# yalnizca /system/bin/... yolu kullaniliyor). Desteklenen yol exec_start.
on early-init
    start mount_harmony_apex
    start harmony_diag
    # DIKKAT (2026-10-16, adbd'nin TCP ACILMAMASININ ASIL NEDENI):
    # AUTOPSY (elle baslatip stderr'i dosyaya yazarak) su satiri
    # gosterdi ve sonrasi KESILDI:
    #     adbd I adb_wifi.cpp:196] Waiting for persist.adb.tls_server.enable=1
    #     adbd I main.cpp:                      <-- burada bitti
    #     AUTOPSY tcp5555: 0
    # Yani adbd TCP:5555 dinleyicisini ACMADAN once bu ozelligi
    # bekliyor ve hic tanimli olmadigi icin (olcduk: /system/build.prop,
    # /vendor/build.prop, /system/etc/prop.default -> HICBIRINDE yok)
    # sonsuza kadar bekliyor. Surec yasaiyor, port acilmiyor.
    # Cozum: degeri 0 olarak ONCEDEN set et. 1 degil, sifir: TLS
    # sunucusu istemiyoruz, duz TCP istiyoruz.
    setprop persist.adb.tls_server.enable 0
    # DIKKAT (2026-10-16, L4 3. KOK NEDEN): hw/init.rc'deki zygote
    # tetikleyicisi SIFRELENMIS /data'yi bekliyor:
    #     on zygote-start && property:ro.crypto.state=unencrypted
    #         start zygote
    # OLCULDU: getprop ro.crypto.state -> BOS. cunku vold her 5
    # saniyede cokuyor:
    #     Abort message: Check failed: android::vold::sBlkidContext
    # Dolayisiyla 'zygote-start' tetigi hic zaman gelmiyor ve zygote
    # OTOMATIK baslamiyor (elle 'setprop ctl.start zygote' ile
    # baslatiyorduk ve o da asagida duzelttigimiz ikinci engele
    # takiliyordu).
    # 'ro.' salt-okunur ve ILK tanim kazanir; hicbir yerde tanimli
    # olmadigi icin burada guvenle yazabiliyoruz.
    # DIKKAT (2026-10-16, GERI ALMA): 'ro.crypto.state unencrypted'
    # burada BIRAKILDI. Tek amaci zygote tetikleyicisini
    # ('on zygote-start && property:ro.crypto.state=unencrypted')
    # hazirlamakti; ama o tetik bizim supervisor'imiz
    # (ensure_zygote -> setprop ctl.start zygote) ile zaten
    # saglaniyor. Buna karsi bu ozellik init in adbd'sini
    # komik ediyor:
    #     init: Service 'adbd' (pid 7044) exited with status 1
    # L5 (adb shell) bu kosudan once bu ozellik YOKKEN calisiyordu.
    # Iki deneme yapildi:
    #   ro.crypto.state=unencrypted + ro.crypto.type=file  -> adbd exit 1
    #   ro.crypto.state=unencrypted (type birakildi)      -> adbd exit 1
    # Yani tetikleyici adbd icin ZARARLI; zygote'yi elle
    # baslattigimiz icin bize de lazim degil.
    # DIKKAT (2026-10-16, L4 4. KOK NEDEN): zygote ANDROID_DATA'siz
    # ABORT ediyor. OLCULEN HATA (logcat):
    #     F DEBUG : Abort message: 'ANDROID_DATA environment variable
    #              unset'
    #     D AndroidRuntime: >>>>>> START com.android.internal.os.
    #                        ZygoteInit uid 0 <<<<<<
    # Yani ZygoteInit BASLIYOR sonra ANDROID_DATA arayinca abort
    # ediyor. Elle calistirilip cikti yakalandiginda:
    #     export ANDROID_DATA=/data ANDROID_ROOT=/system
    #     app_process64 -Xzygote ... -> HATASIZ calisiyor
    # yani zygote saglam, sadece ortam eksik.
    #
    # OLCUM (neden init vermiyordu):
    #     tr '\0' '\n' < /proc/1/environ | grep ANDROID  -> BOS
    # init'in kendi ortaminda sadece PATH var. Ve bu bir PROPERTY
    # degil: getprop ANDROID_DATA -> BOS.
    #
    # COZUM: init 'setenv' komutunu destekliyor (init ikilisinde
    # 'setenv' dizesi VAR -- olculdu). init kendi ortamini degistirir,
    # sonraki tum servisler onu MİRAS alir. Servisleri biz
    # ctl.start ile baslattigimiz icin (ensure_zygote, n>=30) zamanlama
    # sorun degil.
    setenv ANDROID_DATA /data
    setenv ANDROID_ROOT /system
    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art
    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    setenv ANDROID_IOTA_ROOT /apex/com.android.iota

# HarmonyOS emu: zygote'nin ihtiyac duydugu /data dizinleri.
#
# OLCULEN HATA (elle zygote calistirilip cikti yakalandi):
#     Error creating cache dir /data/dalvik-cache/arm64
#         : No such file or directory
#     Aborted
# /data bizim tmpfs'imiz (2.0G) ve BOS; vold coktugu icin de
# icerigi kurulmuyor. Dalvik cache olmadan zygote ABORT ediyor.
#
# DIKKAT: 'mkdir' komutu init'te destekleniyor ve SELinux permissive
# oldugu icin izin sorunu yok (olculdu: mkdir -p TAMAM dondu).
# Dizinleri zygote'den ONCE kurmaliyiz: post-fs-data, early-init
# sonrasi ve class main oncesi.
on post-fs-data
    mkdir /data/dalvik-cache
    mkdir /data/dalvik-cache/arm
    mkdir /data/dalvik-cache/arm64
    mkdir /data/dalvik-cache/x86
    mkdir /data/dalvik-cache/x86_64
    mkdir /data/system
    mkdir /data/system/packages
    mkdir /data/misc
    mkdir /data/local
    mkdir /data/local/tmp
    mkdir /data/app
    mkdir /data/media
    mkdir /data/media/0
    mkdir /data/user
    mkdir /data/user/0

service mount_harmony_apex /bb/mountapex
    class core
    user root
    group root
    oneshot
    disabled

service harmony_diag /bb/diag
    class core
    user root
    group root
    oneshot
    disabled

# HarmonyOS emu: adbd'yi init'in KENDI yoluyla baslat.
#
# Neden elle degil? APEX'in kendi /etc/init.rc'si soyle diyor:
#     service adbd /apex/com.android.adbd/bin/adbd --root_seclabel=u:r:su:s0
#         class core
#         socket adbd seqpacket 660 system system
#         disabled
#         seclabel u:r:adbd:s0
#
# Yani adbd'nin birincil tasimasi TCP DEGIL: init bir SEQPACKET unix
# socketu (/dev/socket/adbd) acar ve surece ANDROID_SOCKET_adbd ortam
# degiskeniyle fd verir. Elle "adbd tcp:5555" ile baslatinca o fd
# olmadigi icin su hatayi basip BIRAKIYOR:
#     adbd E auth.cpp:203] Failed to get adbd socket: Operation not permitted
# Olcutler (nabiz satirlari):
#     adbd=ayakta pid=2565 tcp5555=0     <- surec yasiyor, 5555 dinlenmiyor
#     Windows adb: "offline", QEMU hostfwd RST donuyor
# (ro.secure=0 / ro.adb.secure=0 ekledik ama yetmedi: bu hataya
#  ro.adb.secure degil, SOCKET ACTIVATION eksikligi yol aciyor.)
#
# Soket adi 'adbd' OLMAK ZORUNDA: adbd kütüphanesindeki
# android::GetControlSocket() bu adi sabit arar. 'disabled' OLMADI ->
# class core ile otomatik baslar. --root_seclabel firmware'in kendi
# degeri; su alani yoksa init servis i baslamaz ve loga yazar.
#
# DIKKAT (2026-10-15): init adbd'yi baslattiginda surec olumuyor --
# once 'starting service adbd' + 'Created socket /dev/socket/adbd' geliyor,
# sonra svc=restarting oluyor. Sebep LD_LIBRARY_PATH: elle baslatinca
# adbd'yi calistirmadan once
#     LD_LIBRARY_PATH=/apex/com.android.adbd/lib64
# ile basliyorduk ve o zaman calisiyordu (varyant=ldpath). Init kendi
# ortamini kuruyor, o degisken gelmiyor ve linker
#     CANNOT LINK EXECUTABLE ...: library "libadb_protos.so" not found
# diye adbd'yi olduruyor. Cozum: init'in 'setenv' servisi.
#
# DIKKAT (2026-10-15, ASIL COZUM): 'tcp:5555' ARGUMANI OLMAYINCA
# adbd SADECE unix socket'i dinler. Olcut bunu kanitladi:
#     init: starting service 'adbd'...
#     init: Created socket '/dev/socket/adbd', mode 660, user 1000
#     ###   adbd=ayakta svc=restarting pid=2588 tcp5555=0
# Yani surec yasiyor, init cikisi dogru, ama /proc/net/tcp'te 5555
# YOK; QEMU'nun hostfwd'i guest'e ulasamiyor ve Windows adb
# "offline" veriyordu. APEX'in kendi init.rc'sinde de tcp argmani
# yok -- cunku gercek cihazda adbd USB/UFS ile init tarafindan
# besleniyor, TCP ek yol olarak 'setprop service.adb.tcp.port 5555'
# ile ARIYILDAN SONRA aciliyor. Biz o yolu elle acmak yerine
# argumani dogrudan veriyoruz (daha deterministik).
# 'localfilesystem:' de ekliyoruz ki hem unix hem TCP calissin.
# DIKKAT (2026-10-16, 'socket' SATIRI KALDIRILDI):
# Ayirt edici olcum (olcduk, arac saglam):
#     5900 (bos port)  -> Connection refused  (QEMU guest'e ULASIR)
#     5555             -> TCP KURULDU, sonra ANINDA RST
#     baglanti sirasinda guest logunda HICBIR IZ yok (adbd AVC dahil)
# Yani adbd 5555'i dinliyor, baglantiyi kabul ediyor, cocuk surec
# olusturup ANINDA olup bitiyor. Adbd'in auth yolu (auth.cpp) her
# baglantida init'ten ANDROID_SOCKET_adbd fd'si istiyor ve bizim
# init tanimimiz bu fd'yi 'seqpacket' olarak veriyor; adbd STREAM
# bekliyor, uyumsuzluk olup cocuk sureci olduruyor olabilir.
# COZUM DENEMESI: 'socket' satiri hic koymuyoruz -> adbd saf TCP
# uzerinden calisir, auth icin socket ARAMAZ (ro.adb.secure=0
# zaten auth'u kapatiyor).
service adbd /apex/com.android.adbd/bin/adbd tcp:5555
    class core
    seclabel u:r:adbd:s0
    override
    # DIKKAT (2026-10-16): bu tanim /init.environ.rc ICINDE ve
    # rclog bu dosyayi ISLEMEZ (o yalnizca bind-mount edilen rc
    # agacini yamalayor). Bu yuzden stdio_to_kmsg otomatik eklenmiyor
    # ve init in adbd'si OLURKEN hicbir sey yazmiyor:
    #     init: Service 'adbd' (pid 7044) exited with status 1
    # Elle baslatilan adbd ise sorunsuz:
    #     main.cpp:186] adbd listening on tcp:5555
    # Yani ikili saglam; sorun bu servisin baslatilma yolunda.
    # DIKKAT: bu init surumu 'stdout'/'stderr' secenegini DESTEKLEMIYOR
    #     init: ... Invalid keyword [stdout]
    # dogru secenek stdio_to_kmsg.
    stdio_to_kmsg
    setenv LD_LIBRARY_PATH /apex/com.android.adbd/lib64
    setenv HOME /tmp
    setenv TMPDIR /tmp

# ---------------------------------------------------------------------
# DIKKAT (OLCUM SERVISI 2026-10-18): arkinit'in dlopen izini
# almak icin. NEDEN GEREKIYOR:
#
#   * app_process64'un ART yolunda VM HIC olusmuyor (dltrace
#     kaniti: 10 dlopen cagri, hicbiri libart icin, 0 basarisiz)
#   * Ark yolunu elle taklit ettigimizde de Ark yuklenmiyor
#     (ARK_RUNTIME=libarkruntime.so env degiskeni tek basina
#      yetmiyor; hicbir kutuphanenin DT_NEEDED'inde libarkruntime.so
#      YOK -- olculdu)
#   * init'in baslattigi GERCEK arkinit sureci cok kisa yasadigi
#     icin /proc haritasini yakalayamadik (zombi olarak bulduk)
#
# Bu servis, init.arkinit.rc'deki arkinit taniminin BIREBIR kopyasi
# + tek fark: LD_PRELOAD=/data/dltrace.so. Boylece:
#   - init ona GERCEK ortami verir (setenv'ler dahil)
#   - SELinux baglami dogru olur (u:r:zygote:s0)
#   - stdio_to_kmsg ile dltrace ciktisi SERI LOGA duser
#     (elle calistirdigimizde sadece bize gorunuyordu)
#
# DIKKAT: bu bir TEJHIS aracidir, sistemi degistirmez. disabled
# degil ama ctl.start ile elle baslatilir; surec kendi cikisinda
# init tarafindan temizlenir.
# DIKKAT: /data/dltrace.so'nun var olmasi gerekir; bb/supervise
# her turde /bb/dltrace.so -> /data/dltrace.so kopyalama yapar.
# ---------------------------------------------------------------------
service arkprobe /system/bin/app_process64 -Xzygote /system/bin --zygote --nice-name=zygote64 --socket-name=ark
    stdio_to_kmsg
    setenv ANDROID_DATA /data
    setenv ANDROID_ROOT /system
    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art
    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    setenv ANDROID_IOTA_ROOT /apex/com.android.iota
    setenv ARK_RUNTIME libarkruntime.so
    setenv LD_PRELOAD /data/dltrace.so
    class main
    user root
    group root
# DIKKAT (2026-10-18): bu servis OLcum icin ve TEK BASINA calistirilir.
# boot'ta otomatik BASLATILMAZ (disabled) -- cunku Ark yolunda
# surec sonsuz donup duruyor ve TCG altinda islemciyi yiyor.
# Kullanim:  setprop ctl.start arkprobe
#           /data/dltrace.log dosyasini oku
# SONUC (olculdu, arac dogrulandi): bu yolda da VM OLUSMUYOR.
#   DLOPEN "libc.so" x3 / "libnetd_client.so" x2 /
#   "libiAwareSdkCore.so"  -> hepsi TAMAM
#   android_dlopen_ext     -> HIC CAGRILMADI
#   libarkruntime.so       -> YUKLENMEDI
#   191 benzersiz .so yuklendi, icinde HICBIR VM kutuphanesi
disabled
RC_EOF

# --- /init ------------------------------------------------------------------
cat >"$ROOT/init" <<'INIT_EOF'
#!/bb/sh
# ---- HarmonyOS emu: bolumleri bagla, Android init'e devret ----
export PATH=/bb:/sbin:/bin:/usr/bin:/usr/sbin

mkdir -p /sys/fs/selinux
mount -t proc     proc     /proc  2>/dev/null
# DIKKAT: /dev icin devtmpfs KULLANIYORUZ. Bos tmpfs denendi ve
# KIRMADI: bizim kendi init'imiz /dev/console ve /dev/null'a ihtiyac
# duyuyor; bos /dev onu susturuyor (Run /init as init process
# sonrasi hic cikti gelmiyor).
#
# DIKKAT: CONFIG_DEVTMPFS_MOUNT=y oldugu icin kernel /dev'i boot
# aninda mount ediyor ve /dev/null hazir geliyor; init birinci
# asmada mknod ile tekrar olusturmaya calisiyor ve Huawei bunu
# EEXIST'ye olduruyor. Bu, asagidaki guvenlik agi ile izleniyor.
mount -t devtmpfs devtmpfs /dev   2>/dev/null
mount -t tmpfs    tmpfs    /tmp   2>/dev/null

# --- CIKTI KANALI (G1 DUZELTMESI 2026-10-15) --------------------------------
# DIKKAT: kernel komut satirinda
#     console=ttyAMA0,115200 console=tty0
# yazili. Coklu 'console=' verildiginde /dev/console EN SON konsola
# (yani tty0'a) baglanir. Kernel mesajlari iki konsola da gider (log
# doluyor), ama BU scriptin echo ciktilari SADECE pencereye gider.
# draw_screen de her 2 saniyede '\033[H\033[2J' ile ekrani temizledigi
# icin o cikti bir saniye sonra yok oluyor.
#
# KANIT: log'da 'HARMONYOS BOOT' banner'i HIC YOK; buna karsilik
# supervise'in '/dev/kmsg'ye yazdigi '### /apex tazelendi' satirlari VAR.
# Yani butun teÅŸhis ciktisi kameraya gidiyor, dosyaya degil.
#
# Cozum: stdout/stderr'i /dev/kmsg'ye yonlendir. kmsg TUM konsollara
# yazilir (hem ttyAMA0 seri loga, hem tty0 penceresine) -- hicbir sey
# kaybolmaz, sadece TEKRAR olur. kmsg acilamazsa /dev/console'a duser.
# Cozum: stdout/stderr'i bir DOSYAYA yonlendir, denetleyici kmsg'e
# dokunesrate sinirinin ALTINDA bosalt. kmsg TUM konsollara yazilir
# (hem ttyAMA0 seri loga, hem tty0 penceresine).
#
# DIKKAT (2026-10-15): once dogrudan /dev/kmsg'ye yaziyorduk ve
# cikti KAYBOLUYORDU. Temiz kosunun logunda /init'in butun govdesi
# yok; sadece alt sureclerin ciktisi var:
#     [ 3.441773] linkerconfig: Failed to scan APEX modules   (alt surec)
#     ( DENEY, ANDROID INIT BASLATILIYOR, prop.default ... YOK )
#     printk: init: 40 output lines suppressed due to ratelimiting
#
# NEDEN: cekirdekte
#     kernel/printk/printk.c:  DEFINE_RATELIMIT_STATE(printk_ratelimit_state, 5*HZ, 10)
#     include/linux/ratelimit.h: pr_warn("%s: %d output lines suppressed ...")
# limit 5 saniye / 10 satirdir ve komut satirindaki
# 'printk_ratelimit=1000000' BU CEKIRDEKTE HIC TANIYLI DEGIL
# (core_param tanimi yok) -- sessizce yok sayiliyor.
# Bizim surec adimiz "init" oldugu icin (/init betigi) baskilayan
# cagri noktasi bize ait sayiliyor ve satirlarimiz atiliyor.
#
# COZUM: /init kmsg'ye HIC yazmaz. Bir dosyaya yazar; denetleyici her
# saniye en fazla 3 satiri kmsg'e bosaltir. Boylece hicbir sey kaybolmaz
# ve hicbir sey limiti tetiklemez.
INITLOG=/bb/init.out
: > "$INITLOG" 2>/dev/null
exec 1>>"$INITLOG" 2>&1
echo "### /init cikti kanali -> $INITLOG (denetleyici kmsg'e bosaltacak) ###"

# --- binderfs ----------------------------------------------------------------
# DIKKAT: kernel'imizde CONFIG_ANDROID_BINDERFS=y. Bu ayarla binder, klasik
# /dev/binder misc dugumu olarak DEGIL, binderfs dosya sistemi icinde
# (/dev/binder/binder, /dev/binder/hwbinder, ...) olarak sunulur. Binderfs
# KULLANICI tarafindan mount edilmedikce hicbir binder dugumu gorunmez:
#     ls: /dev/binder*: No such file or directory
#     ProcessState: Opening '/dev/binder' failed: No such file or directory
#
# Bu olmadan Zygote, servicemanager, HAL'lar ve uygulama sureclerinin hicbiri
# calismaz -- hepsi binder uzerinden konusur.
#
# DIKKAT: /dev/binder'e mount EDEMIYORUZ, cunku init /dev'in UZERINE kendi
# tmpfs'ini mount edince kaybolur. Bunun yerine /devblk/binder'a mount
# edip, init /dev'i degistirdikten sonra oraya bind ediyoruz (denetleyici).
#
# DIKKAT: kernel'i CONFIG_ANDROID_BINDERFS=n ile derledigimiz icin binderfs
# mount EDMIYORUZ -- /dev/binder zaten bir karakter cihaz olarak gelir ve
# mountapex'te /devblk'ye baglanir. (Onceki bir denemede bu blok varken
# shell sozdizimi bozuldu: if satiri silinip 'else'/'fi' orphans kalmisti ->
# '/init: line 26: syntax error: unexpected "else"')
# /sys'i ve selinuxfs'i BIZ mount ETMIYORUZ. Denendi: mount edersek init
# "Device or resource busy" aliyor ve BU Ã–LÃœMCÃœL:
#   init: mount("sysfs","/sys",...) failed Device or resource busy
#   init: Init encountered errors starting first stage, aborting
# SELinux'u permissive kilitleme ise asagidaki gozlemci suresi icinde,
# selinuxfs belirir belirmez yapilir.
# /sys'i BIZ mount etmiyoruz: init birinci asamada kendisi mount ediyor ve
# biz mount edersek "Device or resource busy" hatasi aliyor.
# (SELinux'u kilitlemek icin birakiyoruz; asagida gerekirse yine de
#  mount ediyoruz.)

echo ""
echo "================================================================"
echo "  HARMONYOS BOOT  ->  init  ->  apexd  ->  Zygote"
echo "================================================================"
echo "kernel: $(uname -r)"
echo "binder: $(grep -c binder /proc/devices 2>/dev/null || echo 0) kayit"
ls /dev/binder* 2>/dev/null | sed 's/^/  /'
echo ""

mount_boot() {   # $1=partno $2=hedef $3=etiket
  local dev="/dev/vda$1"
  [ -b "$dev" ] || { echo "  [$3] $dev YOK"; return 1; }
  if mount -t erofs "$dev" "$2" 2>/dev/null; then
    echo "  [$3] $dev -> $2   basarili"; return 0
  fi
  echo "  [$3] $dev -> $2   BASARISIZ"; return 1
}

echo "--- bolumler baglaniyor (EROFS) ---"
# Disk sirasi bizim kurdugumuz sirayla:
#   1=system 2=hw_product 3=vendor 4=odm 5=cust
mount_boot 1 /r           "rootfs"
mount_boot 2 /hw_product  "hw_product"
mount_boot 3 /vendor      "vendor"
mount_boot 4 /odm         "odm"
mount_boot 5 /cust        "cust"

# --- /data: kullanici verisi -------------------------------------------------
# DIKKAT (2026-10-15): vold ARIA SUREKLI cokuyordu:
#     vold: Check failed: android::vold::sBlkidContext != nullptr
#     init: starting service 'vold'...        (25 kez)
# Sebep: /data HIC YOK. Disk imajimizin 26 bolumunun hicbiri userdata
# degil (5 sistem + 21 APEX). vold blkid'de userdata ariyor, bulamiyor ve
# CHECK FAIL ile oluyor.
# Sonrasi: 'init_user0' basarisiz -> zygote hic baslamaz:
#     init: Failure (reboot suppressed): init_user0_failed
# Yani zygotenin onundeki SON buyuk engel /data.
#
# Cozum: 80-build-bootdisk.sh bir ext4 data.img uretip EN SON bolum olarak
# ekliyor (su an 29). Burada onu /devblk/vda29 uzerinden /data altina
# bagliyoruz.
# DIKKAT: bolum numarasi KALICI DEGIL; disk duzeni degisirse burasi da
# degismeli. Yanlis numara bir APEX bolumunu /data'ya baglar ve vold
# yine cokmeye devam eder.
DATADEV=__DATADEV__
# DIKKAT (2026-10-15): burasi KOSUL ARASINDA mesaj yazmiyordu; /devblk
# dugumu hazir olmadiginda HICBIR SEY gorunuyordu ve nedenini
# tahmin etmek zorunda kaldik. Artik her durumda yaziyoruz.
mkdir -p /data 2>/bb/null
if [ -b "$DATADEV" ]; then
  if mountpoint -q /data 2>/bb/null; then
    echo "  /data: zaten bagli ($DATADEV)"
  elif mount -t ext4 -o rw "$DATADEV" /data 2>/bb/null; then
    echo "  /data: $DATADEV baglandi (rw)"
  else
    echo "  /data: $DATADEV MOUNT BASARISIZ"
  fi
else
  echo "  /data: $DATADEV blok cihaz degil (vold cokmeye devam eder)"
fi
echo ""

if [ -d /r/system/bin ]; then
  # DIKKAT (COZUM 2026-10-16, L4 11. KOK NEDEN): /system artik
  # SYMLINK DEGIL, GERCEK MOUNT NOKTASI.
  #
  # SORUN (olculdu):
  #     /system -> /r/system   (ls -ld /system)
  # Boylece ikililerin GERCEK yollari /r/system/bin/... oluyor ve
  # linker config bolumu ikilinin YOLUNE gore secildigi icin
  # /r/system/... HICBIR bolumle eslesmiyor (eslesenler: /system/,
  # /vendor/, /apex/<ad>/). Bos (default) bolum -> hic arama yolu:
  #     F linker: CANNOT LINK EXECUTABLE "/r/system/bin/init":
  #                library "libc.so" not found
  #     F linker: "/system/bin/audioserver": libandroidicu.so not
  #                found: needed by /r/system/lib64/libmedia.so
  # Yani tek bir symlink yuzunden 47 hatada 23 tanesi oluyor.
  #
  # COZUM: /system dizinini gercek mount noktasi yap ve
  # /r/system'i UZERINE bind et. Boylece yollar /system/... olur,
  # [system] bolumu dogru secilir ve diger butun duzeltmelerimiz
  # (APEX yollari, permitted.paths) de ise yarar.
  #
  # DIKKAT: bind mount basarisiz olursa symlink'e DUSULUR (eski
  # davranis) -- sistem yine acilir, sadece bu duzelme olmaz.
  rm -f /system 2>/dev/null
  rmdir /system 2>/dev/null
  mkdir -p /system 2>/dev/null
  if mount -o bind /r/system /system 2>/dev/null; then
    echo "  /system: /r/system bind mount olarak baglandi"
  else
    ln -sfn /r/system /system
    echo "  /system: bind BASARISIZ, symlink eklendi (eski yol)"
  fi
  for l in bin sbin etc lib lib64 usr; do
    if [ -e "/r/system/$l" ]; then
      rm -f "/$l" 2>/dev/null
      rmdir "/$l" 2>/dev/null
      ln -sfn "/system/$l" "/$l"
    fi
  done
  rm -f /lib 2>/dev/null; rmdir /lib 2>/dev/null
  ln -sfn /system/lib64 /lib
  echo "--- /system baglandi ---"
  echo "  binary : $(ls /system/bin 2>/dev/null | wc -l)"
  echo "  init   : $(readlink /system/bin/init 2>/dev/null)"
else
  echo "  [HATA] /r/system yok -- bolumler duzgun baglanmadi"
  exec /bb/sh
fi
echo ""

# --- SELinux: DERLENEN politika yerine HAZIR politika ------------------------
# DIKKAT BU ADIM PROJENIN EN ETKILI DUZELTMESI.
#
# Gercekte olusan:
#     init: /vendor/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256
#           exists but /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 doesn't
#     init: Compiling SELinux policy
#     SELinux: 48 adet "Context ... is not valid (left unmapped)"
#
# Yani init hazir politikayi KULLANAMIYOR ve kaynak .cil dosyalarindan
# yeniden derliyor. Derlenen politika eksik cikiyor ve kritik baglamlar
# tanimli degil. Sonuc (olcum):
#     init: Service 'ueventd' ... exited with status 1     (critical!)
#     init: Subcontext exited with status 1                 (vendor_init)
#     starting service 'vendor.*-hal'  -> 0 tane
# Yani Kirin HAL'larinin hicbiri baslamiyor.
#
# NEDEN eslesmiyor: Android 12'de init, vendor ve system_ext tarafinin
# "bu policy ayni surumden mi" imzasini KARSILASTIRIR. Dosyalar ayniysa
# hazir policy guvenle yuklenir. Bu firmware'de vendor tarafi var,
# system_ext tarafi YOK. Dogrulandi: system.img icindeki /system_ext
# dizini BOS, /etc/selinux/system_ext_... da hicbir yerde yok.
# (Bu firmware'de super'da 5 dinamik partition var; system_ext ayri bir
#  partition degil, bos bir dizin.)
#
# COZUM: eşleme dosyasini SENTEZLE. Icerik vendor kopyasinin aynisi
# olmak zorunda (tek satirlik bir onaltilik hash). Boylece init
# "ikisi de ayni" der ve hazir policy'yi yukler -- 48 baglam yerinde
# kalir, ueventd ve vendor_init subcontext calisir.
#
# DIKKAT: bu bir aldatma degil. Politika zaten vendor icinde HAZIR ve
# dogru; sadece init'in guven kontrolu icin gereken ikinci kopyayi
# uretiyoruz. Cihazda ayni dosya system_ext partition'inda duruyor.
VSHA=/vendor/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256
mkdir -p /system_ext/etc/selinux
if [ -f "$VSHA" ]; then
  cp "$VSHA" /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 2>/dev/null
  if [ -s /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 ]; then
    echo "--- SELinux ---"
    echo "  hazir politika eslemesi SENTEZLENDI (init artik derlemeyecek)"
    echo "  sha256: $(cat /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 2>/dev/null | head -c 64)"
  else
    echo "--- SELinux ---"
    echo "  [UYARI] esleme dosyasi kopyalanamadi -> politika yine derlenecek"
  fi
else
  echo "--- SELinux ---"
  echo "  [UYARI] $VSHA yok -> politika derlenmeye devam edecek"
fi
echo ""

mkdir -p /data /data/local /data/system
# DIKKAT (HATA DUZELTMESI 2026-10-16): bu mount HER cagrida kosulsuz
# calisiyordu. mountapex supervisor dongusunde TEKRAR cagriliyor ve
# her cagrida /data uzerine YENI (bos) tmpfs bind ediyordu.
# OLCULEN ETKI:
#   [ 96.2] ### /data dizinleri kuruldu (30. tur) ###
#   [109.2] ### ctl.start zygote -> svc=running dcache=VAR ###
#   ...
#   bootfail: open [/data/system/dropbox] failed!  [No such file]
#   bootfail: open [/data/tombstones] failed!
#   init: critical process 'zygote' exited 4 times before boot completed
# Yani dizinler kuruluyor, zygote bir sure ayakta kaliyor, sonra
# mountapex tekrar cagrilinca /data SIFIRLANIYOR ve zygote dalvik-cache
# bulamayip signal 6 ile cokuyor.
# COZUM: yalnizca /data henuz mount edilmemisse mount et.
#
# DIKKAT (KOK NEDEN DUZELTMESI 2026-10-17): "mountpoint -q /data"
# KORUMASI YETERSIZDI. /init'in kendi ext4 mount denemesi
# (satir ~3144) BASARISIZ oluyor ve /data bir DIZIN kalip buraya
# geliyor. Nedeni satir 214'te yazili:
#     : > /devblk/vda29                       # bos dosya olustur
#     mount -o bind /dev/vda29 /devblk/vda29 # /dev/vda29 YOK
# OLCULEN KANIT (konukta):
#     ls -l /dev/vda29    -> No such file or directory
#     ls -l /devblk/vda29 -> brw------- 1 0 0 259, 13
#                            (bunu sonradan ueventd yaratiyor;
#                             mount aninda duz dosya)
# Yani mount aninda [ -b ] testi basarisiz olur, ext4 mount HIC
# denenmez ve biz buraya tmpfs ile geliriz. Oyleyse /data asla
# gercek bolumu gormez ve vold kurulamaz:
#     vold: Check failed: android::vold::sBlkidContext != nullptr
#     bootfail: find log in [/data/system/dropbox] failed!
#
# OLCULEN GERCEK /data (elle mount edilince):
#     /devblk/vda29 on /data type ext4 (rw,seclabel,relatime)
#     icerik: lost+found  misc  system  user_de
# Bolum saglam ve dolu. Dogru davranis: ONCE GERCEK BOLUMU dene,
# ancak o da yoksa tmpfs'e dus.
# DIKKAT: kontrolu "mount noktasi mi" degil "/data tmpfs mi"
# UZERINDEN yapiyoruz; boylece gecici isimiz her turde gercek
# bolumle degistirilir.
# DIKKAT (IKINCI HATA DUZELTMESI 2026-10-17): ilk denemede burada
# __DATADEV_PART__ yaziyordu. Ama o placeholder SADECE
# bb/mountapex dosyasina ikame ediliyor (satir 421 ve 3744).
# /init'e SADECE __DATADEV__ ikame ediliyor (satir 3743).
# O yuzden ilk surum var OLMAYAN bir yol ariyordu; denetleyici
# gunlugunde mesajimiz hic gorunmedi (GERCEK BOLUM satiri bos
# kaldi) ve /data yine tmpfs olarak kaldi. OLCULARAK ANLASILDI.
# DOGRULU YOL: bu blok /init icinde oldugu icin DATADEV degiskenini
# kullan (satir ~3139'da tanimli, sed ile /devblk/vda29 olur).
DATASRC=
for c in ${DATADEV:-} /devblk/vda__DATADEV_PART__; do
  [ -n "$c" ] || continue
  if [ -b "$c" ]; then DATASRC="$c"; break; fi
done
if [ -n "$DATASRC" ] && /bb/grep " /data " /proc/mounts 2>/dev/null | /bb/grep -q "tmpfs"; then
  if mount -t ext4 -o rw "$DATASRC" /data 2>/dev/null; then
    echo "### /data: gecici tmpfs -> GERCEK BOLUM ($DATASRC) ###"
  else
    echo "### /data: GERCEK BOLUM mount BASARISIZ ($DATASRC) ###"
  fi
fi
if mountpoint -q /data 2>/dev/null; then
  echo "--- /data ---"
  echo "  zaten mountlu, yeniden baglanmadi (icerik korunuyor)"
else
  mount -t tmpfs -o size=2G tmpfs /data 2>/dev/null
  echo "--- /data ---"
  echo "  tmpfs baglandi"
fi
# DIKKAT: tombstoned ve bootfail bu dizinleri ZORUNLU istiyor; yoksa
# her olayda 'open failed' yazip duruyorlar.
for d in tombstones system system/dropbox system/packages misc \
         local local/tmp app media media/0 user user/0 \
         dalvik-cache dalvik-cache/arm dalvik-cache/arm64 \
         dalvik-cache/x86 dalvik-cache/x86_64 ; do
  mkdir -p "/data/$d" 2>/dev/null
done
df -h /data 2>/dev/null | tail -1
echo ""

# --- /cache -----------------------------------------------------------------
# DIKKAT: /cache /system'in ICINDE (/system/cache) ve EROFS -> salt okunur.
# init post-fs asamasinda orayi sahiplenmeye calisiyor ve HATA ALIYOR:
#     init: Command 'chown system cache /cache' action=post-fs
#           (init.rc:574) took 0ms and failed: lchown() failed: Read-only FS
#     init: Command 'mkdir /cache/recovery 0770 system cache'
#           took 4ms and failed: Read-only FS
# Bu bir sonraki asamayi (post-fs-data -> class main -> ZYGOTE) bloklar.
# Cozum: uzerine yazilabilir bir tmpfs bagla.
mkdir -p /cache
mount -t tmpfs -o size=64M tmpfs /cache 2>/dev/null
echo "--- /cache ---"
df -h /cache 2>/dev/null | tail -1
echo ""

# --- /metadata, /mnt/vendor, /odm_dlkm vb. -----------------------------------
# DIKKAT: Huawei rc'leri bu yollari da sahiplenmeye calisiyor. Hepsi
# /system altinda oldugu icin ayni sorun. Tek tek tmpfs baglamak yerine
# hepsini bir dongude yapiyoruz; olmayanlari eklemek zararsiz.
for d in /metadata /mnt/vendor /mnt/vendor/persist /odm_dlkm /vendor_dlkm \
         /sdcard /storage/emulated /mnt/user /mnt/sdcard /second_stage_resources; do
  mkdir -p "$d" 2>/dev/null
  mountpoint -q "$d" 2>/dev/null && continue
  mount -t tmpfs -o size=32M tmpfs "$d" 2>/dev/null
done
echo "--- yazilabilir mount noktalari ---"
echo "  tmpfs sayisi: $(grep -c ' tmpfs ' /proc/mounts 2>/dev/null)"
echo ""

# --- /log ------------------------------------------------------------------
# --- tracefs (2026-10-16) ---------------------------------------------------
# OLCULEN BELIRTI: system_server fork ediyor ama hemen:
#     E cutils-trace: Error opening trace file: No such file or
#       directory (2)
# ve ayrica tombstoned uyari veriyordu:
#     Abort message: tracefs must be mounted at either
#       /sys/kernel/tracing or /sys/kernel/debug/tracing
# Bu ikinci mesaj bir vendor servisini (android.hardware.atrace) ABORT
# ediyordu. Izinli yollara tracefs'i ekliyoruz; kernel'de
# CONFIG_TRACING=FS_TRACE yazili (diger tracer ayarlari ile birlikte).
if ! mountpoint -q /sys/kernel/tracing 2>/dev/null; then
  mkdir -p /sys/kernel/tracing 2>/dev/null
  mount -t tracefs nodev /sys/kernel/tracing 2>/dev/null
fi
if [ -d /sys/kernel/tracing/events ]; then
  echo "--- tracefs ---"
  echo "  bagli: $(ls /sys/kernel/tracing/events 2>/dev/null | wc -l) olay grubu"
else
  echo "--- tracefs ---"
  echo "  [UYARI] baglanamadi (cutils-trace yine hata verecek)"
fi

# Huawei'nin 'bootfail' modulu kritik surec hatalarini /log altina yaziyor:
#     bootfail: lstat [/log/critical_process_crash.txt] failed!
# /log EROFS'te SALT OKUNUR bir dizin; uzerine tmpfs baglayarak yazilabilir
# yapiyoruz. Duz olmasa da init'in sonraki adimlari (rapor yazma, yeniden
# deneme) takilip kalabiliyor.
mkdir -p /log
mount -t tmpfs -o size=64M tmpfs /log 2>/dev/null
echo "--- /log ---"
df -h /log 2>/dev/null | tail -1
echo ""

# --- APEX: TAVUK-YUMURTA SORUNU --------------------------------------------
# /system/bin/init'in KENDISI dinamiktir ve libc.so'ya APEX'ten ihtiyac
# duyar:
#     CANNOT LINK EXECUTABLE "/system/bin/init": library "libc.so" not found
# Oysa APEX mount'unu init.rc'deki bir servisle yapsak, servis ancak
# init calistikten SONRA tetiklenir -- init ise hicbir zaman baglanamaz.
#
# Gercek Android'de bu zincir ramdisk'teki AYRI bir first_stage init ile
# cozulur; o /apex'i baglar, sonra /system/bin/init'i baslatir.
#
# Burada iki katman kuruyoruz:
#   1) simdi (/init icinde)  -> init'in baglanabilmesi icin ZORUNLU
#   2) init.rc early-init   -> init /apex'in USTUNE kendi tmpfs'sini
#                              mount ederse yeniden baglar
# Ikinci katman zararsiz: ayni cihazi ayni noktaya tekrar mount etmek
# ust ustte mount yaratir ve oncekiyi gizler -- bu tam da istenen etki.
/bb/mountapex
echo ""

# --- DENEY: apexd'nin link adimini kendi /init icimizde tekrarla -------------
# Chroot'ta ayni islem calisiyor (bootstrap linkerconfig ciktisi + /apex
# mount) ama QEMU'da calismiyor. Farki init BASLAMADAN once olusturuyoruz:
# once init'in kullanacagi bootstrap config'i uret, sonra apexd'yi bagla.
# Boylece "apexd libc.so'yu neden bulamiyor" sorusu init olmadan yanitlanir.
echo "--- DENEY: bootstrap linkerconfig + apexd baglama ---"
mkdir -p /linkerconfig/bootstrap
/system/bin/bootstrap/linkerconfig --target /linkerconfig/bootstrap 2>&1 | sed 's/^/    /'
echo "    ld.config.txt /apex satiri: $(grep -c '/apex/' /linkerconfig/bootstrap/ld.config.txt 2>/dev/null)"
echo "    libc.so hedefi : $(readlink /system/lib64/libc.so 2>&1)"
if ls -lL /system/lib64/libc.so >/dev/null 2>&1; then
  echo "    libc.so COZULUYOR (dosya sisteminde)"
else
  echo "    libc.so COZULMUYOR (dosya sisteminde)  <-- SORUN BURDA"
fi
echo "    apexd baglama denemesi:"
/system/bin/linker64 --list /system/bin/apexd 2>&1 | tail -6 | sed 's/^/      /'
echo "--- DENEY bitti ---"
echo ""

# --- DENETLEYICI -------------------------------------------------------------
# exec ile PID 1 olunca bu betik kaybolur; o yuzden denetleyiciyi onceden
# arka plana birakiyoruz. init onu devralir ve calismaya devam eder.
# Gorevleri: /apex'i tazelemek (init uzerine tmpfs mount edip gizliyor) ve
# SELinux'u permissive kilitlemek.
setsid /bb/supervise &

# --- /bb/supervise ----------------------------------------------------------
# Arka planda calisan denetleyici. Iki isi var:
#
# 1) SELinux'u kalici PERMISSIVE birakmak.
#    DIKKAT: selinuxfs'i /init icinde mount ETMEK yanlis -- init birinci
#    asamada "Device or resource busy" alip OLUR:
#      init: Init encountered errors starting first stage, aborting
#    Dogru zaman, selinuxfs hazir olur olmaz ve init policy'yi yukledikten
#    hemen sonra. enforce dosyasi SELinux pseudo-dosyasi; duz bir dosyaya bind
#    mount edince init'in "1" yazmasi cekirdege ulasmaz.
#
# 2) /apex'i TAZELEMEK. Asil sorun bu. init (apexd-bootstrap) /apex'in
#    UZERINE bos bir tmpfs mount ediyor; 22 APEX mount'u altta kaliyor ama
#    gizleniyor:
#      SNAP: apex=0  ama  /proc/mounts'ta 22 apex mount'u
#    Sonuc: /system/lib64/libc.so -> /apex/com.android.runtime/.../libc.so
#    symlink'i kirilir ve init'in baslattigi HER sey baglanamaz:
#      apexd:  CANNOT LINK ... library "libc.so" not found
#      init:   cannot execv('/system/bin/app_process64')   â† ZYGOTE
#    Denetimcisi bir sefer yapip birakmiyor; /apex bosalirsa yeniden
#    mount ediyor.
echo "================================================================"
echo "  ANDROID INIT BASLATILIYOR"
echo "================================================================"
echo ""

# --- /bb/nb: yazilabilir bosluk (SALT OKUNUR KOKTEN SONRA) ------------------
# DIKKAT (2026-10-15): init 'on post-fs' icinde kok dosya sistemini salt
# okunur yapiyor:
#     mount rootfs rootfs / remount bind ro nodev
# O andan sonra /bb uzerine yazilamaz ve stderr yonlendirmelerimiz hata
# verir:
#     can't create /bb/null: Read-only file system
# Salt okunur bir dosya sisteminin ALT dizinine tmpfs baglamak serbesttir.
mkdir -p /bb/nb
mount -t tmpfs -o size=64k tmpfs /bb/nb 2>/bb/null
: > /bb/nb/null 2>/bb/null
echo "  /bb/nb: yazilabilir bosluk hazir ($(ls -l /bb/nb/null 2>/bb/null | tr -s ' ' | cut -d' ' -f1,5,9))"
export ANDROID_ROOT=/system
export ANDROID_DATA=/data
export ANDROID_STORAGE=/data
export PATH=/system/bin:/system/sbin:/vendor/bin:/vendor/sbin:/bb
export LD_LIBRARY_PATH=/system/lib64:/vendor/lib64:/apex/com.android.runtime/lib64

# --- EKSIK OZELLIK: ro.logsystem.usertype -----------------------------------
# DIKKAT (2026-10-15): firmware'de /system/etc/prop.default DOSYASI YOK
# (erofs'tan dogrulandi) ve init'in yukledigi TUM build.prop dosyalarinda
# da su ozellik tanimli degil. Duzeltilmis tarayici ile BES bolumun
# tamami tarandi (/system, /hw_product, /vendor, /odm, /cust):
#     arama bitti: logsystem.usertype
# Kontrol amacli ayni tarayici "ro." desenini denedi ve /vendor/build.prop
# icinde 15+ ozellik buldu -- yani arac calisiyor, ozellik GERCEKTEN yok.
#
# init'e preload edilmis Huawei kitapligi (libhwcust_init) bu ozelligi
# okuyor. vendor_init ALT BAGLAMI okuma hatasiyla STATUS 1 ile oluyor:
#     audit: denied { read } for property=ro.logsystem.usertype
#            scontext=u:r:vendor_init:s0 tclass=file
#     init: Subcontext exited with status 1
#
# DIKKAT: once /system/etc/prop.default UZERINE bind-mount denedik; basarisiz
# oldu, cunku hedef dosya YOK ve bind-mount olmayan bir yola baglanamaz:
#     prop.default: bind BASARISIZ (ozellik tanimsiz kalir)
# /system EROFS oldugu icin dosyayi da yaratamiyoruz.
#
# COZUM: build.prop dosyalarini kopyalayip EKLE satiri ekliyoruz ve
# bind-mount ile GERCEK dosyanin UZERINE koyuyoruz. Hedef dosya VAR
# oldugu icin bu calisir.
mkdir -p /bb/prop
NPROP=0
for bp in /system/build.prop /vendor/build.prop /odm/build.prop \
          /cust/build.prop /hw_product/build.prop; do
  [ -f "$bp" ] || continue
  mkdir -p "/bb/prop$(dirname "$bp")" 2>/bb/null
  cp "$bp" "/bb/prop$bp" 2>/bb/null || continue
  echo "ro.logsystem.usertype=0" >> "/bb/prop$bp"
  # DIKKAT (2026-10-15, adbd'nin TCP DINLEYICISININ ACILMAMASI):
  # Firmware "user" yapisi: ro.build.type=user -> ro.secure=1.
  # adbd IsAdbSecure() ile ro.adb.secure'e bakar; o yoksa ro.secure'e
  # bakar. 1 ise AUTH acar ve init'ten ANDROID_SOCKET_adbd fd'si
  # bekler. Biz adbd'yi elle baslattigimiz icin o fd yok ve adbd
  # baglantiyi KURULMADAN birakiyor:
  #     adbd E auth.cpp:203] Failed to get adbd socket: Operation not permitted
  # olcut (nabiz satiri): adbd=ayakta pid=2563 ama tcp5555=0
  # Yani surec yasiyor, 5555'i DINLEMIYOR. Bu yuzden Windows adb
  # "offline" diyor ve QEMU hostfwd baglantisi RST ile kapaniyor.
  # COZUM: ro.adb.secure=0 -> auth hic acilmaz, dogrudan dinler.
  # DIKKAT (2026-10-16, DUZELTME): firmware'in /system/build.prop'unda
  # ZATEN 'ro.adb.secure=1' satiri var (olcduk: _tls-prop.sh). 'ro.'
  # property'ler SALT-OKUNURDUR; property_service ILK tanimi kabul
  # eder, sonrakileri GORMEZ. Yani dosyanin sonuna ekledigimiz
  # 'ro.adb.secure=0' ETKISIZDI ve auth kapanmiyordu:
  #     adbd E auth.cpp:203] Failed to get adbd socket: Operation not permitted
  #
  # COZUM: mevcut satirlari once YORUMLA, sonra temiz degeri yaz.
  #
  # DIKKAT (HATA, OLCUM): onceki surumde burada cift tirnakli 'sed'
  # YAZIYDI:     sed -i 's/^ro\.adb\.secure=.*/# & .../'
  # /init, /system mount EDILMEDEN once calisiyor. O anda PATH'te
  # /system/bin YOK (erofs, icinde sed yok) ve initramfs'te de sed
  # symlink'i yok -- komut "not found" olup 2>/bb/null ile SESSIZCE
  # basarisiz oluyordu. Kanit, bizim kendi dogrulama satirimizdi:
  #     DIKKAT: /system/build.prop icinde ro.adb.secure hala ETKIN
  # Duzeltme: busybox eklentisini ACIKCA adresle (/bb/sed).
  #
  # DIKKAT: sed'i ONCE calistir, temiz degerleri SONRA ekle; tersi
  # olursa yeni yazdigimiz 0 degerini de yorumlamis oluruz.
  # DIKKAT (2026-10-16, HATA 2): 'sed -i' BAYRAGINDAN VAZGECTIK.
  # busybox 'sed -i' gecici dosyayi TMPDIR altina yazar. /init, /system
  # mount edilmeden once calistigi icin TMPDIR bos ve /tmp henuz yok
  # -- komut sessizce basarisiz olur (2>/bb/null yuzunden gorunmez).
  # Guvenli desen: acik gecici dosyaya yaz, sonra mv et. Hicbir gecici
  # dizin gerektirmez. Tek geciste UC deseni birden.
  /bb/sed -e 's/^ro\.adb\.secure=.*/#& # HARMONY-EMU: auth kapali/' \
          -e 's/^ro\.secure=.*/#& # HARMONY-EMU: root adb serbest/' \
          -e 's/^ro\.debuggable=.*/#& # HARMONY-EMU: debuggable/' \
          "/bb/prop$bp" > /bb/nb/prop.fix 2>/bb/nb/null
  if [ -s /bb/nb/prop.fix ]; then
    /bb/mv -f /bb/nb/prop.fix "/bb/prop$bp" 2>/bb/nb/null
  else
    /bb/echo "  DIKKAT: $bp sed ciktisi BOS, yama uygulanmadi"
  fi
  echo "ro.adb.secure=0" >> "/bb/prop$bp"
  echo "ro.secure=0" >> "/bb/prop$bp"
  echo "ro.debuggable=1" >> "/bb/prop$bp"
  # DIKKAT (GERI ALMA 2026-10-18): ro.ark.enable=0 DENEMESI ISE YARIMADI.
# Kanitlar:
#  1) Bu ROM'da zygote/arkinit AYNI ikili:
#       service arkinit /system/bin/app_process64 -Xzygote /system/bin
#                   --zygote --nice-name=arkinit
#     ve /apex/com.android.art/bin/ icinde ikinci bir app_process
#     YOK (stok AOSP'de com.android.art/bin/app_process64 vardir).
#  2) ROM'da Ark runtime'inin TAMAMI var:
#       /system/lib64/ark/libarkruntime.so  5.4 MB
#       /system/framework/framework.abc   31 MB
#       /system/framework/core-oj.abc  (64 adet .abc)
#  3) dlopen izleyici (arac dogrulandi: calisan getprop'ta da
#     gercek cagrilari yakaladi):
#       app_process64 10 dlopen cagriyor, 0 basarisiz, HICBIRI
#       libart icin degil; android_dlopen_ext hic cagrilmiyor.
#       Yani Ark kapaliyken VM HIC OLUSMADI.
#  4) persist.sys.hw.forcedark_policy=0 da TEK FARKI yaratmadi
#     (once 10/0/0, sonra 10/0/0 -- birebir ayni).
# SONUC: Ark yolu dogru olan yol. ro.* salt-okunur oldugu icin
# (setprop ile degistirilemiyor) build.prop yamasindan KALDIRILIR
# ve firmware degeri (1) birakilir.
echo "# ro.ark.enable: HARMONY-EMU yaması kaldirildı, firmware degeri 1 birakildi"
  # DIKKAT: yama gercekten tuttu mu? Iki kontrol:
  #   (1) asil deger satirinin yorum icinde olmasi (sed calisti mi)
  #   (2) temiz deger satirinin dosyanin SONUNDA olmasi (ro. ilk deger)
  # (1) tutmazsa adbd auth'u kapanmaz, L5 gelmez. Olcum aracini
  # dogrula kurali: yamanin calistigini iddia etmeden olc.
  if /bb/grep -q '^#ro\.adb\.secure=' "/bb/prop$bp" 2>/bb/null; then
    /bb/echo "  prop: $bp -> ro.adb.secure YORUMLANDI (auth kapali)"
  else
    /bb/echo "  DIKKAT: $bp icinde ro.adb.secure yorumlanmadi (sed calismadi mi?)"
  fi
  # ro.ark.enable ARTIK YORUMLANMIYOR (2026-10-18'de geri alindi:
  # bu ROM'da Ark yolu dogru olan yol). Firmware degeri (1)
  # birakilir. Yine de olcuyoruz -- "yamalama kalkti" demek
  # firmware'in degerini BOZMADIGIMIZ anlamina gelir.
  if /bb/grep -q '^ro\.ark\.enable=1$' "/bb/prop$bp" 2>/bb/null; then
    /bb/echo "  prop: $bp -> ro.ark.enable=1 FIRMWARE DEGERI KORUNDU (Ark yolu acik)"
  else
    /bb/echo "  DIKKAT: $bp icinde ro.ark.enable=1 yok (beklenen: firmware degeri)"
  fi
  if mount -o bind "/bb/prop$bp" "$bp" 2>/bb/null; then
    NPROP=$((NPROP + 1))
  fi
done
echo "  prop: ro.logsystem.usertype $NPROP build.prop dosyasina eklendi"

# DIKKAT (2026-10-15): /apex/com.android.adbd/etc/init.rc icinde de
# 'service adbd' tanimi var. Biz init.environ.rc'ye ayni tanimi
# ekledik; ikisi de import edilirse init "duplicate service" hatasi
# verip dosyayi TUMDEN reddeder -- bizim dosyamiz da mount_harmony_apex
# ve harmony_diag servislerini tasiyor, onlar da kaybolur.
# Cozum: APEX'inkini bosaltip kendimizinkini tek tanim birakiyoruz.
if [ -f /apex/com.android.adbd/etc/init.rc ]; then
  mkdir -p /bb/rc 2>/bb/null
  echo "# HarmonyOS emu: adbd servisi init.environ.rc'de tanimli." \
    > /bb/rc/adbd-init.rc
  if mount -o bind /bb/rc/adbd-init.rc /apex/com.android.adbd/etc/init.rc 2>/bb/null; then
    echo "  adbd: APEX init.rc nötralize edildi (bizim tanimimiz kullanilacak)"
  fi
fi

cd /system 2>/dev/null

# --- SERVIS LOGLARI + MODEM KALDIRMA: rc agacini yamalayip bagla ------------
# DIKKAT SIRA: bu 'exec init'TEN HEMEN ONCE olmak ZORUNDA. init rc
# dosyalarini kendi ilk asamasinda PARSE ediyor; bizim bind-mount'umuz
# ancak ondan sonra konusmaya baslar.
#
# DIKKAT: init kendi stdout'unu /dev/null'a cevirdigi icin (bu scriptin
# ciktisi da gorunmez -- tek istisna init'in KENDI LOG() cagrilari
# /dev/kmsg'ye gider) asagidaki cagri kendi ciktisini zaten /dev/kmsg'ye
# yaziyor.
/bb/rclog
echo "--- rc yamalama bitti ---"

# --- /dev/null gÃ¼venlik aÄŸÄ± (RC YAMALAMADAN SONRA) ---------------------------
# DIKKAT: bu adim rclog'DAN SONRA olmak ZORUNDA. Ã–nceden buradaydÄ± ve
# rclog 80 saniye sürüyor; o pencere içinde /dev/null yine bir DIZINE
# dÃ¶nÃ¼ÅŸÃ¼yor ve init mknod'da EEXIST alÄ±p TÃœM sistemi dÃ¼ÅŸÃ¼rÃ¼yordu:
#     init: mknod("/dev/null", S_IFCHR | 0666, makedev(1, 3)) failed File exists
#     init: Init encountered errors starting first stage, aborting
#
# DIKKAT: önceki hâli 'sadece dizinse kaldır' diyordu. Bu YETERLI DEGIL:
# init'in ilk aÅŸamasÄ± mknod'u koÅŸulsuz dener ve EEXIST'i Ã–LÃœMCÃœL sayar.
# Karakter cihazÄ± da olsa, kendisi yaratabilmesi iÃ§in yolu boÅŸaltÄ±yoruz.
# Aradaki pencerede /dev/null'a ihtiyaÃ§ duyan tek ÅŸey yok (init milisaniye
# sonra kendi doÄŸru dÃ¼ÄŸÃ¼mÃ¼nÃ¼ mknod'luyor).
rm -f /dev/null 2>/dev/null
rmdir /dev/null 2>/dev/null
rm -rf /dev/null 2>/dev/null
if [ -e /dev/null ]; then
  echo "--- [UYARI] /dev/null hala var, silinemedi: $(ls -ld /dev/null 2>&1) ---"
else
  echo "--- /dev/null temizlendi (init kendisi mknod'layacak) ---"
fi

exec /system/bin/init "$@"
INIT_EOF
chmod +x "$ROOT/init"

# --- kesme isareti korumasi (awk programi icinde TEK TIRNAK OLMAZ) ---------
# DIKKAT: /bb/rclog icindeki awk programi shellin TEK tirnakli dizisi
# icinde yaziliyor. Yorum satirlarindaki bir kesme isareti diziyi ERKEN
# kapatir ve uretilen betik sozdizimi hatasi verir:
#     bb/rclog: line 144: syntax error near unexpected token '}'
# Bu tuzak bes kez oldu ve her seferinde ayri ayri avlamak gerekti.
# Kontrolu sh -n DEN ONCEye aliyoruz ki hatanin satiri degil, tam
# olarak bu kural gorunsun; sh -n sadece "biri bozuk" der.
NQS=$(A0=$(grep -n 'awk -v OVL=' "$ROOT/bb/rclog" 2>/dev/null | head -1 | cut -d: -f1); \
       A1=$(grep -n 'rclog.stats' "$ROOT/bb/rclog" 2>/dev/null | head -1 | cut -d: -f1); \
       [ -n "$A0" ] && [ -n "$A1" ] && sed -n "${A0},${A1}p" "$ROOT/bb/rclog" | grep -c "'")
if [ "${NQS:-0}" -ne 2 ]; then
  echo "HATA: awk programi icinde beklenmeyen tek tirnak var (bulunan: ${NQS:-0}, beklenen: 2)"
  echo "      awk, shellin tek tirnakli dizisi icinde; yorumda kesme"
  echo "      isareti diziyi erken kapatir. Su satirlar supheli:"
  A0=$(grep -n 'awk -v OVL=' "$ROOT/bb/rclog" 2>/dev/null | head -1 | cut -d: -f1)
  A1=$(grep -n 'rclog.stats' "$ROOT/bb/rclog" 2>/dev/null | head -1 | cut -d: -f1)
  sed -n "$((A0 + 1)),$((A1 - 1))p" "$ROOT/bb/rclog" | grep -n "'" | sed 's/^/      /'
  exit 1
fi

# --- uretilen scriptleri DOGRULA -------------------------------------------
# DIKKAT: asagidaki kesme isareti kontrolu, bu dogrulamadan ONCE
# calismalidir; yoksa hata "biri bozuk" olarak gorunur ve gercek
# supheli satir gosterilmez.
# DIKKAT: /init, /bb/supervise, /bb/mountapex, /bb/rclog, /bb/diag bunlarin
# HICBIRI busybox ash ile ayristiriliyor. Sozdizimi hatasi bir betigin
# sessizce hic calismamasina yol acar ve "sistem bozuk" sanilir; oysa
# sorun 2 satirlik bir tirnak. Kurulumdan SONRA, QEMU'DAN ONCE dogrula.
#
# DIKKAT: sh -n calistirirken /bb/* yollari bu konakta yok; ash yollari
# ayristirmaz, sadece sozdizimine bakar. Yeterli.
say "uretilen scriptler dogrulaniyor"
SYNTAX_BAD=0
for f in "$ROOT/init" "$ROOT/bb/supervise" "$ROOT/bb/mountapex" \
         "$ROOT/bb/rclog" "$ROOT/bb/diag" "$ROOT/bb/diag2" \
         "$ROOT/init.environ.rc" "$ROOT/bb/mountapex"; do
  [ -f "$f" ] || continue
  if bash -n "$f" 2>/tmp/synerr; then
    printf '  [ok] %s\n' "${f#$ROOT/}"
  else
    SYNTAX_BAD=1
    printf '  [HATA] %s\n' "${f#$ROOT/}"
    sed 's/^/         /' /tmp/synerr
  fi
done
if [ $SYNTAX_BAD -ne 0 ]; then
  echo ""
  echo "HATA: uretilen scriptlerden biri ayristirilamiyor. QEMU calistirilmadi."
  exit 1
fi

# --- /dev/null TUZAKINI KALICI OLARAK KAPAT ---------------------------------
# DIKKAT: sorun 'kaldir ve umut' ile cozulemiyor; bir YARIS var ve
# penceresi 0.6 saniye. Kaynak:
#
#   /init          : 'rm -rf /dev/null'  ->  21.04 s
#   init           : mknod("/dev/null")  ->  21.66 s   (EEXIST -> ABORT)
#
# Bu arada kim olusturuyor? DENETLEYICI. Her saniye dolasan
# /bb/supervise icindeki yuzlerce '... 2>/dev/null' yonlendirmesi.
# Shell, /dev/null YOKKEN `2>/dev/null` yazinca oraya DUZ BIR DOSYA
# olusturur (acilis O_CREATE ile yapilir, karakter cihazi olmaz).
# init mknod'a gince dosya zaten yerinde -> EEXIST -> tumden abort.
#
# DIKKAT: bu yuzden yeniden yazan yeni bir 'kaldir' denemesi de ayni
# sonucu verir. Cozum yonlendirmeyi /dev/null'dan UZAKLASTIRMAK:
#     2>/dev/null   ->   2>/bb/null
# /bb/null initramfs'te duran duz bir dosya; hicbir seyin onu
# karakter cihaz sanmasina gerek yok, sadece stderr'i yutmak lazim.
#
# DIKKAT: '/dev/null' ADINI her yerde degistirmiyoruz; yalnizca YONLENDIRME
# desenlerini degistiriyoruz. Yoksa /init'in 'rm -rf /dev/null'
# guvenlik agi da bozulur.
# DIKKAT: data bolumunun GERCEK numarasini disk duzeninden OKUYORUZ.
# Elle yazmak yanlissa (/devblk/vda27 = bir APEX bolumu) mount sessizce
# calisir ama /data dolu bir APEX olur ve vold yine cokmeye devam eder.
# DIKKAT: bu /init uretildikten SONRA calismali; __DATADEV__ yerine
# konmadan once konulmaz.
DATA_PART=$(sgdisk -p "$DISK" 2>/dev/null | awk '$NF=="data" {print $1; exit}')
[ -n "$DATA_PART" ] || DATA_PART=29
sed -i "s|__DATADEV__|/devblk/vda${DATA_PART}|g" "$ROOT/init"
sed -i "s|__DATADEV_PART__|${DATA_PART}|g" "$ROOT/bb/mountapex"
ok "  /data bolumu: vda${DATA_PART} (disk duzeninden okundu)"

# DIKKAT: /bb/null, uretimde konuk /bb icinde duz bir dosya olarak birakilir
# (asagidaki touch). Konukta /bb altina tmpfs baglanir; bkz. /init.
touch "$ROOT/bb/null" 2>/dev/null
# DIKKAT (KRITIK HATA 2026-10-15): /bb/nb/null de URETIMDE olusturulmali.
# Once sadece /init icinde mount ediyordum; ama /init'in EN BASINDAKI
# yonlendirmeler zaten /bb/nb/null adresini kullaniyor:
#     mount -t proc  proc  /proc  2>/bb/nb/null
# /bb/nb o anda daha yok; redirection acamayinca busybox ash OLDUGU YERDE
# cokup /init ANINDA oluyor:
#     Kernel panic - not syncing: Attempted to kill init!
# DIKKAT: yonlendirme hatasi busybox ash'i oldurur -- dosyayi gec olsa
# olurdu. Bu yuzden dosya initramfs'te HAZIR bulunmali.
mkdir -p "$ROOT/bb/nb"
touch "$ROOT/bb/nb/null" 2>/dev/null
for f in "$ROOT/init" "$ROOT/bb/supervise" "$ROOT/bb/mountapex" \
         "$ROOT/bb/rclog" "$ROOT/bb/diag" "$ROOT/bb/diag2"; do
  [ -f "$f" ] || continue
  sed -i 's#2>/dev/null#2>/bb/null#g' "$f"
  sed -i 's#1>/dev/null#1>/bb/null#g' "$f"
  sed -i 's# >/dev/null# >/bb/null#g' "$f"
done
# DIKKAT (2026-10-15): /bb/null -> /bb/nb/null.
#
# SORUN: init 'on post-fs' icinde kok dosya sistemini SALT OKUNUR yapiyor:
#     mount rootfs rootfs / remount bind ro nodev
# O andan sonra /bb UZERINE yazilamaz ve her stderr yonlendirmemiz hata
# veriyor:
#     can't create /bb/null: Read-only file system        (100 kez)
# Kirilan sey /bb/null dosyasinin kendisi degil, oraya YAZMA denemesi;
# yani uretilen butun betiklerdeki yonlendirmeler sessizce basarisiz oluyor.
#
# COZUM: konukta /bb altina kucuk bir tmpfs baglanir (/init icinde) ve
# yonlendirmeler /bb/nb/null adresine gider. Salt okunur bir dosya sisteminin
# ALT dizinine mount etmek serbesttir; altindaki dosya sistemine yazma
# gerekmez.
for f in "$ROOT/init" "$ROOT/bb/supervise" "$ROOT/bb/mountapex" \
         "$ROOT/bb/rclog" "$ROOT/bb/diag" "$ROOT/bb/diag2"; do
  [ -f "$f" ] || continue
  sed -i 's#/bb/null#/bb/nb/null#g' "$f"
done
# Kalan yonlendirme var mi? (rapor için)
LEFTOVER=$(grep -c '>/dev/null' "$ROOT/init" "$ROOT/bb/supervise" \
                        "$ROOT/bb/mountapex" "$ROOT/bb/rclog" 2>/dev/null \
            | awk -F: '{s+=$2} END{print s+0}')
[ "$LEFTOVER" -eq 0 ] || ok "  [uyari] $LEFTOVER yonlendirme /dev/null'a kaldi"
ok "  /bb/null: tum stderr yonlendirmeleri oraya tasindi"

say "cpio paketleniyor"
mkdir -p "$(dirname "$OUT")"
# DIKKAT (2026-10-15): ATOMIK YAZIM. Dogrudan '> "$OUT"' yazmak dosyayi
# ANDA sifirlar, sonra ~10 saniyede doldurur. O aralikta baslayan bir
# QEMU YARIM BIR GZIP AKISI okur; cekirdek initramfs'i acamaz, panikler
# ve -no-reboot ile QEMU birkac saniyede kapanir. Bu, kullaniciya
# "pencere 5 saniye sonra kapandi" olarak gorunuyordu.
# Once .tmp yaz, sonra mv ile ATOMIK olarak yerine koy.
( cd "$ROOT" && find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -1 ) > "$OUT.tmp"
mv -f "$OUT.tmp" "$OUT"
ok "initramfs: $(du -h "$OUT" | cut -f1)"

# --- KURULUM MODU (QEMU calistirmadan) --------------------------------------
# DIKKAT: bir denemeyi 87 saniye beklemeden bitirmek icin. Uretilen
# initramfs'i sadece kurup geri donmek, sonra QEMU'yu elle baslatmak
# mumkundur:
#     NOQEMU=1 bash scripts/81-boot-zygote.sh
#     qemu-system-aarch64 ... -serial stdio
if [ "${NOQEMU:-0}" = "1" ]; then
  ok "NOQEMU=1 -> initramfs hazir, QEMU calistirilmadi"
  exit 0
fi

say "QEMU calisiyor"
mkdir -p "$(dirname "$LOG")"
# DIKKAT (2026-10-15): seri log KOSUMA OZEL bir dosyaya yazilir, QEMU
# bitince kanonik adi (logs/boot-zygote.log) uzerine ATOMIK olarak
# tasinir. Neden: 'file:' chardev dosyayi acarken TRUNCATE eder. Iki
# ornek ayni dosyayi acarsa ikincisi birincinin logunu siler ve
# ikisi birbirinin icine yazar -- yani elimize gelen log hangi ornege
# ait oldugunu bilmedigimiz bir karisim olur. Bu, son uc kosunun
# olcumlerini supheli kilmis ti.
: > "$RUNLOG"

# --- KERNEL KOMUT SATIRI -----------------------------------------------------
# DIKKAT: 'printk_ratelimit=0' OLMAZSA MESAJLAR KAYBOLUYOR.
# Kernel, ayni kaynaktan gelen printk'leri sn'de bir kez sinirliyor:
#     printk: apexd: 40 output lines suppressed due to ratelimiting
#     printk: init: 28 output lines suppressed due to ratelimiting
# Tam da bizim ihtiyacimiz olan yerlerde: apexd'nin mount adimlari,
# vendor_init subcontext'inin parse hatasi, ueventd'nin neden status 1
# ile ciktigi. Yani projenin EN KRITIK teşhis kanalı sessizce kesiliyor
# ve "kod yanlislik yapmis" saniyoruz.
#
# DIKKAT: 'console=ttyAMA0,115200 console=tty0' SIRASI ONEMLI.
# Coklu 'console=' verildiginde /dev/console EN SONKINE baglanir; yani
# tty0. /init cikti kanali bu yuzden /dev/kmsg'ye cevrildi (bkz. /init).
#
# DIKKAT: 'printk_ratelimit=0' YETMIYOR, hatta ters etki yapiyor.
# Kernel bunu 'baski araligi' olarak yorumluyor; 0 saniye + 0 burst
# demek 'hicbir sey yazma' demek. Dogru degerler:
#     printk_ratelimit=1000000   (1.000 saniye -> pratikte kaldir)
#     printk_ratelimit_burst=1000000
# DIKKAT: 'loglevel=7' debug mesajlarini da acar.
#
# !!! 'enforcing=0' OLMAZSA SISTEM KILITLENIR !!!
# Once init politikayi KENDISI DERLIYORDU ve 'androidboot.selinux=permissive'
# gecerli oluyordu. Hazir precompiled_sepolicy yuklenince kernel'in kendi
# enforcing durumu gecerli oluyor (varsayilan 1):
#     avc: denied { write } for pid=2040 comm="supervise" path="/dev/kmsg"
#         ... permissive=0
# yani DENETLEYICI /dev/kmsg'ye yazamaz, apexd ciktisi kaybolur ve init
# gercekten kilitlenir. .config'ta CONFIG_SECURITY_SELINUX_BOOTPARAM=y
# oldugu icin 'enforcing=0' komut satirinda calisir.
# Emulasyonda dogru olan da bu: once calistir, sonra kisitlari konus.
KCMD="console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"

# --- Pencere modu ------------------------------------------------------------
# DIKKAT: varsayilan headless ('-display none') idi ve biz hep seri loga
# baktik. Kullanici pencereyi gormek istiyor.
#
# Grafik zinciri:
#     -device virtio-gpu-device  ->  kernel DRM_VIRTIO_GPU  ->  /dev/fb0
#     ->  fbcon  ->  tty0
#
# DIKKAT: bu kernel upstream degil, Huawei vendor kernel'i. Upstream'teki
# CONFIG_DRM_RAMFB sembolu burada YOK; dogru yol virtio-gpu + mevcut
# CONFIG_DRM_FBDEV_EMULATION.
#
# DIKKAT: kernel komut satirinda 'console=tty0' da var. Kernel mesajlarini
# IKI konsola birden yazar; yani pencere canli boot gunlugunu gosterirken
# seri log dosyasi da dolmaya devam eder. hicbiri kaybetmeyiz.
#
# DIKKAT: DISPLAY yoksa (WSLg kapali) gtk acilamaz; o durumda headless'e
# duseriz ve hatayi birakmaz.
#
# DIKKAT: pencereyi 'wt ... wsl -e bash script' ile baslattigimizda DISPLAY
# aktarilmamiyor olabiliyor (Start-Process argumanlariyla arasinda
# bozuldu ve pencere hic acilmadi). Bu yuzden WSLg kuruluysa ortami
# KENDIMIZ kuruyoruz; boylece baslatma komutu ne olursa olsun calisir.
if [ -z "${DISPLAY:-}" ] && [ -d /mnt/wslg ]; then
  export DISPLAY=:0
  export WAYLAND_DISPLAY=wayland-0
  export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
fi

GUI=0
if [ "${HEADLESS:-0}" != "1" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  GUI=1
else
  echo "  [uyari] DISPLAY/WAYLAND yok -> headless calisiliyor"
fi

if [ $GUI -eq 1 ]; then
  echo "  pencere modu: gtk + virtio-gpu (pencere aciliyor)"
  # DIKKAT: '-global virtio-mmio.force-legacy=false' sart.
  # QEMU'nun virt makinesinde virtio-mmio transportlari varsayilan olarak
  # LEGACY (0.9.5) moddadir:
  #     dev: virtio-mmio
  #       force-legacy = true
  # virtio_blk legacy ile calisiyor (diski goruyoruz), ama virtio-gpu'nun
  # DRM surucusu MODERN (virtio 1.0) transport istiyor ve legacy modda
  # hicbir DRM/virtgpu mesaji gelmiyordu -- yani konuk cihazi hic
  # probelamiyordu. Bu bayrak transport'i modern'e cevirir.
  QEMU_DISPLAY_OPTS="-display gtk -global virtio-mmio.force-legacy=false -device virtio-gpu-device -vga none"
else
  QEMU_DISPLAY_OPTS="-display none"
fi

# DIKKAT (2026-10-18, BELLEK DENEYI): -m 4096 -> QEMU_MEM ile
# degistirilebilir.
#
# HIPOTEZ: zygote 191 kutuphane yukluyor ve Ark VM kurmaya
# calisiyor; 4 GB yetmeyip tahsis sessizce basarisiz olabilir.
#
# DENEY SONUCU (OLCULDU, HIPOTEZ ELENDI):
#     MemTotal  8121920 kB   (8 GB, ayar tuttu)
#     arkprobe  VmRSS 38404 kB  VmPeak 2659188 kB
#     dlopen izi: 7 cagri, hepsi TAMAM, VM YINE YOK
#     system_server: 0
# Yani 4 -> 8 GB arasinda TEK BIR FARK olmadi. Zaten surec sadece
# 38 MB kullaniyor -- bir VM'in ihtiyacinin cok altinda.
# Varsayilan 4096 BIRAKILDI (her makinede calisir); deney icin:
#     QEMU_MEM=8192 bash scripts/81-boot-zygote.sh

timeout --signal=KILL "${TMO:-1200}" qemu-system-aarch64 \
  -machine virt,gic-version=3,virtualization=on \
  -cpu max -smp 4 -m "${QEMU_MEM:-4096}" \
  -accel tcg,thread=multi \
  -kernel "$KERNEL" -initrd "$OUT" \
  -append "$KCMD" \
  $QEMU_DISPLAY_OPTS \
  -drive "file=$DISK,if=none,format=raw,id=sysdisk,cache=unsafe" \
  -device virtio-blk-device,drive=sysdisk,bootindex=1 \
  -device virtio-rng-device \
  -device virtio-net-device,netdev=n0 -netdev user,id=n0,hostfwd=tcp::5555-:5555 \
  -monitor none -no-reboot -serial "file:$RUNLOG" </dev/null >"$HERE/../logs/qemu-stderr.log" 2>&1
QRC=$?
# DIKKAT: kosum bittikten SONRA kanonik adi devral. mv atomiktir, yani
# logs/boot-zygote.log hicbir zaman yarim gorunmez.
cp -f "$RUNLOG" "$LOG" 2>/dev/null && rm -f "$RUNLOG"
rm -f "$LOCK"
# DIKKAT: '-no-reboot' GERI GELDI. Pencereli modu eklerken yanlislikla
# dusurulmustu. Onemsiz: konuk reboot isteyince QEMU sessizce yeniden
# basliyor ve seri gunlugu yarisinda kesiliyor -- o yuzden son kosuda log
# tam 'starting service ueventd...' satirinda BITTI ve nedenini
# goremiyorduk. -no-reboot ile konuk 'reboot' cagrisini loga yazar ve
# QEMU cikar, boylece gercek neden gorunur olur.
# DIKKAT: QEMU'nun stderr'i ONCEDEN /dev/null'a atiliyordu. Bu bir kor nokta
# idi: QEMU hic baslamazsa (kaynak/target hatasi, ekran acilamadi vb.) HICBIR
# cikti gormuyorduk ve "log bos" ile "QEMU olmedi" ayirt edilemiyordu.
# Artik stderr ayri dosyaya yaziliyor.
if [ -s "$HERE/../logs/qemu-stderr.log" ]; then
  say "--- qemu stderr ---"
  head -10 "$HERE/../logs/qemu-stderr.log" | sed 's/^/  /'
fi

echo ""
say "--- seri cikti ---"
sed -n '/HARMONYOS BOOT/,$p' "$LOG" 2>/dev/null | grep -vE "EXT4-fs|erofs:" | head -60
echo ""
say "--- Zygote izleri ---"
grep -iE 'zygote|system_server|servicemanager|apexd|fatal|panic|reboot:' "$LOG" 2>/dev/null | head -25
echo ""
say "tam log: $LOG"
