#!/bin/bash
# Developer ID 서명 → 공증 → DMG → 배포 판정까지 한 번에.
#
# 다른 둘(Fire·Workspace Shelf)은 SPM이라 번들을 손으로 조립하지만
# HiddenNotch는 Xcode 프로젝트다. 그래서 빌드 단계만 xcodebuild이고
# 그 뒤(서명·공증·dmg·판정)는 셋이 같다.
#
# 프로젝트 기본 서명은 ad-hoc(`-`)이라 남의 맥에서 안 열린다.
# 여기서 Developer ID + 하드닝 런타임으로 덮어쓴다.
# 공증 티켓은 앱과 dmg **양쪽에** 박는다(사용자는 dmg를 먼저 연다 —
# omni-windows/scripts/notarize-dmg.sh 2026-08-24 실측).
#
# 사용법:
#   ./scripts/release.sh            # dmg까지
#   ./scripts/release.sh --publish  # GitHub 릴리즈 업로드까지
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="HiddenNotch"
SCHEME="HiddenNotch"
TEAM_ID="D9FZ6BL5FD"
IDENTITY="Developer ID Application: RRLLAB (${TEAM_ID})"
SECRETS="${NOTARIZE_ENV:-$HOME/Desktop/app-development/omniai/_secrets/notarize.env}"

# Sparkle 자동 업데이트
SPARKLE_VERSION="2.9.6"
SPARKLE_TOOLS=".build/sparkle-tools"
REPO="kimhung910924/hiddennotch"
FEED_SLUG="hiddennotch"               # rrllab.com/apps/<slug>/appcast.xml
SITE="${RRLLAB_SITE:-$HOME/Desktop/app-development/omniai/rrl-lab-site}"

# 출력을 .build 아래(숨김 폴더)에 둔다. 그냥 build/에 두면 스팟라이트가 색인해서
# 응용 프로그램 검색에 Debug·Release 빌드가 설치본과 나란히 뜬다 (2026-08-28 실측).
DERIVED=".build/DerivedData"
APP="${DERIVED}/Build/Products/Release/${APP_NAME}.app"
DIST="dist"

PUBLISH=0
[ "${1:-}" = "--publish" ] && PUBLISH=1

[ -f "$SECRETS" ] || { echo "공증 자격 증명이 없다: $SECRETS" >&2; exit 1; }
set -a; source "$SECRETS"; set +a
: "${APPLE_API_KEY:?notarize.env에 APPLE_API_KEY가 없다}"
: "${APPLE_API_KEY_ID:?notarize.env에 APPLE_API_KEY_ID가 없다}"
: "${APPLE_API_ISSUER:?notarize.env에 APPLE_API_ISSUER가 없다}"

notarize() {
    xcrun notarytool submit "$1" \
        --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" \
        --wait --output-format json
}

echo "==> 테스트"
xcodebuild test -scheme "$SCHEME" -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" 2>&1 | tail -5

# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO 가 반드시 필요하다 (2026-08-28 실측).
# Xcode는 archive가 아닌 build 액션에서 Release 설정이어도 디버거 부착용
# com.apple.security.get-task-allow 를 주입한다. 그 상태로 공증을 넣으면
#   status: Invalid — "The executable requests the com.apple.security.get-task-allow entitlement."
# 로 거절당한다. 이 프로젝트는 entitlements 파일이 없어서 주입된 이 하나가 전부다.
echo "==> 빌드 (Release, Developer ID)"
rm -rf "$APP"
xcodebuild build -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp" 2>&1 | tail -5

[ -d "$APP" ] || { echo "앱이 안 나왔다: $APP" >&2; exit 1; }

# Xcode는 SPM이 넣어 준 Sparkle.framework를 ad-hoc 서명 그대로 둔다(2026-08-28 실측).
# 그 상태로 공증을 넣으면 Updater.app에서
#   "The binary is not signed with a valid Developer ID certificate"
# 로 거절당한다. 중첩 코드부터 안쪽 순서로 다시 서명한다 — 바깥을 먼저 서명하면
# 안쪽을 건드리는 순간 깨진다. --deep은 애플이 권장하지 않는다.
echo "==> Sparkle 재서명"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for target in \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE" \
    "$APP"
do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$target"
done

# 버전은 빌드 산출물의 plist가 진실이다(Xcode가 생성한다).
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"
echo "==> ${APP_NAME} ${VERSION}"

codesign --verify --strict --verbose=2 "$APP"

mkdir -p "$DIST"
rm -f "$ZIP" "$DMG"
echo "==> 앱 공증"
ditto -c -k --keepParent "$APP" "$ZIP"
notarize "$ZIP"
xcrun stapler staple "$APP"

echo "==> dmg 생성"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

echo "==> dmg 서명·공증"
codesign --sign "$IDENTITY" --timestamp -f "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> 판정 (accepted가 아니면 배포하면 안 된다)"
spctl -a -t open --context context:primary-signature -vv "$DMG"
spctl -a -vv "$APP"

# zip은 지우지 않는다. 공증 제출물이면서 동시에 Sparkle이 내려받는 업데이트 파일이다.
echo "==> 완료: $DMG"

# ── Sparkle appcast ───────────────────────────────────────
echo "==> Sparkle 서명"
if [ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]; then
    echo "  도구 내려받는 중 ($SPARKLE_VERSION)"
    mkdir -p "$SPARKLE_TOOLS"
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
        | tar -xJ -C "$SPARKLE_TOOLS"
fi

# sign_update는 Keychain의 개인키를 쓴다. 백업은 _secrets/sparkle-ed25519-private.key.
SIGN_OUTPUT="$("$SPARKLE_TOOLS/bin/sign_update" "$ZIP")"
ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -E 's/.*edSignature="([^"]+)".*/\1/')"
ZIP_LENGTH="$(echo "$SIGN_OUTPUT" | sed -E 's/.*length="([0-9]+)".*/\1/')"
[ -n "$ED_SIGNATURE" ] || { echo "서명을 못 만들었다: $SIGN_OUTPUT" >&2; exit 1; }

# 이 프로젝트는 Resources/Info.plist가 없다. Xcode가 만든 산출물의 plist가 진실이다.
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
MIN_SYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
FEED_URL="https://rrllab.com/apps/${FEED_SLUG}/appcast.xml"
NOTES_URL="https://rrllab.com/apps/${FEED_SLUG}/notes/${VERSION}.html"
ZIP_URL="https://github.com/${REPO}/releases/download/v${VERSION}/$(basename "$ZIP")"

if [ -d "$SITE" ]; then
    APPCAST="$SITE/public/apps/${FEED_SLUG}/appcast.xml"
    NOTES="$SITE/public/apps/${FEED_SLUG}/notes/${VERSION}.html"
    python3 scripts/update-appcast.py \
        --appcast "$APPCAST" --title "$APP_NAME" --feed "$FEED_URL" \
        --version "$VERSION" --build "$BUILD" \
        --url "$ZIP_URL" --length "$ZIP_LENGTH" --signature "$ED_SIGNATURE" \
        --min-system "$MIN_SYSTEM" --notes-url "$NOTES_URL" \
        --pub-date "$(date -R)"

    if [ ! -f "$NOTES" ]; then
        mkdir -p "$(dirname "$NOTES")"
        cat > "$NOTES" <<HTML
<!doctype html>
<meta charset="utf-8">
<title>${APP_NAME} ${VERSION}</title>
<h2>${APP_NAME} ${VERSION}</h2>
<ul>
  <li>이번 버전에서 달라진 점을 여기에 적어 주세요. 사용자가 업데이터에서 그대로 읽습니다.</li>
</ul>
HTML
        echo "  릴리즈 노트 초안: $NOTES  ← 내용을 채울 것"
    fi
else
    echo "  ⚠️  홈페이지 저장소가 없다: $SITE — appcast를 갱신하지 못했다" >&2
fi

# ── GitHub 릴리즈 ─────────────────────────────────────────

if [ "$PUBLISH" = "1" ]; then
    TAG="v${VERSION}"
    echo "==> GitHub 릴리즈 $TAG"
    gh release view "$TAG" >/dev/null 2>&1 \
        && gh release upload "$TAG" "$DMG" "$ZIP" --clobber \
        || gh release create "$TAG" "$DMG" "$ZIP" --title "$APP_NAME $VERSION" --generate-notes
    gh release view "$TAG" --json url --jq .url

    # appcast는 zip이 실제로 올라간 뒤에 공개한다. 순서가 반대면 앱이 404를 받는다.
    if [ -d "$SITE" ]; then
        echo "==> appcast 배포 (Vercel이 푸시를 받아 배포한다)"
        git -C "$SITE" add "public/apps/${FEED_SLUG}"
        git -C "$SITE" commit -q -m "chore(${FEED_SLUG}): appcast ${VERSION}" || echo "  바뀐 것 없음"
        git -C "$SITE" push -q
        echo "  $FEED_URL"
    fi
fi
