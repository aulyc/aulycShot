# aulycShot 正式发布

## 发布身份

| 字段 | 值 |
|---|---|
| Release Profile | `macos-arm64-app` 2.0.0 |
| 架构 | Apple Silicon `arm64` only |
| 分发渠道 | 公开 GitHub 源码与 Release；Gitee 同名仓仅承载正式产物 |
| GitHub | `aulyc/aulycShot` / `origin` / `main` |
| 唯一版本源 | `aulycShot/App/Info.plist` |
| App Bundle ID | `com.aulyc.aulycshot` |
| 最低系统 | macOS 14.0 |
| 安装位置 | `/Applications/aulycShot.app` |

App 和 share extension 都必须只包含 `arm64` slice，并共享相同的版本、build、
Bundle ID、entitlements、Developer ID、Hardened Runtime 和公证信任。出现其他
架构或缺少任一信任检查都会阻断发布。

当前不发布测试版，也不触发 Homebrew。渠道切换完成后，正式源码 branch/tag 和
GitHub Release 都位于公开 `aulyc/aulycShot`；同一个已签名、公证的 DMG 会原样
发布到该 GitHub Release 与仅分发用途的 Gitee `aulyc/aulycShot`。两端 Release
均只包含该 DMG；两端更新渠道保存完全一致的 Schema v2 `latest.json` 和按版本
不可覆盖的 provenance，应用先访问 GitHub，失败后访问 Gitee。

## 发布渠道

```text
GitHub Release  https://github.com/aulyc/aulycShot/releases
GitHub manifest https://raw.githubusercontent.com/aulyc/aulycShot/release-channel/latest.json
Gitee Release   https://gitee.com/aulyc/aulycShot/releases
Gitee manifest  https://gitee.com/aulyc/aulycShot/raw/main/latest.json
```

`1.8.10` 已完成公开渠道迁移，`1.8.11` 已移除旧 `aulycShot-releases` 兼容仓库。
`1.8.12` 采用 `aulyc-dual-mirror-v1` 1.7.0 的 `macos-compact` 模式和 Schema v2。
由于 `1.8.11` 只识别 Schema v1，这次需要从 Release 手动更新；`1.8.12` 同时保留
v1 读取能力并支持 v2，之后继续使用应用内自动更新。

## 版本和发布提交

显示版本取自 `CFBundleShortVersionString`，build 取自 `CFBundleVersion`。组装时
App 直接复制权威 plist，share extension 版本由 `scripts/bundle.sh` 同步。检查：

```bash
make version-check
```

正式版本使用稳定 SemVer，build 必须大于当前值。功能改动必须先形成普通提交并保持
工作区干净；随后执行：

```bash
make prepare-formal-release TARGET_VERSION=1.8.12 TARGET_BUILD=514
```

该入口先执行中央 GitHub preflight，再只修改 `aulycShot/App/Info.plist`、
英文 `CHANGELOG.md` 和简体中文 `CHANGELOG.zh-CN.md`，并创建独立的
`chore: release 1.8.12` 元数据提交。两份 Changelog 的 `Unreleased` 都必须
包含对应内容，缺少任一语言都会阻断正式版本准备。

## 标签前门禁

```bash
make release-check
make release-tag
```

`release-check` 要求 `main`、干净工作区、精确发布提交和 dated Changelog，然后
执行中央 strict scan、编译、Swift 测试和与最终路径一致的 arm64 Release 候选
构建。候选必须是 Developer ID 签名，App 与 share extension 都只包含 `arm64`
并启用 Hardened Runtime。

打包前还会执行 `make icon-check` 的等价只读检查，确认菜单栏 SVG、Dock/About
使用的 ICNS、分享扩展 ICNS 和 Asset Catalog PNG 全部来自
`design/iconMark.svg`，且生成器和资产哈希与 `design/icon-assets.generated.json`
一致。`verify-runtime-resources` 会继续核对 App 内实际封装的图标，详情见
`docs/ICON_ASSETS.md`。

GitHub hosted macOS runner 无法为 SwiftPM AppKit 窗口测试提供稳定的交互式
WindowServer 会话，因此 CI 以 `AULYC_SKIP_WINDOW_SERVER_TESTS=1` 只跳过
`ToolTipWindowTests` 的真实窗口排序用例。本机正式 `release-check` 不设置该变量，
仍会执行完整的窗口创建、附着、移动、停用清理和可见性断言。

`release-tag` 只在门禁通过后创建或验证与版本完全一致、不带 `v` 的 annotated
tag。已有且指向其他 Commit 的标签会被拒绝，不会移动或覆盖。

## 精确标签正式构建

凭据只使用宿主机 Keychain 中已有的 Developer ID 和 `notarytool` profile：

```bash
make release-formal \
  DEVELOPER_ID_APPLICATION='Developer ID Application: nan ma (M9M7M2ARFD)' \
  NOTARY_PROFILE=aulyc-notary
```

脚本从 annotated tag 创建隔离 worktree，构建 arm64 Release App，先签 share
extension 再签 App，使用 `codesign` 的 Apple 默认时间戳服务写入可信 timestamp
并启用 Hardened Runtime，生成并签名 DMG，等待 Apple notarization
`Accepted`，执行 staple、`stapler validate`、DMG/App Gatekeeper 验证，再从挂载
DMG 的 App 验证运行时资源布局并生成 release provenance。隔离源码在构建前后都
必须 clean。

产物位于 `dist/`：

```text
aulycShot-<version>-build.<build>-arm64.dmg
aulycShot-<version>-build.<build>-arm64.dmg.sha256
aulycShot-<version>-build.<build>-arm64.release-provenance.json
aulycShot-<version>-build.<build>-arm64.release-provenance.json.sha256
```

provenance 记录 Profile、Profile 版本、channel、版本、build、tag、Commit、
`dirty: false`、arm64 架构、Bundle ID、Team ID、最低系统、Developer ID、
Hardened Runtime、公证提交 ID、staple、Gatekeeper、DMG 和 App 可执行文件
SHA-256。Profile ID 和版本必须从 `.codex/standards.json` 的当前 macOS 产物声明
读取；生成、复核、安装和发布入口都会拒绝缺失或不一致的 Profile 版本。它与
`Info.plist` 是不同边界，不能互相替代。

## 产物和安装后验证

只读复核 DMG 及挂载 App：

```bash
make verify-artifact RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

这是正式发版的产物门禁，不写入 `/Applications`。`正式发版`和`完整发版`只执行
构建、发布、双端回读和一致性校验，安装状态报告为 `not-requested`。

正式安装并验证：

```bash
make install-release RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

只有用户明确要求“正式发版安装”或“安装正式版”时才执行安装；前者安装本次发布
的精确 provenance，后者只安装既有已验证发布，不创建新版本、标签或 Release。

安装入口先复核产物，再安全替换 `/Applications/aulycShot.app`，失败时回滚旧 App，
不删除设置、历史、截图、Keychain 或隐私数据。随后核对版本、build、Commit、tag、
channel、`dirty: false`、arm64-only、Developer ID、Team ID、Hardened Runtime 和
Gatekeeper，并从 `/Applications` 启动真实二进制。

只读复核已安装 App：

```bash
make verify-installed RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

## 正式 GitHub 源码发布

产物验证后执行：

```bash
make publish-release RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

入口重新验证 DMG 与挂载 App，不检查或修改已安装 App；随后调用中央 gate 原子
推送 `main` 和 annotated tag，
回读远端 branch 与 peeled tag Commit，补齐 provenance 的远端源码字段并刷新其
SHA-256。只有远端标签和最终 provenance 已验证后，才进入中央双镜像
`prepare -> preflight -> publish -> verify`。公开 GitHub 源码仓同时承担 GitHub
Release 角色。

发布说明按平台生成：中央工具把项目提供的中文和英文正文组合为公开 GitHub
中文在前、英文在后的双语 Markdown；Gitee 只使用简体中文。项目原始正文生成
入口为：

```bash
python3 scripts/release_tool.py release-notes \
  --version <version> --channel gitee --output <release-notes.zh-CN.md>
python3 scripts/release_tool.py release-notes \
  --version <version> --channel english --output <release-notes.en.md>
```

随后 `scripts/publish-update-mirrors.sh` 只做项目验证和参数映射，并调用中央
`scripts/dual_mirror_release.py`。两端 Release 只发布完全相同的 DMG：

```text
GitHub  https://github.com/aulyc/aulycShot
Gitee  https://gitee.com/aulyc/aulycShot
```

两个仓库都必须公开。GitHub 同时保存源码、权威标签和正式 Release；Gitee 只保存
正式安装包、简体中文发布说明和更新元数据，并用仓库说明指向 GitHub 源码。DMG
checksum 和 provenance checksum 保留在本地 `verificationEvidence`，不上传为 Release
附件。GitHub Release 由中央客户端通过 `gh` 管理；Gitee 由同一中央客户端使用
宿主机环境中的 `GITEE_ACCESS_TOKEN` 调用官方 OpenAPI。项目不再保存自己的
Gitee API 客户端。令牌不能写入仓库、日志、计划、状态、App、provenance 或
命令行参数。

两端 DMG Release 完成后，发布脚本先把最终 provenance 以
`updates/<version>/<file>` 写入 Gitee `main`，再更新 Gitee `latest.json`；随后以
同一路径写入 GitHub `release-channel`，再更新 GitHub `latest.json`，最后逐字节
回读两端。版本化 provenance 只能创建或复用完全相同的内容，不得覆盖。

```text
https://raw.githubusercontent.com/aulyc/aulycShot/release-channel/latest.json
https://gitee.com/aulyc/aulycShot/raw/main/latest.json
```

Schema v2 清单绑定正式版本、build、tag、Commit、arm64、Bundle ID、Team ID、
最低系统、DMG SHA-256、provenance SHA-256，并分别列出 GitHub/Gitee 的 Release
DMG 地址与 raw 版本化 provenance 地址。应用先读取新 GitHub 清单，失败后读取
Gitee；随后先下载并验证 provenance，再按清单内固定的
GitHub、Gitee 顺序下载 DMG。任一镜像的 SHA-256 不匹配都会拒绝；
provenance 必须再次绑定唯一 GitHub 源码仓库、远端 Commit/tag 和同一 DMG，解包后的
App 还必须通过 Developer ID、固定 Team ID、Bundle ID、最低系统、版本/build、
Commit、Hardened Runtime、arm64-only、嵌套扩展签名和 Gatekeeper 验证。

若源码 branch/tag 已成功而镜像步骤需要单独重试，使用：

```bash
make publish-update-mirrors RELEASE_PROVENANCE=/absolute/path/aulycShot-....release-provenance.json
```

公开镜像不得从不同源码重建产物，也不得覆盖已发布版本。中央 staging 保存在
`dist/dual-mirror-<version>/`，其中 `dual-mirror-state.json` 用于无凭据、
不可覆盖的安全重试。

## 发布阻断条件

- 项目未完成中央登记或 strict scan 不通过
- GitHub 目标、remote URL、正式分支或凭据能力不匹配
- 工作区不干净、发布提交混入功能代码或 Changelog 缺少精确版本
- tag 不是 annotated tag、不是稳定 SemVer、未指向发布提交或远端已占用
- Swift 构建、测试、arm64 候选或精确标签隔离构建失败
- App 或 share extension 不是 arm64-only，或缺少 Developer ID、timestamp、Hardened Runtime
- DMG 签名、公证、staple、Gatekeeper 或 SHA-256 任一步失败
- provenance 的 Profile ID/版本与 `.codex/standards.json` 不一致，或 provenance
  与 Git、DMG、挂载 App、已安装 App、远端回读不一致
- 目标版本、标签、GitHub Release 或任一正式产物已经存在
- 任一公开镜像缺失、不是 public、已有冲突版本、Release 不是仅含同一 DMG、DMG
  回读哈希不一致，或两个版本化 provenance / `latest.json` 不能证明内容相同
- `GITEE_ACCESS_TOKEN` 不可用，或 Gitee Release / 更新元数据写入与回读失败

标签或产物公开后禁止覆盖。任何内容变化都必须使用新的 PATCH 版本和更大的 build。
