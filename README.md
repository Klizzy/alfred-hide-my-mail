# alfred-hide-my-mail
<p align="center">
  <img src=".assets/hide-my-mail.png" alt="Hide My Mail Logo" width="200">
</p>

🎩 Create a new iCloud Hide My Mail address with a specified label via Alfred and have it copied to your clipboard.


## Installation
1. Download the latest `.alfredworkflow` file from the [releases page](https://github.com/Klizzy/alfred-hide-my-mail/releases).
2. Double-click the downloaded file to import it into Alfred 5.
3. Configure the workflow, if your MacOS system language is not set to English.

## Usage
1. Open Alfred (default shortcut: `Option + Space`).
2. Type `hide` followed by the label you want to assign to the new iCloud Hide My Mail address.
3. Press `Enter`.
4. Press `CMD + V` to paste the generated iCloud Hide My Mail address.

The workflow will open the MacOS System Settings, navigate to the appropriate section, create a new iCloud Hide My Mail address with the specified label and adds the generate mail to your clipboard.

## Requirements

1. Alfred 5.1 or later
2. Active [iCloud+](https://support.apple.com/guide/icloud/mm9d9012c9e8/icloud) subscription
3. MacOS 14.1 or later
4. Your MacOS system language is supported by the workflow

## Configuration

The workflow currently supports the following languages and config values:
- English
  - `EN`
- German
  - `DE`

The default setting is `EN`. To change the language, open the Alfred Preferences, navigate to the `Workflows` tab, select the `Hide My Mail` workflow, and click on the `Configure Workflow` button. Here you can change the language setting to `DE` and save the configuration.

## Why?

On some websites you don't get the native icloud+ hide my mail prompt for the email field, so it has to be created manually.
The complete process is automated with this workflow, so you don't have to click 8-10 times through the system settings to get your generated mail.

## Contact & Support

- [Code & Support](https://github.com/Klizzy/alfred-hide-my-mail)
- [LinkedIn](https://www.linkedin.com/in/steven-zemelka-82807b279/)

## Credits

The main script is heavily inspired by a created Shortcut from [this reddit thread](https://www.reddit.com/r/shortcuts/comments/yp5817/comment/je8o0or/)
