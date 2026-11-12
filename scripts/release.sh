#!/bin/bash
# Baut ein Release: DMG + Sparkle-Appcast (signiert mit dem EdDSA-Schlüssel aus dem Schlüsselbund).
# Aufruf:  scripts/release.sh <Version> <Build> [--publish]
#   Version  z. B. 1.1.0 (sichtbare Version)
#   Build    ganze Zahl, muss mit jedem Release steigen (Sparkle vergleicht sie)
#   --publish  legt zusätzlich das GitHub-Release v<Version> mit DMG und appcast.xml an
# Release-Notizen aus der Datei dist/NOTES.md (optional).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Version fehlt, z. B. 1.1.0}"
BUILD="${2:?Build-Nummer fehlt, z. B. 2}"
PUBLISH="${3:-}"
REPO="alexanderschubert/moneypapersync"

sed -i '' -E "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VERSION\"/; s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$BUILD\"/" project.yml
xcodegen generate >/dev/null

rm -rf dist build-release
mkdir -p dist/dmg
xcodebuild -scheme MoneyPaperSync -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build-release build | grep -E "error:|BUILD" || true
cp -R build-release/Build/Products/Release/MoneyPaperSync.app dist/dmg/
ln -s /Applications dist/dmg/Applications
hdiutil create -volname MoneyPaperSync -srcfolder dist/dmg -ov -format UDZO dist/MoneyPaperSync.dmg >/dev/null
rm -rf dist/dmg

SIGN="$(find build-release/SourcePackages -path '*artifacts/sparkle/Sparkle/bin/sign_update' | head -1)"
SIG_ATTRS="$("$SIGN" dist/MoneyPaperSync.dmg)"   # sparkle:edSignature="…" length="…"

cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MoneyPaperSync</title>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$(LC_ALL=en_US.UTF-8 date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/MoneyPaperSync.dmg" type="application/octet-stream" $SIG_ATTRS />
    </item>
  </channel>
</rss>
XML
echo "Fertig: dist/MoneyPaperSync.dmg und dist/appcast.xml (Version $VERSION, Build $BUILD)"

if [ "$PUBLISH" = "--publish" ]; then
  NOTES=(--notes "Version $VERSION")
  [ -f dist/NOTES.md ] && NOTES=(--notes-file dist/NOTES.md)
  gh release create "v$VERSION" dist/MoneyPaperSync.dmg dist/appcast.xml --repo "$REPO" --target main \
    --title "MoneyPaperSync $VERSION" "${NOTES[@]}"
fi
