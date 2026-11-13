#!/bin/bash
echo "--- qemu process ---"
ps -eo pid,etimes,comm | grep -i '[q]emu-system' || echo "  yok"
echo ""
echo "--- 5555 portunu kullanan ---"
ss -lntp 2>/dev/null | grep 5555 || echo "  ss: yok"
echo ""
echo "--- windows tarafi ---"
netstat -ano 2>/dev/null | grep ':5555' | head -5 || echo "  windows netstat: temiz"