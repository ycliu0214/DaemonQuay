# DaemonQuay v1.0.1 Release Checklist

**Status:** Source release preparation. Complete the checks below on the target Mac before publication. Developer ID signing and Apple notarization are not included in the current build process.

1. Back up `~/.local/share/DaemonQuay/` before upgrading. Preserve existing settings, logs, installed modules, and service configurations.

2. Build and test on the target Mac:
   ```zsh
   zsh Scripts/build.sh
   zsh Tests/run_tests.sh
   ```
   Confirm application version **1.0.1** and build **30**.

3. Verify the main interface, menu bar status indicators, settings, language persistence, service controls, and log viewing in both English and Traditional Chinese.

4. Verify the Service Logs selector displays multiple modules correctly without clipped or overlapping labels.

5. Verify existing bundled **oMLX** and **Caddy** modules retain their start, stop, status, and configuration behavior.

6. Verify the optional **Tailscale external module** can be installed independently, enabled through `enabled-modules.json`, and controlled through DaemonQuay without rebuilding the application. Test Start, Stop, Status, and Validate. Confirm that its VPN state matches the Tailscale application.

7. Confirm modules under `ExternalModules/` are not automatically bundled into `DaemonQuay.app`. Review module documentation and executable permissions.

8. Verify upgrading an existing installation preserves user settings, service order, hidden services, logs, and installed external modules.

9. Review Git changes for credentials, personal paths, logs, generated files, and other unintended content before committing.

10. Create the Git commit and annotated `v1.0.1` tag only after completing the applicable checks.

11. An optional DMG can be created with `zsh Scripts/create_dmg.sh`. The current build uses ad-hoc signing and is not notarized. Public binary distribution requires Developer ID signing, hardened runtime, Apple notarization, and verification on a clean macOS installation.

12. Publish the GitHub source release with accurate release notes. Clearly identify Tailscale as an optional external module.

**Verification:** Record completed tests and any remaining limitations before publishing. Do not describe unperformed checks as passed.

