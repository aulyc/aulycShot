# 双发布源接入

本项目显式采用中央可选策略 `aulyc-dual-mirror-v1` `1.6.0`，Release Profile
仍是 `macos-arm64-app`。私有 GitHub 仓库 `aulyc/aulycShot` 是唯一源码权威；
不得向 Gitee 推送源码。

中央渠道映射使用公开 `aulyc/aulycShot-releases` GitHub/Gitee 仓库。GitHub
说明为简体中文在前、English 在后，Gitee 仅简体中文；两端必须发布同一 DMG、
DMG checksum、最终 provenance、provenance checksum 和 `latest.json`。
该映射显式使用 `full-release-assets` / `dual-manifest`，因此上述五个正式附件均
属于公开渠道合同；`obsidian-community` / `obsidian-managed` 及其三文件附件
规则不适用于本 macOS App。构建目录和其他本地验证证据不会作为额外公开附件。

应用内更新器固定先读取 GitHub manifest，失败后读取 Gitee；无论来源均验证
版本、正整数 build、Commit、Bundle ID、arm64、DMG SHA-256、provenance
SHA-256、Developer ID、公证和发布产物身份。installed-runtime 只在明确请求
安装时验证；Gitee 只改变传输来源，不降低验证要求。

项目现有流程仍负责 DMG、最终 provenance、Changelog、签名、公证和发布产物
验证。
源码 branch/tag 已推送并回写最终 provenance 后：

```bash
bash scripts/dual-mirror-release.sh prepare \
  --provenance dist/<final>.release-provenance.json \
  --notes-zh-cn dist/release-notes.zh-CN.md \
  --notes-en dist/release-notes.en.md \
  --output-dir dist/dual-mirror-<version>

bash scripts/dual-mirror-release.sh preflight \
  --plan dist/dual-mirror-<version>/dual-mirror-plan.json
bash scripts/dual-mirror-release.sh publish \
  --plan dist/dual-mirror-<version>/dual-mirror-plan.json \
  --state dist/dual-mirror-<version>/dual-mirror-state.json
bash scripts/dual-mirror-release.sh verify \
  --plan dist/dual-mirror-<version>/dual-mirror-plan.json \
  --state dist/dual-mirror-<version>/dual-mirror-state.json
```

`prepare` 只生成项目内 staging；`preflight` 只读；只有明确授权的 `publish`
写远端。任一端失败都保留无凭据状态并只允许同计划向前重试；禁止覆盖旧版本。

纯正式发版不会写入 `/Applications`，完成时报告
`installationStatus: not-requested`。只有“正式发版安装”在双端发布完整成功后
执行项目安装入口。
