import subprocess
result = subprocess.run(['wsl', '-d', 'Ubuntu', '-u', 'root', '--find', '/', '-name', '.git', '-type', 'd'], capture_output=True, text=True)
print(result.stdout)
print(result.stderr)