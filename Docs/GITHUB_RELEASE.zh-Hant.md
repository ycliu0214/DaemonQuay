# GitHub 發布、命名與授權檢查

**繁體中文** | [English](GITHUB_RELEASE.md)

## 授權：建議 Apache License 2.0

你的要求是**允許商業使用、修改、再發布，但必須保留原作者與授權資訊，且明確標示修改**。Apache-2.0 比 MIT 更貼近這個要求：第 4 條要求散布時附上授權、修改檔案附上明顯變更註記、保留適用的著作權與歸屬聲明；若原專案有 `NOTICE`，衍生發行也必須依條文保留其適用歸屬內容。它**不會禁止**出售、商業使用或商業再散布，也不保證別人的衍生 App 必須維持同樣名稱或在介面顯著展示原作者。正式條文：https://www.apache.org/licenses/LICENSE-2.0.html 。

專案已附完整標準 [LICENSE](../LICENSE) 和 [NOTICE](../NOTICE)，`NOTICE` 已填入 Y.C. Liu (ycliu0214)，正式公開前請確認程式與資源的著作權歸屬。建議自有原始碼逐檔加入 `SPDX-License-Identifier: Apache-2.0` 及相符的著作權標記；不要擅自修改 Apache 授權全文。這是工程性建議，不是法律意見。

## DaemonQuay 名稱衝突

公開搜尋可找到其他使用 **DaemonQuay** 名稱的商業服務及同名 iOS App。即使領域不同，搜尋辨識性與品牌混淆風險仍然存在，故**不建議未確認名稱可用就正式對外發行**。候選名稱可進一步查 `LaunchBerth`、`DaemonQuay`、`ProcHarbor`，但它們**尚未經商標或全球名稱可用性查核**；應先查 GitHub、App Store、網域與相關商標資料庫。

目前程式保留 `DaemonQuay` 名稱與資料路徑，不主動更名，以免既有設定、單一 GUI 鎖、模組 launchd Label 和使用者資料損壞。正式更名必須安排有測試的遷移。

## 上傳 GitHub 前檢查清單

- [ ] `.gitignore` 排除 `build/`、`*.pyc`、`__pycache__/`、`.DS_Store`、本機暫存與編譯產物。
- [ ] **不要提交** `~/.local/share/DaemonQuay/`、實際使用者設定、`logs/`、`agents/*.plist`、API Key、密碼、私鑰、模型與 SSD 快取。
- [ ] `Config/settings.json` 已使用 `~/.omlx/models`，SSD 快取預設停用，啟動前僅需確認模型目錄存在，SSD 快取為選用功能。
- [ ] 搜尋 `/Users/...`、token、password、private key、裝置識別資訊等內容。
- [ ] 不把建置用 `module-control` 二進位檔誤當原始碼上傳；二進位正式版可另放 Release。
- [ ] 確認 `Scripts/install.sh` 和 `Scripts/build.sh` 具有執行權限。
- [ ] 在支援的 Mac 實測 install、build、測試、啟動、優雅停止、狀態、崩潰重啟、重複開啟提示。
- [ ] 公開提供編譯完成的 App 前，評估正式 Developer ID 簽章與公證，而不是只使用本機臨時簽章。
- [ ] 填寫正確著作權資訊、確認第三方程式與素材授權，再公開專案。
- [ ] 決定正式對外名稱並確認不侵權；改名時保留舊版資料的遷移方式。

## 範圍限制

本次是原始碼／打包內容的初步檢查，不是完整安全審計、Apple 公證實測或商標法律鑑定。已啟用第三方模組可以使用登入使用者權限執行，**目前沒有沙箱**。更名或替換模組前，請先停止相關服務。

## 已更新的作者與範例

`NOTICE` 現已標示 `Y.C. Liu (ycliu0214)`、GitHub `ycliu0214`；公開預設設定已改為 `~/.omlx/models`，SSD 快取預設停用。參閱 [名稱與作者](NAME_AND_CREDITS.zh-Hant.md)。

正式發布前，請驗證更名遷移與排序、隱藏偏好是否保留。
