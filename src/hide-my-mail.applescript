#!/usr/bin/osascript
-- Hide My Mail for Alfred — v2.0
-- Creates an iCloud "Hide My Email" address with the given label and copies it to the clipboard.
-- macOS Sequoia (15.x) and Tahoe (26.x) each have their own proven navigation branch.
--
-- Usage:  osascript src/hide-my-mail.applescript "My Label"
--         osascript src/hide-my-mail.applescript --selftest | --version

property kVersion : "2.0"
property kMaxTicks : 100 -- 100 x 0.1 s = 10 s per wait
property kIssuesUrl : "https://github.com/Klizzy/alfred-hide-my-mail/issues"
property kDiagnosisFile : "~/Desktop/hide-my-mail-diagnosis.txt"

-- Button names in every supported language; the first match wins, so no locale detection is needed.
-- en/de: verified by the maintainer on Sequoia. fr/es: Apple support pages, not verified on a live system.
property kCreateNames : {"Create New Address", "Neue Adresse erstellen", "Créer une nouvelle adresse", "Crear nueva dirección"}
property kContinueNames : {"Continue", "Fortfahren", "Continuer", "Continuar"}
property kCopyNames : {"Copy Address", "Adresse kopieren", "Copier l'adresse", "Copiar dirección"}
property kDoneNames : {"Done", "Fertig", "Terminé", "OK", "Listo"}

on run argv
	if (count of argv) > 0 then
		if (item 1 of argv) is "--selftest" then return my runSelfTest()
		if (item 1 of argv) is "--version" then return kVersion
	end if
	if (count of argv) is 0 or ((item 1 of argv) as text) is "" then return "Failed: no label given. Usage: hide <label>"
	return my createAddress((item 1 of argv) as text)
end run

----------------------------------------------------------------------
-- MAIN FLOW
----------------------------------------------------------------------

on createAddress(labelText)
	set major to my majorVersion()
	set branchName to my branchForMajor(major)
	if branchName is "unsupported" then
		return "Failed: macOS " & major & " is not supported by v" & kVersion & ". Use release v1.2 (Sequoia) or v1.0 (Sonoma)."
	end if

	set clipBefore to my clipboardText()
	set shownAddress to ""
	try
		my restartSystemSettings(my paneIdForBranch(branchName))
		if branchName is "tahoe" then
			set shownAddress to my runTahoe(labelText)
		else
			set shownAddress to my runSequoia(labelText)
		end if
		delay 0.5
		set clipAfter to my clipboardText()
		my quitSystemSettings()

		if my looksLikeAddress(clipAfter) and clipAfter is not clipBefore then
			return "Created " & clipAfter & " — copied to your clipboard"
		end if
		if shownAddress is not "" then
			error "the address " & shownAddress & " was shown but nothing new was copied to the clipboard"
		end if
		error "the flow finished but the clipboard did not change"
	on error errMsg
		set diagNote to my captureDiagnosis("Failed: " & errMsg)
		my quitSystemSettings()
		return "Failed: " & errMsg & ". " & diagNote & " Please attach " & kDiagnosisFile & " to an issue at " & kIssuesUrl
	end try
end createAddress

----------------------------------------------------------------------
-- SEQUOIA 15.x — v1.2's proven sequence (click + positional), plus timeouts and name-first Create.
----------------------------------------------------------------------

on runSequoia(labelText)
	set shownAddress to ""
	tell application "System Events"
		tell application process "System Settings"
			-- 1. iCloud section (UI element 1 of the grid).
			tell group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
				repeat with i from 1 to kMaxTicks
					if (exists UI element 1) then exit repeat
					my waitTick(i, "iCloud section")
				end repeat
				click UI element 1
			end tell

			-- 2. Hide My Email tile (UI element 5). Re-addressed from window 1: the window title changed after step 1.
			tell group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
				repeat with i from 1 to kMaxTicks
					if (exists UI element 5) then exit repeat
					my waitTick(i, "Hide My Email tile")
				end repeat
				click UI element 5
			end tell

			-- 3. Sheet: Create New Address (by name in any language, else v1.2's UI element 5).
			repeat with i from 1 to kMaxTicks
				if (exists group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1) then exit repeat
				my waitTick(i, "Hide My Email sheet")
			end repeat
			tell UI element 1 of scroll area 1 of sheet 1 of window 1
				tell group 1 of group 1
					set createBtn to missing value
					repeat with i from 1 to kMaxTicks
						try
							set createBtn to my pickNamed(buttons of group 1, kCreateNames)
							if createBtn is missing value and (exists UI element 5 of group 1) then set createBtn to UI element 5 of group 1
						end try
						if createBtn is not missing value then exit repeat
						my waitTick(i, "Create New Address button")
					end repeat
					click createBtn

					-- 4. Label field.
					repeat with i from 1 to kMaxTicks
						if (exists text field 1 of group 4) then exit repeat
						my waitTick(i, "label field")
					end repeat
					click text field 1 of group 4
					set value of text field 1 of group 4 to labelText
				end tell

				-- The generated address is usually visible on this screen; grab it for the notification (best effort).
				set shownAddress to my addressShownIn(sheet 1 of window 1)

				-- 5. v1.2's four confirmation clicks, alternating group 2 / group 1. Stops early if the sheet closes.
				tell group 1 of group 2 of group 1
					repeat with stepNo from 1 to 4
						repeat with i from 1 to kMaxTicks
							if not (my sheetOpen()) then exit repeat
							if stepNo mod 2 is 1 then
								if (exists UI element 1 of group 2) then exit repeat
							else
								if (exists UI element 1 of group 1) then exit repeat
							end if
							my waitTick(i, "confirmation step " & stepNo)
						end repeat
						if not (my sheetOpen()) then exit repeat
						if stepNo mod 2 is 1 then
							click UI element 1 of group 2
						else
							click UI element 1 of group 1
						end if
						delay 0.3
					end repeat
				end tell
			end tell
		end tell
	end tell
	return shownAddress
end runSequoia

----------------------------------------------------------------------
-- TAHOE 26.x — PR #6's proven sequence (AXPress, identifier, named buttons),
-- plus PR #7's sheet-index detection and address scrape. Positional fallbacks are v1.2's indices
-- (the sheet containers are identical on both versions).
----------------------------------------------------------------------

on runTahoe(labelText)
	set shownAddress to ""
	tell application "System Events"
		tell application process "System Settings"
			-- 1. The pane opens on iCloud already. Find the Hide My Email tile by AXIdentifier in the iCloud+ Features grid.
			set hideTile to missing value
			repeat with i from 1 to kMaxTicks
				try
					tell group 3 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1
						repeat with b in buttons
							try
								if (value of attribute "AXIdentifier" of b) is "six-pack-card-Hide My Email" then
									set hideTile to contents of b
									exit repeat
								end if
							end try
						end repeat
					end tell
				end try
				if hideTile is not missing value then exit repeat
				my waitTick(i, "Hide My Email tile (six-pack-card-Hide My Email)")
			end repeat
			perform action "AXPress" of hideTile -- Tahoe tiles ignore `click` (PR #6)

			-- 2. Create New Address (named; fallback UI element 5).
			set createBtn to missing value
			repeat with i from 1 to kMaxTicks
				try
					tell group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1
						set createBtn to my pickNamed(buttons, kCreateNames)
						if createBtn is missing value and i ≥ 30 and (exists UI element 5) then set createBtn to UI element 5
					end tell
				end try
				if createBtn is not missing value then exit repeat
				my waitTick(i, "Create New Address button")
			end repeat
			perform action "AXPress" of createBtn

			-- 3. On 26.6.x the create dialog may be sheet 2 (PR #7). Find the sheet that owns the label field.
			set createSheet to 0
			repeat with i from 1 to kMaxTicks
				repeat with s from 1 to (count of sheets of window 1)
					if (exists text field 1 of group 4 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet s of window 1) then
						set createSheet to s
						exit repeat
					end if
				end repeat
				if createSheet > 0 then exit repeat
				my waitTick(i, "label field")
			end repeat

			tell UI element 1 of scroll area 1 of sheet createSheet of window 1
				-- 4. Label.
				tell text field 1 of group 4 of group 1 of group 1
					set focused to true
					set value to labelText
				end tell
				set shownAddress to my addressShownIn(sheet createSheet of window 1)
				delay 0.3

				tell group 1 of group 2 of group 1
					-- 5. Continue (group 2).
					set btn to my pickNamed(buttons of group 2, kContinueNames)
					if btn is missing value then set btn to UI element 1 of group 2
					perform action "AXPress" of btn

					-- 6. Copy Address on the "All Set" screen (group 1). Named first; positional after 3 s.
					set btn to missing value
					repeat with i from 1 to kMaxTicks
						try
							set btn to my pickNamed(buttons of group 1, kCopyNames)
							if btn is missing value and i ≥ 30 and (exists UI element 1 of group 1) then set btn to UI element 1 of group 1
						end try
						if btn is not missing value then exit repeat
						my waitTick(i, "Copy Address button")
					end repeat
					perform action "AXPress" of btn
					delay 0.3

					-- 7. Done (group 2). Skip silently if the sheet already closed.
					if my sheetOpen() then
						set btn to my pickNamed(buttons of group 2, kDoneNames)
						if btn is missing value and (exists UI element 1 of group 2) then set btn to UI element 1 of group 2
						if btn is not missing value then perform action "AXPress" of btn
					end if
				end tell
			end tell
		end tell
	end tell
	return shownAddress
end runTahoe

----------------------------------------------------------------------
-- HEADLESS SELF-TEST (no GUI, no iCloud)
----------------------------------------------------------------------

on runSelfTest()
	set report to {}
	set major to my majorVersion()
	my check(report, "majorVersion() is a plausible integer", (major ≥ 14 and major ≤ 40))
	my check(report, "branchForMajor(15) is sequoia", my branchForMajor(15) is "sequoia")
	my check(report, "branchForMajor(26) is tahoe", my branchForMajor(26) is "tahoe")
	my check(report, "branchForMajor(27) is tahoe (newest branch for unknown newer versions)", my branchForMajor(27) is "tahoe")
	my check(report, "branchForMajor(14) is unsupported", my branchForMajor(14) is "unsupported")
	my check(report, "paneIdForBranch(sequoia)", my paneIdForBranch("sequoia") is "com.apple.systempreferences.AppleIDSettings*AppleIDSettings")
	my check(report, "paneIdForBranch(tahoe)", my paneIdForBranch("tahoe") is "com.apple.systempreferences.AppleIDSettings:icloud")
	my check(report, "looksLikeAddress accepts x.y@icloud.com", my looksLikeAddress("x.y@icloud.com"))
	my check(report, "looksLikeAddress rejects plain text", not my looksLikeAddress("hello world"))
	my check(report, "looksLikeAddress rejects text with spaces", not my looksLikeAddress("a b@icloud.com"))
	my check(report, "looksLikeAddress rejects empty", not my looksLikeAddress(""))
	my check(report, "name tables are non-empty", ((count of kCreateNames) > 0 and (count of kContinueNames) > 0 and (count of kCopyNames) > 0 and (count of kDoneNames) > 0))
	my check(report, "scriptDir() is a directory", my fileExists(my scriptDir(), "-d"))
	my check(report, "diagnose.applescript sits next to this script", my fileExists(my scriptDir() & "/diagnose.applescript", "-f"))
	my check(report, "clipboardText() returns text", class of (my clipboardText()) is text)

	set fails to 0
	repeat with ln in report
		if (ln as text) starts with "FAIL" then set fails to fails + 1
	end repeat
	set AppleScript's text item delimiters to linefeed
	set body to report as text
	set AppleScript's text item delimiters to ""
	if fails is 0 then return body & linefeed & "SELFTEST PASS (" & (count of report) & " checks)"
	return body & linefeed & "SELFTEST FAIL (" & fails & " of " & (count of report) & " checks)"
end runSelfTest

on check(report, label, cond)
	if cond then
		set end of report to "PASS " & label
	else
		set end of report to "FAIL " & label
	end if
end check

on fileExists(posixPath, testFlag)
	return (do shell script "test " & testFlag & " " & quoted form of posixPath & " && echo yes || echo no") is "yes"
end fileExists

----------------------------------------------------------------------
-- ENVIRONMENT
----------------------------------------------------------------------

on majorVersion()
	return (do shell script "sw_vers -productVersion | cut -d. -f1") as integer
end majorVersion

-- 15 → Sequoia branch. 26 and anything newer → Tahoe branch (newest known layout). Older → unsupported.
on branchForMajor(major)
	if major ≥ 26 then return "tahoe"
	if major is 15 then return "sequoia"
	return "unsupported"
end branchForMajor

on paneIdForBranch(branchName)
	if branchName is "tahoe" then return "com.apple.systempreferences.AppleIDSettings:icloud"
	return "com.apple.systempreferences.AppleIDSettings*AppleIDSettings"
end paneIdForBranch

-- Directory this script lives in (works from Alfred External Script and from `osascript path`).
on scriptDir()
	try
		set p to POSIX path of (path to me)
		return do shell script "dirname " & quoted form of p
	on error
		return (do shell script "pwd") & "/src"
	end try
end scriptDir

----------------------------------------------------------------------
-- CLIPBOARD
----------------------------------------------------------------------

on clipboardText()
	try
		return (the clipboard as text)
	on error
		return ""
	end try
end clipboardText

on looksLikeAddress(t)
	if t is "" then return false
	if t does not contain "@" then return false
	if t does not contain "." then return false
	if t contains " " then return false
	if t contains linefeed then return false
	return true
end looksLikeAddress

----------------------------------------------------------------------
-- WAITS AND LOOKUPS
----------------------------------------------------------------------

-- Call at the end of a `repeat with i from 1 to kMaxTicks` wait loop: sleeps 0.1 s, errors on the last tick.
on waitTick(i, stepName)
	if i ≥ kMaxTicks then error "Timeout waiting for " & stepName
	delay 0.1
end waitTick

-- First element in `candidates` (a list of buttons) whose title or description is in nameList, else missing value.
on pickNamed(candidates, nameList)
	tell application "System Events"
		repeat with b in candidates
			try
				if (name of b) is in nameList then return contents of b
			end try
			try
				if (description of b) is in nameList then return contents of b
			end try
		end repeat
	end tell
	return missing value
end pickNamed

-- Best effort: first static text under `container` whose value looks like an address. "" if none.
on addressShownIn(container)
	try
		with timeout of 5 seconds
			tell application "System Events"
				repeat with el in (entire contents of container)
					try
						if (role of el) is "AXStaticText" then
							set v to value of el
							if v is not missing value and my looksLikeAddress(v as text) then return v as text
						end if
					end try
				end repeat
			end tell
		end timeout
	end try
	return ""
end addressShownIn

on sheetOpen()
	tell application "System Events" to tell application process "System Settings"
		return (exists sheet 1 of window 1)
	end tell
end sheetOpen

----------------------------------------------------------------------
-- SYSTEM SETTINGS LIFECYCLE
----------------------------------------------------------------------

-- Graceful quit first (lets a finished sheet commit), then killall so a stuck modal can never hang us.
on quitSystemSettings()
	try
		with timeout of 3 seconds
			tell application "System Settings" to quit
		end timeout
	end try
	repeat 20 times
		if application "System Settings" is not running then return
		delay 0.1
	end repeat
	do shell script "killall 'System Settings' 2>/dev/null || true"
	repeat 30 times
		if application "System Settings" is not running then return
		delay 0.1
	end repeat
end quitSystemSettings

-- Clean start: quit, relaunch, reveal the pane, wait for the window. Never keeps a window reference.
on restartSystemSettings(paneId)
	my quitSystemSettings()
	tell application "System Settings"
		activate
		delay 0.5
		try
			reveal pane id paneId
		on error
			-- Fallback URL scheme lands on the Apple Account pane on both versions.
			open location "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings"
		end try
	end tell
	repeat with i from 1 to kMaxTicks
		tell application "System Events" to tell application process "System Settings"
			if (exists window 1) then exit repeat
		end tell
		my waitTick(i, "System Settings window")
	end repeat
	delay 0.5
end restartSystemSettings

----------------------------------------------------------------------
-- FAILURE DIAGNOSIS
----------------------------------------------------------------------

-- Runs diagnose.applescript in capture mode (no UI changes) and returns a one-line note for the notification.
on captureDiagnosis(context)
	try
		set diagPath to my scriptDir() & "/diagnose.applescript"
		if not my fileExists(diagPath, "-f") then return "(diagnose.applescript not found next to this script)"
		return do shell script "/usr/bin/osascript " & quoted form of diagPath & " --capture " & quoted form of context
	on error e
		return "(could not write diagnosis: " & e & ")"
	end try
end captureDiagnosis
