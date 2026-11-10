with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find and fix the [ -n "$PATHS" ] || return 0 line
old = '  [ -n "$PATHS" ] || return 0'
new = '''  # DIKKAT (EVR-L29): PATHS bos olabilir (APEX henuz mount degil).
    # Minimal bir config uretilmelidir ki init baslangic sureclerini
    # calistirabilsin.
    if [ -z "$PATHS" ]; then
      PATHS="
namespace.default.search.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      PERTM="
namespace.default.permitted.paths += /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
    fi
  [ -n "$PATHS" ] || return 0'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('PATHS empty fallback added')
else:
    print('Old code block not found')
    import re
    for m in re.finditer(r'\[ -n "\$PATHS" \].*return 0', c):
        start = max(0, m.start() - 100)
        end = min(len(c), m.end() + 100)
        print(f'Found at {m.start()}: {repr(c[start:end])}')
