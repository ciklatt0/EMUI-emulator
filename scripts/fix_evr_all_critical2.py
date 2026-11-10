with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add critical removal from ALL rc files after the umount/fi block
old = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: Zygote servisine ANDROID_DATA etc. ortam degiskenleri ekle.'''

new = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: TUM root-seviye rc dosyalarindaki critical bayragini kaldir
# (init paniğini önler - servis coksa init vazgeçmez)
for rcfile in "$ROOT"/init*.rc "$ROOT"/ueventd*.rc; do
  [ -f "$rcfile" ] || continue
  sed -i 's/^    critical$/    # critical/' "$rcfile" 2>/dev/null
  sed -i 's/^    shutdown critical$/    # shutdown critical/' "$rcfile" 2>/dev/null
done
echo "### EVR-L29: critical bayragi tum rc dosyalardan kaldirildi ###"

# EVR-L29: Zygote servisine ANDROID_DATA etc. ortam degiskenleri ekle.'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('Critical removal from all rc files added')
else:
    print('ERROR: Pattern not found')
    # Debug
    idx = c.find('Zygote servisine ANDROID_DATA')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')