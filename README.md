[**繁體中文**](README.zh-Hant.md) | **English**


> **v1.0.0 source release:** The app bundle has not been compiled or notarized in this packaging environment. Run the macOS checks in [`Docs/RELEASE_CHECKLIST.md`](Docs/RELEASE_CHECKLIST.md) before publishing a binary. `Scripts/build.sh` creates an **ad-hoc signed** local build, not a Developer ID-signed distribution.

For a drag-to-Applications disk image on macOS after building, run `zsh Scripts/create_dmg.sh`. The resulting unsigned/unnotarized DMG is intended for local verification until distribution signing and notarization are completed.

# DaemonQuay v1.0.0 · macOS menu bar service manager

Native macOS 14+ Apple Silicon menu-bar GUI. **oMLX and Caddy are now ordinary, independently loaded service modules.** Neither service is registered by a compiled `ServiceID` enum, has special logic in DaemonQuay's GUI, or requires Python. Bundled modules and future user modules follow **the exact same** discovery, validation, control and log-display path.

> **Module developer specification:** [Docs/MODULE_SPEC.md](Docs/MODULE_SPEC.md) documents the current executable-module protocol, manifest schema, installation rules, permissions and multiple lifecycle implementation examples. The oMLX/Caddy modules remain the reference implementations.

## Log viewer (v0.11.5)

The GUI displays at most the last **10,000 lines** of a selected Log/Error file on Reload. Shorter files are shown in full. This is a read-only display limit, not log rotation: original files are retained. See [TESTING_v0.11.5.md](TESTING_v0.11.5.md) for verification steps.

## Install and build

**Before upgrading:** stop oMLX and Caddy through the *old* ServiceDeck, then quit the old GUI. Preserve the settings and models. Do not overwrite a running App bundle. From the project directory:

```zsh
./Scripts/install.sh
./Scripts/build.sh
open ./build/DaemonQuay.app
```

**Important:** This package has been syntax-checked and its standalone native module host tested outside macOS. SwiftUI/AppKit compilation, bundled code signing, launchctl and service integration have **not** been tested on a target Mac; treat this as an integration candidate, not a proven production release.

`install.sh` never starts a job. Existing data is kept at `~/.local/share/DaemonQuay/`:

```text
settings.json                  # Existing settings retained, no migration needed
logs/omlx/{log,error}.log      # Legacy flat logs still readable
logs/caddy/{log,error}.log
agents/dev.daemonquay.*.plist
modules/                       # User-installed modules
 enabled-modules.json          # ["omlx", "caddy"] initially
```

Bundled service modules live at:

```text
DaemonQuay.app/Contents/Resources/Modules/
  omlx/{module.json,service.json,module-control}
  caddy/{module.json,service.json,module-control}
```

Both native `module-control` executables are built from **the same** `Sources/ModuleHost/main.swift`. The only service-specific logic is data in `service.json`. No hard-coded oMLX/Caddy branching exists in the application or module host. Advanced future services can instead supply their own executable implementing the same protocol.


## Storage locations and file lifecycle

**User-owned DaemonQuay data remains at `~/.local/share/DaemonQuay/`.** This release does not automatically migrate it to `~/Library/Application Support/DaemonQuay/`.

### Build artifacts and deployed App

`./Scripts/build.sh` builds `build/DaemonQuay.app` and an intermediate `build/module-control`. The complete App bundle includes the GUI, English/Traditional Chinese resources, and bundled `omlx`/`caddy` modules (each with `module.json`, `service.json`, and `module-control`). Copy the **entire** bundle to `/Applications/DaemonQuay.app` or another install location; do not copy only the GUI executable. The project source and intermediate build output are not needed once the deployed App works.

### Files created in the user's home directory

| Path (under `~/.local/share/DaemonQuay/`) | Creator and purpose |
|---|---|
| `settings.json` | Installer initializes if absent; GUI updates module settings. |
| `enabled-modules.json` | Installer initializes enabled module IDs; user edits for external modules. |
| `service-order.json` | Saved after customizing display order; **not** shutdown order. |
| `gui.lock` | Single-instance GUI lock file; its existence after quitting is harmless. |
| `agents/dev.daemonquay.*.plist` | Created/updated by the bundled launchd module host on start. |
| `logs/<id>/log.log` | Service stdout; may be empty. |
| `logs/<id>/error.log` | Service stderr; INFO messages may appear here. |
| `modules/<id>/` | User-installed external modules only; bundled modules are in the App. |

The installer creates the base directories; service-specific logs/agents appear when a module starts a service. Stopping does not automatically remove existing log or plist files. Older versions may leave flat `logs/omlx.out.log`, `logs/omlx.err.log`, similar Caddy logs, or Python scripts; upgrading does not delete them. The log viewer may read legacy logs as fallback.

### Other locations and ownership

- `~/Library/Preferences/local.daemonquay.manager.plist` (normally): macOS UserDefaults, e.g. UI language; macOS manages persistence.
- macOS temporary directory: transient `dq-out-*`, `dq-err-*`, `dq-cmd-*` files. Normally removed after actions; abrupt termination may leave remnants.
- `~/.omlx/`, `~/.config/caddy/Caddyfile`, `~/Library/Application Support/Caddy/`, and user-selected model/cache storage in a user-selected directory: **native tool or user data, not owned by DaemonQuay**. Never remove them as part of DaemonQuay cleanup.
- `launchctl bootstrap` changes user GUI-domain runtime state; it does not mean another persistent DaemonQuay data directory was created.

### Update or uninstall

Stop all managed services normally, verify the launchd jobs are no longer running, then quit the GUI before replacing/removing the App. Keep `~/.local/share/DaemonQuay/` through updates. Only delete that directory after deliberately deciding to remove saved settings, external modules, and logs. There is **no full automatic uninstaller**, and no automatic cleanup of old-version artifacts. Third-party modules may create other files; check their own documentation.

Inspect current data with `open "$HOME/.local/share/DaemonQuay"` or `find "$HOME/.local/share/DaemonQuay" -maxdepth 3 -print`.

## Architecture

```text
SwiftUI/AppKit menu + dynamic settings + log viewer
                 |
          PluginRegistry
                 |
           PluginRuntime  (executes only enabled modules)
              /      \\
       bundled       user-installed modules
          |                 |
     start/stop/status JSON protocol
          |                 |
      launchd          module-defined backend
          |
      oMLX, Caddy
```

The App passes exactly one action argument to each short-lived module controller. It passes the following environment variables:

- `DAEMONQUAY_MODULE_ID`: `omlx` / `caddy` / other unique module ID
- `DAEMONQUAY_MODULE_DIR`: absolute directory of the selected module
- `DAEMONQUAY_DATA_DIR`: `~/.local/share/DaemonQuay`

Every action must print **one JSON object** to stdout, e.g. `{"state":"running","message":"PID 123"}`. Supported states: `running`, `stopped`, `external`, `error`. Diagnostic text goes to stderr. The core invokes `status`, `start`, `stop`; `validate` is an optional fourth action (`supportsValidate: true`) for modules exposing editable settings. Modules must exit after replying; the actual service lives independently of the module control process.

The Core:
- never assumes module processes are themselves the long-running services;
- never terminates a module-reported external process;
- verifies `start` and `stop` by polling the module's own `status` operation;
- on normal GUI quit, stops modules in ascending `stopOrder`; failure blocks GUI quit;
- does **not** automatically start or restart services and never uses `SIGKILL` to enforce a stop;
- does not verify model inference, Caddy proxy health or any service-specific business logic.

### Settings

The bundled modules' `module.json` files declare editable string/integer fields. The SwiftUI settings view is generated from these fields; it no longer branches by service ID. The historic `settings.json` document is still used: its existing `omlx` and `caddy` subtrees remain valid. Saving edits only the selected module's keys, retaining unrelated modules' values. Settings can be saved only when the selected service is stopped. Unknown fields are preserved. A version-specific module is responsible for interpreting its own settings.

Service-specific native configuration remains owned by its tool. DaemonQuay does **not** edit the oMLX model/Profiles/API-key JSON or Caddyfile. The Caddy module validates its Caddyfile before startup. oMLX uses existing model and SSD locations. Restart is always manual.

### Adding a new module without recompiling the GUI

1. Create `~/.local/share/DaemonQuay/modules/<id>/`.
2. Place `module.json` and an executable inside it. The manifest must provide `apiVersion: 1`, an ID equal to the directory name, `name`, and a relative `executable` path. Optionally include a `settings` schema, `stopOrder`, timeouts, SF Symbol `symbol`, and `supportsValidate`.
3. Implement `start`, `stop`, and `status` in that executable using the JSON response contract. You may reuse the generic module host binary **if** your service fits its launchd definition format (see bundled modules), or write a custom executable for a specialized service.
4. Add the ID to `~/.local/share/DaemonQuay/enabled-modules.json` explicitly. Do not enable code you do not trust. Restart DaemonQuay to rescan modules. Module enable/disable GUI is intentionally deferred.
5. Install/modify modules only while their services are stopped. Keep enabled modules available for lifecycle tracking even when GUI is not running.

`PluginRegistry` verifies that a module executable is an actual executable **inside** its module directory after resolving symlinks, checks IDs and timeouts, and refuses duplicate IDs. An external module cannot override a bundled module. This is *validation*, not a sandbox: an explicitly enabled executable acts with the user's permissions.

### Built-in module lifecycle

`service.json` describes `start`, optional `preflight`, paths required for validation, stop strategy (`signal` or `commandThenSignal`), port used for collision detection and timeout key. `${field}` interpolation is performed *per argument*, without invoking a shell. oMLX uses `serve` and SIGTERM; Caddy uses `run --config`, `validate --config`, and `caddy stop` with SIGTERM fallback on command failure. Both use their original `dev.daemonquay.*` launchd labels. `RunAtLoad=false` and `KeepAlive=false`. The state indicator means **process alive**, not guaranteed API readiness.

A module that implements its own backend (e.g. a container manager) may use a different status/stop mechanism. DaemonQuay Core will not make assumptions about that backend.

## Tests

On macOS:

```zsh
./Tests/run_tests.sh
```

After building the App, test manually: startup with both services stopped; start/stop individually; use Finder and Log/Error tabs; modify settings while stopped; reproduce a GUI crash and reopen; attempt duplicate GUI launch. This project intentionally does not execute oMLX or Caddy during unit tests.

## Safety and current limitations

- Python is not needed for the app runtime or bundled modules (only for project tests).
- New modules are discovered at startup or on settings-window refresh. The module enable file is not automatically refreshed by the GUI's two-second *service-state* timer.
- A module whose configuration is removed, or that is disabled while still running, may no longer be manageable through DaemonQuay. Stop a module **before** disabling or uninstalling it.
- DaemonQuay's single-instance GUI lock does not provide a cross-process lock against other tools changing a service. Module authors are responsible for their own idempotence and external-process protection.
- Per-service log paths remain `logs/<module-id>/log.log` and `error.log`, with read-only fallback to legacy flat files.
- launchd-related behavior, especially graceful termination on UPS/system shutdown, requires target-machine integration testing; ExitTimeOut is not a guarantee.
- Third-party modules are explicitly trusted executables. Do not install untrusted modules; a JSON manifest alone cannot isolate them.


## v0.10.1 fix

Removed obsolete `ServiceController.loadSettings()` call from `WindowPresenter.showSettings`. Dynamic `SettingsView` loads settings on appear. No service modules or settings are modified.

## v0.10.2: Custom service display order

Settings now includes **Service display order**. Drag a row onto another row or use the up/down arrows; the menu bar and service selectors follow the order immediately. The preference is stored separately in `~/.local/share/DaemonQuay/service-order.json`. It does not modify `module.json`, `service.json`, or native tool settings. New modules not yet in the preference appear last in ID order. Service shutdown still uses the independent module `stopOrder`.

## v0.10.3: Module Specification release

Added comprehensive `Docs/MODULE_SPEC.md` and clarified the boundary between universal module API and the optional generic launchd `service.json` format. No service start/stop/status implementation or security permissions were changed in this release.

## v0.11.0: Bilingual documentation and publishing preparation

No runtime behavior changed. Added Traditional Chinese documents, complete Apache License 2.0 text, an attribution `NOTICE` template, and a publishing checklist. **Verify the copyright attribution and source headers before publishing.** The name “DaemonQuay” is already used by unrelated software/services; review a rename before public release. See [Docs/GITHUB_RELEASE.md](Docs/GITHUB_RELEASE.md) and [Docs/GITHUB_RELEASE.zh-Hant.md](Docs/GITHUB_RELEASE.zh-Hant.md).

## Name and authorship / 專案命名與作者

See [Docs/NAME_AND_CREDITS.md](Docs/NAME_AND_CREDITS.md) for screened name candidates and attribution.


## v0.11.0: branding, visibility and persistence

**DaemonQuay** replaces the original project name. New user data is stored in
`~/.local/share/DaemonQuay/`, with `settings.json`, `service-order.json`,
`hidden-services.json`, `enabled-modules.json`, `agents/`, `logs/`, and `modules/`.
Installation *copies* existing ServiceDeck `settings.json`, enabled modules and display
order when the new files do not exist. It does not delete or move old logs or external
modules, so migrate those manually if required. Do not install while either old
ServiceDeck-managed service is active; stop services and quit the old GUI first.
The old `.app`, preferences and data are left unchanged.

The settings window includes a **Show** checkbox for each module next to the
move arrows. The chosen order persists after relaunch. Hiding affects only the
menu and log-service picker, not module discovery, saved configuration, service
lifecycle or global quit safeguards. Running/unknown modules cannot be hidden:
stop them first. Uncheck Show to hide and check again to restore. The settings
window always lists all enabled modules, including hidden ones. Display order does
not alter `stopOrder`.

The fresh-install oMLX example uses `~/.omlx/models` and **enables optional SSD cache**
with `~/.omlx/cache` and `20GB`. Clear the SSD cache directory to omit both cache
command-line options. User-selected cache directories must exist before starting.
Settings copied from a previous ServiceDeck installation remain as the user
configured them and are **not reset**.
Native oMLX credentials, models and Caddy settings are never copied or edited.

Icon assets are in `Resources/Icons/`: a source SVG and 1024 px PNG for the App,
plus a transparent template PNG/SVG for the menu bar. macOS `iconutil` produces
`AppIcon.icns` during `build.sh`.


## Bundled oMLX example, customization and replacement

The **fresh-install example** enables optional paged SSD cache at `~/.omlx/cache` with a `20GB` maximum. It is not an oMLX mandatory setting. When first starting the bundled default, DaemonQuay creates that default cache folder if `~/.omlx/` exists and is writable; it does **not** create arbitrary user-specified cache folders. If the model directory does not exist, configure it first. Clearing **SSD cache directory** in the GUI omits both SSD cache CLI flags, regardless of the size field; users who want no cache do not need that folder. Custom cache locations must be created by the user. Existing `settings.json` values are preserved during installation.

**Customize the shipped oMLX service:** For basic path, port and cache settings, stop oMLX, open DaemonQuay Settings, edit and save, then manually start. Settings are saved under `~/.local/share/DaemonQuay/settings.json`. For **service definition** changes (arguments, stop method, launchd strategy), edit the *source tree* `Modules/omlx/service.json` and, if required, `Modules/omlx/module.json`, then rebuild and replace the App while its services are stopped. Do **not** edit the signed installed `.app` bundle. The Caddy reference lives at `Modules/caddy/` and uses a native `~/.config/caddy/Caddyfile`.

**Replace with your own oMLX module:** Implement the Module API v1 documented in [`Docs/MODULE_SPEC.md`](Docs/MODULE_SPEC.md), assign a **different module ID** such as `my-omlx`, and install its `module.json` and executable under `~/.local/share/DaemonQuay/modules/my-omlx/`. Add `my-omlx` to `enabled-modules.json` and remove `omlx` from the same JSON array **only after stopping the old module-managed service**. This disables the bundled default, it does not uninstall it. Keep unique launchd labels and do not start both variants against the same port. Restart DaemonQuay to reload module registration. The Settings **Visible** checkbox only hides a service from the menu; it does **not** disable the module.

Example enablement with custom oMLX and stock Caddy: ` ["my-omlx", "caddy"] `.


## v0.11.2 Menu Bar icon sizing fix

The menu bar now uses a system square-width status item and an 18-point template icon. The transparent icon bitmap is tightly cropped, preventing excessive menu-bar space. The app icon and service lifecycle code are unchanged.


### Settings sidebar footer (v0.11.4)
The sidebar displays the App Bundle version, © 2026 Y.C. Liu (ycliu0214), and Licensed under Apache License 2.0. No separate About page is added.

### Build environment / 編譯環境

[Build requirements](Docs/BUILD_REQUIREMENTS.md)
