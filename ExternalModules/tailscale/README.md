[English](README.md) | [繁體中文](README.zh-Hant.md)

# Tailscale Module

A DaemonQuay module for managing Tailscale VPN connectivity on macOS through a single Start / Stop control.

The module uses the CLI included with the official Tailscale Standalone application. DaemonQuay runs with standard user permissions and does not manage privileged system services directly.

## Requirements

- macOS 13 or later
- Homebrew
- DaemonQuay with Module API v1
- A Tailscale account

## Installation

### 1. Install Tailscale

Install the official macOS Standalone application using Homebrew:

```bash
brew install --cask tailscale-app
```

Launch Tailscale:

```bash
open -a Tailscale
```

### 2. Complete Initial Setup

Follow the Tailscale setup assistant:

1. **Required permissions:** Grant both **System Extension** and **VPN Configuration** permissions. macOS may request administrator authentication.
2. **Start at login:** Optional. Leave disabled if you prefer manual control through DaemonQuay.
3. **Connectivity alerts:** Recommended during initial setup.
4. **Join a tailnet:** Sign in with your Tailscale account and authorize the Mac.
5. **Appearance:** Select **Menu bar only** if you prefer to hide the Dock icon.

These permissions belong to Tailscale and macOS. They do not grant administrator privileges to DaemonQuay.

### 3. Recommended Settings

Open **Tailscale → Settings**.

| Setting | Recommendation |
|---|---|
| Allow incoming connections | Enabled, for hosting services |
| Use Tailscale DNS settings | Enabled |
| Use Tailscale subnets | Disabled unless needed |
| Launch Tailscale at login | Optional |
| Notifications | Recommended |
| VPN On Demand | Disabled for manual control |
| Run as exit node | Disabled unless needed |

These settings can be changed later.

### 4. Enable CLI Integration

In the Tailscale application:

1. Open **Settings → CLI Integration → Show me how**.
2. Select **Add Now**.
3. Approve the macOS authorization request if prompted.

The CLI launcher is installed at:

```text
/usr/local/bin/tailscale
```

Verify the installation:

```bash
tailscale version
tailscale status
tailscale ip -4
```

The CLI integration is required by this DaemonQuay module.

## DaemonQuay Module Installation

This module is provided separately under `ExternalModules/tailscale/` and is **not automatically bundled** when building DaemonQuay.

Copy `module.json` and `module-control` into:

```text
~/.local/share/DaemonQuay/modules/tailscale/
```

Make the controller executable:

```bash
chmod 755 ~/.local/share/DaemonQuay/modules/tailscale/module-control
```

Add `"tailscale"` to `~/.local/share/DaemonQuay/enabled-modules.json`.

Example:

```json
["omlx", "caddy", "tailscale"]
```

Preserve existing modules, then restart DaemonQuay.

## Usage

| DaemonQuay Action | Behavior |
|---|---|
| Start | Connects the Tailscale VPN |
| Stop | Disconnects the Tailscale VPN |
| Status | Reports the current VPN connection state |
| Validate | Verifies CLI availability |

**Start and Stop control VPN connectivity, not the lifecycle of the Tailscale GUI application or macOS Network Extension.**

The module does not require administrator privileges or store Tailscale authentication credentials.

Stopping the module disconnects active Tailscale sessions. DaemonQuay's Stop All operation also invokes the module's Stop action.

## References

For VPN troubleshooting, account management, and complete uninstallation procedures, refer to Tailscale's official documentation:

- [macOS installation](https://tailscale.com/docs/install/mac)
- [Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli)
- [macOS troubleshooting](https://tailscale.com/docs/reference/troubleshooting/apple)
- [Uninstall Tailscale](https://tailscale.com/docs/features/client/uninstall)
- [DaemonQuay Module API](../../Docs/MODULE_SPEC.md)
