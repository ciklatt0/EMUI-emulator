with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# After root-level rc file copy and patch, add ANDROID_DATA env vars to zygote service
old = '''  # init.environ.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.environ.rc ]; then
    cp /tmp/sys-mnt-evr/init.environ.rc "$ROOT/init.environ.rc" 2>/dev/null
    echo "### EVR-L29: init.environ.rc kopyalandi initramfs kokuya ###"
  fi
  umount /tmp/sys-mnt-evr 2>/dev/null
fi
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali:'''

new = '''  # init.environ.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.environ.rc ]; then
    cp /tmp/sys-mnt-evr/init.environ.rc "$ROOT/init.environ.rc" 2>/dev/null
    echo "### EVR-L29: init.environ.rc kopyalandi initramfs kokuya ###"
  fi
  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: Zygote servisine ANDROID_DATA etc. ortam degiskenleri ekle.
# Zygote, ANDROID_DATA olmadan abort eder:
#     F DEBUG: Abort message: ANDROID_DATA environment variable unset
# rclog'deki awk bu degiskenleri app_process servislerine ekler ama
# ziye import'u cozulmedi (root seviyesindeki rc dosyalari rclog tarafindan
# islenmiyor). Bunu burada elle yapiyoruz.
if [ -f "$ROOT/init.zygote64_32.rc" ]; then
  # Zaten ANDROID_DATA var mi kontrol et
  if ! /bb/grep -q 'ANDROID_DATA' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
    # service zygote ... satirinin ardina env degiskenleri ekle
    sed -i '/^service zygote /a\\    setenv ANDROID_DATA /data\\n    setenv ANDROID_ROOT /system\\n    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art\\n    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata\\n    setenv ANDROID_IOTA_ROOT /apex/com.android.iota' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    echo "### EVR-L29: ANDROID_DATA env degiskenleri init.zygote64_32.rc'ye eklendi ###"
  fi
fi
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali:'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('ANDROID_DATA env vars added to zygote service')
else:
    print('ERROR: Pattern not found')
    idx = c.find('init.environ.rc de kopyala')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+300])}')