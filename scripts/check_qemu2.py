import subprocess
result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
for line in result.stdout.split('\n'):
    if 'qemu' in line.lower():
        print(line)