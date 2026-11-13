#!/usr/bin/env python3
# Adb protokolunun ilk paketini (CNXN) elle gonderip yaniti dinle.
# Format: command,arg0,arg1,arg2,length,magic,payload  (kucuk uç)
import socket, struct, sys

host, port = "127.0.0.1", 5555
CNXN = 0x4E584E43
VERSION = 0x01000000
MAXDATA = 0x00100000

pkt = struct.pack("<6I", CNXN, VERSION, MAXDATA, 0, 24, CNXN)
pkt += b"host::features=shell_v2,cmd,stat_v2\x00"

try:
    s = socket.create_connection((host, port), timeout=8)
except Exception as e:
    print("baglanti hatasi:", e)
    sys.exit(1)
print("TCP baglandi")

s.settimeout(12)
s.sendall(pkt)
print("CNXN gonderildi (%d bayt)" % len(pkt))

try:
    data = s.recv(1024)
except socket.timeout:
    print("YANIT YOK (12 sn zaman asimi) -> adbd cocugu olmus olabilir")
    sys.exit(2)

if not data:
    print("SUNUCU BAGLANTIYI KAPATTI (0 bayt)")
    sys.exit(3)

print("gelen %d bayt:" % len(data))
if len(data) >= 24:
    cmd, a0, a1, a2, ln, magic = struct.unpack("<6I", data[:24])
    print("  command=0x%08x arg0=0x%08x arg1=0x%08x arg2=0x%08x len=%d magic=0x%08x"
          % (cmd, a0, a1, a2, ln, magic))
    print("  magic metin: %r" % data[20:24])
    print("  yuk: %r" % data[24:24 + min(ln, 300)])
else:
    print("  kisa yanit:", data)