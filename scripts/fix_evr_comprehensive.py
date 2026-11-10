with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Add androidboot.zygote=zygote64_32 to kernel command line
old_kcmd = '''KCMD="console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true androidboot.serialno=unknown printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"'''
new_kcmd = '''KCMD="console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true androidboot.serialno=unknown androidboot.zygote=zygote64_32 printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"'''

if old_kcmd in c:
    c = c.replace(old_kcmd, new_kcmd, 1)
    print('KCMD updated with androidboot.zygote=zygote64_32')
else:
    print('KCMD pattern not found')

# Fix 2: Add APEX paths to PATHS even when APEX not mounted yet
old_paths = '''    if [ -z "$PATHS" ]; then
      PATHS="
namespace.default.search.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      PERTM="
namespace.default.permitted.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
    fi'''

new_paths = '''    if [ -z "$PATHS" ]; then
      PATHS="
namespace.default.search.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      PERTM="
namespace.default.permitted.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      # Add APEX paths from known APEX list (APEX may not be mounted yet)
      for entry in __APEX_LIST__; do
        apname=${entry##*:}
        PATHS="$PATHS
namespace.default.search.paths += /apex/$apname/lib64"
        PERTM="$PERTM
namespace.default.permitted.paths += /apex/$apname/lib64"
        if [ -d "/apex/$apname/lib64/bionic" ]; then
          PATHS="$PATHS
namespace.default.search.paths += /apex/$apname/lib64/bionic"
          PERTM="$PERTM
namespace.default.permitted.paths += /apex/$apname/lib64/bionic"
        fi
      done
    fi'''

if old_paths in c:
    c = c.replace(old_paths, new_paths, 1)
    print('APEX paths added to PATHS fallback')
else:
    print('Old PATHS block not found')
    import re
    # Try to find what's there
    for m in re.finditer(r'\[ -z "\$PATHS" \].*?return 0', c, re.DOTALL):
        start = max(0, m.start() - 50)
        end = min(len(c), m.end() + 50)
        print(f'Found PATHS block: {repr(c[start:end])}')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')
