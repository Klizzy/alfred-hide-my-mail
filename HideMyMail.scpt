-- HideMyMail.scpt v2.0
-- Config-driven GUI scripting with a four-tier element search.
-- Source of truth — referenced by info.plist via `scriptfile`.

on run argv
    if (count of argv) is 1 and (item 1 of argv) is "--selftest" then
        return my runSelfTest()
    end if
    if (count of argv) is 0 then return "Failed: no label provided."
    set labelText to (item 1 of argv) as string

    set workflowDir to (do shell script "pwd")
    set majorVersion to my detectMajorVersion()
    set configPath to my findConfigFile(workflowDir, majorVersion)
    if configPath is "" then
        return "No UI map for macOS " & majorVersion & ". Run hide-diagnose to help add support."
    end if

    set paneId to my readConfig(configPath, "pane_id")
    set hasICloudSection to (my readConfig(configPath, "has_icloud_section") is "1")
    set icloudSectionIdx to my readConfigInt(configPath, "icloud_section_index")
    set hmeIdentifier to my readConfig(configPath, "hme_tile_identifier")
    set hmeIdx to my readConfigInt(configPath, "hme_tile_index")
    set createRole to my readConfig(configPath, "create_button_role")
    set createRoleIdx to my readConfigInt(configPath, "create_button_role_index")
    set createIdx to my readConfigInt(configPath, "create_button_index")
    set labelGroupIdx to my readConfigInt(configPath, "label_field_group_index")
    set labelIdx to my readConfigInt(configPath, "label_field_index")
    set confirmFlow to my readConfig(configPath, "confirm_flow")

    set localeCode to my currentLocaleCode()
    set createNames to my localeNames(configPath, "create_button", localeCode)
    set continueNames to my localeNames(configPath, "confirm_continue", localeCode)
    set copyNames to my localeNames(configPath, "confirm_copy", localeCode)
    set doneNames to my localeNames(configPath, "confirm_done", localeCode)

    try
        -- Clean start: quit first so no stale sheet triggers REVEAL_PANE_ERR_MODAL.
        if application "System Settings" is running then
            tell application "System Settings" to quit
            delay 0.5
        end if

        tell application "System Settings"
            activate
            delay 0.5
            reveal pane id paneId
        end tell

        tell application "System Events"
            tell application process "System Settings"
                set win to window 1

                -- Sequoia only: click the iCloud section first.
                if hasICloudSection then
                    set grid to group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of win
                    set icloudEl to my findElement(grid, "", "", 0, icloudSectionIdx, {}, "iCloud section", 10)
                    my pressElement(icloudEl)
                end if

                -- Hide My Email tile: Tier-1 identifier when known, else positional in the Sequoia grid.
                if hmeIdentifier is not "" then
                    set tileEl to my findElement(win, hmeIdentifier, "", 0, 0, {}, "Hide My Email tile", 15)
                else
                    set grid to group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of win
                    set tileEl to my findElement(grid, "", "", 0, hmeIdx, {}, "Hide My Email tile", 15)
                end if
                my pressElement(tileEl)

                -- Creation sheet (Create + Label sub-structure is identical on Sequoia and Tahoe).
                my waitForSheet(win, 10)
                set sheetRoot to UI element 1 of scroll area 1 of sheet 1 of win
                set createArea to group 1 of group 1 of group 1 of sheetRoot

                set createEl to my findElement(createArea, "", createRole, createRoleIdx, createIdx, createNames, "Create New Address", 10)
                my pressElement(createEl)

                set labelField to my waitForLabelField(sheetRoot, labelGroupIdx, labelIdx, 10)
                my pressElement(labelField)
                set focused of labelField to true
                set value of labelField to labelText

                if confirmFlow is "positional" then
                    -- Sequoia: 4 presses alternating group 2 / group 1 (already language-independent).
                    set confirmArea to group 1 of group 2 of group 1 of sheetRoot
                    set confirmIdx to my readConfigInt(configPath, "confirm_button_index")
                    set confirmCount to my readConfigInt(configPath, "confirm_count")
                    repeat with i from 1 to confirmCount
                        if i mod 2 is 1 then
                            set cGroup to group 2 of confirmArea
                        else
                            set cGroup to group 1 of confirmArea
                        end if
                        set cEl to my findElement(cGroup, "", "", 0, confirmIdx, {}, "Confirm step " & i, 10)
                        my pressElement(cEl)
                    end repeat
                else
                    -- Tahoe: Continue → Copy Address → Done (name-matched; PR #6's proven path).
                    delay 0.3
                    set g2 to group 2 of group 1 of group 2 of group 1 of sheetRoot
                    set g1 to group 1 of group 1 of group 2 of group 1 of sheetRoot
                    set continueEl to my findElement(g2, "", "", 0, 0, continueNames, "Continue", 10)
                    my pressElement(continueEl)
                    set copyEl to my findElement(g1, "", "", 0, 0, copyNames, "Copy Address", 10)
                    my pressElement(copyEl)
                    delay 0.3
                    set doneEl to my findElement(g2, "", "", 0, 0, doneNames, "Done", 10)
                    my pressElement(doneEl)
                end if
            end tell
        end tell

        tell application "System Settings"
            delay 1
            quit
        end tell
        return "iCloud mail has been added to your clipboard"

    on error errMsg
        try
            tell application "System Settings" to quit
        end try
        return "Failed at step: " & errMsg & ". Run hide-diagnose and report at github.com/Klizzy/alfred-hide-my-mail"
    end try
end run

----------------------------------------------------------------------
-- ELEMENT SEARCH LADDER + HELPERS
----------------------------------------------------------------------

-- Tier 1 AXIdentifier → Tier 2 scoped AXRole (roleIndex-th) → Tier 3 positional
-- → Tier 4 localized-name table. Retries until maxSeconds, then errors with stepName.
on findElement(parentElement, searchIdentifier, searchRole, roleIndex, fallbackIndex, nameList, stepName, maxSeconds)
    set maxAttempts to maxSeconds * 10
    set attempt to 0
    repeat
        try
            tell application "System Events"
                if searchIdentifier is not "" then
                    repeat with el in (entire contents of parentElement)
                        try
                            if (value of attribute "AXIdentifier" of el) is searchIdentifier then return el
                        end try
                    end repeat
                end if

                if searchRole is not "" and roleIndex > 0 then
                    set matchCount to 0
                    repeat with el in (entire contents of parentElement)
                        try
                            if (value of attribute "AXRole" of el) is searchRole then
                                set matchCount to matchCount + 1
                                if matchCount is roleIndex then return el
                            end if
                        end try
                    end repeat
                end if

                if fallbackIndex > 0 then
                    set candidateEl to UI element fallbackIndex of parentElement
                    get role of candidateEl -- forces existence; errors (and retries) if not present yet
                    return candidateEl
                end if

                if (count of nameList) > 0 then
                    repeat with b in (buttons of parentElement)
                        try
                            if (name of b) is in nameList then return b
                        end try
                        try
                            if (value of attribute "AXDescription" of b) is in nameList then return b
                        end try
                    end repeat
                end if
            end tell
            error "element not found"
        on error
            set attempt to attempt + 1
            if attempt > maxAttempts then error "Timeout at step: " & stepName
            delay 0.1
        end try
    end repeat
end findElement

on waitForSheet(win, maxSeconds)
    set maxAttempts to maxSeconds * 10
    set attempt to 0
    tell application "System Events"
        repeat
            try
                get sheet 1 of win
                return
            on error
                set attempt to attempt + 1
                if attempt > maxAttempts then error "Timeout waiting for creation sheet"
                delay 0.1
            end try
        end repeat
    end tell
end waitForSheet

on waitForLabelField(sheetRoot, groupIdx, fieldIdx, maxSeconds)
    set maxAttempts to maxSeconds * 10
    set attempt to 0
    tell application "System Events"
        repeat
            try
                set tf to text field fieldIdx of group groupIdx of group 1 of group 1 of sheetRoot
                get tf
                return tf
            on error
                set attempt to attempt + 1
                if attempt > maxAttempts then error "Timeout waiting for label field"
                delay 0.1
            end try
        end repeat
    end tell
end waitForLabelField

on pressElement(el)
    tell application "System Events"
        try
            perform action "AXPress" of el
        on error
            click el
        end try
    end tell
end pressElement

----------------------------------------------------------------------
-- HEADLESS SELF-TEST
----------------------------------------------------------------------

on runSelfTest()
    set wd to (do shell script "pwd")
    set report to {}

    set seqPath to my findConfigFile(wd, "15")
    my assertTrue(report, "findConfigFile(15) → sequoia-15.plist", (seqPath ends with "sequoia-15.plist"))
    set tahPath to my findConfigFile(wd, "26")
    my assertTrue(report, "findConfigFile(26) → tahoe-26.plist", (tahPath ends with "tahoe-26.plist"))
    my assertTrue(report, "findConfigFile(999) falls back non-empty", (my findConfigFile(wd, "999") is not ""))

    my assertEq(report, "sequoia os_name", my readConfig(seqPath, "os_name"), "Sequoia")
    my assertEq(report, "sequoia hme_tile_index", my readConfigInt(seqPath, "hme_tile_index"), 5)
    my assertEq(report, "sequoia missing key → 0", my readConfigInt(seqPath, "nope_nope"), 0)
    my assertEq(report, "tahoe hme identifier", my readConfig(tahPath, "hme_tile_identifier"), "six-pack-card-Hide My Email")
    my assertEq(report, "tahoe pane_id", my readConfig(tahPath, "pane_id"), "com.apple.systempreferences.AppleIDSettings:icloud")

    my assertEq(report, "continue de → {de, en}", my localeNames(tahPath, "confirm_continue", "de"), {"Fortfahren", "Continue"})
    my assertEq(report, "continue fr → {en}", my localeNames(tahPath, "confirm_continue", "fr"), {"Continue"})
    my assertEq(report, "continue en → {en}", my localeNames(tahPath, "confirm_continue", "en"), {"Continue"})
    my assertEq(report, "sequoia create has no names → {}", my localeNames(seqPath, "create_button", "en"), {})

    set fails to 0
    repeat with ln in report
        if (ln as text) starts with "FAIL" then set fails to fails + 1
    end repeat
    set out to my joinLines(report) & linefeed & "----" & linefeed
    if fails is 0 then
        return out & "SELFTEST PASS (" & (count of report) & " checks)"
    else
        return out & "SELFTEST FAIL (" & fails & " of " & (count of report) & " checks)"
    end if
end runSelfTest

on assertTrue(report, label, cond)
    if cond then
        set end of report to "PASS " & label
    else
        set end of report to "FAIL " & label
    end if
end assertTrue

on assertEq(report, label, actual, expected)
    if (my toStr(actual)) is (my toStr(expected)) then
        set end of report to "PASS " & label
    else
        set end of report to "FAIL " & label & " (got " & (my toStr(actual)) & ", want " & (my toStr(expected)) & ")"
    end if
end assertEq

on toStr(v)
    try
        if class of v is list then
            set AppleScript's text item delimiters to ", "
            set s to "{" & (v as text) & "}"
            set AppleScript's text item delimiters to ""
            return s
        end if
        return v as text
    on error
        return "<?>"
    end try
end toStr

on joinLines(lst)
    set AppleScript's text item delimiters to linefeed
    set s to lst as text
    set AppleScript's text item delimiters to ""
    return s
end joinLines

----------------------------------------------------------------------
-- CONFIG / VERSION / LOCALE
----------------------------------------------------------------------

on detectMajorVersion()
    set v to do shell script "sw_vers -productVersion"
    return do shell script "echo " & quoted form of v & " | cut -d. -f1"
end detectMajorVersion

-- Exact major-version config, else newest .plist, else "".
on findConfigFile(workflowDir, majorVersion)
    set configDir to workflowDir & "/ui-maps"
    try
        set m to do shell script "ls " & quoted form of configDir & "/*-" & majorVersion & ".plist 2>/dev/null | head -1"
        if m is not "" then return m
    end try
    try
        set n to do shell script "ls -t " & quoted form of configDir & "/*.plist 2>/dev/null | head -1"
        if n is not "" then return n
    end try
    return ""
end findConfigFile

on readConfig(configPath, keyName)
    try
        return do shell script "defaults read " & quoted form of configPath & " " & quoted form of keyName
    on error
        return ""
    end try
end readConfig

on readConfigInt(configPath, keyName)
    try
        return (do shell script "defaults read " & quoted form of configPath & " " & quoted form of keyName) as integer
    on error
        return 0
    end try
end readConfigInt

on currentLocaleCode()
    try
        set loc to do shell script "defaults read -g AppleLocale 2>/dev/null || echo en_US"
        if (count of loc) < 2 then return "en"
        return text 1 thru 2 of loc
    on error
        return "en"
    end try
end currentLocaleCode

-- Tier-4 name candidates: localized name (if present) then English, de-duped.
on localeNames(configPath, stepPrefix, localeCode)
    set names to {}
    set localized to my readConfig(configPath, stepPrefix & "_names_" & localeCode)
    if localized is not "" then set end of names to localized
    set english to my readConfig(configPath, stepPrefix & "_names_en")
    if english is not "" and english is not localized then set end of names to english
    return names
end localeNames
