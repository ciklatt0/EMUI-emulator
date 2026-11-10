with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

import re

# Check KCMD
kcmd_match = re.search(r'KCMD="([^"]*)"', c)
if kcmd_match:
    print(f"KCMD: {kcmd_match.group(1)}")

# Check if androidboot.zygote is in KCMD
if 'androidboot.zygote' in c:
    print("androidboot.zygote found in KCMD")
else:
    print("androidboot.zygote NOT found in KCMD")

# Check PATHS fallback
if 'sifirdan uretiliyor' in c:
    print("PATHS fallback found")
else:
    print("PATHS fallback NOT found")

# Check APEX path addition
if 'for entry in __APEX_LIST__' in c:
    print("APEX_LIST iteration found in PATHS")
else:
    print("APEX_LIST iteration NOT found in PATHS")

# Show PATHS section
idx = c.find('sifirdan uretiliyor')
if idx != -1:
    print(f"\nContext around sifirdan uretiliyor:")
    print(c[idx-200:idx+500])
