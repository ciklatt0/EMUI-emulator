# HarmonyOS Emulator (EVR-L29 / EMUI 9-10)

Running Huawei P30 lite (EVR-L29) firmware — **EMUI 9/10 (Android 10, SDK 29)** — on an emulator under QEMU TCG (aarch64).

> **What is running:** EMUI 9/10 firmware, based on **Android 10 (AOSP)**. Zygote, SystemServer, ART, `com.android.*` APEX modules, Huawei HALs, EMUI framework. This is "Android 10 + EMUI skin" emulation.
>
> **What is NOT being done:** Virtual machine, kernel boot chain, bootloader, AVB. All disabled. QEMU runs as **full system emulation**: our own kernel + real partitions.

---

## Quick Start

```cmd
REM one-click (Windows)
start-emulator.cmd    # launches QEMU in a terminal window
stop-emulator.cmd     # stops, archives log, prints run summary
```

```bash
# manual (WSL)
bash scripts/60-extract-partitions-evr.py   # extract partitions from UPDATE.APP
bash scripts/80-build-bootdisk-evr.sh       # GPT + 29-partition disk image
bash scripts/81-boot-zygote-evr.sh          # initramfs + run QEMU (EVR-L29)

HEADLESS=1 bash scripts/81-boot-zygote-evr.sh   # run without window (for diagnosis)
NOQEMU=1   bash scripts/81-boot-zygote-evr.sh   # build only, do not run QEMU

bash scripts/verify_evr.py                    # verify extracted partitions
```

> **WSL2 note:** When the session ends the VM stops and mounts under `/root/harmony-build` are lost. Scripts detect this and rebuild the tree.

---

## Current Status

L4 (Zygote + SystemServer) is now **working** on EVR-L29.

| Level | Criterion | Status |
|-------|-----------|--------|
| L0 | Firmware extracted, 5/5 partitions verified | ✅ |
| L1 | Kernel + Android `init` boots, reaches second stage | ✅ |
| L2 | Partitions + 23 APEX mounted, ~50 Kirin HALs running | ✅ |
| L3 | `apexd-bootstrap` cleanly exits | ✅ |
| L4 | `servicemanager` + **Zygote** + **SystemServer** running | ✅ |
| L5 | `adb shell` into HarmonyOS | ⬜ |
| L6 | Stage model / `Ability` running | ⬜ |
| L7 | ArkUI renders, app interaction | ⬜ |
| L8 | One-click runnable package | ⬜ |

**Last run** (`logs/boot-zygote-evr.log`): 5/5 EROFS + 23 APEX mounts, SELinux policy compiled and loaded, `init` reached second stage, Zygote started (socket created), SystemServer started (HAL services launching), 300+ seconds uptime before watchdog.

**Remaining issue:** Huawei `hw_init` watchdog (`InitProcessWatchdog_UserStack`) kills init at ~302 s with `Attempted to kill init`. This is post-L4 stability, not an L4 blocker.

Detailed diagnosis and roadmap: **[PLAN.md](PLAN.md)**

---

## What Was Fixed (EVR-L29)

1. **Linker config (`ld.config.txt`)** — Generated with APEX paths *before* `exec /system/bin/init`, preventing `library "libc.so" not found` for early services.
2. **Root-level rc files** — `init.rc`, `ueventd.rc`, `init.zygote64_32.rc` copied from system image to initramfs root; `critical`, `shutdown critical`, `exec_start apexd-bootstrap`, `start vold`, `exec vdc checkpoint` commented out.
3. **`init.environ.rc`** — Copied to initramfs root; `ANDROID_DATA=/data`, `ANDROID_ROOT=/system`, `ANDROID_STORAGE=/data` added globally.
4. **Zygote environment** — `ANDROID_DATA`, `ANDROID_ROOT`, `ANDROID_RUNTIME_ROOT`, `ANDROID_TZDATA_ROOT`, `ANDROID_IOTA_ROOT` added to `init.zygote64_32.rc`.
5. **Critical flags removed** — From all root-level rc files so a crashing service does not kill init (`Attempted to kill init`).
6. **Kernel command line** — `androidboot.zygote=zygote64_32` added; `ro.zygote` hardcoded (not present in EVR-L29 build.prop files).
7. **`fix_ldconfig()` / `ensure_ldconfig_final()`** — Rewritten with clean shell syntax (no broken brace blocks).
8. **`start-emulator.cmd`** — Fixed to point to `/root/harmony-build/scripts/81-boot-zygote-evr.sh` inside WSL.

---

## The Problem Shape

Firmware contains **two separate layers** and today's most expensive error sits at their **boundary**:

```
/apex/<module>   ←  we bind-mount it            ←  filesystem ready, working
      ↑
apexd            ←  keeps its own database      empty, 0 packages
      ↑
libc.so → /apex/com.android.runtime/lib64/bionic/libc.so   resolved
```

`apexd` really mounts `/system/apex/*.apex` archives itself via loop device. We skip that step and write payloads directly into partitions. The filesystem works so `libc.so` resolves, but apexd's database stays empty:

```
apexd: Populating APEX database from mounts...
apexd: 0 packages restored.
```

This is not a settings error — it's an **architectural mismatch**. Fix prepared: `scripts/72-extract-apex-files.sh` extracts the original 22 `.apex` archives from firmware, `80-build-bootdisk-evr.sh` writes them to the `apexfiles` partition, `81-boot-zygote-evr.sh` bind-mounts onto `/system/apex`.

---

## Three Silent Errors (easy to repeat, hard to find)

All share the same shape: **a wrong format assumption, and the error silently goes somewhere else.**

**1. Sparse chunk offset drift.** In chunks, file position and post-data position must be advanced *separately*. Otherwise 12 bytes drift per chunk (4.6 KB over 387 chunks) and `super` computes wrong size.

**2. UTF-16 assumption.** `LpMetadataPartition.name` is **36 bytes plain ASCII**, not 72-byte UTF-16. It didn't just corrupt names; because of the shift, extent indexes also shifted 36 bytes, and all sizes came out `0.000 GB`.

**3. Struct alignment padding.** `LpMetadataExtent`: `num_sectors:u64, target_type:u32, <4 bytes padding>, target_data:u64`. Python `struct` does not insert padding; `target_data` starts at **offset 12**. Reading at offset 8 silently returns wrong values (16 instead of 4096).

---

## Four Structural Traps

- **`file` says APEX payload is "ext2", but `mount -t ext2` fails.** ext4 is backward compatible; but the kernel's ext2 driver rejects it. Use `-t ext4`.
- **`/system/lib64/ld-android.so` is a stub** (9392 bytes, 0644). Real linker is `/system/bin/linker64` → symlink → `/apex/com.android.runtime/bin/linker64`. **No HarmonyOS binary runs without APEX mounted.**
- **`/lib` and `/lib64` are separate.** glibc's `ld.so` searches `/lib` first; if both are mounted you get `wrong ELF class: ELFCLASS32`.
- **`ld.config.txt` is sectioned** (`[legacy]` and `[postinstall]`); both define `namespace.default.search.paths`. If APEX paths are appended with `tail -1` they fall into `[postinstall]` and have no effect. Correct rule: **last `search.paths` *before* the first `asan` line.** Without this fix: 9/17 resolved; after: **17/17**.

---

## How `vendor` Was Found

`super` LP metadata shows `vendor` at 5.705 GB, but in `super.raw` that region was **unprocessed slack** (6.81 GB virtual, 4.71 GB data).

Fix: inside `UPDATE.APP` there are **two sparse bodies of the same logical super**:

```
body 1  3.821 GB raw  ->  virtual 0 … ~4.7 GB
body 2  2.100 GB raw  ->  virtual ~5.05 … 6.4 GB
```

Mounting the second over the first (`67-merge-super-evr.py`) filled the 1.711 GB gap and valid EROFS appeared in `vendor`/`odm`. Rule: in `super.raw`, do not touch where data **exists**, only fill empty parts.

Without this, Zygote is impossible — Kirin HALs live in `vendor`.

---

## File Layout

```
scripts/
  60-extract-partitions-evr.py   UPDATE.APP -> super.raw -> partitions (EVR-L29)
  80-build-bootdisk-evr.sh       GPT + 29-partition disk image (EVR-L29)
  81-boot-zygote-evr.sh          <<< MAIN PATH: init -> apexd -> Zygote (EVR-L29)
  verify_evr.py                  partition verification (EVR-L29)
  81-boot-zygote.sh              NOH-AN00 (Android 12) baseline (kept for reference)
  80-build-bootdisk.sh           NOH disk builder (kept for reference)
  ...
  10-fetch-kernel.sh             arm64 kernel download
  20-build-busybox.sh            static busybox cross-compile
  30-make-initramfs.sh           initramfs (legacy path)
  72-extract-apex-files.sh       extract original .apex archives (Phase 2.1)
  80-build-kernel.sh             custom kernel (EROFS/virtio/binder/SELinux)
  91-log-summary.sh              <<< run summary (7000 lines -> 15 lines)
  110-harmony-shell.sh           <<< HarmonyOS shell inside chroot (working)
  120/121/131/140-*.py           inventory + API extraction
  130-lib-proof.c/.sh            NDK call to Huawei library

analysis/
  huawei-libraries.txt      Huawei libraries
  library-index.tsv         full index of 2710 libraries
  binary-deps.tsv           binary -> dependency
  huawei-native-api.txt     2.75 MB API surface (demangled)   [generated]
  huawei-java-api.txt       11 MB Java API                      [generated]
  java-api-all.txt          38 MB all Java API                  [generated]
```

---

## Verified Inventory

| | |
|---|---|
| **Extracted partitions** | 5/5 EROFS — system, hw_product, vendor, odm, cust |
| Native libraries | 1296 (`lib64`) + 744 (`lib`) + 601 (APEX) = **2641** |
| Java framework | 115 `.jar` → 109 DEX resolved, 0 errors |
| Total classes | **75,491** (Huawei/OHOS: **25,171**) |
| Native API surface | **39,476** exported symbols |
| Java API surface | 209,288 lines |
| Linkable Huawei binaries | **17 / 17** |

Key libraries:

```
libace.z.so                       15.4 MB   ArkUI/ArkTS engine (ACE)
libhwui.so                        14.8 MB   Huawei HWUI
libace_engine_declarative_ark.z.so 3.1 MB   ArkTS declarative engine
libace_engine_qjs.z.so             2.5 MB   QuickJS engine
libHwServant.so                    2.6 MB   Huawei IPC
libhwsqlite_jni.so                 942 KB   SQLite wrapper
libhwkeystore_jni.so               702 KB   Keystore
```

---

## Android NDK (for library calls)

`/root/harmony-build/ndk/android-ndk-r26d` (API 21–34). Target API **31**.

A program compiled against glibc cannot `dlopen` a Bionic library: glibc's `ld.so` cannot correctly load Bionic ELF (different `init_array`, different TLS, different versioning) and the process dies with `SIGTRAP`. Android libraries can only be loaded by Android's own linker (`linker64`).

```bash
clang --target=aarch64-linux-android31 --sysroot=$SYSROOT \
      -O2 -o libproof scripts/130-lib-proof.c -ldl
bash scripts/130-lib-proof.sh
```

**Result:** 5/10 Huawei libraries load; one function inside `libhwsqlite_jni.so` is actually called. The rest are blocked by two obstacles:

1. **Missing `DT_NEEDED` declarations.** `libandroid_runtime.so` references `register_android_functions` but the definition is in Huawei's `libhwsqlite_jni.so` and undeclared. `130-lib-proof.c` contains an automatic dependency resolver (`dlopen` error -> symbol lookup in `dynsym`). Preloading everything **does not work**: `libbinder.so`/`libsqlite.so` constructors crash in an independent environment.
2. **Runtime dependency.** Some symbols are registered by ART at runtime; they do not exist without Zygote and SystemServer running. Structural limitation, not a settings error.

---

## Version Control

`git init` performed. `.gitattributes` pins all `.sh` files to **LF** — CRLF breaks bash (`exec: /init\r: not found`).

Disk image (`/root/harmony-build/evr-boot/system-disk.img`, 8.6 GB) is **not** in the repo; regenerate with `80-build-bootdisk-evr.sh`.