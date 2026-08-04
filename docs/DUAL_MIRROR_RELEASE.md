# 双发布源接入

本项目显式采用中央可选策略 `aulyc-dual-mirror-v1` `1.6.0`，Release Profile
仍是 `macos-arm64-app`。目标拓扑以公开 GitHub 仓库 `aulyc/aulycShot` 作为唯一
源码权威、正式标签和 GitHub Release 仓；Gitee `aulyc/aulycShot` 只承载 Release、
附件、`latest.json` 和指向 GitHub 源码的说明，不得向 Gitee 推送源码。

目标中央渠道映射使用上述同名 GitHub/Gitee 仓库。GitHub 说明为简体中文在前、
English 在后，Gitee 仅简体中文；两端必须发布同一 DMG、
DMG checksum、最终 provenance、provenance checksum 和 `latest.json`。
该映射显式使用 `full-release-assets` / `dual-manifest`，因此上述五个正式附件均
属于公开渠道合同；`obsidian-community` / `obsidian-managed` 及其三文件附件
规则不适用于本 macOS App。构建目录和其他本地验证证据不会作为额外公开附件。

应用内更新器优先读取新 GitHub manifest，失败后读取新 Gitee；迁移期间再依次
尝试旧 GitHub 和旧 Gitee manifest。无论来源均验证
版本、正整数 build、Commit、Bundle ID、arm64、DMG SHA-256、provenance
SHA-256、Developer ID、公证和发布产物身份。installed-runtime 只在明确请求
安装时验证；Gitee 只改变传输来源，不降低验证要求。

## 渠道迁移

新地址为：

```text
GitHub Release  https://github.com/aulyc/aulycShot/releases
GitHub manifest https://raw.githubusercontent.com/aulyc/aulycShot/release-channel/latest.json
Gitee Release   https://gitee.com/aulyc/aulycShot/releases
Gitee manifest  https://gitee.com/aulyc/aulycShot/raw/main/latest.json
```

切换前必须先通过旧 `aulycShot-releases` 渠道正式发布一个包含新旧地址兼容能力的
版本。该版本回读验证成功后，才能完成 GitHub 公开审计、创建 Gitee 同名分发仓、
切换中央渠道映射，并把同一正式版本及完全一致的产物发布到新地址。旧
GitHub/Gitee 镜像继续保持公开、只读和不可覆盖，供尚未升级的客户端读取；不得
先删除或改写旧清单。

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
