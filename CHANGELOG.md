# Changelog

## v1.3

### macOS Tahoe Support

Fixed the AppleScript GUI automation to work with macOS Tahoe 26.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Navigate straight to the iCloud pane via the new `com.apple.systempreferences.AppleIDSettings:icloud` pane ID
- Locate the Hide My Email tile by `AXIdentifier` instead of a hardcoded grid index
- Updated sheet element paths for the redesigned Hide My Email sheet
- Added `package.sh` to build the `.alfredworkflow` bundle from the command line

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
