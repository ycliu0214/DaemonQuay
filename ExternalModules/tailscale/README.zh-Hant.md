[English](README.md) | [繁體中文](README.zh-Hant.md)

# Tailscale 模組

本模組讓 DaemonQuay 透過單一 Start / Stop 開關管理 macOS 上的 Tailscale VPN 連線。

模組使用 Tailscale 官方 Standalone App 內建的 CLI。DaemonQuay 維持一般使用者權限，不直接管理需要系統特權的背景服務。

## 系統需求

- macOS 13 或更新版本
- Homebrew
- 支援 Module API v1 的 DaemonQuay
- Tailscale 帳號

## 安裝

### 1. 安裝 Tailscale

使用 Homebrew 安裝官方 macOS Standalone 版本：

```bash
brew install --cask tailscale-app
```

安裝完成後開啟：

```bash
open -a Tailscale
```

### 2. 首次設定

依照 Tailscale 的安裝精靈完成：

1. **Required permissions（必要權限）：** 核准 **System Extension** 與 **VPN Configuration**。macOS 可能要求輸入管理員密碼或使用 Touch ID。
2. **Start at login（登入時啟動）：** 非必要。如果希望主要透過 DaemonQuay 手動控制，可以保持關閉。
3. **Connectivity alerts（連線通知）：** 建議初次使用時開啟。
4. **Join a tailnet（加入私人網路）：** 使用 Tailscale 帳號登入，完成設備授權。
5. **顯示方式：** 建議選擇 **Menu bar only**，隱藏 Dock 圖示。

上述系統授權由 Tailscale 與 macOS 處理，不會讓 DaemonQuay 取得管理員權限。

### 3. 建議設定

進入 **Tailscale → Settings**。

| 設定 | 建議 |
|---|---|
| Allow incoming connections | 開啟，允許其他設備連入本機服務 |
| Use Tailscale DNS settings | 開啟 |
| Use Tailscale subnets | 無需求時關閉 |
| Launch Tailscale at login | 自行決定 |
| Notifications | 建議開啟 |
| VPN On Demand | 手動管理時建議關閉 |
| Run as exit node | 無需求時關閉 |

以上設定都可以在日後修改。

### 4. 啟用 CLI Integration

在 Tailscale App 中：

1. 進入 **Settings → CLI Integration → Show me how**。
2. 點擊 **Add Now**。
3. 如有要求，完成 macOS 管理員授權。

CLI 啟動器會安裝至：

```text
/usr/local/bin/tailscale
```

開啟 Terminal 驗證：

```bash
tailscale version
tailscale status
tailscale ip -4
```

**DaemonQuay Tailscale 模組需要先完成 CLI Integration。**

## DaemonQuay 模組安裝

本模組獨立提供於 `ExternalModules/tailscale/`，**不會在編譯 DaemonQuay 時自動打包**。

將 `module.json` 和 `module-control` 複製至：

```text
~/.local/share/DaemonQuay/modules/tailscale/
```

設定控制程式的執行權限：

```bash
chmod 755 ~/.local/share/DaemonQuay/modules/tailscale/module-control
```

在 `~/.local/share/DaemonQuay/enabled-modules.json` 中加入 `"tailscale"`。

範例：

```json
["omlx", "caddy", "tailscale"]
```

保留原有模組，完成後重新啟動 DaemonQuay。

## 使用方式

| DaemonQuay 操作 | 功能 |
|---|---|
| Start | 連接 Tailscale VPN |
| Stop | 中斷 Tailscale VPN |
| Status | 查詢 VPN 連線狀態 |
| Validate | 確認 CLI 是否可用 |

**Start / Stop 控制的是 VPN 連線，不是 Tailscale GUI 或 macOS Network Extension 的程序生命週期。**

模組不需要管理員權限，也不會儲存 Tailscale 帳號認證資訊。

中斷 VPN 會使現有的 Tailscale 遠端連線中斷。DaemonQuay 執行 Stop All 時，也會呼叫本模組的 Stop 操作。

## 官方文件

Tailscale 的疑難排解、帳號管理及完整解除安裝程序，請參考官方說明：

- [macOS 安裝說明](https://tailscale.com/docs/install/mac)
- [Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli)
- [macOS 疑難排解](https://tailscale.com/docs/reference/troubleshooting/apple)
- [解除安裝 Tailscale](https://tailscale.com/docs/features/client/uninstall)
- [DaemonQuay 模組規格](../../Docs/MODULE_SPEC.zh-Hant.md)
