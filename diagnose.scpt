-- diagnose.scpt v2.0
-- Dumps grid + creation-sheet accessibility attributes for building version configs.
-- Triggered by "hide-diagnose" in Alfred.

on run argv
    set workflowDir to (do shell script "pwd")
    set osVersion to do shell script "sw_vers -productVersion"
    set majorVersion to (do shell script "echo " & quoted form of osVersion & " | cut -d. -f1")
    set diagDate to do shell script "date '+%Y-%m-%d %H:%M:%S'"

    set configPath to my findConfigFile(workflowDir, majorVersion)
    if configPath is not "" then
        set paneId to my readConfig(configPath, "pane_id")
    else
        set paneId to "com.apple.systempreferences.AppleIDSettings:icloud"
    end if

    set out to {"=== Hide My Mail UI Diagnosis ===", "macOS: " & osVersion & " (major " & majorVersion & ")", "Config: " & configPath, "pane_id: " & paneId, "Date: " & diagDate, ""}

    try
        if application "System Settings" is running then
            tell application "System Settings" to quit
            delay 0.5
        end if
        tell application "System Settings"
            activate
            delay 0.5
            reveal pane id paneId
        end tell
    on error errMsg
        set end of out to "ERROR opening pane: " & errMsg
    end try
    delay 1.5

    tell application "System Events"
        tell application process "System Settings"
            set win to window 1

            set end of out to "--- window 1 top-level children ---"
            set end of out to my dumpChildren(win)

            set end of out to ""
            set end of out to "--- candidate grid: group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1 (Sequoia) ---"
            try
                set end of out to my dumpChildren(group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of win)
            on error e
                set end of out to "  n/a: " & e
            end try

            set end of out to ""
            set end of out to "--- candidate grid: group 3 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1 (Tahoe) ---"
            try
                set tahoeGrid to group 3 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of win
                set end of out to my dumpChildren(tahoeGrid)
            on error e
                set end of out to "  n/a: " & e
            end try

            -- Best-effort: open the sheet so its buttons can be captured.
            set end of out to ""
            set end of out to "--- opening creation sheet (best effort) ---"
            try
                set tileHit to missing value
                try
                    set tileHit to (first button of (entire contents of win) whose value of attribute "AXIdentifier" is "six-pack-card-Hide My Email")
                end try
                if tileHit is missing value then
                    try
                        set tileHit to UI element 5 of (group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of win)
                    end try
                end if
                if tileHit is not missing value then
                    try
                        perform action "AXPress" of tileHit
                    on error
                        click tileHit
                    end try
                    delay 1.5
                end if
            on error e
                set end of out to "  could not press tile: " & e
            end try

            set end of out to ""
            set end of out to "--- sheet: group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 (Create/Label area) ---"
            try
                set sheetRoot to UI element 1 of scroll area 1 of sheet 1 of win
                set end of out to my dumpChildren(group 1 of group 1 of group 1 of sheetRoot)
                set end of out to ""
                set end of out to "  group 4 (label area):"
                try
                    set end of out to my dumpChildren(group 4 of group 1 of group 1 of sheetRoot)
                end try
                set end of out to ""
                set end of out to "--- sheet: confirm area group 1 of group 2 of group 1 of UI element 1 ... ---"
                try
                    set confirmArea to group 1 of group 2 of group 1 of sheetRoot
                    set end of out to "  group 1 of confirm area:"
                    set end of out to my dumpChildren(group 1 of confirmArea)
                    set end of out to "  group 2 of confirm area:"
                    set end of out to my dumpChildren(group 2 of confirmArea)
                end try
            on error e
                set end of out to "  no sheet captured: " & e
            end try
        end tell
    end tell

    set outputText to my joinLines(out)
    set outputPath to (POSIX path of (path to desktop)) & "hide-my-mail-diagnosis.txt"
    do shell script "cat > " & quoted form of outputPath & " <<'HMMEOF'" & linefeed & outputText & linefeed & "HMMEOF"

    try
        tell application "System Settings" to quit
    end try
    return "Diagnosis saved to ~/Desktop/hide-my-mail-diagnosis.txt"
end run

on dumpChildren(parentElement)
    set res to ""
    tell application "System Events"
        set idx to 1
        repeat with el in (every UI element of parentElement)
            set r to my safeAttr(el, "AXRole")
            set aid to my safeAttr(el, "AXIdentifier")
            set sub to my safeAttr(el, "AXSubrole")
            set dsc to my safeAttr(el, "AXDescription")
            set val to my safeAttr(el, "AXValue")
            set res to res & "  [" & idx & "] AXRole=" & r & "  AXIdentifier=" & aid & "  AXSubrole=" & sub & "  AXDescription=" & dsc & "  AXValue=" & val & linefeed
            set idx to idx + 1
        end repeat
    end tell
    if res is "" then return "  (no children)"
    return res
end dumpChildren

on safeAttr(el, attrName)
    tell application "System Events"
        try
            set v to value of attribute attrName of el
            if v is missing value then return "(none)"
            return v as text
        on error
            return "(none)"
        end try
    end tell
end safeAttr

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

on joinLines(lst)
    set AppleScript's text item delimiters to linefeed
    set s to lst as text
    set AppleScript's text item delimiters to ""
    return s
end joinLines
