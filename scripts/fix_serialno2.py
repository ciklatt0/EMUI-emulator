with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# 1. propof'e ro.serialno ekle (ro.hardware block'unun sonuna)
old_propof = '''  if [ "$1" = "ro.hardware" ]; then
    for f in /vendor/etc/init/hw/init.*.rc; do
      [ -f "$f" ] || continue
      b=${f##*/}; b=${b#init.}; b=${b%.rc}
      [ "$b" = "zygote32" ] && continue
      echo "$b"; return 0
    done
  fi
  return 1}'''

new_propof = '''  if [ "$1" = "ro.hardware" ]; then
    for f in /vendor/etc/init/hw/init.*.rc; do
      [ -f "$f" ] || continue
      b=${f##*/}; b=${b#init.}; b=${b%.rc}
      [ "$b" = "zygote32" ] && continue
      echo "$b"; return 0
    done
  fi
  if [ "$1" = "ro.serialno" ]; then
    echo "unknown"; return 0
  fi
  return 1}'''

if old_propof in c:
    c = c.replace(old_propof, new_propof, 1)
    print('propof duzenlendi')
else:
    print('HATA: propof bulunamadi')

# 2. awk'de ro.serialno cozumlemesi ekle
old_awk_subst = '    if (ZYG != "") { gsub(/[$][{]ro\\.zygote[}]/, ZYG, ln) }\n    if (HW  != "") { gsub(/[$][{]ro\\.hardware[}]/, HW, ln) }'

new_awk_subst = '    if (ZYG != "") { gsub(/[$][{]ro\\.zygote[}]/, ZYG, ln) }\n    if (HW  != "") { gsub(/[$][{]ro\\.hardware[}]/, HW, ln) }\n    if (SR  != "") { gsub(/[$][{]ro\\.serialno[}]/, SR, ln) }'

if old_awk_subst in c:
    c = c.replace(old_awk_subst, new_awk_subst, 1)
    print('awk cozumleme eklendi')
else:
    print('HATA: awk cozumleme bulunamadi')

# 3. awk cagrisina SR parametresi ekle
old_call = 'awk -v OVL="$OVL" -v SRC="$SRC" -v ZYG="$RO_ZYG" -v HW="$RO_HW" \''
new_call = 'awk -v OVL="$OVL" -v SRC="$SRC" -v ZYG="$RO_ZYG" -v HW="$RO_HW" -v SR="$RO_SR" \''

if old_call in c:
    c = c.replace(old_call, new_call, 1)
    print('awk cagrisi guncellendi')
else:
    print('HATA: awk cagrisi bulunamadi')

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')

