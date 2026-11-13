with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# 1. propof fonksiyonuna ro.serialno ekle
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

# 2. awk'de ro.serialno degiskenini de coz
old_awk = '    if (ZYG != "") { gsub(/[$][{]ro\\.zygote[}]/, ZYG, ln) }\n    if (HW  != "") { gsub(/[$][{]ro\\.hardware[}]/, HW, ln) }'

new_awk = '    if (ZYG != "") { gsub(/[$][{]ro\\.zygote[}]/, ZYG, ln) }\n    if (HW  != "") { gsub(/[$][{]ro\\.hardware[}]/, HW, ln) }\n    if (SR != "") { gsub(/[$][{]ro\\.serialno[}]/, SR, ln) }'

if old_awk in c:
    c = c.replace(old_awk, new_awk, 1)
    print('awk cozumleme duzenlendi')
else:
    print('HATA: awk cozumleme bulunamadi')

# 3. RO_SERIALNO degiskenini tanimla
old_vars = 'RO_ZYG=$(propof ro.zygote)\nRO_HW=$(propof ro.hardware)'

new_vars = 'RO_ZYG=$(propof ro.zygote)\nRO_HW=$(propof ro.hardware)\nRO_SR=$(propof ro.serialno)'

if old_vars in c:
    c = c.replace(old_vars, new_vars, 1)
    print('degisken tanimlandi')
else:
    print('HATA: degiskenler bulunamadi')

# 4. awk cagirisina SR parametresi ekle
old_call = "/bb/awk -v OVL=\"$OVL\" -v SRC=\"$SRC\" -v ZYG=\"$RO_ZYG\" -v HW=\"$RO_HW' '"
new_call = "/bb/awk -v OVL=\"$OVL\" -v SRC=\"$SRC\" -v ZYG=\"$RO_ZYG\" -v HW=\"$RO_HW\" -v SR=\"$RO_SR' '"

if old_call in c:
    c = c.replace(old_call, new_call, 1)
    print('awk parametresi eklendi')
else:
    print('HATA: awk cagrisi bulunamadi')
    import re
    matches = re.findall(r"awk -v.*ZYG.*HW.*'$", c)
    for m in matches[:3]:
        print(f'  Bulunan: {m[:120]}')

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')

