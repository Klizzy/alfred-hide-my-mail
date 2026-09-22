# Changelog

## v2.0

### macOS Tahoe support, honest results, built-in diagnostics

**Changes:**
- **macOS Tahoe 26.x support.** Navigation based on [#6](https://github.com/Klizzy/alfred-hide-my-mail/pull/6) by [@coryfklein](https://github.com/coryfklein) (iCloud pane id, `six-pack-card-Hide My Email` tile, `AXPress`, Continue → Copy Address → Done), confirmed by [@kboyington](https://github.com/kboyington) and [@DrBones](https://github.com/DrBones). Sheet-index detection and reading the generated address from the sheet based on [#7](https://github.com/Klizzy/alfred-hide-my-mail/pull/7) by [@JosefGvirt](https://github.com/JosefGvirt) (verified on 26.6.2).
- **Sequoia 15.x keeps working** with its own proven navigation path (v1.2's).
- **The notification tells the truth.** Success is only reported when a new address really landed on the clipboard; the notification shows the address. Failures name the step.
- **Automatic diagnosis on failure.** `~/Desktop/hide-my-mail-diagnosis.txt` is written with the System Settings layout at the moment of failure. `hide-diagnose` produces it on demand.
- **Localised button names** (English, German, French, Spanish) with positional fallbacks.
- **Robustness:** clean restart of System Settings, 10 s timeout on every step, cleanup on every exit path, no stale window references.
- **Project:** scripts live in `src/` as executable `.applescript` files run by Alfred's External Script mode, `package.sh` builds the bundle, `tests/headless.sh` runs in GitHub Actions, `tests/live.sh` for manual smoke tests.

**Removed:** the embedded script copy in `info.plist`; Sonoma 14 support (use v1.0/v1.2).

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
