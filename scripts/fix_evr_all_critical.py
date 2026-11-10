with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# After all rc file patching, add a final pass to remove 'critical' from ALL services
# in ALL rc files in initramfs root (not just init.rc and ueventd.rc)
old = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: ANDROID_DATA env degiskenleri ekle'''

new = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: TUM rc dosyalarindaki critical bayragini kaldir (init paniğini önler)
# init.rc, ueventd.rc, init.zygote64_32.rc ve diger root-seviye rc dosyalari
for rcfile in "$ROOT"/init*.rc "$ROOT"/ueventd*.rc; do
  [ -f "$rcfile" ] || continue
  sed -i 's/^    critical$/    # critical/' "$rcfile" 2>/dev/null
  sed -i 's/^    shutdown critical$/    # shutdown critical/' "$rcfile" 2>/dev/null
done
echo "### EVR-L29: critical bayragi tum rc dosyalardan kaldirildi ###"

# EVR-L29: ANDROID_DATA env degiskenleri ekle'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('Critical removal from all rc files added')
else:
    print('ERROR: Pattern not found')
    idx = c.find('umount /tmp/sys-mnt-evr')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+300])}')