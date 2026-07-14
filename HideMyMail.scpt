-- HideMyMail.scpt v2.0
-- Config-driven GUI scripting with a four-tier element search.
-- Source of truth — referenced by info.plist via `scriptfile`.

on run argv
    if (count of argv) is 1 and (item 1 of argv) is "--selftest" then
        return my runSelfTest()
    end if
    return "Failed: no label provided."  -- replaced by the real flow in Task 3
end run

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
