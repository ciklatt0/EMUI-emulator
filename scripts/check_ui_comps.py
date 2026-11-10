import os

root = '/tmp/sys-mnt-evr/system/bin'
ui_components = []
for f in os.listdir(root):
    name = f.lower()
    if any(kw in name for kw in ['surface', 'window', 'launcher', 'home', 'boot', 'anim', 'gralloc', 'composer', 'serviceman', 'display', 'hw']):
        ui_components.append(f)

for c in sorted(ui_components):
    print(c)