# Changelog

## v1.3

### macOS Tahoe (26.x) Support

Reworked the AppleScript GUI automation for macOS Tahoe 26.x, which restructured
System Settings again and broke the Sequoia paths.

**Changes:**
- Navigate directly to the iCloud pane via the new `com.apple.systempreferences.AppleIDSettings:icloud`
  pane ID instead of opening the Apple Account pane and clicking into iCloud.
- Locate the Hide My Email tile by its `AXIdentifier` (`six-pack-card-Hide My Email`)
  instead of a hardcoded grid index — the tile order in the iCloud+ features grid is not stable.
- Updated sheet element paths for the redesigned Hide My Email sheet (the new-address
  form sits at a different depth than the address list view).
- Use the `AXPress` accessibility action instead of AppleScript's `click` — in
  26.x the iCloud+ tile buttons no longer respond to `click`.
- Replaced busy-wait `delay 0` loops with real `delay 0.1` waits plus a 10 s
  per-step timeout so the script fails fast instead of pinning a CPU core.
- Quit any running System Settings instance before `reveal pane` to avoid
  `REVEAL_PANE_ERR_MODAL` when a stale sheet is left over from a previous run.

Added `package.sh` which bundles `info.plist` + `icon.png` into
`HideMyMail.alfredworkflow` so releases can be built from the command line.

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
