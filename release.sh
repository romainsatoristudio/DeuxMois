#!/bin/zsh
# Fabrique build/DeuxMois-<version>.dmg à publier.
#
# L'app est signée « ad hoc » (sans identité) : un certificat de développeur contient le nom
# et l'e-mail de son propriétaire, qui seraient lisibles par quiconque inspecte la signature.
# Le script refuse de produire le .dmg si le binaire contient une donnée personnelle connue.
set -euo pipefail
cd "${0:A:h}"

PREFIX=${RELEASE_BUNDLE_ID_PREFIX:-io.github.romainsatoristudio}
DERIVED=build/release-derived
APP=$DERIVED/Build/Products/Release/DeuxMois.app
STAGE=build/release-dmg

[[ -f Config/Local.xcconfig ]] || cp Config/Local.xcconfig.example Config/Local.xcconfig
xcodegen generate --quiet
rm -rf "$DERIVED" "$STAGE"
xcodebuild -project DeuxMois.xcodeproj -scheme DeuxMois -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
    BUNDLE_ID_PREFIX="$PREFIX" DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES STRIP_STYLE=all \
    build | grep -E "error:|BUILD"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG=build/DeuxMois-$VERSION.dmg

# Signature sans identité ni équipe.
codesign --verify --deep --strict "$APP"
signature=$(codesign -dv "$APP" 2>&1)
[[ $signature == *"Signature=adhoc"* ]] || { echo "La signature n'est pas ad hoc."; exit 1; }
[[ $signature == *"TeamIdentifier=not set"* ]] || { echo "Une équipe Apple est présente."; exit 1; }

# Données personnelles à ne jamais publier : chemin du dossier personnel, nom complet,
# e-mail git, et les valeurs de Config/Local.xcconfig.
needles=("$HOME/" "$(id -F 2>/dev/null || true)" "$(git config --global user.email 2>/dev/null || true)")
for key in DEVELOPMENT_TEAM BUNDLE_ID_PREFIX; do
    value=$(sed -n "s/^$key *= *//p" Config/Local.xcconfig | tr -d ' ')
    [[ -n "$value" && "$value" != com.example ]] && needles+=("$value")
done
# L'identifiant public de l'app ($PREFIX) est retiré avant la recherche : il est voulu.
found=0
for f in ${(f)"$(find "$APP" -type f)"}; do
    text=$(strings -a "$f" | sed "s/${PREFIX//./\\.}//g")
    for needle in $needles; do
        [[ -z "$needle" ]] && continue
        if grep -qiF -- "$needle" <<< "$text"; then
            echo "Donnée personnelle trouvée dans ${f#$APP/}"
            found=1
        fi
    done
done
(( found == 0 )) || exit 1

mkdir -p "$STAGE"
ditto "$APP" "$STAGE/DeuxMois.app"
ln -s /Applications "$STAGE/Applications"
xattr -cr "$STAGE"
rm -f "$DMG"
hdiutil create -volname "Deux mois" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

echo "$DMG"
shasum -a 256 "$DMG"
