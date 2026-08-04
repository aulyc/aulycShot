<p align="center">
  <img src="images/app-banner.png" alt="aulycShot 应用横幅" width="760" />
</p>

<h1 align="center">aulycShot</h1>

<p align="center">
  macOS 上最顺手的菜单栏截图工具：双击 <code>⌘</code> 即刻截图、标注、长截图和钉图。
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
  <a href="https://github.com/aulyc/aulycShot/releases/latest">下载</a> ·
  <a href="CHANGELOG.md">更新日志</a> ·
  <a href="https://github.com/aulyc/aulycShot/issues">Issues</a>
</p>

**macOS 上最顺手的截图工具。** 双击 `⌘` 即开即用——窗口一点就贴边、选区像素级精准、长截图边滚边拼，再用浮动编辑器一气呵成完成标注。常驻菜单栏，不占 Dock，无遥测、无订阅、零第三方依赖。

<p align="center">
  <img src="images/editor.png" alt="aulycShot 标注编辑器——箭头、序号、马赛克、高亮和文字层叠在截图上，所有操作集中在一个浮动工具栏中" width="760" />
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest"><b>下载最新版本</b></a> &nbsp;·&nbsp;
  macOS 14+ &nbsp;·&nbsp; Apple Silicon（arm64）
</p>

## 为什么选 aulycShot

- **一个快捷键，零学习成本。** 在任意 app 中双击 `⌘` 即刻唤起 aulycShot；也可以在设置中录制任何全局快捷键。
- **控件、窗口、全屏智能选区，框选仍然精准。** 鼠标悬停自动识别可访问控件和窗口，按 `Tab` 切换到窗口或当前屏幕，也可以直接拖拽任意区域。
- **真正可二次编辑的标注。** 箭头、序号、文字、马赛克、高亮笔、画笔——放下之后还能拖、能转、能撤销，所见即所改。
- **长截图边滚边拼。** 在选区内滚动，实时预览拼接结果，合并后继续在同一个编辑器里改。
- **截图钉图。** 把成图钉在所有窗口之上，随时对照参考。
- **Finder 图片也能直接编辑。** 在 Finder 中选中一张图片，按下同一个快捷键即可载入编辑器，原文件不会被改动。
- **纯 AppKit 构建。** 没有 SwiftUI、Electron，也没有遥测。小、快、像 macOS 该有的样子。

## 功能预览

<table>
<tr>
  <td width="50%" align="center">
    <img src="images/window-snap.png" alt="智能窗口识别——绿色虚线自动贴合应用窗口边缘" /><br/>
    <sub><b>窗口一点即贴边</b><br/>无需精确拖拽，aulycShot 自动识别窗口边界。</sub>
  </td>
</tr>
<tr>
  <td width="50%" align="center">
    <img src="images/scroll-stitch.png" alt="长截图拼接：在选区内滚动并实时拼接出一张超长截图" /><br/>
    <sub><b>长截图边滚边拼</b><br/>在选区内滚动，画面实时合并，拼完还能继续编辑。</sub>
  </td>
</tr>
</table>

## 功能特性

- **直接编辑已有图片**：在 Finder（桌面或任意窗口）中选中一张图片文件，再触发截图快捷键，aulycShot 会跳过截图，直接把这张图载入标注编辑器。原文件不会被修改，编辑后的结果像普通截图一样进入剪贴板。
- **智能选区和自由框选**：悬停识别控件、图标和窗口，按 `Tab` 在控件、窗口和当前屏幕之间切换；按住鼠标拖动仍可框选任意区域。
- **多显示器支持**：在所有连接的屏幕上创建截图遮罩，并按 Retina 真实像素分辨率输出。
- **完整标注编辑器**：支持矩形、椭圆、箭头、画笔、高亮笔、马赛克、序号标注和文字。
- **标注可二次编辑**：可移动已有标注，调整颜色和尺寸；支持旋转、弯曲箭头/序号引线、修改文字、删除标注，以及撤销/重做。
- **长截图**：在选区内滚动时连续捕获画面，实时预览拼接结果，合并后继续编辑。
- **钉在屏幕**：把当前截图作为可拖动浮窗置顶显示，方便对照参考。
- **保存或复制**：可保存为 PNG，或确认后把 PNG/TIFF 写入剪贴板；也可以取消不输出。
- **自定义触发方式**：默认双击 `⌘`，也可在设置里录制全局快捷键。
- **设置与本地化**：支持简体中文和 English UI，并提供菜单栏图标开关、开机启动、演示模式、权限状态和快捷键录制。
- **菜单栏应用**：以 agent app 运行，不显示 Dock 图标。

## 环境要求

- macOS 14.0+
- 辅助功能权限：用于默认的双击 `⌘` 触发
- 屏幕录制权限：用于 ScreenCaptureKit 和屏幕内容捕获
- Finder 自动化权限：首次使用「编辑已选中的图片」时弹出

首次启动时，aulycShot 会直接运行并打开设置窗口。左下角只显示统一的「功能状态」；只有辅助功能和屏幕与系统音频录制权限都已开启时才为可用，否则截图和录屏入口会停止执行并显示整合授权说明。

## macOS 校验拦截

如果 macOS 弹出类似 `Apple 无法验证 “aulycShot” 是否包含恶意软件` 的提示，可以对你信任的应用包移除 quarantine 标记后再重新打开：

```bash
xattr -dr com.apple.quarantine /Applications/aulycShot.app
```

如果你运行的是本地构建版本，而不是 `/Applications` 里的副本，把路径替换成实际位置即可，例如：

```bash
xattr -dr com.apple.quarantine ./.cache/build/aulycShot.app
```

只应对你信任的构建执行这个命令，例如本仓库下载的版本或你本地自行构建的版本。

## 从源码构建

```bash
# 构建并打包为 .cache/build/aulycShot.app
./scripts/bundle.sh
```

本地开发时，可以使用下面的脚本重新构建、关闭旧进程、启动新应用，并确认应用已运行：

```bash
bash scripts/rebuild-and-open.sh
```

如需打包可拖拽安装的 DMG：

```bash
scripts/package-dmg.sh
```

应用包会输出到隐藏目录 `.cache/build/aulycShot.app`；DMG 会输出到 `dist/`。

## 使用方法

1. 双击 `⌘ Command`，按下自定义快捷键，或从菜单栏选择 **截图**。
2. 悬停并点击智能选区，按 `Tab` 切换控件、窗口和当前屏幕；也可以拖拽选择任意区域。
3. 使用浮动工具栏进行标注、长截图、保存、钉图、取消或确认。
4. 点击绿色对勾或按 `Enter` 复制最终图片到剪贴板；按 `Esc` 或点击 `x` 取消。

如果想编辑桌面上或 Finder 里已经存在的图片，先在 Finder 中点选一张图片文件让它处于选中状态，再触发同一个快捷键。aulycShot 会把文件复制到临时目录后载入编辑器，工具栏直接就绪。如果当前选中的不是恰好一张图片（没选中、选了多张、或选的不是图），快捷键会照常进入截图流程。

## 编辑器工具

| 工具 | 作用 |
|------|------|
| 矩形 / 椭圆 | 绘制描边形状，可选择颜色和线宽 |
| 箭头 | 绘制直线箭头；选中后可移动端点或弯曲箭头 |
| 画笔 | 绘制平滑的自由画笔线条 |
| 高亮笔 | 绘制半透明高亮，不会因重叠反复加深 |
| 马赛克 | 在敏感区域刷出像素化遮挡，可调整块大小 |
| 序号 | 添加自动递增的序号圆点；放置时拖拽可带出箭头 |
| 文字 | 添加可编辑单行文字，支持颜色和 10-100 pt 字号 |
| 撤销 / 重做 | 撤销或恢复编辑器操作 |
| 移动选区 | 选区完成后拖动整个截图区域 |
| 长截图 | 在选区内滚动并拼接画面，完成后继续编辑 |
| 保存 | 将当前结果保存为 PNG |
| 钉在屏幕 | 将当前结果置顶悬浮显示 |
| 确认 | 将最终结果复制到剪贴板 |

选中标注后，aulycShot 会显示对应的调整控件：形状、线条和文字支持旋转；箭头和序号引线支持弯曲；箭头端点可重新拖动；文字可再次编辑；选中标注可删除。

## 设置

从菜单栏打开设置后，可以配置：

- 语言：简体中文、English
- 是否显示菜单栏图标
- 是否开机自动启动
- 演示模式：允许外部录屏软件捕获 aulycShot 的遮罩和编辑器
- 截图快捷键：保留双击 `⌘`、录制自定义快捷键，或恢复默认
- 统一功能状态和辅助功能、屏幕录制权限入口

## 项目结构

- `aulycShot/App/`：应用入口、AppDelegate 和 bundle 元数据
- `aulycShot/Capture/`：截图遮罩、选区、窗口检测、ScreenCaptureKit 捕获、长截图拼接和剪贴板
- `aulycShot/Editor/`：标注模型、编辑画布、浮动工具栏、马赛克、长截图预览和钉图窗口
- `aulycShot/Trigger/`：双击 `⌘` 监听和自定义 Carbon 全局快捷键
- `aulycShot/UI/`：菜单栏控制器、toast、鼠标提示和工具提示
- `aulycShot/Settings/`：首次启动/设置窗口和偏好设置 UI
- `aulycShot/Utilities/`：默认值、本地化和开机启动支持
- `scripts/`：编译检查、打包、重启运行、图标和 DMG 辅助脚本

## 开发

```bash
# 对影响 Swift 构建的改动做快速编译验证
bash scripts/compile-check.sh

# 构建、重启并确认本地应用已运行
bash scripts/rebuild-and-open.sh
```

## 致谢

1. 感谢伟大的 AI 时代，让更多想法得以更快成为现实
2. 致敬 Codex 与 Claude，在创作与开发中持续并肩协作
3. 感谢 [Linux.do](https://linux.do) 社区在测试、反馈与讨论中的支持
4. 感谢每一位提交需求、报告问题和提出改进建议的用户
5. 感谢开源社区与开发工具带来的启发和帮助
6. 感谢 aulyc 一路以来的坚持与灵感

## 第三方许可证

- [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) 使用 MIT License。详见 [ThirdParty/PermissionFlow/LICENSE](ThirdParty/PermissionFlow/LICENSE)。

## Star History

[查看 aulycShot 的 Star History](https://www.star-history.com/?repos=aulyc%2FaulycShot&type=date&legend=top-left)

## License

[MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)
