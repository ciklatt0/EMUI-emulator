import os, subprocess

# Mount system image
os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

root = '/tmp/sys-mnt-evr/system/bin'
if os.path.isdir(root):
    ui_components = []
    for f in os.listdir(root):
        name = f.lower()
        if any(kw in name for kw in ['surface', 'window', 'launcher', 'home', 'boot', 'anim', 'gralloc', 'composer', 'serviceman', 'display', 'hw']):
            ui_components.append(f)
    for c in sorted(ui_components):
        print(c)
else:
    print("system/bin not found")