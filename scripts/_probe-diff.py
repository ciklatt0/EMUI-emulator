#!/usr/bin/env python3
# AYIRT EDICI TEST: QEMU hostfwd guest'e ulasamiyor mu, yoksa
# adbd mi reddediyor?
#
#  - Kullanilmayan bir porta (5900) baglan: guest'te kimse
#    dinlemiyorsa TCP RST (ECONNRESET) gelir -- bu QEMU'nun
#    "guest'e ulastim ama cevap yok" demesidir.
#  - 5555'e baglan: adbd dinliyorsa ya CNXN gonderir ya da RST.
#
# Ikisi de RST ise  -> guest'e ULASILMIYORUZ (ag/servis sorunu).
# 5900 RST, 5555 timeout -> adbd DINLEMIYOR (bind sorunu).
import socket, struct, sys, time

CNXN = 0x4E584E43


def probe(port, label, send_cnxn):
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=8)
    except Exception as e:
        print("%-22s BAGLANAMADI: %s" % (label, e))
        return
    print("%-22s TCP KURULDU" % label)
    if send_cnxn:
        s.sendall(struct.pack("<6I", CNXN, 0x01000000, 0x00100000, 0, 24, CNXN)
                  + b"host::features=shell_v2\x00")
    s.settimeout(10)
    try:
        d = s.recv(1024)
        if not d:
            print("%-22s SUNUCU KAPATTI (0 bayt)" % label)
        else:
            print("%-22s %d BAYT ALDI: %s" % (label, len(d), d[:40]))
    except socket.timeout:
        print("%-22s TIMEOUT (10 sn) -- sunucu sessiz" % label)
    except ConnectionResetError:
        print("%-22s RST aldi (baglanti aninda sifirlandi)" % label)
    s.close()


print("QEMU hostfwd testi")
probe(5900, "5900 (bos port)", False)
time.sleep(1)
probe(5555, "5555 (adbd)", True)
time.sleep(1)
probe(5900, "5900 tekrar", False)