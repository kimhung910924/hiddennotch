# 변경 이력

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/)를 따르고,
버전은 [유의적 버전](https://semver.org/lang/ko/)을 따른다.

## [1.1] — 2026-08-28

### 더함

- **자동 업데이트(Sparkle).** 메뉴바 메뉴의 「업데이트 확인…」으로 직접 확인할 수도 있다.
  피드는 `rrllab.com`에 둔다 — 이 주소는 배포된 앱 안에 영구히 박히고 이미 깔린 앱이
  몇 년 뒤에도 계속 두드리므로, 호스팅을 갈아끼울 수 있는 자기 도메인이어야 한다.
- **앱 아이콘.** 응용 프로그램과 Spotlight에서 아이콘이 보인다.
- **배포 파이프라인.** Developer ID 서명 → 공증 → dmg → GitHub 릴리즈까지 한 줄로.
  자세한 건 [docs/RELEASING.md](docs/RELEASING.md).

### 바뀜

- Sparkle 키를 담을 `HiddenNotch-Info.plist`가 생겼다. `INFOPLIST_KEY_*` 빌드 설정으로는
  Sparkle 키를 넣을 수 없다 — Xcode가 아는 키 목록에 없어서 조용히 무시된다.
- 빌드 산출물이 `build/DerivedData`에서 `.build/DerivedData`로 옮겨졌다. `build/`는
  스팟라이트가 색인해서 응용 프로그램 검색에 Debug·Release 빌드가 설치본과 나란히 떴다.
- README를 영어 기본으로 바꾸고 한국어는 `README.ko.md`로 분리했다.

## [1.0]

첫 동작본.

- 노치가 있는 화면의 메뉴바 배경을 검게 유지한다
- 외부 모니터 연결·해제, 배경화면 변경, 잠자기 복귀, 재부팅 이후에도 상태가 유지된다
- 전체 재구성 · 지연 재확인 · 15초 Watchdog · 캐시 없음, 네 겹으로 지킨다

[1.1]: https://github.com/kimhung910924/hiddennotch/releases/tag/v1.1
