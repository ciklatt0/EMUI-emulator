#!/usr/bin/env bash
# Amac: Sanal makineye gerek KALMADAN calisilabilir bir HarmonyOS rootfs agaci kur.
#
# Neden bu yol? Tam sistem emulasyonu (qemu-system) agir ve yavas. Oysa:
#   - system.img bir EROFS -> WSL2'ye DOGRUDAN mount edilebilir
#   - APEX payload'leri ext2 -> dogrudan mount
#   - binfmt_misc + qemu-aarch64 -> ARM64 binarileri SAYFAMIS calisir
# Yani kernel yok, disk imaji yok, sanal makine yok. Dogrudan yurutme.
#
# Agac yapisi:
#   tree/                      <- system.img (Android KOK dosya sistemi)
#   tree/system/               <- gercek /system
#   tree/apex/<modul>/         <- APEX payload'leri (ext2 mount)
#   tree/bin -> system/bin     <- Android kok semalari
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SYSIMG="/root/harmony-build/super-out/parts/system.img"
TREE="/root/harmony-build/tree"
APEXDIR="/root/harmony-build/apex"

[[ -f "$SYSIMG" ]] || die "system.img yok (once 60-extract-partitions.py)"
[[ -f /usr/bin/qemu-aarch64 ]] || die "qemu-aarch64 yok (apt install qemu-user-binfmt)"

# --- 0) eski mount'lari temizle --------------------------------------------
# DIKKAT (guvenlik): Onceki kosudan kalan EROFS/APEX mount'lari takili
# kalirsa, sonraki 'rm -rf $TREE' onlarin USTUNDE calisir ve salt okunur
# dosya sistemi icindeki dosyalari silmeye calisir. Bu hem hata verir hem de
# yanlis bir davranistir. Once mount'lar ic ice indirilir.
#
# AYRICA: 'rm -rf $TREE/<ad>' ifadesi <ad> bir symlink ise iceriGI izler.
# Bizim /bin, /usr gibi semalarimiz symlink -> icerikleri silinmemeli.
# Bu yuzden asagida rm_link() kullanilir; o yalnizca bagin KENDINI kaldirir.
cleanup_tree() {
  # ic ice tum mount'lari sök (ters sirali: en derin once)
  local m
  for m in $(findmnt -Rno TARGET "$TREE" 2>/dev/null | sort -r); do
    umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
  done
  umount "$TREE/rootfs" 2>/dev/null || true
  umount "$TREE" 2>/dev/null || true
}

rm_link() {   # yalnizca symlink'i kaldirir, hedefine DOKUNMAZ
  local p="$1"
  if [ -L "$p" ]; then rm -f "$p"; return 0; fi
  if [ -e "$p" ]; then
    warn "$p symlink degil, birakiliyor (guvenlik): $(ls -ld "$p" | cut -c1-40)"
    return 1
  fi
  return 0
}

cleanup_tree
say "eski mount'lar temizlendi"
# DIKKAT: agacin KOKU EROFS olursa icine mount noktasi (mkdir) acilamaz.
# Yapisal olarak ayiriyoruz:
#   tree/          -> normal, YAZILABILIR dizin
#   tree/rootfs/   -> system.img'nin EROFS mount'u (salt okunur)
#   tree/apex/...  -> APEX mount'lari (yazilabilir tarafta)
#   tree/system    -> rootfs/system  (semla)
say "system.img mount ediliyor -> $TREE/rootfs"
[ -d "$TREE" ] || mkdir -p "$TREE"
mkdir -p "$TREE/rootfs"
mount -t erofs -o loop,ro "$SYSIMG" "$TREE/rootfs" \
  || die "EROFS mount basarisiz"
ok "EROFS mount -> $TREE/rootfs  (salt okunur)"

# --- 1b) vendor / odm / cust bolumleri -------------------------------------
# Bu ucu super.raw'tan dilimleniyor (60-extract-partitions.py). vendor,
# Kirin HAL'lerini icerir ve Zygote'yi ayaga kaldirmak icin sarttir.
# DIKKAT: Bu bolumler super.raw'in IKI sparse govdesi birlestirildiginde
# ortaya cikiyor (67-merge-super.py). Tek govde tek basina yetmiyor.
say "vendor / odm / cust bolumleri baglaniyor"
PARTS="/root/harmony-build/super-out/parts"
for b in vendor odm cust; do
  P="$PARTS/$b.img"
  [ -f "$P" ] || continue
  mkdir -p "$TREE/$b"
  if mountpoint -q "$TREE/$b"; then
    ok "$b zaten bagli"
    continue
  fi
  if mount -t erofs -o loop,ro "$P" "$TREE/$b" 2>/dev/null; then
    ok "$b.img mount -> $TREE/$b  ($(du -sh --apparent-size "$TREE/$b" 2>/dev/null | cut -f1))"
  else
    warn "$b mount edilemedi"
  fi
done

# --- 2) APEX payload'lerini ac ---------------------------------------------
# DIKKAT: .apex dosyalari KOK dizindeki /apex altinda DEGIL, /system/apex
# altindadir. Kok /apex sadece mount noktasidir (Android'de apexd orayi
# doldurur). Kaynak yanlis secilirse 0/0 bulunur.
say "APEX modulleri aciliyor"
SRC_APEX="$TREE/rootfs/system/apex"
[ -d "$SRC_APEX" ] || die "beklenen dizin yok: $SRC_APEX"
mkdir -p "$TREE/apex"
mkdir -p "$APEXDIR"
N=0; OK=0
for apex in "$SRC_APEX"/*.apex; do
  [ -f "$apex" ] || continue
  name=$(basename "$apex" .apex)
  N=$((N+1))
  mkdir -p "$TREE/apex/$name"
  if mountpoint -q "$TREE/apex/$name"; then OK=$((OK+1)); continue; fi
  work="$APEXDIR/$name"; mkdir -p "$work"
  if ! unzip -o -q "$apex" apex_payload.img -d "$work" 2>/dev/null; then
    warn "$name: payload cikarilamadi"
    continue
  fi
  # DIKKAT: 'file' bu payload'i "ext2" diye raporlar (ext4 geriye donuk
  # uyumlu oldugu icin sihirli bayt ayni). Ama cekirdegin ext2 surucusu
  # dosyayi reddeder; ext4 surucusu kabul eder. O yuzden ext4 kullanilir.
  if mount -t ext4 -o loop,ro "$work/apex_payload.img" "$TREE/apex/$name" 2>/dev/null; then
    OK=$((OK+1))
  elif mount -o loop,ro "$work/apex_payload.img" "$TREE/apex/$name" 2>/dev/null; then
    OK=$((OK+1))   # otomatik algilama yedegi
  else
    warn "$name: payload mount edilemedi"
  fi
done
ok "22 APEX modulu mount edildi (baski sayi asagida)"

# --- 2b) linker yapilandirmasina APEX yollarini ekle ----------------------
# linkerconfig, /apex/apex-info-list.xml dosyasini okuyarak APEX modullerini
# sayar ve arama yollarina ekler. Bu dosya apexd tarafindan uretilir; biz
# apexd calistirmadigimiz icin dosya YOK ve linkerconfig yalnizca
# /system, /product, /vendor ... yollarini yaziyor.
#
# Sonuc: /apex/com.android.os.statsd/lib64/libstatssocket.so gibi
# APEX'te bulunan kutuphaneler cozumlenemiyor -> "CANNOT LINK EXECUTABLE".
#
# DIKKAT: linkerconfig bu ortamda SEGFAULT veriyor. Bu yuzden dosyayi
# yeniden uretmeye BAGIMLI OLMAMALIYIZ: once mevcut dosyayi kullaniriz
# (veya uretmeyi deneriz), sonra APEX yollarini dosyaya ekleriz.
# Metin eklentisi icin segfault veren bir araca ihtiyac yok.
say "linker yapilandirmasi kontrol ediliyor (APEX yollari dahil)"
mkdir -p "$TREE/linkerconfig"
LD_CFG="$TREE/linkerconfig/ld.config.txt"

if [ ! -s "$LD_CFG" ]; then
  chroot "$TREE" /system/bin/linkerconfig --target /linkerconfig >/dev/null 2>&1 || true
fi

if [ ! -s "$LD_CFG" ]; then
  warn "ld.config.txt uretilemedi (linkerconfig segfault veriyor olabilir)"
  warn "APEX kutuphaneleri cozumlenemeyebilir"
else
  # DIKKAT: ld.config.txt bolumlu: [legacy] satiri 9'da ve asil arama yollari
  # (namespace.default.search.paths) BU BOLUMUN ICINDE. [postinstall] ise
  # dosyanin sonunda. Dosyanin sonuna eklemek bu yuzden HIC BIR ETKI YAPMAZ.
  #
  # Daha kotusu: sadece "grep -q /apex/" ile idempotency kontrolu YANILIS
  # pozisyondaki eski eklemeyi "zaten var" saniyordu. Bu yuzden:
  #   1) mevcut TUM /apex/ satirlarini temizle (nerede olurlarsa olsunlar)
  #   2) dogru yola yeniden ekle
  # Boylece hem kendini duzeltir hem tekrarlanabilir.
  grep -v '/apex/' "$LD_CFG" > "$LD_CFG.clean" && mv "$LD_CFG.clean" "$LD_CFG"

  APEX_BLOCK="$BUILD_DIR/apex-paths.txt"
  {
    echo "# --- HarmonyOS emu: APEX yollari ---"
    echo "# linkerconfig apex-info-list.xml'i okuyamadi (apexd yok); elle ekliyoruz."
    for d in "$TREE"/apex/*/; do
      n=$(basename "$d")
      [ -d "$d/lib64" ] && echo "namespace.default.search.paths += /apex/$n/lib64"
      [ -d "$d/lib" ]   && echo "namespace.default.search.paths += /apex/$n/lib"
    done
  } > "$APEX_BLOCK"

  # Dogru konum: '[legacy]' bolumunde, ilk 'namespace.default.asan' satirinden
  # ONCE gelen SON 'namespace.default.search.paths' satiri.
  #
  # DIKKAT: dosyada '[legacy]' ve '[postinstall]' olmak uzere iki bolum var ve
  # IKISI DE 'namespace.default.search.paths' icerir. 'tail -1' ile secim
  # [postinstall] bolumundeki satiri secerdi -> ekleme yine etkisiz kalirdi.
  # Bu yuzden asan satirinda durup, ondan onceki son search.paths'i aliyoruz.
  INS=$(awk '
    /^namespace\.default\.asan/ { exit }
    /^namespace\.default\.search\.paths/ { n = NR }
    END { print n+0 }' "$LD_CFG")

  if [ "${INS:-0}" -gt 0 ]; then
    head -n "$INS"          "$LD_CFG"  >  "$LD_CFG.new"
    cat "$APEX_BLOCK"                   >> "$LD_CFG.new"
    tail -n +"$((INS + 1))" "$LD_CFG"  >> "$LD_CFG.new"
    mv "$LD_CFG.new" "$LD_CFG"
    ok "APEX yollari [legacy] bolumune eklendi (satir $INS'ten sonra, $(grep -c '/apex/' "$LD_CFG") yol)"
  else
    cat "$APEX_BLOCK" "$LD_CFG" > "$LD_CFG.new" && mv "$LD_CFG.new" "$LD_CFG"
    warn "arama yolu satiri bulunamadi, basa eklendi"
  fi
  ok "ld.config.txt hazir"
fi

# --- 2c) calistirma ortami (LD_LIBRARY_PATH) -------------------------------
# DIKKAT: dlopen ile yuklenen bir kutuphanenin BAGIMLILIKLARI, ana programin
# namespace'ini miras almaz; linker onlari default namespace'te arar.
# ld.config.txt'e APEX yolu eklemek bazi durumlarda yetmiyor -- test edildi,
# LD_LIBRARY_PATH ile ayni sonucu verdi. Ikisini birlikte kullanıyoruz.
#
# Ayrica /system/lib64/ark gibi ALT DIZINLER arama yollarinda degil
# (libark_jsruntime.so orada).
say "calistirma ortami hazirlaniyor"
# DIKKAT: env dosyasi agacin KOKUNE yazilir, /etc'ye DEGIL. /etc, EROFS
# icindeki system/etc'ye semalanir ve oraya yazilamaz (salt okunur).
ENVF="$TREE/harmony-env.sh"
# DIKKAT: 'python3 - <arg1> <arg2>' ile sys.argv[0]='-', argv[1]=arg1,
# argv[2]=arg2 olur. Tek arguman gecirilirse argv[2] yoktur -> IndexError.
TREE="$TREE" python3 - "$TREE" "$ENVF" <<'PY'
import os, sys, glob
tree, out = sys.argv[1], sys.argv[2]
dirs = []
for pat in ("apex/*/lib64", "apex/*/lib"):
    for d in sorted(glob.glob(os.path.join(tree, pat))):
        if os.path.isdir(d):
            dirs.append("/" + os.path.relpath(d, tree))
dirs += ["/system/lib64", "/system/lib64/ark"]
seen, uniq = set(), []
for d in dirs:
    if d not in seen:
        seen.add(d); uniq.append(d)
with open(out, "w") as f:
    f.write("# HarmonyOS emu - calistirma ortami (100-usable-rootfs.sh uretti)\n")
    f.write('# ld.config.txt ile cozulemeyen APEX ve alt dizin yollari.\n')
    f.write('export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}'
            + ":".join(uniq) + '"\n')
PY
ok "calistirma ortami: $ENVF ($(grep -o '/apex/' "$ENVF" | wc -l) APEX yolu)"

# --- 3) Android kok semalari ------------------------------------------------
# /system ise yazilabilir tarafta symlink ile gosterilir; boylece /system/bin
# yolu cozulur ama APEX mount'lari ayri yerde kalir.
# KRITIK: /lib (32-bit) ve /lib64 (64-bit) AYRI dizinlerdir. Glibc'nin
# ld.so'su varsayilan olarak /lib'i ONCE arar. Ikisi de bagliysa
# 'libcutils.so: wrong ELF class: ELFCLASS32' hatasi alirsin -- cozumlenen
# 32-bit surum olur.
#
# Biz arm64 hedefliyoruz; 32-bit katman kullanilmiyor. Bu yuzden /lib de
# 64-bit gostergesine yonlendirilir. Boylece her isim cozumlemesi dogru
# (64-bit) surume gider.
for l in bin sbin etc lib lib64 usr; do
  [ -e "$TREE/rootfs/system/$l" ] || continue
  rm_link "$TREE/$l" || continue
  ln -sfn "system/$l" "$TREE/$l" || warn "$l semasi kurulamadi"
done
rm_link "$TREE/lib" || true
ln -sfn system/lib64 "$TREE/lib"
ok "/lib -> system/lib64  (32-bit katman devre disi)"

# vendor/odm/cust icin ek symlink GEREKMEZ: $TREE/<bolum> zaten bir mount
# noktasi, chroot icinde /vendor, /odm, /cust dogrudan oraya cozulur.
# (Burasa yanlislikla '$TREE/vendor -> vendor' gibi kendine donen bir symlink
#  kurmak kolay bir hatadir; boyle bir sey kurmayalim.)
mkdir -p "$TREE/dev" "$TREE/proc" "$TREE/sys" "$TREE/tmp" "$TREE/data" "$TREE/root"
chmod 1777 "$TREE/tmp" 2>/dev/null || true

# --- 4) chroot icin sanal dosya sistemleri --------------------------------
say "/proc /dev /sys baglaniyor (chroot icin)"
mountpoint -q "$TREE/proc" || mount -t proc proc "$TREE/proc"
mountpoint -q "$TREE/dev"  || mount --rbind /dev "$TREE/dev"
mountpoint -q "$TREE/sys"  || mount --rbind /sys "$TREE/sys"

# --- 5) dogrulama ------------------------------------------------------------
echo ""
say "DOGRULAMA"
echo "  agac          : $TREE"
echo "  rootfs        : EROFS mount (salt okunur)"
echo "  boyut         : $(du -sh --apparent-size "$TREE/rootfs" 2>/dev/null | cut -f1)"
echo ""
echo "  /system/bin -> $(ls "$TREE/system/bin" 2>/dev/null | wc -l) binar"
echo "  /apex      -> $(ls "$TREE/apex" 2>/dev/null | wc -l) modul"
echo ""
echo "  ELF interpreter zinciri:"
for p in system/bin/linker64 apex/com.android.runtime/bin/linker64; do
  if [ -e "$TREE/$p" ]; then
    printf '    [OK] %-40s %s bayt\n' "$p" "$(stat -L -c %s "$TREE/$p" 2>/dev/null)"
  else
    printf '    [--] %-40s YOK\n' "$p"
  fi
done

cat <<EOF

================================================================
  HAZIR. Kullanmak icin:
================================================================

  # tek komutla HarmonyOS shell'i:
  $TREE/../harmony-shell.sh

  # ya da dogrudan:
  sudo chroot $TREE /system/bin/sh

  # bir binaire girerek calistir:
  sudo chroot $TREE /system/bin/toybox --help

================================================================
EOF