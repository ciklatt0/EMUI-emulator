with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
idx = c.find("cat >\"$ROOT/init.environ.rc\"")
if idx != -1:
    end = c.find("RC_EOF", idx)
    if end != -1:
        print(c[idx:end+7])
    else:
        print("RC_EOF not found after cat")

