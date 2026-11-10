with open('/tmp/sys-check/init.rc') as f:
    for i, line in enumerate(f, 1):
        if 'servicemanager' in line.lower() or 'servicemaker' in line.lower():
            print(f'{i}: {line.rstrip()}')
