import os

# Check for HWComposer and EGL libraries
for search_root in ['/tmp/sys-mnt-evr/system/lib64', '/tmp/sys-mnt-evr/vendor/lib64', '/tmp/sys-mnt-evr/apex']:
    if not os.path.isdir(search_root):
        continue
    for root, dirs, files in os.walk(search_root):
        for f in files:
            name = f.lower()
            if any(kw in name for kw in ['hwcomposer', 'gralloc', 'egl', 'gles', 'gl2', 'gl3']):
                full = os.path.join(root, f)
                print(full)