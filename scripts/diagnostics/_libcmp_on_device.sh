#!/bin/sh
echo "=== 1) /apex/com.android.art/lib64 (ilk 40) ==="
ls /apex/com.android.art/lib64/ 2>&1 | head -40
echo ""
echo "=== 2) Karsilastirma ==="
for f in libart.so libartbase.so libartpalette.so libnativehelper.so \
         libandroid_runtime.so libbase.so libcutils.so libdl.so liblog.so \
         libicu.so libunwind.so libsigchain.so libbacktrace.so; do
  if [ -e "/apex/com.android.art/lib64/$f" ]; then
    apex="VAR"
  else
    apex="YOK"
  fi
  if [ -e "/system/lib64/$f" ]; then
    sys="VAR"
  else
    sys="YOK"
  fi
  echo "  $f: apex=$apex system=$sys"
done
echo ""
echo "=== 3) Eksik olanlar (apex'te var, system'de yok) ==="
for f in $(ls /apex/com.android.art/lib64/ 2>/dev/null); do
  if [ ! -e "/system/lib64/$f" ]; then
    echo "  EKSIK: $f"
  fi
done | head -40
echo "  (bitis)"
