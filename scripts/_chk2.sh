#!/usr/bin/env bash
echo "=== selinux_enforcing tanimi ==="
grep -rn "selinux_enforcing" /root/harmony-build/linux-6.6/security/ 2>/dev/null | head -20
echo
echo "=== __setup(\"enforcing=\") var mi? ==="
grep -rn 'setup("enforcing' /root/harmony-build/linux-6.6/security/ 2>/dev/null
echo
echo "=== __setup ile selinux parametreleri ==="
grep -rn '__setup(' /root/harmony-build/linux-6.6/security/selinux/*.c 2>/dev/null