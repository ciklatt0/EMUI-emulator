import zipfile

z = zipfile.ZipFile('./dload.zip')
for i in z.infolist():
    if 'update_sd_base' in i.filename:
        print(i.filename, i.file_size)
