# aulycShot 正式发布

## 发布身份

| 字段 | 值 |
|---|---|
| Release Profile | `macos-arm64-app` 1.0.0 |
| 项目适配 | Universal 2，`arm64` + `x86_64` |
| 分发渠道 | Developer ID DMG，私有 GitHub Release |
| GitHub | `aulyc/aulycShot` / `origin` / `main` |
| 唯一版本源 | `aulycShot/App/Info.plist` |
| App Bundle ID | `com.aulyc.aulycshot` |
| 最低系统 | macOS 14.0 |
| 安装位置 | `/Applications/aulycShot.app` |

Profile 原生要求 Apple Silicon `arm64`。本项目延续 Universal 2 分发并做显式
适配：App 和 share extension 都必须同时包含 `arm64` 与 `x86_64`，两个 slice
共享相同的版本、build、Bundle ID、entitlements、Developer ID、Hardened Runtime
和公证信任。缺少任一 slice 或任一信任检查都会阻断发布。

当前不发布测试版，不生成自动更新 feed，也不触发 Homebrew。正式版本只通过私有
GitHub Release 提供手动下载。

## 版本和发布提交

显示版本取自 `CFBundleShortVersionString`，build 取自 `CFBundleVersion`。组装时
App 直接复制权威 plist，share extension 版本由 `scripts/bundle.sh` 同步。检查：

```bash
make version-check
```

正式版本使用稳定 SemVer，build 必须大于当前值。功能改动必须先形成普通提交并保持
工作区干净；随后执行：

```bash
make prepare-formal-release TARGET_VERSION=1.6.13 TARGET_BUILD=495
```

该入口先执行中央 GitHub preflight，再只修改 `aulycShot/App/Info.plist` 和
`CHANGELOG.md`，并创建独立的 `chore: release 1.6.13` 元数据提交。

## 标签前门禁

```bash
make release-check
make release-tag
```

`release-check` 要求 `main`、干净工作区、精确发布提交和 dated Changelog，然后
执行中央 strict scan、编译、Swift 测试和与最终路径一致的 Universal 2 Release
候选构建。候选必须是 Developer ID 签名，App 与 share extension 都包含两个架构
并启用 Hardened Runtime。

`release-tag` 只在门禁通过后创建或验证与版本完全一致、不带 `v` 的 annotated
tag。已有且指向其他 Commit 的标签会被拒绝，不会移动或覆盖。

## 精确标签正式构建

凭据只使用宿主机 Keychain 中已有的 Developer ID 和 `notarytool` profile：

```bash
make release-formal \
  DEVELOPER_ID_APPLICATION='Developer ID Application: nan ma (M9M7M2ARFD)' \
  NOTARY_PROFILE=aulyc-notary
```

脚本从 annotated tag 创建隔离 worktree，构建 Universal 2 Release App，先签 share
extension 再签 App，启用 timestamp 和 Hardened Runtime，生成并签名 DMG，等待
Apple notarization `Accepted`，执行 staple、`stapler validate`、DMG/App Gatekeeper
验证，再从挂载 DMG 的 App 生成 release provenance。隔离源码在构建前后都必须
clean。

产物位于 `dist/`：

```text
aulycShot-<version>-build.<build>-universal2.dmg
aulycShot-<version>-build.<build>-universal2.dmg.sha256
aulycShot-<version>-build.<build>-universal2.release-provenance.json
aulycShot-<version>-build.<build>-universal2.release-provenance.json.sha256
```

provenance 记录 Profile、channel、版本、build、tag、Commit、`dirty: false`、两个
架构、Bundle ID、Team ID、最低系统、Developer ID、Hardened Runtime、公证提交
ID、staple、Gatekeeper、DMG 和 App 可执行文件 SHA-256。它与 `Info.plist` 是不同
边界，不能互相替代。

## 产物和安装后验证

只读复核 DMG 及挂载 App：

```bash
make verify-artifact RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

正式安装并验证：

```bash
make install-release RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

安装入口先复核产物，再安全替换 `/Applications/aulycShot.app`，失败时回滚旧 App，
不删除设置、历史、截图、Keychain 或隐私数据。随后核对版本、build、Commit、tag、
channel、`dirty: false`、两个架构、Developer ID、Team ID、Hardened Runtime 和
Gatekeeper，并从 `/Applications` 启动真实二进制。

只读复核已安装 App：

```bash
make verify-installed RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

## 正式 GitHub 源码发布

安装验证后执行：

```bash
make publish-release RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

入口重新验证产物与已安装 App，调用中央 gate 原子推送 `main` 和 annotated tag，
回读远端 branch 与 peeled tag Commit，补齐 provenance 的远端源码字段并刷新其
SHA-256。只有远端标签已验证后，才以 `gh release create --verify-tag` 创建私有
GitHub Release 并上传 DMG、checksums 和 provenance。该流程不会创建隐式标签、
自动更新 feed 或 Homebrew dispatch。

## 发布阻断条件

- 项目未完成中央登记或 strict scan 不通过
- GitHub 目标、remote URL、正式分支或凭据能力不匹配
- 工作区不干净、发布提交混入功能代码或 Changelog 缺少精确版本
- tag 不是 annotated tag、不是稳定 SemVer、未指向发布提交或远端已占用
- Swift 构建、测试、Universal 2 候选或精确标签隔离构建失败
- App 或 share extension 缺少任一架构、Developer ID、timestamp 或 Hardened Runtime
- DMG 签名、公证、staple、Gatekeeper 或 SHA-256 任一步失败
- provenance 与 Git、DMG、挂载 App、已安装 App 或远端回读不一致
- 目标版本、标签、GitHub Release 或任一正式产物已经存在

标签或产物公开后禁止覆盖。任何内容变化都必须使用新的 PATCH 版本和更大的 build。
