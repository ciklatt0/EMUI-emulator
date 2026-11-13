#!/bin/bash
# ARK_RUNTIME ortam degiskeni tek basina yetmiyor: 7 dlopen
# cagrisi, hicbiri ark icin. Demek Ark runtime DT_NEEDED ile
# yukleniyor ya da baska bir yoldan. Iki sey olcuyoruz:
#  A) app_process64'in yukledigi Huawei kutuphanelerinin DT_NEEDED'inde
#     ark var mi?
#  B) init'in baslattigi GERCEK arkinit haritasinda ark var mi?
#     (surec cok kisa yasadigi icin agresif yoklama gerekiyor)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== A) Huawei kutuphanelerinin DT_NEEDED'inde ark/libarkruntime var MI ==="
A 'for L in libiAwareSdkCore.so libwilhelm.so libandroid_runtime.so libhwcust_init.so; do
   P=$(find /system/lib64 /vendor/lib64 -maxdepth 1 -name "$L" 2>/dev/null | head -1)
   [ -n "$P" ] || { echo "  $L: bulunamadi"; continue; }
   N=$(/system/bin/toybox readelf -d "$P" 2>/dev/null | grep NEEDED | grep -ciE "ark|panda")
   echo "  $L ($P): ark/panda bagimliligi = $N"
   [ "$N" -gt 0 ] && /system/bin/toybox readelf -d "$P" 2>/dev/null | grep NEEDED | grep -iE "ark|panda" | head -4
 done'
echo ""
echo "=== A2) libarkruntime.so'yu kim NEEDED ediyor (ters arama) ==="
A 'for d in /system/lib64 /system/lib64/ark /vendor/lib64; do
   for f in $d/*.so; do
     [ -f "$f" ] || continue
     if /system/bin/toybox readelf -d "$f" 2>/dev/null | grep -q "libarkruntime.so"; then
       echo "  $f  -> libarkruntime.so"
     fi
   done
 done 2>/dev/null | head -10
   echo "  (bos = kimse DT_NEEDED ile istemiyor)"'
echo ""
echo "=== B) GERCEK arkinit haritasinda ark var MI (agresif yoklama) ==="
A 'i=0; found=0
while [ $i -lt 60 ]; do
  P=$(getprop init.svc_debug_pid.arkinit 2>/dev/null)
  if [ -n "$P" ] && [ -d /proc/$P ] && [ -n "$(readlink /proc/$P/exe 2>/dev/null)" ]; then
    N=$(grep -c . /proc/$P/maps 2>/dev/null)
    if [ "${N:-0}" -gt 200 ]; then
      echo "  arkinit pid=$P state=$(awk "{print \$3}" /proc/$P/stat) maps=$N"
      echo "  libark=$(grep -c libark /proc/$P/maps 2>/dev/null) libart=$(grep -c libart /proc/$P/maps 2>/dev/null)"
      echo "  --- ark kutuphaneleri:"
      grep -oE "/[a-zA-Z0-9./_]*ark[a-zA-Z0-9._]*\.so" /proc/$P/maps 2>/dev/null | sort -u | head -8
      echo "  --- ORTAM:"
      tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "ARK|ANDROID" | sed "s/^/    /" | head -8
      found=1; break
    fi
  fi
  i=$((i+1)); /bb/sleep 0.15
done
[ $found -eq 0 ] && echo "  arkinit 9 sn boyunca YAKALANAMADI (cok kisa yasiyor)"'