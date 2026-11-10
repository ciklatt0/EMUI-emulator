with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
c = c.replace('PARTS="/root/harmony-build/super-out/parts"', 'PARTS="/root/harmony-build/lio-super-out/parts"')
c = c.replace('DISK="/root/harmony-build/boot/system-disk.img"', 'DISK="/root/harmony-build/lio-boot/system-disk.img"')
c = c.replace('LOG="$HERE/../logs/boot-zygote.log"', 'LOG="$HERE/../logs/boot-zygote-lio.log"')
with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('duzenlendi')

