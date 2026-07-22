# 图标资产

## 单一几何源

`design/iconMark.svg` 是截图框和手写小写 `a` 的唯一几何源，也统一保存小写
`a` 在截图框内的垂直位置。不要直接修改下列派生文件：

- `design/menuBarIcon.svg`
- `design/appIcon.svg`
- `Resources/AppIcon.icns`
- `Resources/Assets.xcassets/AppIcon.appiconset/*`
- `design/icon-assets.generated.json`

菜单栏图标使用模板黑色和较粗线宽；App 图标保留深色背景、浅色线条和适合
Dock 的线宽。两者可以有不同呈现样式，但路径和小写 `a` 的位置只能来自
`design/iconMark.svg`。

## 更新和验证

修改几何源后运行：

```bash
make icons
```

该命令会重新生成两个 SVG、ICNS、Asset Catalog PNG 和哈希清单。随后可运行：

```bash
make icon-check
```

`scripts/bundle.sh` 会在编译前自动执行同一个只读检查。任何源文件、生成脚本或
派生资产发生漂移都会阻断本地打包、CI 和正式发布；构建过程不会自动改写源码，
因此精确标签构建仍保持干净。

## 运行时调用关系

| 使用位置 | 打包资源 | 运行时入口 |
| --- | --- | --- |
| 菜单栏 | `Contents/Resources/MenuBarIcon.svg` | `StatusBarController.statusBarIcon()` |
| Dock | `Contents/Resources/AppIcon.icns` | `Info.plist` 的 `CFBundleIconFile` |
| 关于 | 与 Dock 相同 | `NSApp.applicationIconImage` |
| 分享扩展 | 扩展内的 `AppIcon.icns` | 分享扩展 `Info.plist` |

`verify-runtime-resources` 会核对打包后的这些图标是否与仓库中的已生成资产完全
一致，安装后验证也复用该检查。
