import re
with open('/tmp/strace-6.11/src/ptp.c','r') as f:
    c=f.read()
c=c.replace('CHECK_TYPE_SIZE(sysoff.rsv, sizeof(unsigned int) * 3);','/* CHECK_TYPE_SIZE(sysoff.rsv, sizeof(unsigned int) * 3); */')
c=c.replace('CHECK_TYPE_SIZE(sysoff.rsv, sizeof(unsigned int) * 4);','/* CHECK_TYPE_SIZE(sysoff.rsv, sizeof(unsigned int) * 4); */')
with open('/tmp/strace-6.11/src/ptp.c','w') as f:
    f.write(c)
print('patched')
