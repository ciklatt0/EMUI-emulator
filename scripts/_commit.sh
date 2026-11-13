set -u
cd "$(dirname "$0")/.."
git add -A
cat > /tmp/cmsg.txt <<'MSG'
L4: zygote artik taniniyor, baglaniyor ve ayakta kaliyor

Uc ayri kok neden, ucu de OLCULE KAPANDI:

1) import satiri bizim kendi yamamizla yorumlaniyordu
   /system/etc/init/hw/init.rc:12
     RCYAMALAMA(import cozulemedi, yorumlandi):
       import /system/etc/init/hw/init.zygote64_32.rc
   Bu kural degisken iceren TUM import satirlarini yorumluyordu;
   vendor connectivity alt baglami icin konulmustu. init 166 servis
   tanimliyordu ama "zygote" DILE bu yuzden tanimli degildi:
     setprop ctl.start zygote
       -> Failed to set property ctl.start to zygote
   NOT: daha once yalnizca ust duzey *.rc dosyalarina bakildigi
   icin bu importun yorumlandigi fark edilmemisti; master rc
   /system/etc/init/hw/init.rc alt dizininde.
   COZUM: degerler prop dosyalarindan okunup yol somutlastiriliyor.
   ro.zygote /vendor/build.prop:146 da (system/build.prop ta DEGIL).
   NIMPOK sayaci eklendi: 0 ise "hicbir import somutlastirilamadi"
   uyarisi verir; olcum araci kendini dogruluyor.

2) APEX kutuphaneleri linker a gorunmuyordu
   F linker: CANNOT LINK EXECUTABLE /system/bin/app_process64:
             library libnativeloader.so not found
   libnativeloader.so YALNIZCA /apex/com.android.art/lib64 te var.
   fix_ldconfig() APEX yollarini dosyanin EN BASINA ekliyordu ve
   awk ilk "namespace.default.search.paths" satirini ariyordu;
   o satir bizim kendi basligimizdi, yani ekleme [system]
   bolumune hic girmiyordu. Stok bolumdeki = atamasi basta
   yazilan her seyi SILIYORDU.
   LD_CONFIG_FILE ile zorlayinca da ayni hata; yani sorun arama
   sirasi degil, eklemenin YERININ yanlis olmasi.
   COZUM: once orijinal dosyanin icine, ilk
   "namespace.default.search.paths" satirindan sonraya yaz;
   isaret satiri SONRA eklenir. Dogrulama artik [system]
   bolumundeki apex yolunu sayiyor (31 adet).

3) /data/dalvik-cache/arm64 yok
   Elle calistirilip cikti yakalaninca:
     Error creating cache dir /data/dalvik-cache/arm64
   /data tmpfs 2.0G ama BOS (vold her 5 saniyede cokuyor).
   mkdir -p sonrasi zygote HATA VERMEDI ve ayakta kaldi.

SONUC (olculerek):
  16254 app_process64 -Xzygote --start-system-server --socket-name=zygote
  16257 app_process64 -Xzygote --nice-name=zygote64 --socket-name=arkinit
  durum S (uyuyor). Daha once [app_process64] = ZOMBI idi.
  system_server henuz fork edilmedi.

Yanlis pozitif #7: getprop ciktisi "[init.svc.adbd]: [stopped]"
biciminde; grep "^init.svc" ile BOS doner. "[init.svc" kullan.
MSG
git commit -q -F /tmp/cmsg.txt
git log --oneline -1