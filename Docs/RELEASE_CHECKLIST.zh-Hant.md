# DaemonQuay v1.0.1 發布檢查表

**狀態：** 準備發布原始碼版本。發布前須於目標 Mac 完成下列檢查。目前建置流程不包含 Developer ID 正式簽署及 Apple 公證。

1. 升級前備份 `~/.local/share/DaemonQuay/`，保留既有設定、日誌、已安裝模組及服務設定。

2. 在目標 Mac 編譯並測試：
   ```zsh
   zsh Scripts/build.sh
   zsh Tests/run_tests.sh
   ```
   確認 App 版本為 **1.0.1**、Build 為 **30**。

3. 檢查主介面、選單列狀態燈、設定、語言保存、服務控制及日誌顯示，並測試英文與繁體中文介面。

4. 確認 Service Logs 的多模組切換器沒有文字遮蔽或重疊問題。

5. 確認內建 **oMLX** 與 **Caddy** 模組的啟動、停止、狀態查詢及設定功能維持正常。

6. 確認選用的 **Tailscale 外部模組** 可以獨立安裝，透過 `enabled-modules.json` 啟用，不需重新編譯 DaemonQuay。測試 Start、Stop、Status、Validate，並確認 VPN 狀態與 Tailscale App 一致。

7. 確認 `ExternalModules/` 中的模組不會自動打包進 `DaemonQuay.app`，並檢查模組文件及執行權限。

8. 確認升級後保留使用者設定、服務排序、隱藏服務、日誌及已安裝的外部模組。

9. 提交前檢查 Git 變更，排除憑證、私人路徑、日誌、建置產物及其他非預期檔案。

10. 完成必要測試後，再建立 Git Commit 與 `v1.0.1` 註記標籤。

11. 可執行 `zsh Scripts/create_dmg.sh` 產生 DMG。目前使用 ad-hoc 簽署，尚未完成 Apple 公證。公開發布二進位版本前，仍須完成 Developer ID 簽署、Hardened Runtime、Apple 公證，以及乾淨 macOS 環境的驗證。

12. 發布 GitHub 原始碼版本，附上正確的更新說明，並明確標示 Tailscale 為選用外部模組。

**驗證紀錄：** 發布前應記錄已完成的測試及尚未解決的限制，不應將未執行的項目標示為通過。

