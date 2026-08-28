# HiddenNotch — 인수인계

새 대화에서 이 파일부터 읽고 시작한다.
기획은 [HIDDENNOTCH-PLAN.md](HIDDENNOTCH-PLAN.md), 기술 메모는 [README.ko.md](README.ko.md)에 있다.

---

## 0. 지금 상황 한 줄

**2026-08-28 — 1.2 배포·설치 완료. 본래 기능은 잘 돈다.**

노치 숨김 자체는 문제가 없다. 남은 문제는 **메뉴바 메뉴를 열면 1.5초쯤 뒤 저절로 닫히는
것**인데, 이건 HiddenNotch 단독 문제가 아니라 Fire와 얽혀 있다.

## 1. 1.2에서 고친 것

`DisplayCoordinator.rebuild`가 조건과 무관하게 **항상** 오버레이 창을 전부 버리고 새로
만들고 있었다. 그 과정에서 키 윈도우가 바뀌면서 열려 있던 자기 메뉴가 함께 닫힌다.
재구성은 앱이 활성화될 때마다(`app-active`) 도는데, 사용자가 메뉴를 여는 순간이 곧 앱이
활성화되는 순간이라 열자마자 닫히는 것처럼 보였다.

이미 상태가 맞는지 확인하는 `overlays.isConsistent(with:)`가 있었는데 쓰지 않고 있었다.
맞으면 손대지 않도록 했다. 화면 구성이 실제로 바뀌었을 때는 예전처럼 전부 새로 만들므로,
부분 수정이 어긋난 채 굳는 문제(`OverlayController` 주석)는 그대로 피한다.

**⚠️ 이 수정으로 메뉴 닫힘은 해결되지 않았다.** 1.2 설치 후에도 메뉴는 1.5초 뒤 닫힌다.
원인이 다른 데 있다는 뜻이고, Fire를 죽이면 메뉴가 유지되므로 Fire 쪽을 더 파야 한다.
상세는 `../fire/HANDOFF.md`의 0절에 있다.

## 2. 지금 막힌 것

**Fire Bar에서 HiddenNotch 아이콘을 눌러 연 메뉴가 1.5초쯤 뒤 저절로 닫힌다.**

```
0.7초 ~ 2.1초   메뉴 열림 x=706   Fire 구분자 x909 (고정)
2.2초           메뉴 닫힘         Fire 구분자 x909 (그대로)
```

Fire가 숨김을 되돌려서 닫히는 게 아니다. 구분자가 움직이지 않았다.
메뉴가 뜬 직후 Fire를 죽이면 유지되므로 원인은 Fire 안이지만, 후보 여섯 개를 실험으로
배제한 상태다. 목록과 다음 단계는 `../fire/HANDOFF.md` 0절에 정리해 두었다.

## 3. 사용자가 직접 해야 하는 것

**HiddenNotch 아이콘이 메뉴바에서 물리적으로 맨 왼쪽에 있다.**

Fire의 숨김은 "구분자보다 왼쪽 전부"라, 맨 왼쪽 항목은 무언가를 하나라도 숨기는 한
**절대 보일 수 없다.** Fire 설정에서 MAIN으로 지정해도 말려든다.

측정한 물리적 순서:

```
HiddenNotch > MenubarX > Gemini > Workspace Shelf > AudioVideo > Fire > Claude > Owly > ...
```

Fire를 끄고 메뉴바에서 `⌘`+드래그로 HiddenNotch 아이콘을 Owly 오른쪽으로 옮겨야 한다.
`⌘`+드래그는 macOS가 실제 사람의 입력으로만 받아서 에이전트가 대신 못 한다.

## 4. 8/28에 끝난 것

- **배포 파이프라인** — `./scripts/release.sh --publish` 한 줄.
  절차와 함정은 [docs/RELEASING.md](docs/RELEASING.md)
- **Sparkle 자동 업데이트** — 피드는 `https://rrllab.com/apps/hiddennotch/appcast.xml`
- **앱 아이콘**, [CHANGELOG.md](CHANGELOG.md), README 영어 기본 + `README.ko.md` 분리

### 이 저장소에서만 걸렸던 것 (반복하지 말 것)

1. **패키지 참조를 `project.pbxproj`에 직접 넣을 때 객체 ID가 겹치면 프로젝트가 깨진다.**
   처음에 쓴 `…0060`, `…0061`이 기존 `PBXTargetDependency`와 겹쳐
   "The project is damaged"가 났다. 새 ID는 `grep -oE "AA[0-9]{22}"`로 먼저 확인할 것.
2. **`INFOPLIST_KEY_SU*`는 무시된다.** Xcode가 아는 키 목록에 없다.
   그래서 `HiddenNotch-Info.plist`를 만들고 `INFOPLIST_FILE`로 지정했다.
   `GENERATE_INFOPLIST_FILE=YES`가 켜져 있어 Xcode가 생성한 키들은 그 위에 얹힌다.
3. **Xcode는 SPM이 넣어 준 Sparkle.framework를 ad-hoc 서명으로 둔다.**
   그대로 공증에 넣으면 Updater.app에서
   "not signed with a valid Developer ID certificate"로 거절당한다.
   `release.sh`가 중첩 코드부터 안쪽 순서로 다시 서명한다.
4. **개발 빌드가 실행되지 않을 수 있다.** 앱은 ad-hoc, 캐시된 Sparkle은 Developer ID로
   서명돼 있으면 Team ID가 달라 dyld가 거부한다. 같은 신원으로 빌드하거나
   DerivedData를 지울 것.

## 5. 설치 방법

`/Applications`의 기존 앱은 터미널로 **덮어쓸 수 없다**(앱 관리 권한). 다만 **지우고 새로
넣는 것은 된다.** 에이전트가 설치까지 할 수 있다.

```bash
mv /Applications/HiddenNotch.app ~/.Trash/"HiddenNotch (옛버전).app"
MP=$(hdiutil attach dist/HiddenNotch-1.2.dmg -nobrowse -readonly | grep -o '/Volumes/.*')
ditto "$MP/HiddenNotch.app" /Applications/HiddenNotch.app
hdiutil detach "$MP"
```

⚠️ **같은 이름의 볼륨이 이미 붙어 있으면 엉뚱한 dmg에서 복사된다.** 실제로 이 때문에
1.2를 설치했는데 1.1이 들어갔다. `ls /Volumes/`로 먼저 확인하고, 마운트 경로를 변수로
받아서 쓸 것.

⚠️ 앱을 옮긴 뒤에는 **로그인 항목을 다시 등록**해야 한다. `SMAppService`가 등록 당시
경로를 물고 있다. 메뉴에서 "로그인 시 자동 실행"을 껐다 켜면 된다.

## 6. 현황판

전체 현황은 `~/Desktop/status/projects/mac-apps.md`에 있다.
