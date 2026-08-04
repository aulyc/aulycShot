<p align="center">
  <img src="images/app-banner.png" alt="aulycShot app banner" width="760" />
</p>

<h1 align="center">aulycShot</h1>

<p align="center">
  macOS 메뉴 막대 스크린샷 도구입니다. <code>⌘</code>를 두 번 탭해 캡처, 주석, 긴 스크린샷 병합, 고정까지 이어갈 수 있습니다.
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/aulyc/aulycShot?style=flat-square"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Swift 5.9" src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square"></a>
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.zh-TW.md">繁體中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest">다운로드</a> ·
  <a href="CHANGELOG.md">변경 내역</a> ·
  <a href="https://github.com/aulyc/aulycShot/issues">Issues</a>
</p>

**macOS에서 스크린샷을 빠르게 캡처하고, 표시하고, 공유하는 도구입니다.** 어디서든 `⌘`를 두 번 탭하면 창 캡처, 영역 캡처, 스크롤 병합, 주석 편집을 한 흐름으로 처리할 수 있습니다. 메뉴 막대에 상주하며 Dock 아이콘, 원격 측정, 구독, 외부 의존성이 없습니다.

<p align="center">
  <img src="images/editor.png" alt="aulycShot annotation editor" width="760" />
</p>

## aulycShot을 쓰는 이유

- **단축키 하나로 시작**: 기본 `⌘` 두 번 탭 또는 사용자가 지정한 전역 단축키로 실행합니다.
- **창 또는 영역 캡처**: 창 위에 마우스를 올리고 클릭하거나 원하는 영역을 Retina 해상도로 캡처합니다.
- **다시 편집할 수 있는 주석**: 화살표, 번호, 텍스트, 모자이크, 형광펜, 펜은 배치 후에도 이동, 회전, 수정, 실행 취소가 가능합니다.
- **긴 스크린샷 병합**: 선택 영역 안에서 스크롤하며 실시간 미리보기를 보고 병합한 뒤 계속 편집합니다.
- **스크린샷 고정**: 완성된 이미지를 다른 창 위에 고정해 참고할 수 있습니다.
- **Finder 이미지 직접 편집**: Finder에서 이미지 하나를 선택하고 같은 단축키를 누르면 원본을 건드리지 않고 편집기에 엽니다.
- **순수 AppKit**: SwiftUI, Electron, 외부 의존성 없이 작고 빠르게 동작합니다.

## 미리보기

<table>
<tr>
  <td width="50%" align="center"><img src="images/window-snap.png" alt="Smart window detection" /><br/><sub><b>창을 클릭해 캡처</b><br/>aulycShot이 창 경계를 자동으로 감지합니다.</sub></td>
</tr>
<tr>
  <td width="50%" align="center"><img src="images/scroll-stitch.png" alt="Scroll capture" /><br/><sub><b>긴 페이지 병합</b><br/>스크롤하며 결과를 실시간으로 확인합니다.</sub></td>
</tr>
</table>

## 요구 사항

- macOS 14.0 이상
- 손쉬운 사용 권한: 기본 `⌘` 두 번 탭 트리거에 사용
- 화면 기록 권한: ScreenCaptureKit 캡처에 사용
- Finder 자동화 권한: 선택한 이미지를 편집할 때 사용

## macOS 확인 경고

macOS에서 `Apple에서 "aulycShot"에 악성 소프트웨어가 있는지 확인할 수 없음` 같은 경고가 표시되면 신뢰하는 앱 번들에서 quarantine 플래그를 제거한 뒤 다시 여세요.

```bash
xattr -dr com.apple.quarantine /Applications/aulycShot.app
```

`/Applications`의 앱이 아니라 로컬에서 빌드한 사본을 실행 중이라면 실제 앱 위치로 경로를 바꾸세요. 예:

```bash
xattr -dr com.apple.quarantine ./.cache/build/aulycShot.app
```

이 명령은 이 저장소에서 다운로드한 빌드나 직접 빌드한 사본처럼 신뢰할 수 있는 빌드에만 실행하세요.

## 소스에서 빌드

```bash
./scripts/bundle.sh
```

개발 중에는 다음 스크립트로 빌드, 기존 앱 종료, 새 앱 실행 확인을 한 번에 처리할 수 있습니다.

```bash
bash scripts/rebuild-and-open.sh
```

## 사용법

1. `⌘ Command`를 두 번 탭하거나 사용자 단축키를 누르거나 메뉴 막대에서 스크린샷을 선택합니다.
2. 창을 클릭해 캡처하거나 원하는 영역을 드래그합니다.
3. 플로팅 도구 막대에서 주석, 스크롤 캡처, 저장, 고정, 확인을 선택합니다.
4. 초록 체크 또는 `Enter`로 결과를 클립보드에 복사합니다. `Esc` 또는 `x`로 취소합니다.

## 편집 도구

| 도구 | 기능 |
| --- | --- |
| 사각형 / 타원 | 색상과 두께를 선택해 도형을 그립니다 |
| 화살표 | 직선 화살표를 그리고 나중에 끝점과 곡선을 조절합니다 |
| 펜 / 형광펜 | 자유 곡선 또는 반투명 마커를 그립니다 |
| 모자이크 | 민감한 영역을 픽셀화합니다 |
| 번호 / 텍스트 | 번호 표시와 편집 가능한 텍스트를 추가합니다 |
| 스크롤 캡처 / 고정 | 결과 편집과 공유를 돕습니다 |

## 설정

설정에서 언어, 메뉴 막대 아이콘, 로그인 시 실행, 데모 모드, 단축키, 권한 바로가기를 조정할 수 있습니다. UI 언어는 简体中文과 English를 지원합니다.

## Star History

[aulycShot Star History 보기](https://www.star-history.com/?repos=aulyc%2FaulycShot&type=date&legend=top-left)

## 라이선스

[MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)
