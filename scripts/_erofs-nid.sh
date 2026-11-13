#!/bin/bash
# erofs imajinda yolu NID ile adim adim cozer.
# dump.erofs 1.9.1'de --path SembolIK BAGLANTIYI cozemiyor
# ("invalid de[0].nameoff" hatasi), o yuzden her dizini tek tek
# --ls ile listeleyip cocuk NID'i elle esliyoruz.
IMG=$1
shift
cur=47                      # kok inode (dump.erofs superblock "root nid")
for part in "$@"; do
  n=$(dump.erofs --ls --nid=$cur "$IMG" 2>/dev/null \
      | awk -v p="$part" '$3==p {print $1; exit}')
  if [ -z "$n" ]; then echo "YOK: /$part (nid $cur)" >&2; exit 1; fi
  cur=$n
  echo "  /$part -> nid $cur" >&2
done
echo "$cur"