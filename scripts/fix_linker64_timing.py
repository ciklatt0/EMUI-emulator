with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Step 1: Remove linker64 block from custom /init section (lines 3668-3680, 0-indexed: 3667-3679)
# Find it by content
linker64_block_start = None
linker64_block_end = None
for i, line in enumerate(lines):
    if 'Fix linker64 symlink' in line and i > 3600:
        linker64_block_start = i
    if linker64_block_start is not None and line.strip() == 'fi' and i > linker64_block_start:
        linker64_block_end = i
        break

print(f"Removing linker64 block from /init: lines {linker64_block_start+1} to {linker64_block_end+1}")

# Remove those lines
del lines[linker64_block_start:linker64_block_end+1]

# Step 2: Find where to insert linker64 fix in mountapex - after /system bind mount
# Look for the line: echo "  init   : $(readlink /system/bin/init 2>/dev/null)"
insert_after = None
for i, line in enumerate(lines):
    if 'readlink /system/bin/init' in line:
        insert_after = i
        break

print(f"Will insert linker64 fix after line {insert_after+1}")

linker64_fix = '''  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it over the broken symlink so
  # servicemanager and all dynamically-linked binaries can run.
  # MUST run AFTER /system is bind-mounted (above), otherwise the mount covers
  # our overlay. MUST run BEFORE exec init so servicemaker sees it.
  if [ -f /system/bin/bootstrap/linker64 ]; then
    mkdir -p /system-bin-tmp 2>/dev/null
    cp -a /system/bin/* /system-bin-tmp/ 2>/dev/null
    rm -f /system-bin-tmp/linker64 2>/dev/null
    cp /system/bin/bootstrap/linker64 /system-bin-tmp/linker64 2>/dev/null
    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \\
      && echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"
  fi

'''

# Insert after the readlink line
lines.insert(insert_after + 1, linker64_fix)

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.writelines(lines)

print("Done! Linker64 fix moved to mountapex (after /system mount).")
