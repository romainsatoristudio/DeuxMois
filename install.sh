#!/bin/zsh
# Compile l'app, l'installe dans /Applications et force macOS à recharger les widgets.
set -euo pipefail
cd "${0:A:h}"

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT=build/Build/Products/Release/DeuxMois.app
INSTALLED=/Applications/DeuxMois.app

if [[ ! -f Config/Local.xcconfig ]]; then
    cp Config/Local.xcconfig.example Config/Local.xcconfig
    echo "Config/Local.xcconfig vient d'être créé : renseignez DEVELOPMENT_TEAM et BUNDLE_ID_PREFIX, puis relancez."
    exit 1
fi
if ! command -v xcodegen >/dev/null; then
    echo "XcodeGen est nécessaire : brew install xcodegen"
    exit 1
fi

xcodegen generate --quiet
xcodebuild -project DeuxMois.xcodeproj -scheme DeuxMois -configuration Release \
    -destination 'platform=macOS' -derivedDataPath build build | grep -E "error:|BUILD"

# Seule la copie de /Applications doit être connue de macOS.
pluginkit -r "$BUILT/Contents/PlugIns/DeuxMoisWidget.appex" 2>/dev/null || true
$LSREGISTER -u "$BUILT" 2>/dev/null || true

osascript -e 'quit app "DeuxMois"' 2>/dev/null || true
pkill -f "$INSTALLED/Contents/PlugIns/DeuxMoisWidget.appex" 2>/dev/null || true
sleep 1
rm -rf "$INSTALLED"
ditto "$BUILT" "$INSTALLED"
$LSREGISTER -f "$INSTALLED"
pluginkit -a "$INSTALLED/Contents/PlugIns/DeuxMoisWidget.appex"

# Vide le cache des rendus de widgets (ces deux processus système redémarrent tout seuls).
killall chronod NotificationCenter 2>/dev/null || true
sleep 3
open "$INSTALLED"
echo "Installé dans $INSTALLED"
