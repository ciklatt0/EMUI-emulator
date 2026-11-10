with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
count = content.count('Fix linker64 symlink')
print(f'Total occurrences: {count}')
pos = 0
while True:
    pos = content.find('Fix linker64 symlink', pos)
    if pos == -1:
        break
    line_num = content[:pos].count('\n') + 1
    print(f'  Position {pos}, line ~{line_num}')
    pos += 1
