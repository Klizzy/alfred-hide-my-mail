# Changelog

## v2.0

### macOS Tahoe support, honest results, built-in diagnostics

**Changes:**
- **macOS Tahoe 26.x support.** Navigation based on [#6](https://github.com/Klizzy/alfred-hide-my-mail/pull/6) by [@coryfklein](https://github.com/coryfklein) (iCloud pane id, `six-pack-card-Hide My Email` tile, `AXPress`, Continue → Copy Address → Done), confirmed by [@kboyington](https://github.com/kboyington) and [@DrBones](https://github.com/DrBones). Sheet-index detection and reading the generated address from the sheet based on [#7](https://github.com/Klizzy/alfred-hide-my-mail/pull/7) by [@JosefGvirt](https://github.com/JosefGvirt) (verified on 26.6.2).
- **Sequoia 15.x: position-independent navigation.** The Hide My Email card is now found by its `six-pack-card-…` accessibility identifier instead of a fixed position (the iCloud+ grid gained an *Apple Invites* card in 15.3), the opened sheet is verified before anything is typed, and System Settings is opened directly on the iCloud pane instead of clicking through Apple Account.
- **The notification tells the truth.** Success is only reported when a new address really landed on the clipboard; the notification shows the address. Failures name the step.
- **Automatic diagnosis on failure.** `~/Desktop/hide-my-mail-diagnosis.txt` is written with the System Settings layout at the moment of failure. It includes the navigation log of the failed run; the next failure overwrites it. The open sheet is listed first, long lists (your saved address labels) are shortened to a few entries plus a count, and an element System Settings could not read shows the error (`? [err -1719: …]`) instead of a bare `?`. If System Settings stops responding, the dump stops after 3 timeouts or 60 s instead of waiting minutes. The diagnosis's navigation log shows the seconds since the start on every line.
- **Localised button names and card identifiers** (English, German, French, Spanish) with positional fallbacks for buttons; for an unknown language the card is found by the shape of the sheet it opens, and a failure lists the card identifiers seen so they can be added.
- **Robustness:** clean restart of System Settings (a hung instance from a previous run is force-quit and the new one is waited for), waits for the iCloud pane to really be on screen before clicking, a lost press on the Hide My Email card (the grid redraws once on a cold start) is repeated, 10 s timeout on every step, cleanup on every exit path, no stale window references.
- **Project:** scripts live in `src/` as executable `.applescript` files run by Alfred's External Script mode, `package.sh` builds the bundle, `tests/headless.sh` runs in GitHub Actions, `tests/live.sh` for manual smoke tests.

**Removed:** the embedded script copy in `info.plist`; Sonoma 14 support (use v.1.1 or v.1.0).

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
