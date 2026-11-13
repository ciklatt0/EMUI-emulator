#!/bin/bash
# QEMU hostfwd gercekten guest'e ulasabiliyor mu? Ham TCP denemesi.
echo "--- WSL tarafindan 127.0.0.1:5555 ---"
if timeout 6 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5555' 2>/dev/null; then
  echo "  TCP baglantisi KURULDU (QEMU guest'e ulasti)"
else
  echo "  TCP baglantisi BASARISIZ (QEMU guest'e ulasamadi)"
fi
echo ""
echo "--- 5555'i dinleyen QEMU ---"
ss -lntp 2>/dev/null | grep 5555 || echo "  yok"