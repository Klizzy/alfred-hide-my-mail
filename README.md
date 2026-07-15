# alfred-hide-my-mail
![Download Count](https://img.shields.io/github/downloads/klizzy/alfred-hide-my-mail/total?label=Downloads&style=plastic)
![Last Release](https://img.shields.io/github/v/release/klizzy/alfred-hide-my-mail?label=Latest%20Release&style=plastic)

<p align="center">
  <img src=".assets/hide-my-mail.png" alt="Hide My Mail Logo" width="200">
</p>

### 🎩 Create a new iCloud Hide My Mail address automatically with an specified label via Alfred and have it copied to your clipboard.

## Showcase
> The whole shown process is completed within a couple seconds.
<p align="center">
  <img src=".assets/alfred-command.png" alt="Hide My Mail Logo" width="623">
  <img src=".assets/complete-workflow.gif" alt="Hide My Mail Logo" width="803">
</p>


## Installation
1. Download the latest `.alfredworkflow` file from the [releases page](https://github.com/Klizzy/alfred-hide-my-mail/releases).
2. Double-click the downloaded file to import it into Alfred 5.

## Usage
1. Open Alfred (default shortcut: `Option + Space`).
2. Type `hide` followed by the label you want to assign to the new iCloud Hide My Mail address.
3. Press `Enter`.
4. Press `CMD + V` to paste the generated iCloud Hide My Mail address.

The workflow will open the MacOS System Settings, navigate to the appropriate section, create a new iCloud Hide My Mail address with the specified label and adds the generate mail to your clipboard.

## Requirements

1. Alfred 5.1 or later
2. Active [iCloud+](https://support.apple.com/guide/icloud/mm9d9012c9e8/icloud) subscription
3. macOS:

| macOS | Status |
|-------|--------|
| Sequoia 15.x | ✅ Tested |
| Tahoe 26.x | 🧪 Community-reported working (please report issues with `hide-diagnose`) |
| Other versions | ⚠️ Untested — run `hide-diagnose` and open an issue to add support |

The workflow auto-detects your macOS version and loads the matching UI map from `ui-maps/`. If your version isn't mapped yet, it falls back to the newest map and warns you.

## Configuration

You can change the keyword to trigger the workflow by opening the Alfred Preferences, navigating to the `Workflows` tab, selecting the `Hide My Mail` workflow, and clicking on the `Configure Workflow` button. Here you can change the keyword to your desired value.
- The default keyword is `hide`.

## Diagnostics

If the workflow stops working after a macOS update, help get it fixed:

1. Open Alfred and run `hide-diagnose` (no argument).
2. It writes `~/Desktop/hide-my-mail-diagnosis.txt` with the current System Settings UI layout.
3. Open a [GitHub issue](https://github.com/Klizzy/alfred-hide-my-mail/issues) and attach that file.

The maintainer can turn that dump into an updated `ui-maps/<name>-<version>.plist` — usually with no script change.

## Why?

On some websites you don't get the native icloud+ hide my mail prompt for the email field, so it has to be created manually.
The complete process is automated with this workflow, so you don't have to click 8-10 times through the system settings to get your generated mail.

## Troubleshooting

**Nothing gets copied / System Settings just opens.** Your macOS version likely shifted the UI. Run `hide-diagnose` and open an issue (see Diagnostics).

**"System Settings got an error" / accessibility permission.** macOS may not prompt for Accessibility permission automatically. Grant it manually: System Settings → Privacy & Security → Accessibility → enable Alfred. If it's already listed but not working, remove and re-add it (or run `tccutil reset Accessibility` in Terminal and re-trigger).

**A leftover System Settings sheet from a previous run.** The workflow now quits System Settings before it starts, which clears this automatically.

**Last step doesn't complete on slower Macs.** Increase the final delay: open Alfred Preferences → Workflows → Hide My Mail → double-click the `Run Script` node and raise the trailing `delay 1` to `delay 2` (or higher).

## Building from source

The workflow bundles `info.plist`, `icon.png`, both scripts, and `ui-maps/`. Rebuild the `.alfredworkflow` after editing:

```sh
./package.sh
```

This writes `HideMyMail.alfredworkflow` in the repo root, which Alfred imports on double-click.

## Contact & Support

- [Code & Support](https://github.com/Klizzy/alfred-hide-my-mail)
- [LinkedIn](https://www.linkedin.com/in/steven-zemelka-82807b279/)

## Credits

The main script is heavily inspired by a created Shortcut from [this reddit thread](https://www.reddit.com/r/shortcuts/comments/yp5817/comment/je8o0or/)
