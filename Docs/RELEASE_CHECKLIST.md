# DaemonQuay v1.0.0 release checklist

**Status:** Source package prepared. macOS build, GUI behavior, service control, Developer ID signing, and notarization **not verified** by this package preparation.

1. Back up `~/.local/share/DaemonQuay/` before a live upgrade. Keep existing running services unchanged. Do not overwrite oMLX or Caddy configuration.
2. On the target Mac, run `zsh Scripts/install.sh`, `zsh Scripts/build.sh`, and `zsh Tests/run_tests.sh`. Confirm app bundle version 1.0.0 and build 29 with `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/DaemonQuay.app/Contents/Info.plist`.
3. Test launch, sidebar hit-testing, general preferences, persisted language, startup hint toggle, one-time welcome prompt, menu status indicators/alignment, services start/status/graceful stop, log reload (last 10,000 lines), and quit/reopen. Test in both languages and appearances.
4. Verify updating a prior installation retains `settings.json`, logs, service order, hidden modules, and agents. Do not kill/restart existing services during an update. Review embedded ModuleHost paths before moving a live installation.
5. Build an optional drag-install disk image with `zsh Scripts/create_dmg.sh`; this script does not sign or notarize. The app and all nested executables must be correctly signed with a valid Developer ID Application identity and hardened runtime before Apple notarization; verify on a clean Mac. Do not publicly label an ad-hoc signed DMG as trusted/notarized.
6. Inspect `git status`, `git diff --cached`, and a secrets search before first public push. Commit only source, generic example configuration, and docs; never commit local user data, API keys, `build/`, `.app`, signing certificates, or logs.
7. Publish source release/tag only after source review; publish binaries only after macOS integration, Gatekeeper, and notarization checks.
