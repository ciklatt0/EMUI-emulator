import subprocess, sys

result = subprocess.run(['readelf', '-d', '/tmp/sys-mnt-evr/system/bin/app_process64'],
                       capture_output=True, text=True)
for line in result.stdout.split('\n'):
    if 'NEEDED' in line:
        print(line)
