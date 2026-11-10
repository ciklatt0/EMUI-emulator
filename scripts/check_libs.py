import os

# Check all lib64 directories for any .so files
for search_root in ['/tmp/sys-mnt-evr/system/lib64', '/tmp/sys-mnt-evr/vendor/lib64']:
    if not os.path.isdir(search_root):
        continue
    files = os.listdir(search_root)
    print(f"=== {search_root} ({len(files)} files) ===")
    for f in sorted(files)[:50]:
        print(f"  {f}")
    if len(files) > 50:
        print(f"  ... and {len(files)-50} more")
    print()

# Check APEX for runtime
apex_runtime = '/tmp/sys-mnt-evr/apex/com.android.runtime/lib64'
if os.path.isdir(apex_runtime):
    files = os.listdir(apex_runtime)
    print(f"=== {apex_runtime} ({len(files)} files) ===")
    for f in sorted(files)[:50]:
        print(f"  {f}")