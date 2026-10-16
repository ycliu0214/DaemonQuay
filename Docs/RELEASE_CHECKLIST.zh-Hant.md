# DaemonQuay v1.0.0 正式發布檢查表

**狀態：** 已整理原始碼。此環境**無法驗證** macOS 編譯、GUI、服務啟停、Developer ID 簽署及 Apple 公證。

1. 升級前先備份 `~/.local/share/DaemonQuay/`，不覆寫 oMLX/Caddy 原生設定，也不因升級強制重啟服務。
2. 在目標 Mac 執行 `zsh Scripts/install.sh`、`zsh Scripts/build.sh` 與 `zsh Tests/run_tests.sh`，確認版本為 1.0.0、Build 29。
3. 實測選單燈號與對齊、側邊欄點擊範圍、一般偏好、語言保存、啟動提示選項、首次 Welcome、服務啟停與狀態、Log Reload、重新啟動 App；包含雙語與深淺色。
4. 從舊版升級並核對 settings、logs、agents、模組順序與隱藏設定皆保留；搬移 App 前先檢查既有 launchd 執行檔路徑。
5. 可執行 `zsh Scripts/create_dmg.sh` 製作拖曳安裝 DMG，但此腳本**不等於正式簽署或公證**；公開二進位檔前須完成 Developer ID／hardened runtime／Apple notarization 與乾淨 macOS 實機測試。
6. 首次公開 GitHub 前，檢查待提交檔案、金鑰、路徑、隱私內容。不可提交本機使用者資料或 `build/`。
7. 靜態檢查通過不代表正式版已通過全部功能驗證。
