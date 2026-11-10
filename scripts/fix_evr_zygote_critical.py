with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# After adding ANDROID_DATA env vars to zygote service, also remove critical from zygote services
old = '''if [ -f "$ROOT/init.zygote64_32.rc" ]; then
  # Zaten ANDROID_DATA var mi kontrol et
  if ! /bb/grep -q 'ANDROID_DATA' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
    # service zygote ... satirinin ardina env degiskenleri ekle
    sed -i '/^service zygote /a\\    setenv ANDROID_DATA /data\\n    setenv ANDROID_ROOT /system\\n    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art\\n    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata\\n    setenv ANDROID_IOTA_ROOT /apex/com.android.iota' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    echo "### EVR-L29: ANDROID_DATA env degiskenleri init.zygote64_32.rc'ye eklendi ###"
  fi
fi'''

new = '''if [ -f "$ROOT/init.zygote64_32.rc" ]; then
  # Zaten ANDROID_DATA var mi kontrol et
  if ! /bb/grep -q 'ANDROID_DATA' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
    # service zygote ... satirinin ardina env degiskenleri ekle
    sed -i '/^service zygote /a\\    setenv ANDROID_DATA /data\\n    setenv ANDROID_ROOT /system\\n    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art\\n    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata\\n    setenv ANDROID_IOTA_ROOT /apex/com.android.iota' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    echo "### EVR-L29: ANDROID_DATA env degiskenleri init.zygote64_32.rc'ye eklendi ###"
  fi
  # DIKKAT: zygote ve zygote_secondary critical -> init paniği yapar
  # coktu. Kaldir (servis yine yeniden baslatilir, ama init vazgeçmez).
  sed -i 's/^    critical$/    # critical/' "$ROOT/init.zygote64_32.rc" 2>/dev/null
  sed -i 's/^    shutdown critical$/    # shutdown critical/' "$ROOT/init.zygote64_32.rc" 2>/dev/null
  # writepid cgroup dugumlerine yazmaya calisir (yok) -> hatali
  sed -i 's/^    writepid/    # writepid/' "$ROOT/init.zygote64_32.rc" 2>/dev/null
  # onrestart write /sys/power/state on -> "Invalid argument" hatasi
  sed -i 's/^    onrestart write \\/sys\\/power\\/state on$/    # onrestart write \\/sys\\/power\\/state on/' "$ROOT/init.zygote64_32.rc" 2>/dev/null
  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"
fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('critical/writepid removed from zygote services')
else:
    print('ERROR: Pattern not found')
    idx = c.find('ANDROID_DATA env degiskenleri')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+300])}')