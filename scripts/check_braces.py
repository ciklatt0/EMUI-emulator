with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

open_count = c.count('{')
close_count = c.count('}')

print(f"Open braces: {open_count}")
print(f"Close braces: {close_count}")
print(f"Difference: {open_count - close_count}")

# Also check parens
open_paren = c.count('(')
close_paren = c.count(')')
print(f"Open parens: {open_paren}")
print(f"Close parens: {close_paren}")
print(f"Difference: {open_paren - close_paren}")
