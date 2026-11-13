import os

app_path = './UPDATE.APP'

CHUNK = 16 * 1024 * 1024  # 16 MB chunks
OVERLAP = 256

with open(app_path, 'rb') as f:
    file_size = os.fstat(f.fileno()).st_size
    print(f"File size: {file_size} bytes ({file_size / 1024 / 1024:.1f} MB)")
    
    for name in [b'system', b'vendor', b'boot', b'recovery', b'cache', b'userdata', b'persist']:
        print(f"\nSearching for '{name.decode()}'...")
        pos = 0
        count = 0
        prev_pos = -OVERLAP
        
        while pos < file_size:
            f.seek(pos)
            chunk = f.read(CHUNK)
            if not chunk:
                break
            
            search_from = 0
            if pos > 0:
                search_from = 0  # We already handled overlap by seeking back
            
            idx = chunk.find(name)
            while idx != -1:
                real_pos = pos + idx
                count += 1
                if count <= 5:
                    f.seek(max(0, real_pos - 32))
                    context = f.read(96)
                    hex_part = ' '.join(f'{b:02x}' for b in context)
                    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in context)
                    print(f"  at 0x{real_pos:08x} ({real_pos}):")
                    print(f"    {hex_part}")
                    print(f"    {ascii_part}")
                
                # Search next occurrence in chunk
                idx = chunk.find(name, idx + 1)
            
            pos += CHUNK - OVERLAP
            # Seek back to catch overlapping matches
            f.seek(pos - OVERLAP if pos > OVERLAP else 0)
        
        print(f"  Total '{name.decode()}' occurrences: {count}")
