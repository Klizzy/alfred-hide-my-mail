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
3. MacOS Sonoma 14.1 or later - **macOS Sequoia is not [yet](https://github.com/Klizzy/alfred-hide-my-mail/issues/4) supported**

## Configuration

You can change the keyword to trigger the workflow by opening the Alfred Preferences, navigating to the `Workflows` tab, selecting the `Hide My Mail` workflow, and clicking on the `Configure Workflow` button. Here you can change the keyword to your desired value.
- The default keyword is `hide`.

## Why?

On some websites you don't get the native icloud+ hide my mail prompt for the email field, so it has to be created manually.
The complete process is automated with this workflow, so you don't have to click 8-10 times through the system settings to get your generated mail.

## Troubleshooting

On some lower spec Macs, the last step can sometimes be not executed correctly while closing the system applications after copying the generated iCloud mail. If that occurs on your Mac, you can fix it by increasing the delay within the workflow script. To do so, follow these steps:
1. Open the Alfred Preferences
2. Navigating to the `Workflows` tab, selecting the `Hide My Mail` workflow and double click on the `Run Script` workflow item within the workflow editor
3. Increase the last delay in seconds at the end of the script, which is currently set to `delay 1`, to `delay 2` or higher
4. Save the change

In a future release this will be made configurable - so stay stuned!

## Contact & Support

- [Code & Support](https://github.com/Klizzy/alfred-hide-my-mail)
- [LinkedIn](https://www.linkedin.com/in/steven-zemelka-82807b279/)

## Credits

The main script is heavily inspired by a created Shortcut from [this reddit thread](https://www.reddit.com/r/shortcuts/comments/yp5817/comment/je8o0or/)
