# DaemonQuay

**Version 1.0.0 · Native macOS menu bar service manager**

[English](README.md) | [繁體中文](README.zh-Hant.md)

DaemonQuay is a lightweight SwiftUI/AppKit menu bar app for manually controlling local services. It includes modules for **oMLX** and **Caddy** and supports additional modules through a common executable-module interface.

## Features

- Start and gracefully stop services on demand; no automatic service start or restart.
- Display service status with compact, subdued status indicators.
- Configure supported module options without overwriting the services' native configuration files.
- Show stdout and stderr separately. Reload reads up to the **last 10,000 lines** without truncating the underlying logs.
- Reorder or hide services in the interface without changing their underlying enablement.
- Install third-party service modules without recompiling the GUI.
- English and Traditional Chinese interfaces; first-launch guidance and an optional menu bar location hint.

DaemonQuay uses the per-user `launchd` domain for its bundled oMLX and Caddy module controllers. A displayed running state reports the module's process status, not application-level API health.

## Build from source

See [build requirements](Docs/BUILD_REQUIREMENTS.md) for the tested build environment and tools. The build script targets Apple Silicon and macOS 14.0 or later; this target is **not** a claim that all target versions have been tested.

```zsh
zsh Scripts/install.sh
zsh Scripts/build.sh
open ./build/DaemonQuay.app
```

`install.sh` initializes DaemonQuay's user data only when missing and does not start services. `build.sh` creates `build/DaemonQuay.app`. To install the built app, copy the **entire** `.app` bundle into `/Applications` after quitting the app and safely stopping services under its management.

To create a drag-to-Applications disk image on a Mac after building:

```zsh
zsh Scripts/create_dmg.sh
```

The build currently uses **ad-hoc code signing**. The disk image script does not sign or notarize the app or DMG. Public binary distribution requires separate Developer ID signing, notarization, and testing on macOS. See the [release checklist](Docs/RELEASE_CHECKLIST.md).

## First configuration

The bundled module descriptors provide example paths and defaults. Before starting a service, open **Settings** and verify the executable path, model directory or Caddyfile, port, and other module options. oMLX and Caddy must be installed and configured separately; they are **not** build dependencies of DaemonQuay.

Services are started and stopped manually. DaemonQuay does not modify oMLX's own configuration or Caddy's Caddyfile.

## User data

DaemonQuay stores its own settings and service-management files in:

```text
~/.local/share/DaemonQuay/
├── settings.json             # App preferences and module settings
├── enabled-modules.json      # Enabled module IDs
├── service-order.json        # Saved interface order, when customized
├── hidden-services.json     # Saved visibility preferences, when customized
├── agents/                  # User launchd job definitions
├── logs/<module-id>/         # Service stdout/stderr logs
└── modules/<module-id>/      # User-installed modules
```

The `_daemonquay` section in `settings.json` stores the UI language, welcome-prompt completion, and startup location-hint preference. Service logs and settings remain separate from the installed `.app` and are not deleted when the app quits. The original oMLX/Caddy configurations, models, and caches remain owned by those services or the user.

## Module architecture

```text
DaemonQuay menu bar / Settings / Logs
                │
         PluginRegistry
                │
          PluginRuntime
           /         \
    Bundled modules   User modules
           \         /
       start / stop / status
                │
      Module-defined backend
```

Each module provides a manifest (`module.json`) and a controller executable. Controllers implement `start`, `stop`, and `status`, with optional `validate`, and return a JSON status response. The bundled oMLX and Caddy modules use the same generic Swift module host. See the [module developer specification](Docs/MODULE_SPEC.md) for schema, security considerations, and examples.

External modules execute with the current user's privileges and are not sandboxed. Enable only trusted modules.

## Removal and precautions

Before removing or replacing an installed app, stop managed services normally and quit DaemonQuay. Removing the `.app` does not remove its settings, logs, user modules, or the underlying service installations. Do not delete `~/.local/share/DaemonQuay/` unless you deliberately intend to remove that data.

DaemonQuay does not forcibly terminate services with `SIGKILL` and does not automatically restart them. Module-specific health and third-party configuration remain outside the app's responsibility.

## Documentation and license

- [Build requirements](Docs/BUILD_REQUIREMENTS.md)
- [Module developer specification](Docs/MODULE_SPEC.md)
- [Release checklist](Docs/RELEASE_CHECKLIST.md)
- [License](LICENSE) and [attribution](NOTICE)

Licensed under the **Apache License 2.0**.

Copyright 2026 Y.C. Liu (ycliu0214).

**Verification status:** The source package has undergone syntax and available script/test checks. Complete macOS AppKit/SwiftUI integration, service lifecycle, and binary signing/notarization must be verified on the target Mac before describing a binary as production-tested.
