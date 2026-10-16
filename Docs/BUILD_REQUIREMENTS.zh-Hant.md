# DaemonQuay 編譯需求

## Tested Build Environment（已實測編譯環境）

| 項目 | 作者實測設定 |
| --- | --- |
| macOS | 27.0.1（Build 26A434） |
| Xcode | 27.0（Build 27A266a） |
| Apple Swift | 6.4（swiftlang-6.4.0.34.1） |
| Swift Driver | 1.168.6 |
| 編譯主機架構 | Apple Silicon |
| 作者使用的 Target | arm64-apple-macosx27.0.0 |

以上是作者的**實測環境**，不是最低支援版本。現有 `Scripts/build.sh` 使用 `arm64-apple-macosx14.0` 作為編譯 target，並設定 `LSMinimumSystemVersion=14.0`，不代表已完成所有 macOS 版本的相容性驗證。

## 編譯所需工具

- Xcode Command Line Tools：`xcrun`、`swiftc`、macOS SDK。
- `/usr/bin/sips`：縮放圖示；`/usr/bin/iconutil`：產生 `.icns`。
- `/usr/bin/codesign`：進行 ad hoc 簽署。
- `/bin/zsh`：執行編譯腳本；另使用一般 shell 工具 `cp`、`mkdir`、`rm`、`find`、`chmod`。
- Swift 原始碼使用 Apple SDK 的 AppKit、SwiftUI、Foundation、Combine 與 UniformTypeIdentifiers。編譯腳本未宣告外部 Swift Package 依賴。

在專案根目錄執行 `zsh Scripts/build.sh`，輸出為 `build/DaemonQuay.app`。編譯會重新建立該 App bundle，但不修改使用者設定、日誌、agents 或服務設定。替換已安裝 App 前，仍應依 README 檢查服務狀態。

本文件**僅包含 DaemonQuay 本體**，不將 oMLX 或 Caddy 的安裝需求列為編譯依賴。
