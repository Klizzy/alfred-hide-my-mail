# Changelog

## v2.0

### Hardened, config-driven GUI scripting + macOS Tahoe support

Rewrote the automation so it survives macOS UI changes with a config edit instead of a script rewrite.

**Changes:**
- **Four-tier element search** (AXIdentifier → scoped AXRole → positional index → localized-name table) replaces hardcoded positional indices.
- **Per-version UI maps** in `ui-maps/` (`sequoia-15.plist`, `tahoe-26.plist`), auto-selected via `sw_vers`.
- **macOS Tahoe 26.x support**, based on the fix in [#6](https://github.com/Klizzy/alfred-hide-my-mail/pull/6) (thanks [@coryfklein](https://github.com/coryfklein), confirmed by [@kboyington](https://github.com/kboyington)). Uses the `…AppleIDSettings:icloud` pane, the `six-pack-card-Hide My Email` tile identifier, `AXPress` (Tahoe tiles ignore `click`), and the explicit Continue → Copy Address → Done flow.
- **`hide-diagnose` command** dumps the UI hierarchy to `~/Desktop/hide-my-mail-diagnosis.txt` so new-version maps are easy to contribute.
- **Honest notifications** — the success/failure message now reflects the script's actual result instead of always showing "Success!".
- **Robustness:** quits System Settings first (avoids `REVEAL_PANE_ERR_MODAL`), 10s timeouts on every wait, and a top-level error handler that cleans up.
- **`package.sh`** builds the `.alfredworkflow` bundle from the command line.

Localized button names seeded from [#1](https://github.com/Klizzy/alfred-hide-my-mail/pull/1) (English + German).

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
