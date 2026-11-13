#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) linkerconfig icindeki XML etiketleri ==="
A 'strings /system/bin/bootstrap/linkerconfig 2>/dev/null | grep -iE "apex-instances|apex-info|preInstallDir|isActive|version" | head -12'
echo ""
echo "=== 2) apex-info-list.xml olustur ve linkerconfig'i calistir ==="
A 'rm -f /apex/apex-info-list.xml
{
  echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
  echo "<apex-instances>"
  for d in /apex/*/; do
    n=$(basename "$d")
    case "$n" in
      com.android.adbd|metadata|apexfiles) continue ;;
    esac
    v=1
    [ -f "$d/apex_manifest" ] || [ -f "$d/etc/sdkinfo.pb" ]
    echo "  <apex-info name=\"$n\" version=\"330000000\" preInstallDir=\"/apex/$n\" />"
  done
  echo "</apex-instances>"
} > /apex/apex-info-list.xml
wc -l /apex/apex-info-list.xml; head -5 /apex/apex-info-list.xml'
echo ""
echo "=== 3) linkerconfig simdi calisiyor mu ==="
A 'rm -rf /tmp/lc; mkdir -p /tmp/lc; /system/bin/bootstrap/linkerconfig --target /tmp/lc 2>&1 | head -8'
echo ""
echo "=== 4) uretilen configte APEX yolu var mi ==="
A 'wc -l /tmp/lc/ld.config.txt 2>&1; grep -c "apex" /tmp/lc/ld.config.txt 2>&1'
A 'grep -n "i18n\|art/lib64" /tmp/lc/ld.config.txt 2>&1 | head -5'