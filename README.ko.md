# HiddenNotch

*[English](README.md)*
*[변경 이력](CHANGELOG.md)* · *[릴리즈 방법](docs/RELEASING.md)*

MacBook 메뉴바 배경을 검게 유지해 노치를 눈에 띄지 않게 하는 초경량 macOS 앱.

외부 모니터 연결·해제, 배경화면 변경, 잠자기 복귀, 재부팅 이후에도 조작 없이 상태가 유지된다.
앱 584KB, 상주 메모리 42MB. Dock 아이콘 없이 메뉴바에만 산다.

## 다운로드

**[HiddenNotch 1.1 내려받기 (dmg)](https://github.com/kimhung910924/hiddennotch/releases/latest)**

- macOS 13 Ventura 이상
- Apple 공증을 마쳤다. 경고 없이 열린다
- dmg를 열고 HiddenNotch를 `응용 프로그램`으로 끌어다 놓는다
- 별도 권한을 요구하지 않는다

## 문의

[rrllab.com](https://rrllab.com) · contact@rrllab.com

---

기획: [HIDDENNOTCH-PLAN.md](HIDDENNOTCH-PLAN.md)

## 요구 사항

- macOS 13 Ventura 이상
- Xcode 16 이상 (프로젝트는 파일 시스템 동기화 그룹을 사용한다)
- 외부 의존성 없음

## 빌드와 실행

```bash
xcodebuild -scheme HiddenNotch -configuration Release build
```

```bash
xcodebuild test -scheme HiddenNotch -configuration Debug
```

Xcode에서 열어 실행해도 된다. Dock에는 나타나지 않고 메뉴바 오른쪽에 아이콘만 생긴다.

### 배포본 만들기

```bash
./scripts/release.sh            # Developer ID 서명·공증·dmg
./scripts/release.sh --publish  # GitHub 릴리즈 업로드까지
```

## 동작 방식

배경화면 파일을 건드리지 않는다. 노치가 있는 화면의 상단 메뉴바 영역에 검은 패널을
**배경화면 바로 위, 나머지 모든 것의 아래**(`kCGDesktopIconWindowLevel + 1`)에 깔아 둔다.
메뉴바 자체는 반투명이라 그 뒤가 검으면 메뉴바 배경과 노치 양옆이 함께 검게 보이고,
메뉴바 글자와 아이콘은 그대로 보인다.

레벨을 낮게 두는 이유는 메뉴바가 **없는** 상황 때문이다. 미션 컨트롤과 전체화면 앱은
화면 맨 위까지 자기 UI를 그리는데, 패널이 그 위에 있으면 UI를 잘라먹는다(미션 컨트롤에서
데스크탑 썸네일 윗부분이 잘리는 증상). 메뉴바 영역은 원래 일반 창이 침범하지 못하는
자리라 낮은 레벨에 둬도 평상시에는 가려지지 않는다.

- 패널은 `ignoresMouseEvents = true`라 클릭을 가로채지 않는다.
- 모든 Space에 참여하고(`canJoinAllSpaces`), Cmd-Tab과 Mission Control 순환에서 빠진다.
- 오버레이 높이는 하드코딩하지 않고 화면마다 safe area·보조 영역·실제 메뉴바 높이 중
  최댓값으로 계산한다. 화면마다 값이 다르다(예: 내장 33pt, 외부 30pt).
- 외부 모니터는 메뉴바가 있어도 `visibleFrame`이 줄어들지 않아 높이를 알 수 없다.
  그래서 메뉴바 창의 실제 좌표를 창 목록에서 읽어 보완한다(`MenuBarProbe`).
  좌표와 소유자만 읽으므로 화면 기록 권한이 필요 없고, private API도 아니다.

- AppKit이 창을 메뉴바 아래로 밀어내는 기본 동작은 `constrainFrameRect`를 재정의해 끈다.
  이 한 줄이 없으면 검은 띠가 메뉴바 높이만큼 아래로 내려가 앉는다.

## 외부 모니터

기본값은 기획안대로 **노치 화면에만** 적용이다. 메뉴의 `외부 모니터에도 적용`을 켜면
노치가 없는 외부 모니터의 메뉴바까지 검게 만든다. 기획안 §4 기본값과 완료 기준 7번을
기본 상태에서 그대로 지키기 위해 항상 켜두지 않고 토글로 뒀다.

이 설정은 `UserDefaults`의 세 번째 값(`applyToAllScreens`)으로, 기획안 §9가 정한
두 값 원칙에서 벗어난다. 다만 화면 ID·좌표·해상도를 저장하지 않는다는 핵심 원칙은
그대로다.

## 상태가 풀리지 않게 하는 장치

1. **전체 재구성** — 화면이 바뀌면 기존 창 프레임을 고쳐 쓰지 않고 전부 버린 뒤 새로 만든다.
2. **지연 재확인** — 외부 모니터를 연결한 직후 macOS는 화면 목록과 좌표를 한 번에 확정하지
   않는다. 즉시 적용한 뒤 0.5초·1.5초·3초에 다시 확인한다. 몰려 오는 이벤트는 debounce한다.
3. **Watchdog** — 15초마다 화면 수·오버레이 수·프레임 일치 여부를 값 비교만으로 점검하고,
   어긋나면 스스로 재구성한다. 이벤트 알림을 놓쳐도 복구된다.
4. **캐시 없음** — 화면 ID·좌표·해상도는 저장하지 않는다. `UserDefaults`에 있는 값은
   `isEnabled`와 `launchAtLoginRequested` 둘뿐이다.

## 로그인 시 자동 실행

`SMAppService.mainApp`을 쓴다. macOS가 사용자 승인을 요구하는 상태(`requiresApproval`)면
메뉴에 "로그인 항목 승인 필요" 항목이 나타나고, 선택하면 시스템 설정의 로그인 항목 화면이 열린다.

ad-hoc 서명 상태(개발 빌드)에서는 등록이 실패할 수 있다. 실제 자동 실행을 검증할 때는
`/Applications`에 옮긴 뒤 확인하는 편이 안정적이다.

## 확인된 것과 남은 것

실기(노치 내장 화면 + 외부 모니터 연결) 확인:

- 노치 화면만 대상으로 잡고 외부 모니터에는 오버레이를 만들지 않는다.
- 오버레이가 내장 화면 상단에 정확히 1470×33으로 놓인다(메뉴바 영역과 일치).
- 유닛 테스트 16개 통과.

직접 눈으로 확인이 필요한 항목(기획안 Phase 0 판정 기준):

- 메뉴바 글자·아이콘이 가려지지 않는지
- 전체화면 앱에서 상단 콘텐츠를 덮지 않는지 — 화면이 보고하는 메뉴바/safe area 값이
  0으로 떨어지면 오버레이가 자동으로 사라지도록 되어 있으나, macOS 버전에 따라 값이
  유지될 수 있어 실사용 확인이 필요하다.
- 메뉴바 자동 숨김 설정에서의 동작

## 구조

```text
HiddenNotch/
├── App/          진입점, 앱 수명주기
├── StatusBar/    메뉴바 아이콘과 메뉴
├── Display/      화면 스냅샷, 노치 감지, 재구성 조율
├── Overlay/      검은 패널과 좌표 계산
├── Stability/    시스템 이벤트 감시, debounce·재시도, watchdog
├── LoginItem/    SMAppService 등록
└── Settings/     UserDefaults 두 값
```
