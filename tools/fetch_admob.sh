#!/bin/bash
# Ставит рекламу AdMob для iOS в папку $1 (в CI это godot/ios/plugins/admob): готовый плагин
# Poing Studios godot-admob-ios под Godot $GODOT_VERSION, Google Mobile Ads SDK и Google UMP
# (окна согласия GDPR и ATT), и пишет admob.gdip с App ID и списком SKAdNetwork.
# Плагин Poing ждёт, что SDK добавит их редакторный аддон через Swift Package Manager; у нас
# экспорт без редактора, поэтому SDK скачивается здесь и подключается через gdip (linked).
set -e -o pipefail

OUT="$1"
[ -n "$OUT" ] || { echo "usage: $0 <out dir>"; exit 2; }
V="${GODOT_VERSION:-4.5.1}"

# App ID из AdMob (Приложения - Настройки приложения). Блок Rewarded - Ads.REWARDED_ID в godot/scripts/core/ads.gd.
ADMOB_APP_ID="ca-app-pub-9867750696429328~8153185043"

POING_VERSION="v4.1.0"
GMA_URL="https://dl.google.com/googleadmobadssdk/c8c5523373ed76aa/googlemobileadsios-spm-12.14.0.zip"
GMA_SHA="c8c5523373ed76aa6da7bbe1324458e680981bd4593271cca5958fc8e8ffc5e7"
UMP_URL="https://dl.google.com/googleadmobadssdk/90fe6bf3b0f4ce0d/googleusermessagingplatformios-spm-3.1.0.zip"
UMP_SHA="90fe6bf3b0f4ce0d0199628c0871de58b6f673375148b98d52348aecc86db231"

W="${RUNNER_TEMP:-/tmp}/admob-fetch"
rm -rf "$W" && mkdir -p "$W"

fetch() {
  curl -fsSL --retry 3 -o "$2" "$1"
  if [ -n "$3" ]; then
    echo "$3  $2" | shasum -a 256 -c -
  fi
}

fetch "https://github.com/poing-studios/godot-admob-ios/releases/download/${POING_VERSION}/poing-godot-admob-ios-v${V}.zip" "$W/poing.zip"
fetch "$GMA_URL" "$W/gma.zip" "$GMA_SHA"
fetch "$UMP_URL" "$W/ump.zip" "$UMP_SHA"
unzip -q "$W/poing.zip" -d "$W/poing"
unzip -q "$W/gma.zip" -d "$W/gma"
unzip -q "$W/ump.zip" -d "$W/ump"

rm -rf "$OUT" && mkdir -p "$OUT/bin" "$OUT/frameworks"
cp -R "$W"/poing/poing-godot-admob/bin/poing-godot-admob-ads.*.xcframework "$OUT/bin/"
GMA=$(find "$W/gma" -type d -name "GoogleMobileAds.xcframework" | head -1)
UMP=$(find "$W/ump" -type d -name "UserMessagingPlatform.xcframework" | head -1)
[ -d "$GMA" ] && [ -d "$UMP" ] || { echo "::error::SDK не найден в архивах"; find "$W/gma" "$W/ump" -maxdepth 3; exit 1; }
cp -R "$GMA" "$UMP" "$OUT/frameworks/"

# Список SKAdNetwork берём из gdip плагина (в нём рекомендованный Google список)
SKAD=$(awk '/^SKAdNetworkItems:raw="/{f=1; sub(/^SKAdNetworkItems:raw="/, ""); } f{ if ($0 ~ /^"$/) {exit} print }' "$W/poing/poing-godot-admob-ads.gdip")
echo "$SKAD" | grep -q "skadnetwork" || { echo "::error::Нет списка SKAdNetwork в gdip плагина"; exit 1; }

cat > "$OUT/admob.gdip" <<EOF
[config]
name="AdMob"
binary="bin/poing-godot-admob-ads.xcframework"
use_swift_runtime=true

initialization="register_poing_godot_admob_ads_types"
deinitialization="unregister_poing_godot_admob_ads_types"

[dependencies]
linked=["frameworks/GoogleMobileAds.xcframework", "frameworks/UserMessagingPlatform.xcframework"]
embedded=[]
system=["AppTrackingTransparency.framework", "AdSupport.framework", "JavaScriptCore.framework", "WebKit.framework", "SafariServices.framework", "StoreKit.framework", "SystemConfiguration.framework", "CoreTelephony.framework", "AVFoundation.framework", "AudioToolbox.framework", "CoreMedia.framework", "MessageUI.framework"]
capabilities=[]
files=[]
linker_flags=["-ObjC"]

[plist]
GADApplicationIdentifier:string="${ADMOB_APP_ID}"
NSUserTrackingUsageDescription:string="This lets rewarded ads be more relevant to you. The game works the same either way."
SKAdNetworkItems:raw="
${SKAD}
"
EOF

echo "== $OUT"
find "$OUT" -maxdepth 3 | sort
file "$GMA"/ios-arm64/GoogleMobileAds.framework/GoogleMobileAds 2> /dev/null || true
find "$OUT/frameworks" -name "*.xcprivacy" -o -name "*.bundle" | head
