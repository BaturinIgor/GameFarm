#!/bin/sh
# Собирает спрайты из паков и кладёт их в репозиторий в зашифрованном виде.
#   ASSETS_KEY=... sh tools/pack_sprites.sh <папка с паками>
# Ключ тот же, что в секрете ASSETS_KEY на GitHub.
set -e
SRC="$1"
[ -n "$SRC" ] || { echo "usage: ASSETS_KEY=... $0 <packs dir>"; exit 1; }
[ -n "$ASSETS_KEY" ] || { echo "ASSETS_KEY is not set"; exit 1; }
TMP="$(mktemp -d)"
python3 -I "$(dirname "$0")/sprites.py" "$SRC" "$TMP/Sprites"
tar -C "$TMP" -czf "$TMP/sprites.tar.gz" Sprites
mkdir -p Art
openssl enc -aes-256-cbc -md sha256 -salt -in "$TMP/sprites.tar.gz" -out Art/sprites.enc -pass env:ASSETS_KEY
rm -rf "$TMP"
ls -lh Art/sprites.enc
