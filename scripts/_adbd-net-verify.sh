#!/bin/bash
# IPv6 hipotezi BAGIMSIZ dogrulama: Huawei adbd'si 'tcp:PORT'u
# IPv6 oncelikli mi aciyor? Adbd ikilisindeki dizelere bak.
#
# AOSP adbd'nin kodu (adb/daemon/main.cpp):
#     if (android::base::StartsWith(arg, "tcp:")) {
#         std::string port_str = arg.substr(4);
#         int port = atoi(port_str.c_str());
#         fds.push_back(create_local_socket("tcp", ...));
#     }
# ve create_local_socket() once AF_INET6 dener, duser ve AF_INET'e
# duser. Bu sirada 'error' donerse devam eder.
#
# DIZELERDE ARANACAKLAR:
#   AF_INET6 / AF_INET  -> socket() cagrisinin sirasi
#   "tcp:%s", "Cannot bind"
#   "cannot bind socket"
set -u
A=/tmp/adbdx/bin/adbd
[ -x "$A" ] || { echo "adbd yok, once unzip + mount"; exit 1; }
echo "=== bind/socket ile ilgili dizeler ==="
strings -a "$A" | grep -iE 'bind|inet6|inet_|AF_INET|cannot listen|listen on' | head -25
echo ""
echo "=== tcp: arguman formati ==="
strings -a "$A" | grep -E '^tcp:|localabstract|localreserved|localfilesystem|vsock' | head -15