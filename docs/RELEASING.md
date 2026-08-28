# 릴리즈 하는 법

## 한 줄

```bash
./scripts/release.sh --publish
```

버전만 올려두면 나머지는 전부 이어진다.

1. `swift test` / `xcodebuild test`
2. Release 빌드 + Developer ID 서명 (하드닝 런타임 + 타임스탬프)
3. 앱 공증 → 스테이플
4. dmg 생성 → 서명 → 공증 → 스테이플
5. `spctl` 판정 — **accepted가 아니면 거기서 멈춘다**
6. Sparkle 서명(`sign_update`)과 appcast 항목 생성
7. GitHub 릴리즈에 dmg + zip 업로드
8. appcast·릴리즈 노트를 rrllab.com 저장소에 커밋·푸시 (Vercel이 배포)

`--publish` 없이 실행하면 6번까지만 하고 멈춘다. 먼저 이렇게 확인하는 편이 안전하다.

## 버전 올리기

`HiddenNotch.xcodeproj`의 `MARKETING_VERSION`(표시용)과
`CURRENT_PROJECT_VERSION`(빌드 번호)을 올린다. Debug·Release 두 설정 모두다.

**`CFBundleVersion`(빌드 번호)을 반드시 같이 올려라.** Sparkle이 새 버전인지 판단할 때
보는 값이 이것이다. 표시용 버전만 올리면 업데이트가 안 내려간다.

## 릴리즈 노트

`release.sh`가 초안을 만든다.

```
<rrl-lab-site>/public/apps/hiddennotch/notes/<버전>.html
```

**`--publish` 전에 내용을 채워라.** 앱 안의 업데이터가 이 페이지를 그대로 보여준다.
비워 두면 사용자가 "여기에 이번 버전에서 바뀐 것을 적는다"를 읽는다.

`CHANGELOG.md`도 같이 갱신한다.

## 필요한 것

| 것 | 어디 |
|---|---|
| Developer ID 인증서 | 키체인 — `Developer ID Application: RRLLAB (D9FZ6BL5FD)` |
| 공증 자격 증명 | `~/Desktop/app-development/omniai/_secrets/notarize.env` |
| Sparkle 서명 개인키 | 키체인 + `_secrets/sparkle-ed25519-private.key` 백업 |
| 홈페이지 저장소 | `~/Desktop/app-development/omniai/rrl-lab-site` (`RRLLAB_SITE`로 바꿀 수 있다) |

⚠️ **Sparkle 개인키를 잃으면 이미 깔린 앱에 영영 업데이트를 못 보낸다.** 공증 키와 같은 급이다.

## 자주 걸리는 것

**공증이 `Invalid`로 떨어진다.** 로그를 받아 이유를 본다. 추측하지 마라.

```bash
set -a && source ~/Desktop/app-development/omniai/_secrets/notarize.env && set +a
xcrun notarytool log <submission-id> --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER"
```

실제로 겪은 것 둘:

- `The executable requests the com.apple.security.get-task-allow entitlement`
  → Xcode가 `build` 액션에서 디버거용 entitlement를 주입한다.
    `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`로 막는다.
- `The binary is not signed with a valid Developer ID certificate` (Sparkle의 Updater.app)
  → 중첩 코드가 ad-hoc으로 남았다. 안쪽부터 같은 신원으로 다시 서명해야 한다.

**`/Applications`의 기존 앱을 터미널로 못 바꾼다.** macOS 14부터 앱 관리 권한이 필요하다.
dmg를 열어 손으로 끌어다 놓아라. 한 번만 하면 그 뒤로는 Sparkle이 알아서 갈아끼운다.

**서명 신원이 바뀌면 권한이 리셋된다.** TCC는 권한을 코드 서명 신원에 묶는다.
개발 빌드(Apple Development)와 배포본(Developer ID)은 다른 신원이다.

## 개발 빌드

```bash
xcodebuild build -scheme HiddenNotch -configuration Release
```

배포용이 아니다. 남의 맥에서는 Gatekeeper가 막는다.
