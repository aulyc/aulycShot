<p align="center">
  <img src="images/app-banner.png" alt="aulycShot 應用程式橫幅" width="760" />
</p>

<h1 align="center">aulycShot</h1>

<p align="center">
  macOS 上最順手的選單列截圖工具：雙擊 <code>⌘</code> 即刻截圖、標注、長截圖和釘圖。
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
  <a href="https://github.com/aulyc/aulycShot/releases/latest">下載</a> ·
  <a href="CHANGELOG.md">更新日誌</a> ·
  <a href="https://github.com/aulyc/aulycShot/issues">Issues</a>
</p>

**macOS 上最順手的截圖工具。** 雙擊 `⌘` 即開即用——視窗一點就貼邊、選取範圍像素級精準、長截圖邊捲邊拼，再用浮動編輯器一氣呵成完成標注。常駐選單列，不佔 Dock，無遙測、無訂閱、零第三方依賴。

<p align="center">
  <img src="images/editor.png" alt="aulycShot 標注編輯器——箭頭、序號、馬賽克、螢光筆和文字層疊在截圖上，所有操作集中在一個浮動工具列中" width="760" />
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest"><b>下載最新版本</b></a> &nbsp;·&nbsp;
  macOS 14+ &nbsp;·&nbsp; Apple Silicon（arm64）
</p>

## 為什麼選 aulycShot

- **一個快速鍵，零學習成本。** 在任意 App 中雙擊 `⌘` 即刻喚起 aulycShot；也可以在設定中錄製任何全域快速鍵。
- **視窗一點即貼邊，選取範圍像素級精準。** 懸停視窗一點截取，或拖曳任意區域，多顯示器全量支援，按 Retina 原生解析度輸出。
- **真正可二次編輯的標注。** 箭頭、序號、文字、馬賽克、螢光筆、畫筆——放下之後還能拖、能轉、能復原，所見即所改。
- **長截圖邊捲邊拼。** 在選取範圍內捲動，即時預覽拼接結果，合併後繼續在同一個編輯器裡改。
- **截圖釘圖。** 把成圖釘在所有視窗之上，隨時對照參考。
- **Finder 圖片也能直接編輯。** 在 Finder 中選取一張圖片，按下同一個快速鍵即可載入編輯器，原始檔案不會被修改。
- **純 AppKit 建置。** 沒有 SwiftUI、Electron，也沒有遙測。小、快、像 macOS 該有的樣子。

## 功能預覽

<table>
<tr>
  <td width="50%" align="center">
    <img src="images/window-snap.png" alt="智慧視窗識別——綠色虛線自動貼合應用程式視窗邊緣" /><br/>
    <sub><b>視窗一點即貼邊</b><br/>無需精確拖曳，aulycShot 自動識別視窗邊界。</sub>
  </td>
</tr>
<tr>
  <td width="50%" align="center">
    <img src="images/scroll-stitch.png" alt="長截圖拼接：在選取範圍內捲動並即時拼接出一張超長截圖" /><br/>
    <sub><b>長截圖邊捲邊拼</b><br/>在選取範圍內捲動，畫面即時合併，拼完還能繼續編輯。</sub>
  </td>
</tr>
</table>

## 功能特性

- **直接編輯已有圖片**：在 Finder（桌面或任意視窗）中選取一張圖片檔案，再觸發截圖快速鍵，aulycShot 會跳過截圖，直接把這張圖載入標注編輯器。原始檔案不會被修改，編輯後的結果像一般截圖一樣進入剪貼簿。
- **快速區域/視窗截圖**：拖曳任意區域，或懸停識別視窗後點擊，自動貼合視窗邊界。
- **多顯示器支援**：在所有已連接的螢幕上建立截圖遮罩，並按 Retina 真實像素解析度輸出。
- **完整標注編輯器**：支援矩形、橢圓、箭頭、畫筆、螢光筆、馬賽克、序號標注和文字。
- **標注可二次編輯**：可移動已有標注，調整顏色和尺寸；支援旋轉、彎曲箭頭/序號引線、修改文字、刪除標注，以及復原/重做。
- **長截圖**：在選取範圍內捲動時連續擷取畫面，即時預覽拼接結果，合併後繼續編輯。
- **釘在螢幕**：把目前截圖作為可拖曳浮動視窗置頂顯示，方便對照參考。
- **儲存或複製**：可儲存為 PNG，或確認後把 PNG/TIFF 寫入剪貼簿；也可以取消不輸出。
- **自訂觸發方式**：預設雙擊 `⌘`，也可在設定裡錄製全域快速鍵。
- **設定與本地化**：支援简体中文和 English UI，並提供選單列圖示開關、開機啟動、示範模式、權限狀態和快速鍵錄製。
- **選單列應用程式**：以 agent app 執行，不顯示 Dock 圖示。

## 環境需求

- macOS 14.0+
- 輔助使用功能權限：用於預設的雙擊 `⌘` 觸發
- 螢幕錄製權限：用於 ScreenCaptureKit 和螢幕內容擷取
- Finder 自動化權限：首次使用「編輯已選取的圖片」時彈出

首次啟動時，aulycShot 會開啟設定視窗並顯示統一的「功能狀態」。只有輔助使用功能和螢幕錄製權限都開啟時才為可用，否則截圖和錄影入口會停止執行並顯示整合授權說明。

## macOS 驗證攔截

如果 macOS 彈出類似 `Apple 無法驗證「aulycShot」是否包含惡意軟體` 的提示，可以對你信任的應用程式套件移除 quarantine 標記後再重新開啟：

```bash
xattr -dr com.apple.quarantine /Applications/aulycShot.app
```

如果你執行的是本機建置版本，而不是 `/Applications` 裡的副本，把路徑替換成實際位置即可，例如：

```bash
xattr -dr com.apple.quarantine ./.cache/build/aulycShot.app
```

只應對你信任的建置版本執行這個指令，例如本存放庫下載的版本或你本機自行建置的版本。

## 從原始碼建置

```bash
# 建置並打包為 .cache/build/aulycShot.app
./scripts/bundle.sh
```

本機開發時，可以使用下面的指令碼重新建置、關閉舊處理程序、啟動新應用程式，並確認應用程式已執行：

```bash
bash scripts/rebuild-and-open.sh
```

如需打包可拖曳安裝的 DMG：

```bash
scripts/package-dmg.sh
```

應用程式套件會輸出到隱藏目錄 `.cache/build/aulycShot.app`；DMG 會輸出到 `dist/`。

## 使用方式

1. 雙擊 `⌘ Command`，按下自訂快速鍵，或從選單列選擇 **截圖**。
2. 懸停視窗並點擊可截取視窗；也可以拖曳選擇任意區域。
3. 使用浮動工具列進行標注、長截圖、儲存、釘圖、取消或確認。
4. 點擊綠色勾號或按 `Enter` 複製最終圖片到剪貼簿；按 `Esc` 或點擊 `x` 取消。

如果想編輯桌面上或 Finder 裡已經存在的圖片，先在 Finder 中點選一張圖片檔案讓它處於選取狀態，再觸發同一個快速鍵。aulycShot 會把檔案複製到暫存目錄後載入編輯器，工具列直接就緒。如果目前選取的不是恰好一張圖片（沒選取、選了多張、或選的不是圖），快速鍵會照常進入截圖流程。

## 編輯器工具

| 工具 | 作用 |
|------|------|
| 矩形 / 橢圓 | 繪製描邊形狀，可選擇顏色和線寬 |
| 箭頭 | 繪製直線箭頭；選取後可移動端點或彎曲箭頭 |
| 畫筆 | 繪製平滑的自由畫筆線條 |
| 螢光筆 | 繪製半透明螢光標記，不會因重疊反覆加深 |
| 馬賽克 | 在敏感區域刷出像素化遮擋，可調整區塊大小 |
| 序號 | 加入自動遞增的序號圓點；放置時拖曳可帶出箭頭 |
| 文字 | 加入可編輯單行文字，支援顏色和 10-100 pt 字級 |
| 復原 / 重做 | 復原或重做編輯器操作 |
| 移動選取範圍 | 選取完成後拖曳整個截圖區域 |
| 長截圖 | 在選取範圍內捲動並拼接畫面，完成後繼續編輯 |
| 儲存 | 將目前結果儲存為 PNG |
| 釘在螢幕 | 將目前結果置頂懸浮顯示 |
| 確認 | 將最終結果複製到剪貼簿 |

選取標注後，aulycShot 會顯示對應的調整控制項：形狀、線條和文字支援旋轉；箭頭和序號引線支援彎曲；箭頭端點可重新拖曳；文字可再次編輯；選取標注可刪除。

## 設定

從選單列開啟設定後，可以設定：

- 語言：简体中文、English
- 是否顯示選單列圖示
- 是否開機自動啟動
- 示範模式：允許外部錄影軟體擷取 aulycShot 的遮罩和編輯器
- 截圖快速鍵：保留雙擊 `⌘`、錄製自訂快速鍵，或恢復預設
- 統一功能狀態和輔助使用功能、螢幕錄製權限入口

## 專案結構

- `aulycShot/App/`：應用程式進入點、AppDelegate 和套件中繼資料
- `aulycShot/Capture/`：截圖遮罩、選取範圍、視窗偵測、ScreenCaptureKit 擷取、長截圖拼接和剪貼簿
- `aulycShot/Editor/`：標注模型、編輯畫布、浮動工具列、馬賽克、長截圖預覽和釘圖視窗
- `aulycShot/Trigger/`：雙擊 `⌘` 監聽和自訂 Carbon 全域快速鍵
- `aulycShot/UI/`：選單列控制器、toast、滑鼠提示和工具提示
- `aulycShot/Settings/`：首次啟動/設定視窗和偏好設定 UI
- `aulycShot/Utilities/`：預設值、本地化和開機啟動支援
- `scripts/`：編譯檢查、打包、重啟執行、圖示和 DMG 輔助指令碼

## 開發

```bash
# 對影響 Swift 建置的修改做快速編譯驗證
bash scripts/compile-check.sh

# 建置、重啟並確認本機應用程式已執行
bash scripts/rebuild-and-open.sh
```

## 致謝

感謝 Linux.do 社群在測試、回饋和討論中的支持。

## 第三方授權條款

- [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) 使用 MIT License。詳見 [ThirdParty/PermissionFlow/LICENSE](ThirdParty/PermissionFlow/LICENSE)。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=aulyc/aulycShot&type=Date)](https://star-history.com/#aulyc/aulycShot&Date)

## License

[MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)
