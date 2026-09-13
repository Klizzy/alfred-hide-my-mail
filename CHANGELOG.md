# Changelog

## v1.3

### macOS Tahoe Support

Complete rewrite of the AppleScript automation to support macOS Tahoe 26.x, which introduced significant System Settings UI changes. The new script uses more robust element discovery and explicit process management.

**Changes:**
- Rewrote UI navigation to dynamically locate "iCloud+ Features" section by searching for the static text instead of relying on fixed element indices
- Added AXIdentifier-based button detection for the "Hide My Email" card with fallback to button index
- Implemented proper process lifecycle management with `killall` before opening settings and cleanup after completion
- Added sheet index detection to handle multiple concurrent sheets
- Improved error handling and timeout mechanisms throughout the workflow
- Updated README to require macOS Tahoe 26.x and document Accessibility permission requirement

**Note:** macOS Sequoia 15.x users should continue using v1.2.

## v1.2

### macOS Sequoia Support

Fixed the AppleScript GUI automation to work with macOS Sequoia 15.x, which changed the UI element hierarchy in System Settings.

**Changes:**
- Updated the Hide My Mail tile index in the iCloud+ features grid (`UI element 2` → `UI element 5`)
- Updated the Create New Address button index in the Hide My Mail sheet (`UI element 4` → `UI element 5`)

Resolves [#4](https://github.com/Klizzy/alfred-hide-my-mail/issues/4). Thanks to [@DrBones](https://github.com/DrBones) for identifying the required changes and sharing a working fix.

## v1.0

- Initial release with macOS Sonoma 14.1+ support
