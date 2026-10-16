# DaemonQuay

**版本 1.0.0 · macOS 原生選單列服務管理工具**

[English](README.md) | [繁體中文](README.zh-Hant.md)

DaemonQuay 是以 SwiftUI 與 AppKit 開發的輕量化 macOS 選單列應用程式，用於**手動管理本機服務**。內建 **oMLX**、**Caddy** 模組，亦可透過共用模組介面擴充其他服務。

## 主要功能

- 手動啟動與正常停止服務，不會自動啟動或重新啟動。
- 使用小型、柔和色系狀態燈顯示服務狀態。
- 在設定介面調整模組參數，不覆寫服務自身的原生設定檔。
- 分別查看 stdout 與 stderr；手動重新讀取時最多顯示**最後 10,000 行**，不截斷原始日誌。
- 調整服務排序與顯示／隱藏，不因此變更模組是否啟用。
- 支援不重新編譯主程式即可安裝第三方模組。
- 英文及繁體中文介面、首次啟動指引，以及可關閉的選單列位置提示。

內建 oMLX、Caddy 模組使用使用者網域的 `launchd` 管理服務。狀態燈反映模組回報的程序狀態，**不代表 API 一定已經就緒**。

## 從原始碼建置

請參閱[編譯需求](Docs/BUILD_REQUIREMENTS.zh-Hant.md)了解實際測試環境與工具。建置設定以 Apple Silicon、macOS 14.0 以上為目標；這**不代表所有目標版本均已完成實機驗證**。

```zsh
zsh Scripts/install.sh
zsh Scripts/build.sh
open ./build/DaemonQuay.app
```

`install.sh` 只在資料尚不存在時初始化設定，不會自動啟動服務。`build.sh` 產生 `build/DaemonQuay.app`。若要安裝至 `/Applications`，請先正常停止受管理服務並結束 DaemonQuay，再複製**完整 `.app`**，不要只複製執行檔。

在 Mac 上建置完成後，可產生拖曳安裝的 DMG：

```zsh
zsh Scripts/create_dmg.sh
```

目前建置使用 **ad-hoc 簽署**。DMG 腳本不會替 App 或磁碟映像檔執行正式簽署、公證。公開散布二進位版本之前，仍需進行 Developer ID 簽署、Apple 公證與 macOS 實機測試。請參閱[發布檢查表](Docs/RELEASE_CHECKLIST.zh-Hant.md)。

## 首次設定

內建模組提供範例路徑與預設參數。啟動服務前，請在**設定**中確認程式執行路徑、模型資料夾或 Caddyfile、連接埠及其他必要選項。oMLX 與 Caddy 需另外安裝與設定，**不是** DaemonQuay 的編譯依賴。

服務由使用者手動控制。DaemonQuay 不修改 oMLX 自身設定或 Caddy 的 Caddyfile。

## 使用者資料位置

DaemonQuay 自有設定與服務管理資料儲存在：

```text
~/.local/share/DaemonQuay/
├── settings.json             # App 偏好與模組設定
├── enabled-modules.json      # 已啟用模組 ID
├── service-order.json        # 自訂顯示順序（儲存後建立）
├── hidden-services.json     # 服務顯示偏好（儲存後建立）
├── agents/                  # 使用者 launchd 工作定義
├── logs/<模組 ID>/           # 服務 stdout／stderr 日誌
└── modules/<模組 ID>/        # 使用者自行安裝的模組
```

`settings.json` 的 `_daemonquay` 區塊包含介面語言、首次歡迎提示完成紀錄及啟動時位置提示開關。App 結束不會刪除使用者設定或日誌。oMLX、Caddy 原生設定、模型與快取仍由對應服務或使用者自行管理。

## 模組架構

```text
DaemonQuay 選單列／設定／日誌
             │
       PluginRegistry
             │
        PluginRuntime
         /         \
     內建模組     使用者模組
         \         /
    start / stop / status
             │
        模組自行管理服務
```

每個模組由 `module.json` 與可執行控制程式組成，需支援 `start`、`stop`、`status`，並可選擇支援 `validate`；操作結果以 JSON 回傳。內建 oMLX、Caddy 共用 Swift 模組執行器。詳細格式、權限與範例請參閱[模組開發規範](Docs/MODULE_SPEC.zh-Hant.md)。

第三方模組會以目前登入使用者的權限執行，並未沙箱化，請僅啟用可信任的模組。

## 移除與注意事項

移除或替換已安裝的 App 之前，請先正常停止受管理服務，再結束 DaemonQuay。刪除 `.app` 不會自動刪除設定、日誌、使用者模組或底層服務。只有在確定不再需要這些資料時，才應刪除 `~/.local/share/DaemonQuay/`。

DaemonQuay 不使用 `SIGKILL` 強制停止服務，也不自動重新啟動服務。模組特定的健康檢查與第三方原生設定不屬於主程式的管理範圍。

## 文件與授權

- [編譯需求](Docs/BUILD_REQUIREMENTS.zh-Hant.md)
- [模組開發規範](Docs/MODULE_SPEC.zh-Hant.md)
- [發布檢查表](Docs/RELEASE_CHECKLIST.zh-Hant.md)
- [授權](LICENSE)與[作者資訊](NOTICE)

本專案使用 **Apache License 2.0**。

Copyright 2026 Y.C. Liu (ycliu0214).

**驗證狀態：** 原始碼封裝已完成語法與可執行的腳本／測試檢查。完整 macOS AppKit／SwiftUI 整合、服務啟停、正式簽署與公證，仍須在目標 Mac 上驗證後，才能宣稱二進位發行版已完成正式測試。
