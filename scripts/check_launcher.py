import os

# Check for launcher apps in system/app and system/priv-app
for base in ['/tmp/sys-mnt-evr/system/app', '/tmp/sys-mnt-evr/system/priv-app', '/tmp/sys-mnt-evr/product/app', '/tmp/sys-mnt-evr/product/priv-app']:
    if os.path.isdir(base):
        print(f"=== {base} ===")
        for d in sorted(os.listdir(base)):
            print(f"  {d}")
        print()

# Also check vendor/app
for base in ['/tmp/sys-mnt-evr/vendor/app', '/tmp/sys-mnt-evr/vendor/priv-app']:
    if os.path.isdir(base):
        print(f"=== {base} ===")
        for d in sorted(os.listdir(base)):
            print(f"  {d}")
        print()