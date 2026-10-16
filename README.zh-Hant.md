[**繁體中文**](README.zh-Hant.md) | [English](README.md)


> **v1.0.0 原始碼版本：** 此封裝環境無法編譯或公證 macOS App。公開二進位檔前，請先完成 [`Docs/RELEASE_CHECKLIST.zh-Hant.md`](Docs/RELEASE_CHECKLIST.zh-Hant.md)。`Scripts/build.sh` 目前僅執行 ad-hoc 簽署，並非 Apple Developer ID 正式發布簽署。

在 Mac 編譯後可用 `zsh Scripts/create_dmg.sh` 產生拖曳至 Applications 的 DMG；完成正式簽署及公證前，僅建議用於本機測試。

# DaemonQuay v1.0.0 · macOS 原生選單列服務管理工具

DaemonQuay 是為 macOS 14 以上、Apple Silicon 設計的選單列工具。它提供統一的 **啟動、正常停止、存活狀態、日誌與設定** 介面。oMLX 與 Caddy 都是使用同一套契約載入的獨立模組；Core 不包含針對這兩個服務的特殊判斷。應用程式及內建模組執行時不需要 Python。

- [模組開發規範（繁體中文）](Docs/MODULE_SPEC.zh-Hant.md)／[English](Docs/MODULE_SPEC.md)
- [GitHub 發布與授權檢查（繁體中文）](Docs/GITHUB_RELEASE.zh-Hant.md)／[English](Docs/GITHUB_RELEASE.md)

## 日誌檢視器（v0.11.5）

按下 Reload 時，GUI 最多顯示所選 Log／Error 檔案的**最後 10,000 行**；不足則全部顯示。這只是唯讀的顯示上限，不會截斷或刪除原始日誌。驗證步驟請見 [TESTING_v0.11.5.md](TESTING_v0.11.5.md)。

## 安裝與建置

**升級前**，請先透過舊版 ServiceDeck 正常停止所有受管理的服務，退出舊版 GUI，再執行：

```zsh
./Scripts/install.sh
./Scripts/build.sh
open ./build/DaemonQuay.app
```

`install.sh` 不會自動啟動服務。原本的 ServiceDeck 設定與原生 oMLX、Caddy 資料會保留。可在驗證新 App 正常後複製整個 `build/DaemonQuay.app` 到 `/Applications/`。

**驗證限制：** 這個發行包已做原始碼語法／資料格式檢查，但完整 SwiftUI／AppKit 編譯、macOS 簽章、launchctl 啟停與 GUI 互動仍須在實際 Mac 上確認；請勿將其視為已完整驗證的正式版。

## 架構

```text
DaemonQuay.app（選單列 GUI、設定、日誌）
    │
    ├── PluginRegistry（搜尋、檢查、啟用模組）
    └── PluginRuntime（執行模組控制程式）
            ├── App 內建模組（oMLX / Caddy）
            └── 使用者另外安裝的模組
                    │
               start / stop / status
                    │
              模組自行管理服務
```

每個模組提供短暫執行的控制程式，支援 `start`、`stop`、`status`；可選 `validate`。Core 依 JSON 通訊結果顯示服務狀態，不要求第三方模組都使用 launchd。內建 oMLX／Caddy 則共用以原生 Swift 實作的 launchd 模組執行器。

Module Controller 由 DaemonQuay 傳入一個操作引數，並設定 `DAEMONQUAY_MODULE_ID`、`DAEMONQUAY_MODULE_DIR`、`DAEMONQUAY_DATA_DIR` 環境變數；模組透過 stdout 回傳一個 UTF-8 JSON 物件，如 `{"state":"running","message":"PID 123"}`。狀態值支援 `running`、`stopped`、`external`、`error`；診斷輸出請放 stderr。詳見模組規範。

DaemonQuay **不會**自動啟動／重啟服務、不會為了停止而強制 `SIGKILL` 外部程序，也不負責測試 oMLX 推論或 Caddy 路由功能。狀態燈號代表受管理程序存活，不保證 API 就緒。

## 設定、日誌與服務排序

設定介面依模組的 `module.json` 欄位動態建立，目前支援 `string` 與 `integer`。服務停止時才可儲存對應服務設定；不會修改 oMLX 的原生模型設定或 Caddyfile。Caddy 模組會在啟動前驗證 Caddyfile。

日誌依服務放在 `logs/<模組 ID>/log.log`（stdout）和 `error.log`（stderr）；兩種輸出不是 INFO／ERROR 等級分類。日誌視窗提供手動重新讀取與 Finder 對應子資料夾。舊版平面日誌可能仍可回退讀取。

服務顯示順序可以在設定視窗以拖曳或上下按鈕調整，並儲存在 `service-order.json`；這**不影響**停止全部服務時使用的 `stopOrder`。

## 實際產生的資料夾與檔案

`~` 代表執行 DaemonQuay 的使用者家目錄。**目前仍使用 `~/.local/share/DaemonQuay/`，不會自動搬移到 macOS Application Support。**

```text
<專案>/build/                     # build.sh 建立，可在部署後移除
├── DaemonQuay.app/               # 包含 GUI、語言包、內建模組
└── module-control                 # 編譯與複製的中間產物

~/.local/share/DaemonQuay/
├── settings.json                  # 初始化與儲存設定
├── enabled-modules.json           # 已啟用模組清單
├── service-order.json             # 使用者儲存排序後建立
├── gui.lock                       # 防止重複 GUI；殘留檔名不代表鎖仍有效
├── agents/                        # 啟動服務時產生 launchd plist
├── logs/<id>/                     # 服務啟動後的 log.log / error.log
└── modules/<id>/                  # 使用者額外安裝的模組
```

**App 內建模組：** `DaemonQuay.app/Contents/Resources/Modules/omlx/` 與 `caddy/`，包含 `module.json`、`service.json`、`module-control`。使用者不需再複製內建模組到外部目錄；外部 `modules/` 才是第三方模組安裝位置。

其他可能使用的位置：

| 位置 | 說明 |
|---|---|
| `~/Library/Preferences/local.daemonquay.manager.plist`（通常） | macOS UserDefaults 存放介面語言等偏好，實際由系統管理 |
| macOS 暫存目錄 `dq-out-*`／`dq-err-*`／`dq-cmd-*` | 短暫指令輸出，正常結束時清理，異常退出可能殘留 |
| `~/.omlx/` | oMLX 自身設定，不屬於 DaemonQuay |
| `~/.config/caddy/Caddyfile` | Caddy 原生設定，不屬於 DaemonQuay |
| `~/Library/Application Support/Caddy/` | Caddy 自身資料，不屬於 DaemonQuay |
| 使用者自行指定的模型與快取資料夾 | 使用者模型／快取，不屬於 DaemonQuay |

`launchctl bootstrap` 改變使用者 GUI Domain 的執行期狀態，不表示新增另一個 DaemonQuay 固定資料夾。不同第三方模組可能自行建立額外檔案，應查看該模組文件。

## 新增外部模組

1. 先在 DaemonQuay 以外完成服務啟動、正常停止與存活判定的測試。
2. 建立 `~/.local/share/DaemonQuay/modules/<id>/`，放入 `module.json` 與可執行的模組控制程式；若使用共用 launchd 執行器才需要 `service.json`。
3. 將 ID 加入 `~/.local/share/DaemonQuay/enabled-modules.json` JSON 字串陣列，保留現有服務 ID。
4. 重新開啟 GUI 讓 Registry 載入。新增外部模組**不需要重新編譯主程式**。
5. 只在服務已停止時更新、停用、移除模組。

**目前沒有**圖形化模組安裝器、模組商店、第三方模組沙箱或 CLI；模組控制程式將以登入使用者權限執行，請勿啟用來源不明的程式。

## 更新、解除安裝與注意事項

- 更新 App 之前，先停止所有受管理服務，確認 launchd Job 停止，退出 GUI，再替換完整 App Bundle。
- 更新時保留 `~/.local/share/DaemonQuay/`；舊版 Python 控制腳本與平面日誌不會被自動清除。
- 移除 App 並不會自動清除設定、日誌與外部模組。如要完整移除，先確認服務已停止，再決定是否刪除 DaemonQuay 專用資料目錄。
- **不要**因移除 DaemonQuay 而刪除 oMLX、Caddy 自身資料、模型與 SSD 快取。
- `start/stop/status` 由模組負責辨識自己的程序；DaemonQuay 單一 GUI 鎖不能保證防止所有外部並行操作。
- UPS／macOS 關機時的優雅停止仍需要實機驗證，`ExitTimeOut` 不是絕對保證。

## 授權與公開發布

本專案預計以 **Apache License 2.0** 發布：允許商業使用、修改與再散布，但須保留授權與著作權／歸屬聲明，並清楚標示修改。詳見 [LICENSE](LICENSE)、[NOTICE](NOTICE) 和 [GitHub 發布檢查](Docs/GITHUB_RELEASE.zh-Hant.md)。**公開前請確認著作權歸屬。**

## 版本摘要

- v0.10.1：移除舊版 `loadSettings()` 呼叫，修正編譯錯誤。
- v0.10.2：新增服務顯示排序，不影響停止順序。
- v0.10.3：整理完整 Module API v1 文件。
- v0.11.0：新增中英文分離文件、授權與 GitHub 發布清單；**不更改模組啟停核心**。

## Name and authorship / 專案命名與作者

See [Docs/NAME_AND_CREDITS.zh-Hant.md](Docs/NAME_AND_CREDITS.zh-Hant.md) for screened name candidates and attribution.


## v0.11.0：更名、排序、隱藏及資料保留

正式名稱改為 **DaemonQuay**，新的使用者資料位於
`~/.local/share/DaemonQuay/`，包含 `settings.json`、`service-order.json`、
`hidden-services.json`、`enabled-modules.json`、`agents/`、`logs/`、`modules/`。
安裝時僅在新設定不存在的情況下，複製舊 ServiceDeck 的設定、模組啟用清單及顯示順序。
舊版日誌和外部模組**不會自動搬移或刪除**，如有需要請自行檢查後遷移。
升級前務必在舊版停止 oMLX、Caddy 並退出舊 GUI；舊 App 與資料皆保留。

設定視窗的服務排序清單新增「**顯示**」核取方塊：取消即可隱藏選單與日誌選取清單的該服務，
不會解除安裝、停用、刪除設定或改變服務關閉優先序。
執行中或狀態不明的服務不可直接隱藏，必須先正常停止；設定頁仍可看到並重新顯示所有模組。
上下箭頭與拖曳排序會寫入 `service-order.json`，重新開啟程式仍保留。

oMLX 公開預設使用 `~/.omlx/models`；SSD cache **預設啟用**，快取路徑為 `~/.omlx/cache`，上限為 `20GB`。
若改用自訂快取路徑，請先建立該資料夾；若清空快取路徑，DaemonQuay 就不附加
`--paged-ssd-cache-dir` 和 `--paged-ssd-cache-max-size` 參數。
已存在的使用者設定不會因版本更新而被覆蓋。

App 圖示及選單列透明圖示來源位於 `Resources/Icons/`，建置時會產生 `AppIcon.icns`。


## 內建 oMLX 範例、自訂與取代方式

**全新安裝的公開範例**預設啟用選用的 SSD 快取：`~/.omlx/cache`，容量上限 `20GB`。這並不是 oMLX 的必備設定。使用內建預設值第一次啟動服務時，如果 `~/.omlx/` 存在且可寫入，DaemonQuay 會建立預設快取資料夾；**不會自動建立使用者指定的其他快取路徑**。模型資料夾仍須先由使用者配置。若不使用快取，在設定視窗清空 **SSD 快取資料夾**，即不傳入兩項 SSD Cache 參數（即使容量欄位仍有數值）；自訂快取位置則須自行先建立。已存在的 `settings.json` 不會被安裝程序覆蓋。

**修改內建 oMLX：** 只需修改模型位置、Port 或快取等參數時，先停止 oMLX，在 DaemonQuay 設定視窗修改並儲存，再手動啟動。實際參數儲存於 `~/.local/share/DaemonQuay/settings.json`。若需更改**模組的啟動指令、停止策略或 launchd 行為**，請修改專案原始碼 `Modules/omlx/service.json`（必要時 `Modules/omlx/module.json`），在服務停止後重新編譯並替換 App。**不要直接改已簽署 App Bundle 內的檔案**。Caddy 的範例定義位於 `Modules/caddy/`，路由等原生設定則維持在 `~/.config/caddy/Caddyfile`。

**自行撰寫 oMLX 模組、停用內建版本：** 遵循 [`Docs/MODULE_SPEC.zh-Hant.md`](Docs/MODULE_SPEC.zh-Hant.md) 的 Module API v1，以**不同模組 ID**（例如 `my-omlx`）建立 `module.json` 和可執行控制程式，放入 `~/.local/share/DaemonQuay/modules/my-omlx/`。先正常停止舊 oMLX，再編輯 `~/.local/share/DaemonQuay/enabled-modules.json` 的 JSON 字串陣列：加入 `my-omlx` 並移除 `omlx`，最後重新開啟 DaemonQuay。這只代表**停用內建模組，不是刪除模組**；也要使用不衝突的 launchd Label，不能同時讓兩份服務占用相同 Port。設定中的「顯示」勾選框**僅隱藏列表**，不能代替停用。

例如保留內建 Caddy、改用自己的 oMLX：`["my-omlx", "caddy"]`。


## v0.11.2 選單列圖示寬度修正

選單列改用系統方形寬度的狀態項目、18 點的透明樣板圖示，並裁切圖片多餘的透明邊界，避免佔用過寬空間。App 圖示及服務啟停邏輯均未變更。


### 設定側邊欄頁尾（v0.11.4）
側邊欄底部顯示從 App Bundle 讀取的版本、© 2026 Y.C. Liu (ycliu0214) 與 Licensed under Apache License 2.0。不增加獨立的「關於」頁面。

### Build environment / 編譯環境

[編譯需求](Docs/BUILD_REQUIREMENTS.zh-Hant.md)
