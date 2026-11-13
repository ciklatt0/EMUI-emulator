# HarmonyOS NOH-AN00 Emülatör — Kapanış Raporu

**Tarih:** 2026-10-18
**Firmware:** Huawei Mate 40 Pro (NOH-AN00), HarmonyOS 3.0 / Android 12
**Yaklaşım:** QEMU (TCG, aarch64) + özel kernel + elle kurulan boot zinciri

---

## 1. Ne başardık

| Seviye | Ölçüt | Durum |
|---|---|---|
| L0 | Firmware çıkarıldı, 29 bölüm doğrulandı | ✅ |
| L1 | Kernel + `init` ikinci aşama | ✅ |
| L2 | Bölümler + 23 APEX, Huawei HAL'ları | ✅ |
| L3 | SELinux politikası, `apexd` bağlanıyor | ✅ |
| L5 | **`adb shell` root erişimi** | ✅ **kalıcı** |
| L4 | AOSP `system_server` | ❌ **bu ROM'la ulaşılamaz** |

```console
$ adb connect 127.0.0.1:5555
connected to 127.0.0.1:5555
$ adb shell id
uid=0(root) gid=0(root) groups=(0,1004,1007,1011,...,3011)
context=u:r:kernel:s0
```

**Çalışan servisler: 27** · `CANNOT LINK`: **0** · `/data`: gerçek `ext4`

---

## 2. Kapatılan 20 kök neden

Hepsi **ölçülerek** bulundu; tahmin yürütülmedi. Kısa liste:

| # | Sorun | Çözüm |
|---|---|---|
| 1 | `/system` bir **symlink** → ikililer `/r/system/bin/...` yolunda çalışıyor, linker config **hiçbir bölümle eşleşmiyor** | `/init` içinde gerçek mount noktası (`mount -o bind`) |
| 2 | `/linkerconfig` **iki kez** mount ediliyordu (`bind rec`, özyinelemeli) | satır iptal |
| 3 | `[vendor]` bölümünde sistem yolu yok → `liblog.so` bulunamıyor | `/system/${LIB}` eklendi |
| 4 | Config içeriği **yamanın anına** bağlıydı (ART yolları eksikti) | her turda monteli APEX ile karşılaştır, idempotent yeniden üret |
| 5 | `/data` **gerçek bölümü hiç görmüyordu** (geçici tmpfs) | supervisor döngüsüne taşındı |
| 6 | `critical` kuralı satırı **yorumlamıyordu** | gerçek yorumlama |
| 7 | Çekirdekte `# CONFIG_FTRACE is not set` → tracefs yok | `TRACING/FTRACE/TRACE_FS` eklendi, kernel yeniden derlendi |
| 8 | `/system/lib64/ark` linker config'te **yoktu** | `search.paths` + `permitted.paths` |
| 9 | `ro.hardware` dosyalarda yok → donanım rc ağacı hiç yüklenmiyordu | diskten türetildi |
| 10 | `setenv` servis bloğunda değil, **on** aksiyonunda çalışıyordu | düzeltildi |

*(tam liste ve kanıtlar: `PLAN.md`)*

---

## 3. L4 neden kapanmıyor

### Ölçüm aracı

`scripts/dltrace.c` — NDK'siz derlenen 68 KB'lık bir `LD_PRELOAD`
kütüphanesi (`DT_NEEDED=0`). `dlopen`, `android_dlopen_ext` ve
`android_dlopen_ext_namespace` çağrılarını yakalar; gerçek olanı
`dlsym(RTLD_NEXT, …)` ile çağırır.

```bash
aarch64-linux-gnu-gcc -shared -fPIC -nostdlib -O2 \
    -o dltrace.so dltrace.c
```

### Ölçüm (doğrulanmış araç, gerçek Ark yolundan)

`init.environ.rc`'ye eklenen `arkprobe` servisi, `init.arkinit.rc`'deki
`arkinit` tanımının **birebir kopyası** + `LD_PRELOAD`. `Runtime type:
ark runtime = 1` doğrulandı — gerçekten Ark yolundaydı.

```
=== dltrace yuklendi ===              (iki kez → bir kez fork)
DLOPEN "libc.so"              x3  -> TAMAM
DLOPEN "libnetd_client.so"    x2  -> TAMAM
DLOPEN "libiAwareSdkCore.so"       -> TAMAM
android_dlopen_ext                -> HİÇ ÇAĞRILMADI
libart.so                         -> YÜKLENMEDİ
libarkruntime.so                  -> YÜKLENMEDİ
191 benzersiz .so, içinde HİÇBİR VM kütüphanesi
```

Aynı sonuç ART yolunda da (elle çalıştırılan `app_process64`):
10 `dlopen`, 0 başarısız, hiçbiri `libart` için.

### Yorum

AOSP'de `AndroidRuntime::startVm()` VM kütüphanesini **koşulsuz**
`android_dlopen_ext` ile yükler. Burada:

- çağrı **hiç yapılmıyor**
- hiçbir `dlopen` **başarısız olmuyor**
- 191 kütüphane yükleniyor ama içinde **hiçbir VM kütüphanesi yok**

**Yani bir şey denemekten vazgeçiyor; başarısız olmuyor.**

### Neden bu ikili

| kanıt | değer |
|---|---|
| `service zygote` | `/system/bin/app_process64 -Xzygote … --zygote` |
| `service arkinit` | `/system/bin/app_process64 -Xzygote … --zygote` |
| `/apex/com.android.art/bin/` | `dalvikvm, dex2oat, dexdump…` — **`app_process` YOK** (stok AOSP'de var) |
| `/system/bin/app_process64` | **16 KB** (stok zygote ikilisi çok daha büyük) |
| `/system/lib64/ark/` | `libarkruntime.so` 5.4 MB + tam yığın — **VAR** |
| `/system/framework/*.abc` | **64 adet**, `framework.abc` 31 MB — **VAR** |

HarmonyOS'ta zygote rolünü **Ark VM** oynuyor; AOSP `app_process`'i
genel bir Java başlatıcısı olarak kalıyor ve **VM oluşturma yolu
bu derlemede yok**.

---

## 4. Elenen 15 varsayım

| # | Varsayım | Neden elendi |
|---|---|---|
| 1 | `libzygote.so` eksik | Android 12'de **statik** kütüphane |
| 2 | `permitted.paths` beyaz listesi | `art/lib64` her iki listede de var |
| 3 | Eksik `NEEDED` bağımlılığı | 31/31 bulunabiliyor |
| 4 | `bootclasspath.pb` eksik yol | 7/7 yol diskte var |
| 5 | Ark politikası (`persist.*`) | tek tek kapatıldı, **birebir aynı** |
| 6 | linkerconfig kaybolması | mount=1, uyarı=0 |
| 7 | `/data/dalvik-cache` yok | var ve yazılabilir |
| 8 | `/dev/socket/arkinit` yok | mevcut |
| 9 | `ro.dalvik.vm.library` bayat | boş → varsayılan |
| 10 | `LD_PRELOAD` ile zorlama | hiçbir fark yok |
| 11 | tracefs eksik | **düzeltildi**, tek başına açıklama değil |
| 12 | `/data` geçici tmpfs | **düzeltildi** (gerçek ext4) |
| 13 | `/system/lib64/ark` config'te yok | **düzeltildi** (18/18 çözülüyor) |
| 14 | `libartbased.so` eksik | ROM'da hiç yok; zaten Ark yolunda da kullanılmıyor |
| 15 | Bellek yetersiz (4 GB) | `-m 8192`: `VmRSS` **38 MB**, sonuç **aynı** |

---

## 5. Ölçüm aracı geliştirme — kendi hatalarımız

Kural: **her ölçümden önce aracın sağlamlığını kanıtla.**

Bu oturumda **3 kez** araç hatası bulundu ve düzeltildi:

1. **`putn(path, 0)`** → 0 bayt yazıyordu; yollar hiç görünmüyordu.
   Çıktıdaki `dlopen("")` yolun **boş** olduğu anlamına gelmiyordu.
2. **`stdio_to_kmsg`** init servislerinin stderr'ını seri loga
   **düşürmüyordu** (`dltrace.so` haritada 7 map satırıyla vardı,
   ama çıktı yoktu). → doğrudan `/data/dltrace.log`'a yazma.
3. **`/bb/` altından `LD_PRELOAD`** boş namespace'e düşüyor
   (`libnativeloader.so not found`) → `/data` kullanılıyor.

Ayrıca daha önce öğrenilen tuzaklar: `ps` PID 1. sütunda;
`init.svc.X=running` **bayat olabilir** (`/proc/<pid>/stat` 3. alan);
`kill -0` **zombiye de** başarılı; `&` + `$!` busybox `timeout`'un
PID'sini verir.

---

## 6. Bilinen, engel olmayan sorunlar

| sorun | ölçüm | neden önemsiz |
|---|---|---|
| `vold` → `sBlkidContext != nullptr` | `/dev/socket/ueventd` yok, `socket ueventd` tanımı **0**, vold ortamında `ANDROID_SOCKET_*` yok | `/data`'yı **kendimiz** bağlıyoruz |
| `audio_sa` → ashmem yok | `/proc/misc`'te yok, `CONFIG_ASHMEM` **yok**; Linux 6.6'da ashmem **kaldırılmış** | ses zinciri `system_server`'ın parçası değil |

---

## 7. Önerilen sonraki adımlar

Bu firmware ile AOSP `system_server` **çalıştırılamaz**. Seçenekler:

1. **Hedefi yeniden tanımla**
   - HarmonyOS'un kendi **Ark tabanlı** framework'ünü hedef almak
     (`framework.abc` mevcut, 31 MB) — ama zygote yine bu ikiliye bağlı
   - **Farklı firmware**: EMUI 9/10 (Android 9/10) tabanlı bir
     firmware'de **stok** `app_process` bulunma ihtimali yüksek
   - Mümkünse firmware'den **stok AOSP `app_process64`** çıkarıp
     `/system/bin`'e koymak ve `service zygote`'u ona yönlendirmek
2. `vold` için `socket ueventd seqpacket` tanımını `rclog`'a ekle
   (denendi, işe yaramadı — kaynak analizi gerekiyor)
3. `scripts/` altındaki ~30 teşhis aracını belgele/temizle

---

## 8. Nasıl çalıştırılır

```bash
# Emülatörü başlat (arka planda)
wsl -d Ubuntu -u root -- env TMO=21600 HEADLESS=1 \
  bash scripts/81-boot-zygote.sh

# L5'e bağlan
scripts/adb-test.sh                       # L5'in çalıştığını kanıtlar
scripts/adb.sh sh id                      # doğrudan komut

# Durdurmak
scripts/_reset-qemu.sh
```

> **Kural:** `81-boot-zygote.sh` **koşu sırasında ASLA düzenlenmemeli** —
> bash dosyayı satır satır okur ve bozulma yaşanır. Önce
> `_reset-qemu.sh` çalıştır, sonra düzenle.