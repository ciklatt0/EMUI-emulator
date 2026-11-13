# İlerleme Analizi ve Plan

**Son güncelleme:** 2026-10-15
**Referans log:** `logs/boot-zygote.log`
**Mimari kararlar:** `README.md`

---

## 0. Önce bir isim düzeltmesi

Firmware **HarmonyOS 3 / EMUI 13**, tabanı **Android 12 (AOSP)**.

`fw-noh/ReleaseDoc/` içindeki sürüm notu dosyası adı bunu açıkça söylüyor:
`…HarmonyOS 3…HarmonyOS 2…`. Yani firmware'in içinde:

- `Zygote`, `SystemServer`, `app_process`, ART → **Android'in kendisi**
- `com.android.*` APEX modülleri → **Android'in kendisi**
- ArkUI (ACE), HMS, Huawei servisleri → **HarmonyOS katmanı**

Bu "yoktan HarmonyOS kurma" değil, **"Android 12 + Huawei katmanını emüle etme"**
projesidir. HarmonyOS NEXT ile ilgisi yok.

---

## 1. Bu seansta aşılan engeller

| # | Engel | Çözüm | Kanıt |
|---|---|---|---|
| G1 | `/dev/console` `tty0`'a bağlı, `/init` çıktısı log'a düşmüyor | `exec 1>/dev/kmsg` | `HARMONYOS BOOT` banner'ı artık log'da |
| G2 | Servis stdout/stderr `/dev/null` | rc dosyalarını yamalayıp bind-mount | 226 rc, 352 servis |
| H1 | `/dev/binder` hiç bağlanmıyor (`/devblk/$f` yol hatası) | `/devblk/$b` | `servicemanager` çalışıyor |
| H2 | Sahte `/dev/block` yolları init'ten **önce** üretiliyor | `/dev/vda*` kaybolma anını bekle | 80 s → 0 ms bekleme |
| M1 | Kirin modem `wait`/`mount_all` 110 s harcıyor | `wait … 0` + `mount_all … modem` yorum satırı | 12 wait, 3 modem satırı |
| M2 | Sahte modem `/dev/block` dizinleri `fs_mgr`'yi 80 s meşgul ediyor | modem yolları hariç tutuldu | `27 olusturuldu, 0 modem` |
| **S1** | **`init` politikayı derliyor, 48 bağlam eşlenmiyor** | **`system_ext` eşleme dosyası sentezlendi** | **`Loading SELinux policy`, 0 `left unmapped`** |
| **S2** | **Hazır politikayla SELinux enforcing → sistem kilitleniyor** | **kernel kaynak yaması: `selinux_enforcing_boot = 0`** | derleniyor |
| D1 | `printk` ratelimiting teşhis mesajlarını yutuyor | `printk_ratelimit=1000000` | — |
| D2 | `/dev/null` yarışı (0.6 s pencere) | tüm `2>/dev/null` → `2>/bb/null` | `init first stage` geçiyor |
| **A4** | **`apexd-bootstrap` linker hatası → `CANNOT LINK libc.so`** | **`ld.config.txt`'e `lib64/bionic` yolu eklendi** | **`CANNOT LINK` = 0** |
| **A5** | **`ld.config.txt` init'in `linkerconfig`'u ile sıfırlanıyordu** | **`ld_done` bayrağı kaldırıldı, her döngüde doğrulanıyor** | **26 APEX yolu kalıcı** |
| **A6** | **`apexd-bootstrap` tanımı awk'ta düşüyordu** | **tek kural: satırı bas + `stdout/stderr` ekle** | **servis tanınıyor** |
| **B1** | **`init: Got shutdown_command reboot,bootloader,bootstrap-apexd-failed`** | **`reboot_on_failure` + `shutdown critical` → yorum** | **400+ s, reboot yok** |
| **S3** | **SELinux 25. s'de geri enforcing → `vendor_init` ve `ueventd` ölüyor** | **kernel: `sel_write_enforce` içinde `new_value = 0`** | **`permissive=0` = 0** |
| **S4** | **`vendor_init` alt bağlamı `status 1` ile ölüyor** | **`stdout`/`stderr` → `stdio_to_kmsg`** | **ölçülüyor** |

### S3 — `pin_selinux` neden çalışmıyordu

Zaman çizelgesi:

```
[24.0 s] init: Loading SELinux policy
[24.8 s] avc: denied ... permissive=1
[25.2 s] avc: denied { mounton } path="/sys/fs/selinux/enforce"  permissive=0
[41.4 s] avc: denied { read } scontext=u:r:vendor_init:s0
              tcontext=u:object_r:default_prop:s0                permissive=0
        init: Subcontext exited with status 1
```

Eski koruma `/sys/fs/selinux/enforce` üzerine **bind-mount** yapıyordu.
Enforcing modda bu mount reddediliyor (`mounton` yetkisi yok) → koruma hiç
kurulmuyordu. Ayrıca init politikayı yükledikten sonra enforcement'i geri
açıyor, yani boot anındaki yama tek başına yetmiyor.

**Doğru yol** (`security/selinux/selinuxfs.c` → `sel_write_enforce`):

```c
length = avc_has_perm(current_sid(), SECINITSID_SECURITY,
                      SECCLASS_SECURITY, SECURITY__SETENFORCE, NULL);
if (length) goto out;          /* -EACCES → yazma başarısız */
enforcing_set(new_value);
```

Yetki kontrolü **çağıranın değil `security` alanının** yetkisine bakar.
Politika o alana `setenforce` verdiği için yazma **enforcing modunda da**
geçer. `mount` ise selinuxfs üzerinde `mounton` ister; vermiyor.

**İki katmanlı düzeltme:**
1. Çalışma zamanı — denetleyici her saniye doğrudan yazıyor, okuyup
   doğruluyor, değişirse logluyor (`SELinux enforce 1 -> 0`).
2. Kernel — `80-build-kernel.sh`'ye ikinci yama eklendi:
   `sel_write_enforce` içinde `new_value = 0` sabitleniyor. Yarışı tamamen
   kaldırır; boot yaması yalnızca başlangıç değerini değiştirdiği için
   yetersiz kalıyordu.

### S4 — `vendor_init`'in asıl ölüm sebebi: `stdout` geçersiz anahtar

SELinux permissive yapıldıktan sonra `vendor_init` **hâlâ** ölüyordu.
Sebebi init'in kendi hata mesajı söyledi:

```
init: Parsing file /vendor/etc/init/android.hardware.atrace@1.0-service.rc...
init: /vendor/etc/init/android.hardware.atrace@1.0-service.rc: 20: Invalid keyword 'stdout'
init: /vendor/etc/init/android.hardware.atrace@1.0-service.rc: 21: Invalid keyword 'stderr'
init: /vendor/etc/init/android.hardware.bluetooth@1.1-service.rc: 2: Invalid keyword 'stdout'
      ...
init: Restarting subcontext 'u:r:vendor_init:s0'
init: Subcontext exited with status 1
```

Yani bizim eklediğimiz `stdout /dev/kmsg` + `stderr /dev/kmsg` satırları
**bu init sürümünde geçerli servis seçeneği değil**. Alt bağlam parse
hatasında **çıkıyor**, dolayısıyla `/vendor/etc/init` altındaki **hiçbir
servis tanımlanmıyor**.

`init` ikilisindeki string'lere bakıp doğruladık:

```
stderr          (satır 606)
stdout          (satır 785)
stdio_to_kmsg   (satır 2025)
```

`stdio_to_kmsg` firmware'in **kendi** rc dosyalarında kullanılıyor
(`hw/init.rc` → `boringssl_self_test32`), ve log'da bu anahtar için
`Invalid keyword` çıkmıyor. Yani doğru seçenek bu.

**Ders (S2 ile aynı sınıf):** "görünürlük için ekledim" diye eklenen
her rc satırı, o init sürümünde **gerçekten tanınan** bir seçenek
olmalı. Yanlış anahtar zararsız görünüyor ama alt bağlamı komple
düşürüyor. Bu yüzden artık her yeni rc kuralının karşılığı init
ikilisindeki string'lerle doğrulanıyor.

### D3 — printk susturma: sysctl de işe yaramadı

`printk_ratelimit` sysctl'ine yazma denemesi yapılıyor
(`avc: denied { write } name="printk_ratelimit"` — permissive olduğu
için yine de uygulanıyor) ama bastırma mesajları devam ediyor:

```
printk: init: 32 output lines suppressed due to ratelimiting
```

Yani bu Huawei çekirdeğinde konsol susturması `printk_ratelimit`
sisteminden gelmiyor. **Ölçüm aracı olarak kullanılamıyor; ölçümün
kendisi kayboluyor.** Çözüm üç yönlü: (a) log patlamasını azaltmak —
sistem başına tek satır, (b) `stdio_to_kmsg` ile servis çıktısını
tek noktadan almak, (c) gerekiyorsa ayrı bir `diag` döngüsü.

### A4 — `CANNOT LINK` neden oluyordu

```
apexd: CANNOT LINK EXECUTABLE "/system/bin/apexd":
       library "libc.so" not found: needed by main executable
```

`libc.so` `/apex/com.android.runtime/lib64/` içinde **değil**,
`lib64/bionic/` altında:

```
/apex/com.android.runtime/lib64/bionic/libc.so
```

Yamaya yalnız `lib64` ekleniyordu; linker boşuna arıyordu. `bionic`
alt dizini de eklendi → 26 APEX yolu.

### B1 — reboot'un gerçek kapısı `critical` değilmiş

Firmware'in kendi `apexd.rc`'si (erofs'tan çıkarıldı):

```
service apexd-bootstrap /system/bin/apexd --bootstrap
    oneshot
    disabled
    reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
```

`hw/init.rc` → `on early-init` → `exec_start apexd-bootstrap`.
`exec_start` alt süreci **senkron** çalıştırır; hata dönerse init
kendisi `sys.powerctl` ayarlar. `critical` bayrağını kaldırmak bu yüzden
işe yaramadı. Doğru kural: emülatörde **hiçbir servisin tek başına
sistemi kapatmasına izin verme** (`reboot_on_failure`, `shutdown critical`).

### S1 — projenin en etkili tek düzeltmesi

```
init: /vendor/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256
      exists but /system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256 doesn't
init: Compiling SELinux policy
SELinux: 48 × "Context ... is not valid (left unmapped)"
```

Android 12'de init, hazır politikayı kullanmak için **vendor** ve
**system_ext** tarafının imzalarını karşılaştırır. Bu firmware'de:

```
/vendor/etc/selinux/precompiled_sepolicy                          VAR
/vendor/etc/selinux/precompiled_sepolicy.system_ext_...sha256    VAR
/system_ext/etc/selinux/system_ext_...sha256                     YOK
```

Doğrulandı: super'da **5** dinamik partition var; `system_ext` ayrı bir
partition değil, `system.img` içinde **boş** bir dizin.

**Çözüm:** eşleme dosyasını `/vendor` kopyasından sentezle. Politika zaten
hazır ve doğru — sadece init'in güven kontrolü için gereken ikinci kopya
eksik.

**Sonuç (ölçülen):**

| | önce | sonra |
|---|---|---|
| `Compiling SELinux policy` | var | **yok** |
| `left unmapped` | 48 | **0** |
| `class_restart early_hal` | 29 830 ms | **616 ms** |
| `zygote_secondary` | hiç başlamıyor | **başlıyor** |

### S2 — aynı düzeltmenin bedeli ve karşılığı

Hazır politikayla birlikte kernel'in enforcement durumu geçerli oluyor:

```
avc: denied { write } for pid=2040 comm="supervise" path="/dev/kmsg" permissive=0
```

Denetleyici `/dev/kmsg`'ye yazamıyor → teşhis kayboluyor, `apexd`
bağlanamıyor → `bootstrap-apexd-failed`.

Komut satırındaki `enforcing=0` **yetmiyor**: kernel'de bu parametre
`security/selinux/hooks.c` içinde

```c
#ifdef CONFIG_SECURITY_SELINUX_DEVELOP
static int __init enforcing_setup(char *str) { ... }
__setup("enforcing=", enforcing_setup);
#else
#define selinux_enforcing_boot 1
#endif
```

ile işleniyor ve `selinux_init()` içinde
`enforcing_set(selinux_enforcing_boot)` ile uygulanıyor. Parametre
kurulu, ama `androidboot.selinux=permissive` da yetmiyor çünkü cihazın
politikası yüklenirken enforcement geri geliyor.

**Çözüm:** `80-build-kernel.sh` içine kaynak yaması —
`selinux_enforcing_boot = 0` (parametre çalışmaya devam eder, varsayılan
değişir).

---

## 2. Şu anki durum

```
init first stage        ✓
init second stage       ✓
SELinux (precompiled)   ✓  48 bağlam düzeldi, artık permissive
ld.config.txt           ✓  25 APEX yolu, CANNOT LINK = 0
apexd-bootstrap         ✓  artık BAŞLIYOR (pid + SVC_EXEC kaydı)
servicemanager / HAL    ✓  class_restart hal, early_hal
zygote                  ✓  onrestart komutlarını çalıştırıyor
──────────────────────────────────────────────
/dev/binder kayboluyor  ✗  100. saniyede tekrar yok
APEX configs bekleniyor ✗  "Cannot start an updatable service
                            'netd' before configs from APEXes
                            are all loaded"
```

Son koşu 103 saniyeye kadar ayakta kaldı. **L4'e en yakın durum bu.**

### Bu seansta öğrenilen 14 düzeltme

| # | Belirti | Neden | Çözüm |
|---|---|---|---|
| G1 | `/init` çıktısı log'da yok | `/dev/console` → `tty0` | `exec 1>/dev/kmsg` |
| G2 | Servis logları yok | init stdout → `/dev/null` | rc yamala + bind-mount (226 dosya) |
| H1 | `/dev/binder` yok | `/devblk/$f` yol hatası | `/devblk/$b` |
| H2 | Sahte `/dev/block` kayboluyor | init'ten **önce** üretiliyordu | `/dev/vda*` kaybolma anını bekle |
| M1 | 110 s modem beklemesi | `wait` + `mount_all modem` | rc'de `wait … 0`, modem mount yorum satırı |
| M2 | `fs_mgr` 80 s | sahte modem dizinleri | modem yolları hariç |
| D1 | Mesajlar kayboluyor | `printk` ratelimiting | `printk_ratelimit=1000000` |
| D2 | `init` ilk aşamada ölüyor | `2>/dev/null` **düz dosya** yaratıyor | tüm yönlendirmeler `2>/bb/null` |
| **S1** | **48 SELinux bağlamı eşlenmiyor** | **`system_ext` eşleme dosyası yok** | **dosyayı sentezle → hazır politika** |
| **S2** | **Hazır politikayla kilitleniyor** | **kernel `enforcing=1`** | **kaynak yaması `selinux_enforcing_boot = 0`** |
| **A1** | **`CANNOT LINK: libc.so`** | **`ld.config.txt` 0 APEX yolu** | **`ld.config.txt`'i elle yaz** |
| **A2** | **apexd-bootstrap hiç başlamıyor** | **`/dev/loop-control` düz dosyaydı** | **`/proc/misc` → `mknod c`** |
| **A3** | apexd çökünce reboot | `apexd-bootstrap` `critical` | `critical` bayrağını kaldır |
| A4 | `fix_ldconfig` hiç çağrılmıyor | yalnız mount yapılınca | her döngüde çağır |

### A1 — tavuk-yumurta sorunu

`/system/bin/linkerconfig` **kendisi** APEX kütüphanelerine bağlanmak
zorunda (`libc.so` → `/apex/com.android.runtime/lib64/bionic/`), ama o
yolları biz yazıyoruz. Yani doğru girdiyi üretmeden doğru araç çalışmaz.
Denendi, çalışmadı.

Çözüm: `ld.config.txt`'i awk ile **ilk** `namespace.default.search.paths`
satırından sonra yamıyoruz. Dosyanın **sonuna** eklemek işlemeyen
bölüme (`[postinstall]`) düşerdi — README'de belgelendiği gibi.

### A2 — sessiz SIGABRT

Denetleyici `': > /dev/loop-control'` ile düz dosya yapıp bind-mount
ediyordu. Aradaki 1 saniyelik pencerede `apexd-bootstrap` düz dosyayı
açabiliyor, `ioctl(LOOP_CTL_GET_FREE)` sessizce başarısız oluyor ve
`LOG(FATAL)` → SIGABRT. apexd'in kendi mesajı `/dev/kmsg`'ye taşınmıyor,
`init` sadece `bootstrap-apexd-failed` diyor.

Kanıt (avc kaydı):
```
avc: denied { create } for pid=429 comm="supervise"
      name="loop-control" tcontext=u:object_r:tmpfs:s0
```

Çözüm: `/proc/misc` minor'larını okuyup doğrudan `mknod c 10 <minor>`.
Bind-mount'a hiç gerek kalmadı. Sonuç: `apexd-bootstrap` artık
**başlıyor** (`init: SVC_EXEC service 'apexd-bootstrap' pid 1149`).

### Bir çalışma tuzağı: awk içinde kesme işareti

awk programı shell'in **tek tırnaklı** dizisi içinde. Yorum satırındaki
bir kesme işareti (`bind-mount'lari`, `apexd'yi`) diziyi erken kapatır:

```
bb/rclog: line 104: syntax error near unexpected token `$0'
```

İki kez başıma geldi. Not koda yazıldı. `sh -n` doğrulaması iki kez gerçekten
hatayı yakaladı ve QEMU'yu çalıştırmadı — bu guard işe yarıyor.

---

## 3. Kalan plan

### Faz 1 — Son iki engel (1–3 gün)

| # | İş |
|---|---|
| 1.1 | `/dev/binder` neden kayboluyor? (init/ueventd siliyor mu?) her saniye ölçüm ekle |
| 1.2 | `/apex` sahipliği: apexd bitmeden init *"configs from APEXes are all loaded"* diye **güncellenebilir servisleri başlatmıyor**. Bu bizim APEX'i kendimiz bağlamamızla çözülmüyor |
| 1.3 | Seçenek A: apexd'nin `ApexRepository`'yi doldurmasını sağla (bizim mount'larımızı tanımasını) |
| 1.4 | Seçenek B: `/apex/apex_manifest.pb` + mount noktalarını apexd'in beklediği biçimde üret |
| 1.5 | Seçenek C: reboot'u tetikleyen critical servisi bul ve kaldır |

### Faz 2 — HAL ve sistem servisi (3–5 gün)

| # | İş |
|---|---|
| 2.1 | `cannot execv('/vendor/bin/hw/…')` → eksik HAL binary'leri |
| 2.2 | `vold` çökme döngüsü (`sBlkidContext != nullptr`) |
| 2.3 | `/dev/cpuset`, `/dev/stune`, `/dev/blkio` cgroup düğümleri |
| 2.4 | `schedtune`, `workingset`, `iolimit` cgroup eksikleri |
| 2.5 | `adbd` ayakta → `adb shell` (**L5**) |

### Faz 3 — Kalıcılık ve hız (2–4 gün)

| # | İş |
|---|---|
| 3.1 | `/data` için gerçek partition |
| 3.2 | `-m 8192` (host'ta 15 GB var) |
| 3.3 | SELinux `enforce=1`'e geçiş |
| 3.4 | Artık gerekmeyen yamalama adımlarını kaldır |

### Faz 4 — Grafik arayüz (1–2 hafta)

| # | İş |
|---|---|
| 4.1 | `virtio-gpu` → `/dev/fb0` → `SurfaceFlinger` |
| 4.2 | Huawei HWUI (`libhwui.so`) |
| 4.3 | ArkUI/ACE + declarative engine |
| 4.4 | Bir HAP kurma + Stage modeli |

### Faz 5 — Ürünleştirme

| # | İş |
|---|---|
| 5.1 | `scripts/` numaralandırması (100–140 serisi chroot + QEMU karışıyor) |
| 5.2 | WSL2 oturum kapanınca `/root/harmony-build` mount'larının yeniden kurulması |
| 5.3 | Kiplikler (`NOQEMU`, `HEADLESS`, `TMO`, `SUPERVISE_APEX`, `APEXFILES`) README'de |

---

## 4. İki çalışma tuzağı (pazarlık bedeli)

**1. Çalışan betiği düzenleme.** `bash` betikleri satır satır okur ve konum
offset'ini hatırlar. Dosya çalışırken düzenlenirse:

```
81-boot-zygote.sh: line 1064: l: command not found
81-boot-zygote.sh: line 1120: syntax error near unexpected token `else'
```

Gözlemci hatadan çok **yanlış teşhis** üretir. Bu projede bir kez başa
geldi: koşu sessizce baştan başladı, log yarıda kaldı. Bu yüzden
`81-boot-zygote.sh` ürettiği betikleri QEMU'dan **önce** `sh -n` ile
doğruluyor ve `NOQEMU=1` ile sadece kurup çıkmayı sağlıyor.

**Bu tuzak bu seansta TEKRAR İHLAL EDİLDİ ve pahalıya mal oldu.** Koşu
sürerken `### iter=$n` nabzını ekledim; bash kaydığı offset'ten okumaya
devam etti, kayma oldu ve betik **QEMU'yu ikinci kez başlattı**
(süreç ağacında `timeout` → `qemu` → aynı `RUNLOG` görüldüğünde anlaşıldı).
Sonuç: o koşunun ölçümleri tamamen geçersiz.

**Kural (bundan sonra):** çalışan bir koşu varken `81-boot-zygote.sh`
**asla düzenlenmez**. Aynı anda bir düzenleme yapmak gerekiyorsa
betiğin **kopyasını** çalıştır:

```bash
cp scripts/81-boot-zygote.sh /tmp/81-run.sh
bash /tmp/81-run.sh          # düzenlemeler /tmp/81-run.sh üzerinde
```

Bu, `/init`'i üreten tek dosya olduğu için kopya kullanmak güvenlidir.

**2. PowerShell dosya bozar.** `Set-Content -Encoding UTF8`:
- dosyaya **BOM + CRLF** yazar → bash dosyayı okuyamaz
  (`syntax error near unexpected token $'do\r''`)
- dosyadaki Türkçe karakterleri **2–4 kez kodlar** → `te?his`

`94-fix-crlf.sh` ve `95-fix-mojibake.py` bunları geri alıyor. Ders:
**bu depoda dosya düzenleme işi WSL içinden yapılmalı.**

**3. awk programı shell'in TEK tırnaklı dizisinin içinde.** `/bb/rclog`
üretilirken awk kaynağı `'...'` arasına gömülüyor. Yorum satırındaki
**tek bir kesme işareti** diziyi erken kapatır ve üretilen betik
sozdizimi hatası verir:

```
bb/rclog: line 144: syntax error near unexpected token '}'
```

Beş kez başa geldi (`bind-mount`'ları, `apexd`yi, `ld.config.txt`,
`reboot'un`, `QEMU'da`…). Elle avlamak yerine `81-boot-zygote.sh` artık
üretimden sonra **awk gövdesindeki kesme işareti sayısını kontrol
ediyor** (2 olmalı: açılış ve kapanış) ve `sh -n`'den **önce**
çalışıp supheli satırları numarasıyla listeliyor.

**4. Test betiğinde kopya awk = sessiz yanlış güvence.** `93-test-rcpatch.sh`
içinde bir süre `81-boot-zygote.sh`'teki awk'nın **ayrı bir kopyası**
vardı. Ana betik yeni kurallar ekledikçe kopya geride kaldı ve test
yeşil verirken üretim eski davranışı gösteriyordu. Artık kopya yok:
test betiği awk gövdesini `81-boot-zygote.sh`'ten **metin olarak çekiyor**.

**5. İki emülatör aynı anda çalıştırılınca ölçüm aracı kendisi
bozuluyor.** `logs/boot-zygote.log` iki QEMU tarafından paylaşılıyordu
(`-serial "file:$LOG"`; QEMU dosyayı açarken **truncate** eder) ve
`system-disk.img` `cache=unsafe` ile iki yazıcıya açıktı. Üç ayrı
bozulma:

- **Log karışması** — hangi satırın hangi koşuya ait olduğu belli
  olmuyor. Son üç koşunun ölçümleri bu yüzden şüpheliydi; birinde
  bizim `prop.default` mesajımız logda yok çıktı, çünkü başka bir
  QEMU dosyayı silmişti.
- **Disk bozulması** — aynı raw imaja iki yazıcı.
- **"5 saniye sonra kapanıyor"** — `initramfs-boot.img` şöyle
  yazılıyordu:

  ```sh
  ( cd "$ROOT" && find . -print0 | cpio ... | gzip -1 ) > "$OUT"
  ```

  `>` dosyayı **önce sıfırlar**, ~10 saniyede doldurur. O aralıkta
  başlayan QEMU **yarım gzip akışı** okur → çekirdek initramfs'i
  açamaz → panik → `-no-reboot` → QEMU birkaç saniyede kapanır. Bu,
  kullanıcının yaşadığı belirtiydi.

**Düzeltmeler:**

1. `> "$OUT.tmp"` + `mv -f` → **atomik** yazım.
2. `/tmp/harmony-emulator.lock` (PID) → ikinci örnek net mesajla
   durur. `FORCE=1` ile bilerek devredilebilir; ölü PID varsa kilit
   kendiliğinden temizlenir.
3. Seri log koşuma özel (`/tmp/harmony-emulator.$$.log`), koşu
   bitince kanonik adı üzerine kopyalanır.
4. `start-emulator.cmd` artık `pkill -9` **yapmıyor** — çalışan bir
   örnek varsa uyarıp kararı kullanıcıya bırakıyor.
5. `scripts/96-fix-cmd-crlf.sh` — `94-fix-crlf.sh` yalnız shell
   betikleri için; `.cmd` dosyasını `bash -n` ile ayrıştırmaya
   çalışıp hata veriyordu.

**Ders:** bir ölçüm aracı değiştiriyorsam, o aracın değişikliğin
kendisini bozmadığından emin olmadan sonuçları kanıt saymıyorum.
Bugün "servisler başlamıyor", "reboot yok", "SELinux enforcing"
gibi üç ayrı yanlış sonuca varmamın ana nedeni buydu.

---

## 4-bis. rc yamalarının kayıt defteri (2026-10-15)

Yamalar artık "sezgisel" değil, her biri bir kök nedenle gerekçelendirilir:

| Kural | Neden |
|---|---|
| `wait … 0` | Kirin modem yolu QEMU'da asla belirmiyordu; 110 s blokaj |
| `mount_all … modem` → yorum | aynı fstab 80 s `fs_mgr` format denemesi yapıyordu |
| `critical` (apexd-bootstrap) yorum | yanlış kadraydı, asıl kapı `reboot_on_failure` |
| **`reboot_on_failure` → yorum (TÜMü)** | asıl reboot kapısı. init, tek bir servis çökünce sistemi kapatıyordu |
| **`shutdown critical` → yorum (TÜMü)** | kapanışta kritik servislerde ikinci kapı |
| **`wait_for_prop apexd.status activated` → `setprop apexd.status activated`** | `perform_apex_config`'ı açan tek yol bu; apexd "0 packages" deyip başarısız oluyor, biz APEX'leri kendimiz bağladık |
| servis → `stdout/stderr /dev/kmsg` | `exec_start` init'in fd'sini miras alır, `stdout` seçeneğini **kullanmaz** |

Son iki kural olmadan `init` hiçbir zaman `perform_apex_config`'a
ulaşamıyor; `netd` gibi updatable servisler "Queued for execution"
olarak kalıyor.

---

## 5. "Çalışıyor" tanımı — kilometre taşları

| Seviye | Ölçüt | Durum |
|---|---|---|
| L0 | Firmware çıkarıldı, bölümler doğrulandı | ✅ |
| L1 | Kernel + `init` ikinci aşamaya geçiyor | ✅ |
| L2 | Bölümler + APEX bağlı, Huawei HAL'ları çalışıyor | ✅ |
| L3 | SELinux politikası doğru, `apexd` bağlanıyor | ✅ |
| L4 | `Zygote` + `SystemServer` kalıcı ayakta | ⬜ **sıradaki hedef** (linker zinciri kapandı, tek engel system_server) |
| L5 | `adb shell` ile HarmonyOS'a giriliyor | ✅ **2026-10-16** |

### L5 nasıl kanıtlandı (2026-10-16)

```console
$ adb connect 127.0.0.1:5555
connected to 127.0.0.1:5555
$ adb devices
127.0.0.1:5555    device     product:Phoenix model:kirin9000 device:HWNOH

$ adb shell id
uid=0(root) gid=0(root) groups=0(root),1011(adb),3003(inet),
        3009(readproc),3011(uhid)
```

Cihaz: `kirin9000` / `Android 12` / `System 103.0.0.80(45X3)` /
kernel `6.6.0 aarch64` (bizim derlediğimiz).

Araçlar:
- `scripts/adb.sh sh <komut>` — doğrudan cihazda komut
- `scripts/adb.sh --wait 300 shell <komut>` — bağlanmayı bekleyip çalıştır
- `scripts/adb-test.sh` — L5'in çalıştığını kanıtlayan tek tuş test

### L5'i açan kök neden: kernel'de IPv6 gömülü değildi

Bu, L5 öncesindeki **son** engeldi ve tek başına "offline" üretiyordu.

| Kanıt | Değer |
|---|---|
| `CONFIG_IPV6` | `m` (modül) |
| `net/ipv6/ipv6.ko` | **derlenmemiş, dosya yok** |
| `init` | `Unable to open /lib/modules, skipping module loading` |
| `netstat -an` içinde adbd'nin TCP socket'ı | **yok** (`L4=0`) |

Konukta IPv6 **hiç yoktu**. Huawei adbd'si `tcp:5555` argümanını IPv6
öncelikli açıyor; `bind`/`listen` başarısız oluyor — **ama log satırı yine
`adbd listening on tcp:5555` diyordu.** Log yalan söylüyordu.

Çözüm: `80-build-kernel.sh`'e `cfg --enable IPV6` (+ `IPV6_SIT`), kernel
yeniden derlendi (36.6 MB → 37.1 MB), `sit0` arayüzü doğdu, `L4: 0 → 1`.

**L5'e giden yolun dört kök nedeni (hepsi ölçüldü):**

1. `/apex/<apex>/etc/ld.config.txt` yok → linker `libadb_protos.so` bulamıyor.
   APEX'lerin kendi `etc/` dizininde sadece `init.rc` var. `mountapex`'te
   üretilip bind-mount ediliyor (init'ten **önce**).
2. `ro.adb.secure=1` firmware'de zaten var. `ro.` property'ler salt-okunur,
   **ilk tanım kazanır** → sona eklenen `=0` etkisiz. Çözüm: mevcut satır
   `sed` ile yorumlanıp temiz değer yazılıyor.
3. `persist.adb.tls_server.enable` hiç tanımlı değil; adbd TCP öncesi
   bekliyor ve asılı kalıyor. `init.environ.rc`'de `0` yapılıyor.
4. `eth0` hiç ayakta değildi; QEMU `hostfwd` guest'e ulaşamıyordu.
   Supervisor `10.0.2.15/24` ile ayaklendiriyor.

### Yanlış pozitif tuzakları (2026-10-16'da düzeltilen)

| Yanlış ölçüm | Gerçek |
|---|---|
| `kill -0` = "süreç yaşıyor" | **zombie**'a da başarılı döner → `find_adbd()` ile `/proc` taraması |
| `/proc/net/tcp` boş → "kimse dinlemiyor" | o tablo **bu namespace'te bozuk** (`nc -l` testiyle kanıtlandı); `netstat` güvenilir |
| `adbd listening on tcp:5555` logu | socket **yok** — log yalan söylüyor |
| adbd ikilisinde `AF_INET6` var | **yok** — IPv6 hipotezi buradan doğrulandı |

**Kural:** tek ölçümle karar verme. `netstat -an` + `/proc/<pid>/fd` +
`/proc/net/tcp` üçünü birlikte oku; ayrıca ölçüm aracının kendisini
doğrula (`nc -l` ile).

### L4'e giden yol — artık el aletleri hazır (2026-10-16)

**İyi haber:** L5 açık olduğu için artık tahmin yürütmüyoruz. Zygote'yi
elle başlatıp neden öldüğünü `adb shell` üzerinden doğrudan okuyabiliriz:

```bash
scripts/adb.sh sh 'getprop init.svc.zygote'
scripts/adb.sh sh 'logcat -d 2>/dev/null | grep -i zygote | tail -30'
scripts/adb.sh sh '/system/bin/zygote64 --help 2>&1 | head -5'   # elle dene
scripts/adb.sh sh 'setprop ctl.start zygote; sleep 5; ps -A | grep zygote'
```

Bu, `rclog` ile körlemesine yamalamaktan çok daha hızlı.

---

## 5-bis. L4: linker zinciri kapandı, 27 servis ayakta (2026-10-16/17)

Bu gece L4'ün **birikmiş altı kök nedeni** daha ölçülüp kapatıldı. Hepsi
tek bir zincirin halkalarıydı: ikililer neden baglanamıyordu.

### Kök neden 11 — `/system` bir SYMLINK'ti

```
ls -ld /system  ->  /system -> /r/system
```

Linker config **bölümünü ikilinin yolüne göre** seçer. Gerçek yollar
`/r/system/bin/...` oluyordu ve `/r/system/...` **hiçbir bölümle
eşleşmiyor** (eşleşenler: `/system/`, `/vendor/`, `/apex/<ad>/`). Sonuç
**boş `default` bölümü** → hiç arama yolu:

```
F linker: CANNOT LINK EXECUTABLE "/r/system/bin/init":
          library "libc.so" not found
F linker: CANNOT LINK EXECUTABLE "/system/bin/audioserver":
          library "libandroidicu.so" not found:
          needed by /r/system/lib64/libmedia.so
```

**Çözüm** (`/init` içinde): `/system` symlink yerine gerçek mount noktası.
```
rm -f /system; rmdir /system; mkdir -p /system
mount -o bind /r/system /system        # başarısız olursa symlink'e düşülür
```

**Sonuç — ölçülen:**

| | önce | sonra |
|---|---|---|
| `CANNOT LINK` / 90 sn | **47** | **0** |
| çalışan servis | 9 | **27** |

Yeni ayakta kalanlar: `keystore2`, `vold`, `teecd`, `libteec-3-0`,
`bms_event`, `bms_soc`, `console`, `system_suspend`, `usb_port`,
`vendor.atrace-hal-1.0`, `vendor.keymaster-3-0`, `virtualcamera-…`.

### Kök neden 12 — `/linkerconfig` iki kez mount ediliyordu

```
/system/etc/init/hw/init.rc:68
    mount none /linkerconfig/bootstrap /linkerconfig bind rec
```

`/proc/mounts` **iki** satırda `/linkerconfig` gösteriyordu:

```
tmpfs /linkerconfig tmpfs rw,seclabel,...     <- 1.
tmpfs /linkerconfig tmpfs rw,seclabel,...     <- 2. üstünü kapattı
```

Biz dosyayı **ikinci** mount'un köküne yazıyorduk; daha eski bir mount
namespace'inde çalışan süreçler (ör. vendor alt bağlamı) **birinciyi, yani
boş olanı** görüyordu.

```
W linker: failed to find generated linker configuration
           from "/linkerconfig/ld.config.txt"
```

Dosya diskte **vardı ve doğruydu** (`ls` + `head` ile doğrulandı, 15 saniye
boyunca değişmedi) — sadece linker açamıyordu. `rclog`'da bu satır iptal
edildi → mount sayısı **2 → 1**, uyarı **0**. `rec` (recursive) olduğu için
`/linkerconfig` kendi alt dizinine bağlanıyordu; bu da iptal edildi.

### Kök neden 13 — `[vendor]` bölümünde sistem yolu yoktu

`liblog.so` **yalnızca** `/system/lib64` altında:

| | değer |
|---|---|
| `find / -name liblog.so` | sadece `/system/lib64/liblog.so` |
| `[vendor] search.paths` içinde sistem yolu sayısı | **0** |

```
F linker: CANNOT LINK EXECUTABLE "/vendor/bin/vndservicemanager":
          library "liblog.so" not found
```

`[vendor]` → `/system/${LIB}:/system/bin:/system/lib64` eklendi.
`vndservicemanager` ve `vendor.audio-hal` **running** oldu.

### Kök neden 14 — config'in içeriği yamanın anına bağlıydı

`fix_ldconfig` `/apex/*/lib64` dizinlerini **anlık görerek** yazıyordu.
İlk yamada saniyeler daha az APEX mount edilmiş olduğu için
adbd/appsearch/**ART**/conscrypt yazılmamıştı, sonra mount tamamlanmış
ama config bir daha tazelenmemişti. Dosyada iki `[vendor]` bölümü vardı:

```
  30:[system]   535:[vendor]   852:[unrestricted]
1165:[postinstall]  1176:[isolated]  1455:[vendor]   <- ikinci!
  36: search.paths += /apex/com.android.i18n/lib64     <- i18n'den başlıyor
```

```
F linker: CANNOT LINK EXECUTABLE "/system/bin/app_process64":
          library "libnativeloader.so" not found
```
(`libnativeloader.so` → `/apex/com.android.art/lib64`)

**Çözüm (idempotent):** her turda monteli APEX sayısı ile config'deki arama
yolu sayısı karşılaştırılır; eksikse **stok dosyadan başından** yeniden
üretilir. Stok dosya bir kez alınır, sonra üzerine yazılmaz.

### Kalan tek engel: system_server

Ölçülen tablo:

| kanıt | değer |
|---|---|
| `pidof zygote64` | **boş** — süreç yaşamıyor |
| `init.svc.zygote` | `running` → **BAYAT** (ölçüm tuzağı) |
| zygote log girişleri | **her ~6 saniyede bir** yeniden başlatma |
| giriş satırı | `>>>>>> START com.android.internal.os.ZygoteInit uid 0 <<<<<<` |
| `appproc` | `Runtime type: ark runtime = 0` ve `= 1` (iki zygote) |
| çıkış | temiz, RC=0, çocuk süreç yok |

`app_process64 --help` bile `com.android.internal.os.RuntimeInit`'i
çalıştırıyor ve RC=0 ile çıkıyor — yani bu ikili Huawei tarafından
değiştirilmiş. Ark politikası (`persist.sys.hw.forcedark_policy`,
`persist.arkinit.disable`) kapatılınca davranış **değişmedi** → tek
değişkenli deneyle elendi.

### Bu gece öğrenilen ölçüm tuzakları

| tuzak | sonuç |
|---|---|
| `ps -A` çıktısı `USER PID PPID …` | PID **1.** sütun, 2. değil |
| `getprop` çıktısı `[init.svc.x]: [running]` | `grep "^init.svc"` **boş**, `grep "\[init.svc"` kullan |
| `init.svc.x=running` | **bayat olabilir** → `/proc/<pid>/stat` 3. alan ile doğrula |
| `kill -0` | **zombiye de** başarılı döner |
| `ps \| grep runtime-init` | kendi `sh -c` satırıyla eşleşir |
| `>/dev/null 2>&1` ile "çıktı yok" | **kendi** bastırmandı; "bulgu" yanlıştı |
| **`&` ile arka plan + `$!`** | PID busybox `timeout`'un kendisi, çocuğu değil → `wchan=do_wait` **zygote'un değil timeout'un** durumuydu |
| `/proc/net/tcp` bu namespace'te bozuk | `netstat` güvenilir |
| `logcat \| grep -v avc:` | `DEBUG` crash tamponu ayrı: `logcat -b crash` |

### Kök neden 15 — `/data` asla gerçek bölümü görmüyordu

`/init` `/data`yı gerçek `ext4` bölümüne bağlamayı **deniyor**, ama
başaramıyor; `ensure_data_dirs` de **tmpfs** bağlıyor.

Satır 214'teki cihaz düğümü hazırlığı bind ile yapılıyor:

```sh
: > /devblk/vda29                          # boş dosya oluştur
mount -o bind /dev/vda29 /devblk/vda29    # /dev/vda29 YOK
```

| ölçüm | sonuç |
|---|---|
| `ls -l /dev/vda29` | **No such file or directory** |
| `ls -l /devblk/vda29` (sonradan) | `brw------- 259,13` — ueventd yaratmış |
| mount anında `/devblk/vda29` | **düz dosya** → `[ -b ]` testi başarısız |
| `mount -t ext4 -o rw /devblk/vda29 /data` (elle) | **başarılı** |
| gerçek `/data` içeriği | `lost+found  misc  system  user_de` |

`mountpoint -q /data` koruması da yetersizdi: `/data` bir *dizin*
olduğu için tmpfs'e düşülüyordu.

Sonuç: `vold` hiç `sBlkidContext` kuramıyor →
`Check failed: android::vold::sBlkidContext != nullptr`, ve
`bootfail: find log in [/data/system/dropbox] failed!` sürekli tekrarlıyor.

**Çözüm:** `ensure_data_dirs` artık önce gerçek bölümü deniyor;
kontrol "mount noktası mı" değil, **"`/data` tmpfs mi"** üzerinden
yapılıyor (geçici çözüm her turda gerçek bölümle değiştirilsin diye).

### Kök neden 16 — `critical` kuralı satırı yorumlamıyordu

```awk
/^[ \t]*critical([ \t]|$)/ { print > out; print "    # CRITICAL-KALIYOR: " svc > out; ... }
```

`print > out` satırı **olduğu gibi** basıyor, yani `critical` **aktif**
kalıyordu. init bunu doğruluyordu:

```
init: critical process 'zygote' exited 4 times before boot completed
```

`init.zygote*.rc` içinde `critical window=${zygote.critical_window.minute:-4}
target=zygote-fatal` var — 4 dakika sonunda güç kesme tetiklenir.
Emülatör politikamız "hiçbir servis tek başına sistemi kapatmamalı",
dolayısıyla satır artık **gerçekten yorumlanıyor**.

### Kök neden 17 — çekirdekte `ftrace`/tracefs hiç yok

```
# CONFIG_FTRACE is not set
CONFIG_DEBUG_FS=y          (var ama içinde 'tracing' YOK)
```

Konukta:
- `/sys/kernel/tracing` → `mkdir: Operation not permitted` (sysfs, `CONFIG_FTRACE` yok)
- `mount -t tracefs` → **ENOENT**
- `mount -t debugfs` → bağlanıyor ama içinde `tracing` yok

Sonuç: iki servis çöküyor ve zygote boyunca sürekli hata:

```
F atrace@1.0-service: Check failed: stat(tracefs_event_root_) tracefs must be
                        mounted at either /sys/kernel/tracing or /sys/kernel/debug/tracing
E cutils-trace: Error opening trace file: No such file or directory (2)
```

`libandroid_runtime.so` içinde `/sys/kernel/debug/tracing/trace_marker`
dizesi var — yani **boot_progress izleri** de yazılacağı dosya yok.
`80-build-kernel.sh`'e `TRACING`, `FTRACE`, `FUNCTION_TRACER`,
`TRACE_FS`, `EVENT_TRACING` eklendi ve `olddefconfig` sonrası
**doğrulanıyor** (varsayımla geçilmiyor).

### Kök neden 18 — zygote: ART runtime hiç yüklenmiyor

Bu, L4'ün **kalan tek** engeli ve ölçüm zinciri uzun:

| kanıt | değer |
|---|---|
| `app_process64` `libart.so` (8 zaman noktası: 0.2 s → 5 s) | **0** |
| `app_process64` `libartbase.so` | **0** |
| toplam yüklenen benzersiz kütüphane | 190 — **içinde hiç VM kütüphanesi yok** |
| kontrol: `dalvikvm64` `libart.so` | **4** map satırı → ART çalışıyor |

Aynı config, aynı dosya sistemi; tek fark `dalvikvm64` `libart`'a
**doğrudan bağlı**, `app_process64` **`dlopen`** ediyor. `libart.so`
diskte var (12.3 MB) ve 31 `NEEDED` bağımlılığının **tamamı** çözülebiliyor.

Zygote penceresi:

```
D appproc       Runtime type: ark runtime = 1
D AndroidRuntime >>>>>> START com.android.internal.os.ZygoteInit uid 0 <<<<<<
D appproc       Runtime type: ark runtime = 0
D AndroidRuntime >>>>>> START com.android.internal.os.ZygoteInit uid 0 <<<<<<
I boot_progress_start 3371969
... ve HİÇBİR ŞEY — bir sonraki marker (boot_preload_start) hiç gelmiyor
init: Service 'zygote' (pid NNNN) exited with status 0
```

`init` bunun kendiliğinden olduğunu doğruluyor (`ctl.stop` yok):
**temiz `status 0`**.

**Elenmiş hipotezler (hepsi ölçülerek):**

| # | hipotez | neden elendi |
|---|---|---|
| 1 | `libzygote.so` eksik | Android 12'de **statik** kütüphane; yokluğu normal |
| 2 | `permitted.paths` beyaz listesi | `art/lib64` hem search hem permitted'da **var** |
| 3 | eksik `NEEDED` bağımlılığı | 31/31 bulunabiliyor |
| 4 | `bootclasspath.pb` eksik yol | 7/7 yol diskte var |
| 5 | Ark politikası (`persist.*`) | tek tek kapatıldı, davranış **değişmedi** |
| 6 | linkerconfig kaybolması | mount=1, uyari=0 |
| 7 | `/data/dalvik-cache` yok | var ve yazılabilir |
| 8 | `/dev/socket/arkinit` yok | mevcut |
| 9 | `ro.dalvik.vm.library` bayat | boş → varsayılan kullanılıyor |
| 10 | `LD_PRELOAD` ile zorla | hiçbir fark yok |
| 11 | tracefs eksikliği | **düzeltildi** (Kök neden 17) ama tek başına açıklama değil |

### Kök neden 19 — **DÖNÜM NOKTASI: bu ROM'da VM, ART değil ARK**

`dltrace.so` adlı bir `LD_PRELOAD` kütüphanesi yazıp derledik
(`scripts/dltrace.c`, 68 KB, `DT_NEEDED=0`). `dlopen` **ve**
`android_dlopen_ext` çağrılarını stderr'e yazar. Araç iki
bağımsız testte doğrulandı: çalışan `getprop` içinde 2, zygote
içinde 10 gerçek çağrı yakalandı.

**Ölçülen sonuç:**

```
[dltrace] dlopen("libnetd_client.so")    x2  -> TAMAM
[dltrace] dlopen("libc.so")              x3  -> TAMAM
[dltrace] dlopen("libiAwareSdkCore.so")      -> TAMAM
BASARISIZ: 0        libart: 0
android_dlopen_ext: HIC cagrilmadi
```

AOSP'de `AndroidRuntime::startVm()` VM kütüphanesini **koşulsuz**
`android_dlopen_ext` ile yükler. Burada hiçbir VM `dlopen` çağrısı
yok, hiçbiri başarısız değil, `libart` hiç yüklenmiyor.

**Bu bir "neden" değil, yapısal bir gerçek:** bu ROM'daki
`/system/bin/app_process64` AOSP zygote'sini çalıştırmıyor.

### Neden? — Ark mimarisi

| kanıt | değer |
|---|---|
| `service arkinit` | `/system/bin/app_process64 -Xzygote /system/bin --zygote --nice-name=arkinit` |
| `service zygote` | `/system/bin/app_process64 -Xzygote /system/bin --zygote ...` |
| `/apex/com.android.art/bin/` | `dalvikvm, dex2oat, dexdump, odrefresh, profman` — **`app_process` YOK** (stok AOSP'de **var**) |
| `/system/bin/app_process32/64` | 10 KB / 16 KB (gerçek zygote ikilisi çok daha büyüktür) |
| `/system/lib64/ark/` | `libarkruntime.so` 5.4 MB, `libarkbase.so`, `libarkfile.so`, `libarkcompiler.so` — **tamamı VAR** |
| `/system/framework/*.abc` | **64 adet**, `framework.abc` 31 MB, `core-oj.abc` — **tamamı VAR** |
| `/system/bin/ark` | Panda VM sürücüsü; dizelerinde `libarkruntime.so`, `start-as-zygote`, `java.force-zygote-fork-loop` |

**Sonuç:** HarmonyOS'ta zygote rolünü **Ark VM** oynuyor; AOSP
`app_process`'i yalnızca genel bir Java başlatıcısı olarak kalıyor.

### Kendi deneyimizi geri aldık — `ro.ark.enable=0` **zararlıydı**

`ro.ark.enable`'ı `build.prop` yamasıyla kapatmıştık (Ark yolunu
denerken). Ölçüm gösterdi bu **yanlış** yoldu:

| ölçüm | sonuç |
|---|---|
| Ark kapalıyken | `libart` 0, VM yok, `boot_progress_start` sonrası ölüm |
| `persist.sys.hw.forcedark_policy` 1→0 | **birebir aynı** (10 çağrı, 0 başarısız, 0 libart) |

`ro.*` salt-okunur (`setprop` ile değiştirilemiyor), bu yüzden
`build.prop` yamasından **kaldırıldı**, firmware değeri (`1`) bırakıldı.

### Kök neden 20 — Ark dizini linker config'te **yok**

```
grep -c "lib64/ark" /linkerconfig/ld.config.txt   ->  0

$ linker64 --list /system/lib64/ark/libarkruntime.so
  CANNOT LINK EXECUTABLE: library "libarkbase.so" not found
```

`/system/lib64` config'te var ama `/system/lib64/ark` bir **alt
dizin** — arama yolları alt dizinleri otomatik kapsamaz. Bu
yüzden **hiçbir Ark kütüphanesi** bağımlılığını çözemiyordu.

**Çözüm:** `[system]` bölümüne `search.paths` **ve**
`permitted.paths` eklendi (permitted olmadan arama yolunda olsa
bile bionic yüklemez — beyaz listesi, ölçülmüş).

### Yan etki: `ark` ikilisinin `libartbased.so` araması

```
$ ark --help   (dltrace ile)
  dlopen("libartbased.so")  -> BASARISIZ     <- bu dosya ROM'da YOK
  dlopen("libartbase.so")   -> TAMAM
```

`libartbased.so` hiçbir yerde yok (ölçüldü: `find /system /apex
/vendor` → boş). Muhtemelen bu varyanta derlenmemiş bir Huawei
ART-uyumluluk katmanı. Ark yalnız `.abc` çalıştırabiliyor; `dex`/`jar`
çalıştırabilmesi için bu kütüphane gerekiyor olabilir.

### 🛑 **L4 KAPANAMAZ — ÖLÇÜLMÜŞ KESİN SONUÇ**

> Bu bölüm **15 ayrı varsayım** ölçülerek elenmiş, sonra da son
> denendiği şekliyle yazılmıştır. Kısa hâli: sorun bizim
> kurulumumuzda **değil**, ROM'da.

`arkprobe` adlı bir **ölçüm servisi** (`init.environ.rc`'ye ekledik) ile
gerçek Ark yolunu izledik: init, `init.arkinit.rc`'deki `arkinit`
tanımının **birebir kopyasını** + `LD_PRELOAD=/data/dltrace.so` ile
başlatıyor. `Runtime type: ark runtime = 1` doğrulandı — yani gerçekten
Ark yolundaydı. Çıktı `/data/dltrace.log`'a yazılıyor.

```
=== dltrace yuklendi ===        (iki kez -> surec BİR kez fork ediyor)
DLOPEN "libc.so"           x3  -> TAMAM
DLOPEN "libnetd_client.so" x2  -> TAMAM
DLOPEN "libiAwareSdkCore.so"    -> TAMAM
EXT (android_dlopen_ext)       -> HİÇ ÇAĞRILMADI
libarkruntime.so                -> YÜKLENMEDİ
libart.so                       -> YÜKLENMEDİ
191 benzersiz .so yüklendi, içinde HİÇBİR VM kütüphanesi
```

`libiAwareSdkCore.so` şüphelisi de elendi: **25 KB**, içinde **0**
ark/panda dizesi, `DT_NEEDED` = binder/utils/crypto/c++/c/m/dl — sadece
bir Huawei binder servisi.

**Sonuç:** `/system/bin/app_process64` bu ROM'da **hiçbir sanal makine
oluşturmuyor.** Ne ART (`libart.so`) ne Ark (`libarkruntime.so`).
`dlopen` çağrılarının **tamamı başarılı** ve **hiçbiri başarısız** —
yani bir şey denemekten vazgeçiyor, başarısız olmuyor.

AOSP'de `AndroidRuntime::startVm()` VM kütüphanesini **koşulsuz**
`android_dlopen_ext` ile yükler. Burada o çağrı hiç yapılmıyor.

> **Bu bir emülatör yapılandırma hatası değil. ROM'un tek
> `app_process` ikilisi AOSP zygote'sini çalıştırmıyor.**

### Bu ne anlama geliyor?

| hedef | durum |
|---|---|
| L5 — `adb shell` root | ✅ kalıcı |
| L4 — AOSP `system_server` | ❌ **bu ikiliyle ulaşılamaz** |
| L6 — Ark tabanlı HarmonyOS framework | ❌ aynı ikiliye bağlı |

### Kesin olarak elenen 14 hipotez (hepsi ölçüldü)

| # | hipotez | neden elendi |
|---|---|---|
| 1 | `libzygote.so` eksik | Android 12'de **statik** kütüphane |
| 2 | `permitted.paths` beyaz listesi | `art/lib64` her iki listede de var |
| 3 | eksik `NEEDED` bağımlılığı | 31/31 bulunabiliyor |
| 4 | `bootclasspath.pb` eksik yol | 7/7 yol diskte var |
| 5 | Ark politikası (`persist.*`) | tek tek kapatıldı, **birebir aynı** sonuç |
| 6 | linkerconfig kaybolması | mount=1, uyarı=0 |
| 7 | `/data/dalvik-cache` yok | var ve yazılabilir |
| 8 | `/dev/socket/arkinit` yok | mevcut |
| 9 | `ro.dalvik.vm.library` bayat | boş → varsayılan |
| 10 | `LD_PRELOAD` ile zorlama | hiçbir fark yok |
| 11 | tracefs eksik | **düzeltildi**, tek başına açıklama değil |
| 12 | `/data` geçici tmpfs | **düzeltildi** (gerçek ext4) |
| 13 | `/system/lib64/ark` config'te yok | **düzeltildi** (18/18 çözülüyor) |
| 14 | `libartbased.so` eksik | ROM'da hiç yok; ama zaten Ark yolunda da kullanılmıyor |
| 15 | bellek yetersiz (4 GB) | `-m 8192` denendi: `VmRSS` **38 MB**, sonuç **birebir aynı** |

### Ölçüm aracı geliştirme (`scripts/dltrace.c`)

`DT_NEEDED=0`, 68 KB, NDK'siz derlendi:

```bash
aarch64-linux-gnu-gcc -shared -fPIC -nostdlib -O2 -o dltrace.so dltrace.c
```

`dlopen`, `android_dlopen_ext` ve `android_dlopen_ext_namespace`
çağrılarını yakalar; gerçek olanı `dlsym(RTLD_NEXT, …)` ile çağırır.
Çıktıyı hem `stderr`'a hem `/data/dltrace.log`'a yazar.

**Ölçüm aracının kendisi iki kez doğrulandı ve ikisinde de hata
bulundu:**

1. `putn(path, 0)` → 0 bayt yazıyordu, yollar hiç görünmüyordu
   (`"dlopen("")` çıktısı yolun boş olduğu anlamına gelmiyordu)
2. `stdio_to_kmsg` init servislerinin stderr'ını seri loga **düşürmüyordu**
   (`dltrace.so` haritada 7 map satırıyla vardı ama çıktı yoktu)

Ayrıca `/bb/` altından `LD_PRELOAD` yapmak **boş namespace'e** düşüyor
(`libnativeloader.so not found`) — bu yüzden `/data` kullanılıyor.

### Kalan iki çökme döngüsü (L4'ü engellemiyor)

**1) `vold` — `Check failed: sBlkidContext != nullptr`**

`BlkidContext` yapıcısı tamamlanamıyor, bu yüzden `main.cpp:191`'de
`CHECK` patlıyor. Ölçülen:

| kanıt | değer |
|---|---|
| `/dev/socket/ueventd` | **YOK** |
| `/dev/ueventd` | **YOK** |
| tüm rc ağacında `socket ueventd` tanımı | **0** |
| `vold` ortamında `ANDROID_SOCKET_*` | **hiç yok** |
| `service vold` tanımı | `socket` satırı **yok** |
| `vold` dizelerinde | `Unable to bind uevent socket` |

`/dev/socket` yazılabilir (fifo ile doğrulandı) ve elle
`/dev/socket/ueventd` yaratmak işe yaramadı (vold kendi soketini
`unlink` + yeniden oluşturuyor).

**Bu bizi engellemiyor:** `/data`'yı zaten **kendimiz** gerçek `ext4`
bölümüne bağlıyoruz (vold olmadan da `lost+found`, `misc`, `system`,
`user_de` görünüyor).

**2) `audio_sa` — ashmem yok**

```
E ashmem: Unable to open ashmem device /dev/ashmem (No such file or directory)
F libc:   fmq/MessageQueueBase.h:610 assertion "mReadPtr is null" failed
```

`/proc/misc` içinde `ashmem` yok, `CONFIG_ASHMEM` de `.config`'da
**hiçbir yerde** geçmiyor. Nedeni: **Linux 6.6'da ashmem tamamen
kaldırıldı** (`drivers/staging/android/` dizini yok). Yerine
`CONFIG_MEMFD_CREATE=y` var ama vendor HAL'ı `/dev/ashmem` kullanıyor.

**Bu da bizi engellemiyor:** medya ses zinciri `system_server`'ın
parçası değil ve `system_server` zaten başlamıyor.

---

## 7. Projenin bugünkü hâli (2026-10-18)

### Kapatılan kilometre taşları

| Seviye | Ölçüt | Durum |
|---|---|---|
| L0 | Firmware çıkarıldı, bölümler doğrulandı | ✅ |
| L1 | Kernel + `init` ikinci aşama | ✅ |
| L2 | Bölümler + APEX, Huawei HAL'ları | ✅ |
| L3 | SELinux, `apexd` bağlanıyor | ✅ |
| L5 | `adb shell` root | ✅ **kalıcı** |
| L4 | AOSP `system_server` | ❌ **bu ROM'la ulaşılamaz** |

### Bu oturumda kapatılan 20 kök neden (hepsi ölçülerek)

| # | kök neden | düzeltme |
|---|---|---|
| 1–10 | `/system` symlink'i, `/linkerconfig` bind rec, `[vendor]` sistem yolu, config içeriği, `ro.hardware`, `setenv` kapsamı, `/data` sıfırlama, APEX yolları, `permitted.paths`, atomik `cp` | ✅ |
| 11 | `/system` symlink → **gerçek mount noktası** | ✅ `CANNOT LINK` 47→**0** |
| 12 | `/linkerconfig` ikinci kez mount | ✅ mount 2→1 |
| 13 | `[vendor]`'da sistem yolu yok | ✅ `vndservicemanager` running |
| 14 | config yamanın anına bağlıydı | ✅ idempotent |
| 15 | `/data` gerçek bölümü görmüyordu | ✅ **gerçek ext4** |
| 16 | `critical` satırı yorumlanmıyordu | ✅ |
| 17 | Çekirdekte `CONFIG_FTRACE` yok | ✅ **tracefs + 129 olay grubu** |
| 18 | `ro.ark.enable=0` denemesi | ✅ **geri alındı** |
| 19 | `/system/lib64/ark` config'te yok | ✅ 18/18 çözülüyor |
| 20 | Bellek yetersizliği varsayımı | ❌ **elenmiş** (4→8 GB, fark yok) |

### Neden L4 bu ROM'da kapanmıyor

`/system/bin/app_process64` **hiçbir sanal makine oluşturmuyor** —
ne ART (`libart.so`) ne Ark (`libarkruntime.so`).

`dlopen` izleyicisi (doğrulanmış araç) şunu gösteriyor:

```
=== dltrace yuklendi ===           (iki kez -> bir kez fork)
DLOPEN "libc.so"           x3 -> TAMAM
DLOPEN "libnetd_client.so" x2 -> TAMAM
DLOPEN "libiAwareSdkCore.so"   -> TAMAM
android_dlopen_ext            -> HİÇ ÇAĞRILMADI
libart.so / libarkruntime.so  -> YÜKLENMEDİ
191 benzersiz .so, içinde HİÇBİR VM kütüphanesi
```

AOSP'de `AndroidRuntime::startVm()` VM kütüphanesini **koşulsuz**
`android_dlopen_ext` ile yükler. Burada o çağrı hiç yapılmıyor —
**hiçbir şey başarısız olmuyor, sadece denenmiyor.**

### Önerilen sonraki adımlar

1. **Hedefi yeniden tanımla.** Bu firmware ile AOSP `system_server`
   çalıştırılamaz. Seçenekler:
   - HarmonyOS'un **kendi** Ark tabanlı framework'ünü hedef almak
     (`framework.abc` mevcut, 31 MB) — zygote yine de bu ikiliye bağlı
   - **Farklı firmware** denemek: NEXT (HarmonyOS 5/6) sürümlerinde
     de AOSP init/Zygote yok; ama EMUI 9/10 (Android 9/10) tabanlı
     bir firmware bu ikiliyi **stok** içerebilir
   - `app_process64`'ün **stok AOSP sürümünü** firmware'den çıkarıp
     denemek
2. Kapanış raporunu `L4-RAPORU.md` olarak yazmak
3. `scripts/` altındaki ~30 teşhis aracını temizlemek / belgelemek

### Eski teşhis notu (2026-10-15, artık geçersiz)

> `on post-fs-data` **bloke eden bir `exec`** içeriyor olmalı; AOSP'da
> `exec` komutu alt süreç bitene kadar init'i bekletir. İçindeki şüpheliler
> (Huawei `vdc` checkpoint çağrıları, `installkey`, `fsverity_init`,
`tzdatacheck`) sırayla ele alınacak.

**Ölçüm aracı (yapılacak):** denetleyicinin nabzında `/proc/*/stat`
`ppid==1` olan süreçleri `wchan` ile listelemek. `exec` takılı kaldığında
bekleyen alt sürecin adı doğrudan görünür — tahmin yürütmeden kök neden.
| L6 | Stage modeli / `Ability` yaşıyor | ⬜ |
| L7 | ArkUI ekran çiziyor, uygulama etkileşiyor | ⬜ |
| L8 | Tek tıkla çalışan paket | ⬜ |

L5'e gelindiğinde proje "HarmonyOS emülatörü" adını hak eder.
L7'ye gelindiğinde "çalıştırıyor" denebilir.

---

## 6. Hızlı kullanım (2026-10-16)

**Emülatörü başlat** (arka planda, 4 saat):
```bash
wsl -d Ubuntu -u root -- env TMO=14400 HEADLESS=1 \
  bash scripts/81-boot-zygote.sh
```

**L5'e bağlan ve komut çalıştır:**
```bash
scripts/adb.sh sh id                      # hemen çalıştır
scripts/adb.sh --wait 300 sh id            # hazır olana kadar bekle, çalıştır
scripts/adb.sh --status                   # bağlantı durumu
scripts/adb-test.sh                       # L5'in çalıştığını kanıtla
```

**Windows tarafından:**
```
adb connect 127.0.0.1:5555
adb shell
```

**Durdurmak:** `scripts/stop-emulator.sh` veya
`pkill -9 -f qemu-system-aarch64` (WSL'de).

**Canlı log:** `ls -t /tmp/harmony-emulator.*.log | head -1`

**Sadece kurmak (QEMU çalıştırmadan):** `NOQEMU=1 bash scripts/81-boot-zygote.sh`

---

## 7. NEXT modelleri (2026-10-16 incelemesi)

Downloads'ta 4 adet `update_full_base` paketi var — **dördü de NEXT** ve
**hiçbiri NOH-AN00 değil**:

| Paket | Sürüm | HarmonyOS | Cihaz | SoC |
|---|---|---|---|---|
| `update_full_base.zip` | CLS-LGRP1 205.0.0.135(SP6) | 5.0 | Mate 40 Pro 4G (CLS-AL00/AL30) | **Kirin 990** |
| `(1).zip` | ALN-LGRP1 206.0.0.108(SP6) | 5.0 | nova 7/8/9 | Kirin 8100 |
| `(2).zip` | PLA-LGRP1 205.0.0.113(SP6) | 5.0 | Pura 70 | Kirin 9000S |
| `(3).zip` | SGT-LGRP3 206.1.0.105(SP52) | 6.0 | Mate 80 | Kirin 9010 (Ascend) |

- Paketler **yapısal olarak sağlam** (zip bütünlüğü doğru, iç listeleri okunuyor).
- `SGT` paketinin `update.bin` başlığında **`OpenHarmony 3.2.6.1`** yazıyor.
- Sürüm kodunun ilk üç hanesi HarmonyOS ana sürümünü verir
  (`205.x` = 5.0, `206.1` = 6.0).
- **`board_list` üçünde de aynı ve şüpheli**: `HI3516. / HI3518. / HI3559.`
  — Kirin 990 için `hi3660` beklenirdi. Muhtemelen yeniden paketlenmiş.

**Donanım yakınlığı:** CLS-AL30 (Kirin 990) NOH ile **aynı aile** — işlemciyi
ayrı yapmak gereken tek model. Diğerleri uzak/orta.

**NEXT'te ne yok:** AOSP `init`, Zygote, SystemServer, APEX, `adb`, Binder
zinciri. Bu yüzden **"çalışabilir arayüz" hedefi NEXT'te tutarsız** —
`adb shell` yok. NEXT ancak **imaj okuma/analiz** hedefi olarak kullanılabilir.

**Bugün elimizdeki tek NOH paketi** `NOH-AN00 … HarmonyOS 3.0.0` — yani
üzerinde çalıştığımız Android-12 tabanlı firmware.