#!/bin/bash
# Собирает плагины iOS под Godot $GODOT_VERSION для iPhone (arm64, release): из godot-ios-plugins
# inappstore (StoreKit), icloud (сохранение в iCloud) и gamecenter (достижения и таблицы лидеров),
# и свой localnotify (локальные уведомления, исходники в tools/ios_plugins/localnotify).
# Каждый кладётся в папку $1/<плагин>: <плагин>.xcframework и .gdip. Нужен macOS с Xcode.
# В ios-godot.yml результат кэшируется: пересобирается только при смене версии Godot или этих файлов.
set -e -o pipefail

OUT="$1"
[ -n "$OUT" ] || { echo "usage: $0 <out dir>"; exit 2; }
V="${GODOT_VERSION:-4.5.1}"
PLUGINS_SHA="caafb2c7fbfb5c72a64f163c76449274fa49abaa"
W="${RUNNER_TEMP:-/tmp}/ios-plugins-build"
SRC="$(cd "$(dirname "$0")" && pwd)/ios_plugins"
PLUGINS="inappstore icloud gamecenter localnotify"
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"

rm -rf "$W" && mkdir -p "$W" && cd "$W"
command -v scons > /dev/null || brew install scons > /dev/null

git init -q plugins
cd plugins
git remote add origin https://github.com/godotengine/godot-ios-plugins.git
git fetch -q --depth 1 origin "$PLUGINS_SHA"
git checkout -q FETCH_HEAD
git clone -q --depth 1 --branch "${V}-stable" https://github.com/godotengine/godot.git godot

# Плагину нужны заголовки движка, в том числе созданные при сборке (*.gen.h). Запускаем сборку
# шаблона iOS и останавливаем её, как только они появились: сам движок не нужен.
NEED="core/version_generated.gen.h core/disabled_classes.gen.h core/object/gdvirtual.gen.inc modules/modules_enabled.gen.h"
set -m
(cd godot && exec scons platform=ios target=template_release arch=arm64 -j4 > "$W/scons-godot.log" 2>&1) &
PID=$!
set +m
for _ in $(seq 1 900); do
  ok=1
  for f in $NEED; do [ -f "godot/$f" ] || ok=0; done
  [ $ok = 1 ] && break
  kill -0 $PID 2> /dev/null || break
  sleep 1
done
sleep 5
kill -TERM -- -$PID 2> /dev/null || true
wait $PID 2> /dev/null || true
for f in $NEED; do
  [ -f "godot/$f" ] || { echo "::error::Заголовок $f не создан"; tail -60 "$W/scons-godot.log"; exit 1; }
done

# Флаги как у шаблона Godot для iOS (platform/ios/detect.py и SConstruct): без THREADS_ENABLED
# у Object другой размер (мьютекс), и плагин падал бы на устройстве.
perl -pi -e "s/'-DIOS_ENABLED', /'-DIOS_ENABLED', '-DAPPLE_EMBEDDED_ENABLED', '-DTHREADS_ENABLED', /" SConstruct
grep -q "DTHREADS_ENABLED" SConstruct || { echo "::error::Не удалось добавить флаги в SConstruct плагина"; exit 1; }

# Свои плагины - рядом с родными, и в список допустимых в SConstruct
for d in "$SRC"/*/; do
  name=$(basename "$d")
  rm -rf "plugins/$name" && cp -R "$d" "plugins/$name"
  perl -pi -e "s/'photo_picker'\]/'photo_picker', '$name']/" SConstruct
done

for p in $PLUGINS; do
  scons target=release arch=arm64 plugin=$p version=4.0
  LIB=$(ls bin/*$p*.arm64-ios.release.a | head -1)
  [ -f "$LIB" ] || { echo "::error::Библиотека плагина $p не собрана"; ls -la bin; exit 1; }
  rm -rf "$OUT/$p" && mkdir -p "$OUT/$p"
  xcodebuild -create-xcframework -library "$LIB" -output "$OUT/$p/$p.xcframework"
  cp plugins/$p/*.gdip "$OUT/$p/"
done
ls -laR "$OUT"
