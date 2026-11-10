with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# propof'e ro.serialno ekle (dogru metin ile)
old_propof = '''  if [ "$1" = "ro.hardware" ]; then
    for f in /vendor/etc/init/hw/init.*.rc; do
      [ -f "$f" ] || continue
      b=${f##*/}; b=${b#init.}; b=${b%.rc}
      [ "$b" = "zygote32" ] && continue
      echo "$b"; return 0
    done
  fi
  return 1
}'''

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
  return 1
}'''

if old_propof in c:
    c = c.replace(old_propof, new_propof, 1)
    print('propof duzenlendi')
else:
    print('HATA: propof bulunamadi')
    # Debug: show what we have around return 1
    idx = c.find('return 1')
    if idx != -1:
        print(f'  Context around return 1: {repr(c[idx-50:idx+10])}')

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')

