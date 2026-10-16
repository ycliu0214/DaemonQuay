[**繁體中文**](MODULE_SPEC.zh-Hant.md) | **English**

# DaemonQuay Module Specification · API v1

**Scope:** DaemonQuay v0.10.4 (documentation-only changes; same runtime behavior as v0.10.2). This is the **current, implemented** module interface, not a promise of all the extension ideas in this document.

**Design boundary:** DaemonQuay owns the menu/UI, module discovery, invocation and presentation. Each module owns three service-lifecycle operations: **start, stop, status**. A module is responsible for correct normal startup/shutdown and for reporting whether its own service is alive, not for diagnosing business-level errors, model inference, HTTP health, etc. Modules may implement their backend differently; `launchd` is not mandatory for third-party modules.

## 1. Contents and where to install

A basic **external** module looks like:

```text
~/.local/share/DaemonQuay/modules/example/
├── module.json            # required
├── module-control         # required executable; name/path chosen by manifest
└── service.json           # OPTIONAL, and understood only by the bundled generic ModuleHost
```

`module.json` is mandatory. `service.json` is **not** universally required: it is configuration for DaemonQuay's provided generic launchd module host, **not** part of the universal executable module API. An independent executable may use another internal format or none. The module executable may be native compiled code or an executable script with a valid shebang.

Bundled oMLX/Caddy modules follow the same interface and are built inside `DaemonQuay.app/Contents/Resources/Modules/{omlx,caddy}/`. Bundled modules take precedence over user modules with the same ID. Never edit or install user modules into a signed App bundle: updates may overwrite them and modifying the bundle can invalidate its signature.

**Current manual installation sequence**:

1. Finish testing the external tool independently (including its normal shutdown).
2. Create `~/.local/share/DaemonQuay/modules/<id>/`; copy an already built control executable, `module.json` and any module-owned supporting files. Verify it has executable permission (`test -x ...`). Do not run untrusted code.
3. Add the module ID to the JSON array in `~/.local/share/DaemonQuay/enabled-modules.json`, preserving existing entries (e.g., `omlx`, `caddy`). This is **manual**: no module installation/enable GUI exists yet.
4. Restart the DaemonQuay GUI to rescan its module registry. The settings window also triggers a module rescan, but restarting is simplest. Do not disable, overwrite or uninstall a module while its service is running.
5. When installing updates, stop the service using the old module first. Replace the module only while stopped.

There is no current automated module installer, sandbox, trust-verification workflow, module update system or CLI. Explicitly enabling a third-party executable runs it with the logged-in user's permissions.

## 2. `module.json` manifest: exact implemented schema

```json
{
  "apiVersion": 1,
  "id": "example",
  "name": "Example Server",
  "executable": "module-control",
  "symbol": "shippingbox",
  "stopOrder": 50,
  "startTimeoutSeconds": 20,
  "stopTimeoutSeconds": 60,
  "statusTimeoutSeconds": 4,
  "supportsValidate": false,
  "settings": [
    {"key": "executable", "type": "string", "labels": {"zh-Hant": "執行檔", "en": "Executable"}},
    {"key": "port", "type": "integer", "labels": {"zh-Hant": "連接埠", "en": "Port"}}
  ]
}
```

| Field | Required | Implemented behavior / constraints |
|---|---|---|
| `apiVersion` | Yes | Integer **1** only. Other versions rejected. |
| `id` | Yes | Must match directory name. Regex `^[a-z][a-z0-9-]{1,39}$` (2–40 chars). Unique across both discovery roots. |
| `name` | Yes | Nonempty after trimming whitespace, at most 80 characters. |
| `executable` | Yes | **Relative** path to a regular executable file inside module directory, even after resolving symlinks. Absolute paths / escape outside directory rejected. |
| `symbol` | No | SF Symbol name; defaults to `shippingbox`. Current loader does not validate availability of symbol. |
| `stopOrder` | No | Integer, default 50. Only for normal **stop-all-and-quit**; ascending order. **Not** the user-configurable display order. |
| `startTimeoutSeconds` | No | 1–120 seconds; default 20. Applies to a control invocation and to overall state polling after start. |
| `stopTimeoutSeconds` | No | 10–300 seconds; default 60. Applies to stop control and state polling. |
| `statusTimeoutSeconds` | No | 1–10 seconds; default 4. `validate` invocation timeout is this value plus 10 seconds. |
| `supportsValidate` | No | Boolean, default false. When true, Settings invokes `validate` to check saved settings. |
| `settings` | No | Array of field definitions; default empty. Current UI supports **only** `string` and `integer`, no typed path picker, booleans, secrets or conditional rules. |

For a settings field, `key`, `type`, and `labels` are required. `key` matches `^[A-Za-z][A-Za-z0-9]*$` and must be unique within the module; `labels` maps locale strings to text; view falls back to English or the key. Currently no `min`, `max`, `default`, `required`, or secret-handling schema is enforced by the generic GUI. Module validation should enforce service-specific bounds. Adding unspecified JSON keys to the manifest **does not make the GUI implement those features**.

Registry rejects invalid manifest/permissions/duplicate ID and lists a module issue. Discovery checks both `App Bundle/Resources/Modules/` and `~/.local/share/DaemonQuay/modules/`. `enabled-modules.json` must decode as an array of strings. When that file is absent or invalid, current compatibility fallback enables bundled `omlx` and `caddy` only. Modules not enabled are omitted from regular control UI. Since disablement can hide running services, **stop before disabling**.

## 3. Executable Module API: invocation

DaemonQuay invokes the manifest's `executable` as a **short-lived process**, working directory = module directory, with **exactly one command-line argument**:

```text
module-control status
module-control start
module-control stop
module-control validate     # only if supportsValidate is true
```

It provides these environment variables:

```text
DAEMONQUAY_MODULE_ID   unique module ID
DAEMONQUAY_MODULE_DIR  absolute module directory
DAEMONQUAY_DATA_DIR    ~/.local/share/DaemonQuay (absolute path)
```

The remaining process environment is inherited from the GUI process. Do **not** assume interactive shell initialization files, aliases, Homebrew PATH, or a Terminal session. Prefer absolute executable paths. Modules must emit **one parseable JSON object** on stdout, encoded UTF-8, and exit promptly. The response object supports:

```json
{"state":"running","message":"Running (PID 1234)"}
```

`state` is required; `message` is optional. Valid recognized values: `running`, `stopped`, `external`, `error`. The response must be at most 65,536 bytes. Keep stdout clean of log/debugging output; use stderr for diagnostics. Additional JSON fields are currently ignored. No streaming/IPC session is supported; DaemonQuay calls a fresh controller process for each action.

**Exit status and state must agree**: current runtime accepts the state only when process exit code is zero; nonzero exit is a failure (it may use `message` in the UI). For `status`, `running` is mapped internally to success code 0; `stopped` to status code 1; `external` to 3; `error`, unrecognized or malformed JSON to 2. These **are internal mappings**, not the controller process's OS exit codes. A `stopped` status reply must therefore still exit OS code **0**.

### Action semantics

- **`status`**: Return `running` for your *managed* service, `stopped` when not running and no known conflict, `external` if an unrelated instance/conflict makes operations unsafe, and `error` when reliable status cannot be determined. No side effects; should be fast. DaemonQuay polls every ~2 seconds while GUI runs.
- **`start`**: Must be idempotent: check ownership/occupancy; never silently duplicate a running managed service or take over an external one. Request startup and return a state. DaemonQuay polls `status` until `running`, timeout, or error. A control process may return before the long-running service is ready; business-level readiness is outside current contract.
- **`stop`**: Use the tool's correct graceful method, on your *managed* service only. Wait as appropriate and return a state. DaemonQuay polls `status` until `stopped` or timeout. Do not claim success merely because a signal/stop command was issued. On failure preserve diagnostics; do not silently `SIGKILL` somebody else's process.
- **`validate`** (optional): Validate current stored settings without starting the service. Existing built-in generic host returns `{"state":"stopped","message":"Configuration valid"}` on success; DaemonQuay currently accepts **`running` or `stopped` with exit code zero** as validation success. Keep it side-effect-free.

**Important limitations of the current runtime:** `start`/`stop` is guarded by an initial `status` query and final status polling. There is no general **cross-process atomic lock** across independent GUIs/CLI/direct manual launches. Module authors must ensure their own ownership check and avoid killing external processes. Status checks cannot prevent every possible race. DaemonQuay's GUI single-instance lock covers the GUI, not arbitrary external calls.

### Errors, timeout, protocol violations

A module can report `{"state":"error","message":"..."}` with an OS exit status of 0 or nonzero; either is treated as failure. A nonzero exit causes a failure **even if** `state` is `running` or `stopped`. If stdout is malformed, too large, absent, or output contains extra unparseable text, DaemonQuay reports an invalid module response (possibly showing a short stderr excerpt). Timeout terminates **the control invocation**, not necessarily the actual service. `status` error or `external` causes start/stop to fail closed rather than interfere with another process.

## 4. Settings storage, logs, ordering, and data permissions

- Shared file: `~/.local/share/DaemonQuay/settings.json`; per-module dictionary at root key `id`, e.g. `"example": {"executable":"/absolute/path", "port":1234}`. The dynamic GUI edits fields declared in `module.json` and preserves unknown keys / other module settings.
- **Currently no automatic defaults for new modules:** module authors/users must provide needed keys. Generic module host requires settings subtree to exist. In custom controllers, decide explicitly how to handle missing settings.
- Settings may be edited in GUI only if `status == stopped`. For modules with `supportsValidate`, the GUI writes updated settings, calls `validate`, and tries to roll back on failure. No full transactional lock across external tools exists.
- Service stdout/stderr log convention: `~/.local/share/DaemonQuay/logs/<id>/log.log` and `error.log`. Current GUI reads these paths and has read-only fallback to earlier flat log names. **Core does not automatically route arbitrary third-party services' output**: module authors must arrange the destination or explain if logs are unavailable.
- stdout and stderr are stream names, **not** severity categories; normal INFO entries often go to `error.log`.
- Service display order is saved in `service-order.json`. It does not change `stopOrder`.
- Keep API keys/secrets out of CLI arguments and logs where possible. DaemonQuay files and launchd `ProgramArguments` can disclose plaintext options to processes allowed to read them; current Core is **not** a secret vault and third-party modules are unsandboxed. The user account can access files under its own permissions. A future permission-hardening change must not remove execute bits from module executables.

## 5. Generic `launchd` module host: **optional** helper format

The built-in oMLX and Caddy modules share `Sources/ModuleHost/main.swift`, built as `module-control` per bundled module. You can adapt or compile this host for another module. When using this particular host, you must provide `service.json`:

```json
{
  "apiVersion": 1,
  "launchLabel": "dev.daemonquay.example",
  "start": ["${executable}", "serve", "--port", "${port}"],
  "stopStrategy": "signal",
  "portKey": "port",
  "timeoutKey": "shutdownTimeout",
  "requiredDirectories": ["${workspace}"],
  "requiredFiles": [],
  "preflight": null
}
```

Fields used by this host:

| Field | Requirement / semantics |
|---|---|
| `apiVersion` | Required, integer 1. |
| `launchLabel` | Required, **exactly** `dev.daemonquay.<module-id>`. |
| `start` | Nonempty command argument array. First element must expand to an **absolute executable** path; it is run by `launchd` (no shell parsing). |
| `stopStrategy` | `signal` or `commandThenSignal` only. |
| `stopCommand` | Required nonempty argument array if using `commandThenSignal`; e.g. Caddy `stop`. Command failure triggers SIGTERM fallback. |
| `preflight` | Optional command argument array executed before starting; if command returns nonzero, no service is started. |
| `portKey` | Optional settings key containing integer TCP port; used for collision detection via `lsof`; if absent, no port check. |
| `timeoutKey` | Optional settings key containing integer graceful shutdown timeout (10–300 seconds); default 60 seconds. |
| `requiredDirectories`, `requiredFiles` | Optional arrays of paths that must exist, expanded from settings. |

Each argument supports interpolation of `${field}` using the module's settings dictionary, including substitution inside a string. Tilde at beginning of a **resulting** value (`~/`) is expanded to the user's home directory. No shell variable substitution, globbing, pipelines, redirection, command substitution or `PATH` lookup. Use a wrapper script with an `exec` final service command when complex setup is required; never background the long-running server and exit the wrapper if you want launchd to own it.

The generic host validates paths/ports/timeouts, optionally runs preflight, generates a launchd plist under `agents/`, with `RunAtLoad=false`, `KeepAlive=false`, and log paths under `logs/<id>/`. It uses `launchctl bootstrap` and `kickstart`, and checks the Job PID. It does **not** start at login, relaunch crashed services, provide an automatic health probe or use SIGKILL for graceful-stop timeouts. A `launchd` Job PID is **process liveness**, not an HTTP readiness guarantee. The host always targets the current account's `gui/<uid>` launchd domain; SSH sessions lacking the appropriate GUI domain may behave differently.

`commandThenSignal` caveat: current host falls back to SIGTERM only if `stopCommand` **fails**. A successful stop command that does not actually stop the PID results in a timeout, not automatic fallback. Module authors should test this explicitly.

## 6. Examples: ways to start, check liveness, and stop

**These are design examples, not built-in adapters or new JSON keys.** Implement them in your module executable if not directly supported by the generic launchd host. Actual service correctness is the module developer's responsibility.

| Scenario | Start | Status (liveness) | Normal stop | Notes |
|---|---|---|---|---|
| Long-lived foreground server | Execute directly via generic `launchd` host | `launchctl print` managed Job PID | `SIGTERM` | oMLX is the shipped reference; use foreground mode. |
| Native config-file server | `server run --config /path/config` | Managed Job PID | `server stop` (+ defined fallback) | Caddy is the shipped reference; DaemonQuay does not edit native config. |
| Wrapper/script for complex startup | Script sets env, then `exec /path/server ...` | PID of launchd-managed replacement process | Graceful signal or service-owned stop command | `exec` important; `server &; exit` breaks PID ownership. |
| App with its own graceful stop CLI | Use foreground launcher | Module-defined PID or managed job | Run official stop CLI, then verify exit | Caddy illustrates this general pattern. |
| Long-lived service not suited to launchd | Custom module controller starts through appropriate supervisor | Query supervisor using an owned identity | Supervisor's stop API | Not implemented by generic host; custom module executable required. |
| Container or VM | Custom module asks external manager to start | External manager inspect/status API | External manager stop/shutdown | `docker start` CLI process exiting does **not** represent container liveness. |
| Service with PID file | Custom module ensures PID belongs to its own instance | Validate PID file and process identity; guard against PID reuse | Official shutdown, confirm exit | Naive `kill(pid,0)` by itself is insufficient ownership verification. |
| Port-based detection | Start with proper process ownership checks | Port occupancy can flag conflict | Never stop arbitrary listener by port | Port alone cannot prove a process is a managed service. |

### Practical wrapper example (launchd-owned)

```zsh
#!/bin/zsh
set -e
export EXAMPLE_CONFIG="$HOME/.config/example/config.json"
cd "$HOME/ExampleWorkspace"
exec /absolute/path/to/example-server --config "$EXAMPLE_CONFIG"
```

For the generic launchd host, `service.json` points the `start` command array to the **absolute path of this executable script**. The `module.json` manifest still points its `executable` to the short-lived module controller. Do not put `~`, `$HOME`, `$(...)`, `&&`, or redirection syntax into an `arguments` array and expect shell interpretation. `exec` replaces the wrapper so launchd can track the foreground service.

### Custom controller example: response semantics (pseudocode)

```text
if argument == "status":
    if verified_owned_instance_is_alive(): reply({"state":"running", "message":"PID ..."})
    else if external_conflict_exists(): reply({"state":"external", "message":"Port occupied"})
    else: reply({"state":"stopped", "message":"Not running"})
if argument == "start":
    if status != stopped: return status
    start_with_tool_supported_mechanism()
    reply(status())
if argument == "stop":
    if status == external: return external
    request_graceful_shutdown_of_owned_instance()
    wait_or_delegate_to_DaemonQuay_polling()
    reply(status())
```

Do not claim that a PID, process name, TCP listener or single command success alone proves correct ownership. Use identifiers and semantics appropriate to the particular service.

## 7. Module developer acceptance checklist

- [ ] I can start and gracefully stop the tool **outside DaemonQuay** using exactly the intended commands.
- [ ] The module ID/folder and manifest are valid; executable is really inside the module directory and executable.
- [ ] `status` reliably distinguishes my managed instance, stopped state, external conflict and uncertainty.
- [ ] `start` is idempotent; second start does not spawn another copy.
- [ ] `stop` never targets an unrelated process, verifies eventual termination, and reports timeouts/errors.
- [ ] The executable prints one JSON response with an allowed `state` and exits OS code zero for normal states.
- [ ] `validate` (if enabled) does not start/stop a service or alter unrelated settings.
- [ ] The module works after closing and reopening the GUI; if the GUI crashes, the service remains independent where its backend permits.
- [ ] Settings survive restart; secret values are not leaked through logs or command arguments unintentionally.
- [ ] Log path behavior is documented, and module removal is tested **only after stopping** the service.
- [ ] The module is tested with realistic startup/shutdown delays and missing dependencies.
- [ ] No untrusted executable is automatically enabled.

## 8. Reference implementations and tests

See the actual shipped implementations, not hypothetical duplicated templates:

- `Modules/omlx/module.json`, `Modules/omlx/service.json`.
- `Modules/caddy/module.json`, `Modules/caddy/service.json`.
- `Sources/ModuleHost/main.swift` — native generic `launchd` host implementing both definitions.
- `Sources/DaemonQuay/Plugins/PluginRegistry.swift` — schema and executable validation.
- `Sources/DaemonQuay/Plugins/PluginRuntime.swift` — invocation, stdout protocol, timeouts, state polling.
- `Tests/test_modules.py` — portable conformance checks for bundled metadata.

**Testing limitation:** unit tests do not prove that a new third-party controller uses the right shutdown semantics, prevents races, or will work under macOS launchd. These need service-specific macOS integration tests.

### Optional argument groups (bundled launchd host)

`service.json` optionally supports `optionalStartArguments`: an array of
`{"whenNonEmpty":"settingKey","arguments":["--flag","${settingKey}"]}` entries.
When the specified config key is empty, the entire group is omitted. oMLX uses
this to keep SSD cache disabled in the published defaults. This option belongs
to the provided launchd host, not to the universal module protocol.
