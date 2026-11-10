with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
c = c.replace('DISK="/root/harmony-build/boot/system-disk.img"', 'DISK="/root/harmony-build/evr-boot/system-disk.img"')
c = c.replace('LOG="$HERE/../logs/boot-zygote.log"', 'LOG="$HERE/../logs/boot-zygote-evr.log"')
with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
import os
os.chmod('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 0o755)
print('duzenlendi')
