with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
idx = c.find("cat >\"$ROOT/init.environ.rc\"")
if idx != -1:
    print(c[idx:idx+2000])

