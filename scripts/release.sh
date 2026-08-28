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

DERIVED="build/DerivedData"
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

rm -f "$ZIP"
echo "==> 완료: $DMG"

if [ "$PUBLISH" = "1" ]; then
    TAG="v${VERSION}"
    echo "==> GitHub 릴리즈 $TAG"
    gh release view "$TAG" >/dev/null 2>&1 \
        && gh release upload "$TAG" "$DMG" --clobber \
        || gh release create "$TAG" "$DMG" --title "$APP_NAME $VERSION" --generate-notes
    gh release view "$TAG" --json url --jq .url
fi
