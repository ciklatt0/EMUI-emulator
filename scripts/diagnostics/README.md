# scripts/diagnostics — L4 (ART/Zygote) teshis araclari

Bu klasor, "ART VM'i `dalvikvm64` ile direkt calistirarak L4 (Zygote + SystemServer)'a erismek" icin
yazilmis TEK-SEFERLIK tehis betiklerini toplar. Hepsi `81-boot-zygote.sh`'indan bagimsiz,
QEMU calisirken `scripts/adb.sh shell sh /data/<betik>.sh` seklinde cihazda calistirilmissir.

## Neden ayrildi

Bu araclarin surekli calismasi gerekmemektedir; `81-boot-zygote.sh` (asil yol) onlardan hicbine
referans vermemektedir. L4 bu ROM ile kesinlikle engellendi (asagida kanit), bu yuzden
araclar arsivlenecektir.

## Dosyalar

| Betik | Islevi | Nasil kullanildi | Sonuc |
|-------|--------|----------------|-------|
| `_artchk.sh` | `dalvikvm64` ile ZygoteInit calistirip `stderr`'deki "no namespace called" ve RC'yi okuyor | `adb.sh shell sh /data/test_art.sh` | RC=134, `Error finding namespace of apex: no namespace called com_android_art` — her calistirmada birebir ayni |
| `_artdl.sh` | `LD_PRELOAD=/data/dltrace.so` ile dalvikvm64 calisti, `/data/dltrace.log`'u okudu | `adb.sh shell sh /data/test_artdl.sh` | `EXT "libnativehelper.so" -> TAMAM`, libart yuklendi, sonra InitNativeMethods'te coktu |
| `_artdl2.sh` (yok) | — | — | — |
| `_cfgpath.sh` | Linker config arama sirasi (`/data/property`, `/system/etc`, `/vendor/etc`, `/linkerconfig`) | cihazda calistirildi | Tek kaynak `/linkerconfig/ld.config.txt` |
| `_cfgraw.sh` | `link.default` / `link.public` satirinin TAMAMINI ve virgul/bosluk sayisini yazdirir | cihazda calistirildi | `virgul: 11 bosluk: 2` (dogru) ama linker bunu yok sayiyor |
| `_cfgvalid.sh` | Tanimli namespace'leri ile link.default/public referanslarini karsilastirir | cihazda calistirildi | Tanimsiz referans yok (ama linker link.*'i desteklemiyor) |
| `_chk.sh` | 81-boot-zygote.sh syntax + APEX_LIST ikamesi + link.default/public varligini kontrol eder | yerelde calistirildi | SYNTAX-OK, link satirlari mevcut |
| `_interp.sh` | dalvikvm64'nin PT_INTERP'ini ve /apex altindaki linker/config'i listeler | cihazda calistirildi | `PT_INTERP = /system/bin/linker64`, /apex'te linker yok |
| `_ldpreload_test.sh` | `LD_PRELOAD=/data/local/tmp/libart.so` ile dalvikvm64 calistirir | cihazda calistirildi | Ayni namespace hatasi (libart /apex altindan cozulebiliyor) |
| `_ldpreload2_test.sh` | `LD_PRELOAD=libnativeloader.so:libart.so` | cihazda calistirildi | `timeout` binary'si LD_PRELOAD'dan etkilendi, bozuldu |
| `_ldpreload3_test.sh` | `LD_PRELOAD=libart.so:libnativehelper.so:libnativebridge.so` direkt calisma | cihazda calistirildi | RC=134, ayni namespace hatasi |
| `_libcmp.sh` | /apex/com.android.art/lib64 ile /system/lib64'yi karsilastirir | cihazda calistirildi | libart.so, libartbase.so, libnativehelper.so Sadece APEX'te, /system'de YOK |
| `_libcmp_on_device.sh` | Ayni karsilastirma cihaz icinde (sh betigi) | cihazda calistirildi | Ayni sonuc: eksikler var |
| `_preload.sh` | LD_PRELOAD=libart.so (eski, bozuk quoting) | denendi | calismadi |
| `_tomb.sh` | dltrace.log + son tombstone + crash buffer'ı okur | cihazda calistirildi | tombstone yok (crasher initramfs içindeydi) |

## Kesin bulgu (L4 engeli)

Bu ROM'un bionic surumu `link.default` / `link.public` linker config satirlarini **tamamen yok sayiyor**:

```
WARNING: linker: /linkerconfig/ld.config.txt:5: warning: unexpected property name "link.default",
         expected format dir.<section_name> (ignoring this line)
```

Buna gore `com_android_art` namespace'i asla ihrac edilemiyor. ART'in
`Runtime::Start -> InitNativeMethods -> JavaVMExt::LoadNativeLibrary` zinciri,
`/apex/com.android.art/lib64/` altindaki bir kitaplik (libart.so, libnativehelper.so vb.)
yuklenmeye calistiginda namespace aramasi yapar, `com_android_art` bulamamasi
için SIGABRT (RC=134) verip cokuyor.

`/system` bolumu EROFS salt-okunur (`ro`), dolayisiyla bu kitapliklari
`/system/lib64`'e kopyalayarak `system` namespace'inden erisme de imkansiz.

Sonuc: **L4 (system_server) bu ROM ile ulasilamaz.** Baska bir firmware
(bionic'in link.public destekledigi, /system yazilabilir) veya stok AOSP
`app_process64` gereklidir.

## Ilgili commitler

- `8de53f2` — ART VM `dalvikvm64` ile calisti (L4 yeniden mumkun gibi gorunmemisti)
- `07efd8c` — namespace hatasi cozulmus gibi durdu (sonra flake cikti)
- `f2aee9c` — L4 teslimati: link.public/link.default bu bionic'te desteklenmiyor, /system EROFS ro, L4 bu ROM ile imkansiz — kesin kanit
