# aulycShot 正式发布

## 发布身份

| 字段 | 值 |
|---|---|
| Release Profile | `macos-arm64-app` 1.0.0 |
| 架构 | Apple Silicon `arm64` only |
| 分发渠道 | 私有 GitHub 源码权威；`aulyc-dual-mirror-v1` 公开 GitHub/Gitee 正式产物镜像 |
| GitHub | `aulyc/aulycShot` / `origin` / `main` |
| 唯一版本源 | `aulycShot/App/Info.plist` |
| App Bundle ID | `com.aulyc.aulycshot` |
| 最低系统 | macOS 14.0 |
| 安装位置 | `/Applications/aulycShot.app` |

App 和 share extension 都必须只包含 `arm64` slice，并共享相同的版本、build、
Bundle ID、entitlements、Developer ID、Hardened Runtime 和公证信任。出现其他
架构或缺少任一信任检查都会阻断发布。

当前不发布测试版，也不触发 Homebrew。正式源码 branch/tag 只发布到私有 GitHub
仓库；同一个已签名、公证的 DMG 会原样发布到 GitHub 和 Gitee 两个公开安装包镜像。
两端保存完全一致的 `latest.json`，应用始终先访问 GitHub，失败后访问 Gitee。

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

该入口先执行中央 GitHub preflight，再只修改 `aulycShot/App/Info.plist`、
英文 `CHANGELOG.md` 和简体中文 `CHANGELOG.zh-CN.md`，并创建独立的
`chore: release 1.6.13` 元数据提交。两份 Changelog 的 `Unreleased` 都必须
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
extension 再签 App，使用 Apple 官方 `http://timestamp.apple.com/ts01` 服务写入
可信 timestamp 并启用 Hardened Runtime，生成并签名 DMG，等待 Apple notarization
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

provenance 记录 Profile、channel、版本、build、tag、Commit、`dirty: false`、arm64
架构、Bundle ID、Team ID、最低系统、Developer ID、Hardened Runtime、公证提交
ID、staple、Gatekeeper、DMG 和 App 可执行文件 SHA-256。它与 `Info.plist` 是不同
边界，不能互相替代。

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
`prepare -> preflight -> publish -> verify`。私有源码仓库不承担公开镜像角色。

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
`scripts/dual_mirror_release.py`。两端发布完全相同的 DMG、DMG checksum、最终
provenance、provenance checksum 和 `latest.json`：

```text
GitHub  https://github.com/aulyc/aulycShot-releases
Gitee  https://gitee.com/aulyc/aulycShot-releases
```

两个仓库都必须公开，但只保存正式安装包、校验和、provenance、按上述平台语言
策略生成的发布说明和更新清单，不改变中央 registry 中唯一的私有 GitHub 源码
绑定。GitHub 镜像由中央客户端通过 `gh` 管理；Gitee 由同一中央客户端使用
宿主机环境中的 `GITEE_ACCESS_TOKEN` 调用官方 OpenAPI。项目不再保存自己的
Gitee API 客户端。令牌不能写入仓库、日志、计划、状态、App、provenance 或
命令行参数。

镜像上传完成后，发布脚本生成同一份 `latest.json` 并分别写入两个仓库的 `main`：

```text
https://raw.githubusercontent.com/aulyc/aulycShot-releases/main/latest.json
https://gitee.com/aulyc/aulycShot-releases/raw/main/latest.json
```

清单绑定正式版本、build、tag、Commit、arm64、Bundle ID、DMG SHA-256、
provenance SHA-256，并分别列出 GitHub、Gitee 下载地址。应用先读取 GitHub
清单，只有连接失败、非 200 或清单无效时才读取 Gitee；随后先下载并验证
provenance，再按同一顺序下载 DMG。任一镜像的 SHA-256 不匹配都会拒绝；
provenance 必须再次绑定私有源码仓库、远端 Commit/tag 和同一 DMG，解包后的
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
- provenance 与 Git、DMG、挂载 App、已安装 App 或远端回读不一致
- 目标版本、标签、GitHub Release 或任一正式产物已经存在
- 任一公开镜像缺失、不是 public、已有冲突版本、DMG 回读哈希不一致，或两个
  `latest.json` 不能证明内容相同
- `GITEE_ACCESS_TOKEN` 不可用，或 Gitee Release 附件/清单写入与回读失败

标签或产物公开后禁止覆盖。任何内容变化都必须使用新的 PATCH 版本和更大的 build。
