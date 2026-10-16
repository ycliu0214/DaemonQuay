# GitHub publishing and license review

[繁體中文](GITHUB_RELEASE.zh-Hant.md) | **English**

## License: Apache License 2.0 (recommended)

The author permits **commercial use**, modifications, and redistribution, while requiring preservation of attribution and visible modification notices. Apache-2.0 fits better than MIT for the modification-notice requirement. Its Section 4 requires redistribution with the license, prominent notices in modified files, preservation of applicable notices, and retention of NOTICE attributions if a NOTICE is supplied. It does **not** forbid resale or commercial redistribution and cannot require that every fork retain the same project name or prominently display a marketing-style credit in the app UI. See https://www.apache.org/licenses/LICENSE-2.0.html .

**Before publishing**, confirm the stated copyright holder (Y.C. Liu (ycliu0214)) and ownership of code/assets. Consider adding `SPDX-License-Identifier: Apache-2.0` and a matching copyright notice to owned source files. `LICENSE` contains the complete standard license text; do not customize it. If contributions or third-party material exist, audit their license obligations before redistribution. This guidance is not legal advice.

## Project name

The published name is **DaemonQuay**; the former ServiceDeck name is mentioned only in migration instructions. Recheck third-party trademarks and distribution availability before a public binary release.

## Source/repository review

- [ ] Keep `build/`, generated `.app`, `*.pyc`, `__pycache__/`, `.DS_Store`, and local temporary files out of Git (`.gitignore`).
- [ ] Do not commit `~/.local/share/DaemonQuay/`, real `settings.json`, installed service `agents/*.plist`, `logs/`, native oMLX/Caddy credentials, SSD paths, API keys, certificates or model data.
- [ ] `Config/settings.json` now uses `~/.omlx/models` with SSD cache disabled. The model directory must exist; SSD cache is optional.
- [ ] Audit all text/source/config for `/Users/...`, passwords, tokens, private keys and machine-specific identifiers.
- [ ] Verify binary `module-control` is not included as a source file; users should compile it from source. Releases may include signed/notarized binaries separately.
- [ ] Confirm that executable flags are preserved for `Scripts/build.sh` and `Scripts/install.sh`.
- [ ] Test `./Scripts/install.sh`, `./Scripts/build.sh`, `./Tests/run_tests.sh` on a supported Mac; test start, graceful stop, module status, re-open after crash, and duplicate-GUI toast.
- [ ] Use real Developer ID signing/notarization for public binary distribution as appropriate; ad-hoc local signing is not a substitute.
- [ ] Verify copyright attribution and decide on final project name before publishing.
- [ ] Ensure publication is authorized for any third-party source or assets embedded in the repo.

## Limits of this review

This is a source/package screening, not a security audit, Apple notarization test, trademark clearance or legal opinion. In particular, externally enabled modules run with user permissions and are **not sandboxed**. Updating/renaming installed jobs while running can cause disruption. Preserve user data and module API compatibility during any rebrand.

## Updated attribution and defaults

`NOTICE` now names `Y.C. Liu (ycliu0214)` (GitHub `ycliu0214`). Example paths use `~/.omlx/models` with SSD cache disabled. See [Name and credits](NAME_AND_CREDITS.md).

Verify renaming migration and persistent display/hidden preferences before release.
