#!/bin/sh
# Готовит godot/ к сборке: копирует раскладки карт, строки и иконку из iOS-проекта,
# рисует картинку заставки и распаковывает спрайты (нужен ключ ASSETS_KEY, как для iOS).
#   ASSETS_KEY=... sh tools/godot_sync.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$ROOT/godot"
mkdir -p "$G/data/layouts" "$G/data/strings" "$G/assets/sprites"
cp "$ROOT"/GameFarm/Resources/Layouts/*.json "$G/data/layouts/"
cp "$ROOT"/GameFarm/Resources/Strings/*.json "$G/data/strings/"
# Иконка 1024 для iOS: остальные размеры Godot делает сам при экспорте
ICON="$ROOT/GameFarm/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cp "$ICON" "$G/assets/app_icon.png"
# Картинка заставки (boot splash): иконка и название, нужен Python с Pillow
if python3 -c "import PIL" 2> /dev/null; then
  python3 "$ROOT/tools/make_splash.py" "$ICON" "$G/fonts/Nunito-900.ttf" "$G/assets/splash.png"
else
  echo "Нет Pillow (pip install pillow): assets/splash.png не создан, будет заставка Godot"
fi
# Звуки: m4a из iOS в ogg (Godot не читает m4a). Нужен ffmpeg; без него звуков не будет.
if command -v ffmpeg > /dev/null; then
  mkdir -p "$G/assets/audio"
  for f in "$ROOT"/GameFarm/Resources/Audio/*.m4a; do
    out="$G/assets/audio/$(basename "${f%.m4a}").ogg"
    [ -f "$out" ] || ffmpeg -loglevel error -y -i "$f" -c:a libvorbis -q:a 4 "$out"
  done
fi
if [ -n "$ASSETS_KEY" ]; then
  TMP="$(mktemp -d)"
  openssl enc -d -aes-256-cbc -md sha256 -in "$ROOT/Art/sprites.enc" -pass env:ASSETS_KEY | tar -xz -C "$TMP"
  rm -rf "$G/assets/sprites"
  mv "$TMP/Sprites" "$G/assets/sprites"
  rm -rf "$TMP"
fi
echo "layouts: $(ls "$G/data/layouts" | wc -l), strings: $(ls "$G/data/strings" | wc -l), sprites: $(ls "$G/assets/sprites" | wc -l), audio: $(ls "$G/assets/audio" 2>/dev/null | wc -l), splash: $([ -f "$G/assets/splash.png" ] && echo yes || echo no)"
