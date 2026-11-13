$f = 'C:\Users\windo\OneDrive\Desktop\Harmonyos\start-emulator.cmd'
$txt = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::ASCII)
$bytes = [System.IO.File]::ReadAllBytes($f)
"ilk 3 bayt   : {0}" -f ([System.BitConverter]::ToString($bytes[0..2]))
"BOM var mi    : {0}" -f ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
"CRLF sayisi   : {0}" -f ([regex]::Matches($txt, "`r`n")).Count
"tek basina LF: {0}" -f ([regex]::Matches($txt, "(?<!`r)`n")).Count
"non-ASCII     : {0}" -f ([regex]::Matches($txt, '[^\x00-\x7F]')).Count