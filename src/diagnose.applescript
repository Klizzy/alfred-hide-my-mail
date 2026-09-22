#!/usr/bin/osascript
-- Hide My Mail diagnosis — v2.0
-- Writes ~/Desktop/hide-my-mail-diagnosis.txt: environment + a recursive dump of the System Settings
-- accessibility tree with AppleScript-style addressing on every line, so a maintainer can update the
-- element paths in hide-my-mail.applescript without access to the reporter's Mac.
--
--   (no args)              full mode: restart System Settings, open the iCloud pane, open the Hide My Email
--                          sheet (nothing is created), dump, quit. This is what the `hide-diagnose` keyword runs.
--   --capture <context>    capture mode: dump whatever is on screen now. Used by hide-my-mail.applescript on
--                          failure. Does not restart or quit System Settings.
--   --selftest             headless checks

property kVersion : "2.0"
property kMaxDepth : 14
property kMaxElements : 1500
property kOutputName : "hide-my-mail-diagnosis.txt"
property kMaxTicks : 50 -- 5 s per wait in full mode

property elementCount : 0
property report : {}

on run argv
	if (count of argv) ≥ 1 and (item 1 of argv) is "--selftest" then return my runSelfTest()

	set mode to "full"
	set context to ""
	if (count of argv) ≥ 1 and (item 1 of argv) is "--capture" then
		set mode to "capture"
		if (count of argv) ≥ 2 then set context to (item 2 of argv) as text
	end if

	set report to {}
	set elementCount to 0
	set end of report to "=== Hide My Mail diagnosis (v" & kVersion & ", mode: " & mode & ") ==="
	set end of report to my environmentSummary()
	if context is not "" then set end of report to "Context: " & context
	set end of report to ""

	if mode is "full" then
		try
			my openHideMyEmail()
		on error e
			set end of report to "ERROR while navigating: " & e
		end try
	end if

	try
		my dumpSystemSettings()
	on error e
		set end of report to "ERROR while dumping: " & e
	end try

	set outPath to (POSIX path of (path to desktop)) & kOutputName
	my writeReport(report, outPath)
	if mode is "full" then my quitSystemSettings()
	return "Diagnosis saved to ~/Desktop/" & kOutputName & "."
end run

----------------------------------------------------------------------
-- HEADLESS SELF-TEST
----------------------------------------------------------------------

on runSelfTest()
	set results to {}
	my check(results, "roleToClass(AXGroup) is group", my roleToClass("AXGroup") is "group")
	my check(results, "roleToClass(AXScrollArea) is scroll area", my roleToClass("AXScrollArea") is "scroll area")
	my check(results, "roleToClass(AXSplitGroup) is splitter group", my roleToClass("AXSplitGroup") is "splitter group")
	my check(results, "roleToClass(AXStaticText) is static text", my roleToClass("AXStaticText") is "static text")
	my check(results, "roleToClass(unknown) is UI element", my roleToClass("AXSomethingNew") is "UI element")
	my check(results, "shorten keeps short text", my shorten("abc", 10) is "abc")
	my check(results, "shorten truncates with ellipsis", my shorten("abcdefghij", 5) is "abcde…")
	my check(results, "shorten flattens newlines", my shorten("a" & linefeed & "b", 10) is "a b")
	my check(results, "environmentSummary mentions macOS", my environmentSummary() contains "macOS ")
	my check(results, "environmentSummary mentions Accessibility", my environmentSummary() contains "Accessibility")
	set tmp to do shell script "mktemp"
	my writeReport({"line one", "line two"}, tmp)
	my check(results, "writeReport writes UTF-8 lines", (read (POSIX file tmp) as «class utf8») is "line one" & linefeed & "line two")
	do shell script "rm -f " & quoted form of tmp

	set fails to 0
	repeat with ln in results
		if (ln as text) starts with "FAIL" then set fails to fails + 1
	end repeat
	set AppleScript's text item delimiters to linefeed
	set body to results as text
	set AppleScript's text item delimiters to ""
	if fails is 0 then return body & linefeed & "SELFTEST PASS (" & (count of results) & " checks)"
	return body & linefeed & "SELFTEST FAIL (" & fails & " of " & (count of results) & " checks)"
end runSelfTest

on check(results, label, cond)
	if cond then
		set end of results to "PASS " & label
	else
		set end of results to "FAIL " & label
	end if
end check

----------------------------------------------------------------------
-- PURE HELPERS
----------------------------------------------------------------------

-- AX role → the System Events class name used in AppleScript element paths.
on roleToClass(axRole)
	if axRole is "AXGroup" then return "group"
	if axRole is "AXScrollArea" then return "scroll area"
	if axRole is "AXSplitGroup" then return "splitter group"
	if axRole is "AXButton" then return "button"
	if axRole is "AXStaticText" then return "static text"
	if axRole is "AXTextField" then return "text field"
	if axRole is "AXSheet" then return "sheet"
	if axRole is "AXWindow" then return "window"
	if axRole is "AXImage" then return "image"
	if axRole is "AXCheckBox" then return "checkbox"
	if axRole is "AXRadioButton" then return "radio button"
	if axRole is "AXPopUpButton" then return "pop up button"
	if axRole is "AXMenuButton" then return "menu button"
	if axRole is "AXList" then return "list"
	if axRole is "AXOutline" then return "outline"
	if axRole is "AXTable" then return "table"
	if axRole is "AXRow" then return "row"
	if axRole is "AXCell" then return "cell"
	if axRole is "AXToolbar" then return "toolbar"
	if axRole is "AXScrollBar" then return "scroll bar"
	if axRole is "AXTabGroup" then return "tab group"
	if axRole is "AXSlider" then return "slider"
	return "UI element"
end roleToClass

on shorten(t, maxLen)
	set s to t as text
	set AppleScript's text item delimiters to linefeed
	set parts to text items of s
	set AppleScript's text item delimiters to " "
	set s to parts as text
	set AppleScript's text item delimiters to ""
	if (length of s) > maxLen then return (text 1 thru maxLen of s) & "…"
	return s
end shorten

on shellOr(cmd, fallback)
	try
		return do shell script cmd
	on error
		return fallback
	end try
end shellOr

on environmentSummary()
	set envLines to {}
	set end of envLines to "Date: " & (my shellOr("date '+%Y-%m-%d %H:%M:%S %z'", "?"))
	set end of envLines to "macOS " & (my shellOr("sw_vers -productVersion", "?")) & " (" & (my shellOr("sw_vers -buildVersion", "?")) & ")"
	set end of envLines to "Locale: " & (my shellOr("defaults read -g AppleLocale", "?")) & "  Languages: " & (my shellOr("defaults read -g AppleLanguages | tr -d '\\n' | tr -s ' '", "?"))
	set end of envLines to "Alfred: " & (my shellOr("defaults read '/Applications/Alfred 5.app/Contents/Info.plist' CFBundleShortVersionString", "not found in /Applications"))
	set axEnabled to "unknown"
	try
		tell application "System Events" to set axEnabled to (UI elements enabled) as text
	end try
	set end of envLines to "Accessibility (UI elements enabled for this process): " & axEnabled
	set end of envLines to "System Settings running: " & ((application "System Settings" is running) as text)
	set end of envLines to "Script: " & (my shellOr("echo " & quoted form of (POSIX path of (path to me)), "?"))
	set AppleScript's text item delimiters to linefeed
	set s to envLines as text
	set AppleScript's text item delimiters to ""
	return s
end environmentSummary

on writeReport(textLines, outPath)
	set AppleScript's text item delimiters to linefeed
	set body to textLines as text
	set AppleScript's text item delimiters to ""
	set f to open for access (POSIX file outPath) with write permission
	try
		set eof of f to 0
		write body to f as «class utf8»
	end try
	close access f
end writeReport

----------------------------------------------------------------------
-- GUI: NAVIGATION (full mode only) — mirrors hide-my-mail.applescript up to the sheet, creates nothing.
----------------------------------------------------------------------

on openHideMyEmail()
	set major to (do shell script "sw_vers -productVersion | cut -d. -f1") as integer
	if major ≥ 26 then
		set paneId to "com.apple.systempreferences.AppleIDSettings:icloud"
	else
		set paneId to "com.apple.systempreferences.AppleIDSettings*AppleIDSettings"
	end if
	set end of report to "--- navigation (full mode) ---"

	my quitSystemSettings()
	tell application "System Settings"
		activate
		delay 0.5
		try
			reveal pane id paneId
			set end of report to "reveal pane " & paneId & ": ok"
		on error e
			set end of report to "reveal pane " & paneId & ": FAILED (" & e & ")"
		end try
	end tell
	tell application "System Events" to tell application process "System Settings"
		repeat with i from 1 to kMaxTicks
			if (exists window 1) then exit repeat
			if i is kMaxTicks then error "System Settings window did not appear"
			delay 0.1
		end repeat
	end tell
	delay 1

	tell application "System Events" to tell application process "System Settings"
		if major < 26 then
			-- Sequoia: click the iCloud section first.
			try
				tell group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
					repeat with i from 1 to kMaxTicks
						if (exists UI element 1) then exit repeat
						if i is kMaxTicks then error "grid UI element 1 never appeared"
						delay 0.1
					end repeat
					click UI element 1
				end tell
				set end of report to "iCloud section click (Sequoia grid UI element 1): ok"
			on error e
				set end of report to "iCloud section click: FAILED (" & e & ")"
			end try
			delay 1
			try
				tell group 3 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
					repeat with i from 1 to kMaxTicks
						if (exists UI element 5) then exit repeat
						if i is kMaxTicks then error "grid UI element 5 never appeared"
						delay 0.1
					end repeat
					click UI element 5
				end tell
				set end of report to "Hide My Email tile click (Sequoia grid UI element 5): ok"
			on error e
				set end of report to "Hide My Email tile click: FAILED (" & e & ")"
			end try
		else
			-- Tahoe: press the tile by identifier.
			set hideTile to missing value
			try
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
					if i is kMaxTicks then error "tile six-pack-card-Hide My Email not found in Tahoe grid"
					delay 0.1
				end repeat
				perform action "AXPress" of hideTile
				set end of report to "Hide My Email tile AXPress (six-pack-card-Hide My Email): ok"
			on error e
				set end of report to "Hide My Email tile: FAILED (" & e & ")"
			end try
		end if
		repeat with i from 1 to kMaxTicks
			if (exists sheet 1 of window 1) then exit repeat
			delay 0.1
		end repeat
		set end of report to "sheets open: " & (count of sheets of window 1)
	end tell
	delay 1
	set end of report to ""
end openHideMyEmail

----------------------------------------------------------------------
-- GUI: DUMP
----------------------------------------------------------------------

on dumpSystemSettings()
	if application "System Settings" is not running then
		set end of report to "System Settings is not running — nothing to dump."
		return
	end if
	tell application "System Events" to tell application process "System Settings"
		set winCount to count of windows
		set end of report to "--- accessibility tree (" & winCount & " window(s); depth ≤ " & kMaxDepth & ", ≤ " & kMaxElements & " elements) ---"
		set end of report to "Each line: <indent>[UI element N | <class> M]  role  id=…  title=…  desc=…  value=…   — compose paths bottom-up, e.g. 'group 3 of scroll area 1 of … of window 1'."
		repeat with w from 1 to winCount
			my dumpTree(window w, 0, "window " & w)
		end repeat
	end tell
	if elementCount ≥ kMaxElements then set end of report to "(stopped after " & kMaxElements & " elements)"
end dumpSystemSettings

-- Recursive. `label` is this element's own address relative to its parent (e.g. "group 3").
on dumpTree(el, depth, label)
	if depth > kMaxDepth then return
	if elementCount ≥ kMaxElements then return
	set elementCount to elementCount + 1
	set end of report to (my indent(depth)) & "[" & label & "]  " & (my describe(el))

	set kids to {}
	try
		tell application "System Events" to set kids to every UI element of el
	end try
	if (count of kids) is 0 then return

	-- Per-class sibling counters so labels match AppleScript addressing ("group 3", "button 2").
	set kidRoles to {}
	repeat with k in kids
		set r to ""
		try
			tell application "System Events" to set r to role of k
		end try
		set end of kidRoles to r
	end repeat
	set seen to {}
	repeat with idx from 1 to (count of kids)
		set cls to my roleToClass(item idx of kidRoles)
		set nth to 0
		repeat with j from 1 to idx
			if (my roleToClass(item j of kidRoles)) is cls then set nth to nth + 1
		end repeat
		my dumpTree(item idx of kids, depth + 1, "UI element " & idx & " | " & cls & " " & nth)
	end repeat
end dumpTree

on describe(el)
	set r to "?"
	set sub to ""
	set ttl to ""
	set dsc to ""
	set val to ""
	set aid to ""
	set en to ""
	try
		tell application "System Events"
			set p to properties of el
			set r to role of p
			try
				if subrole of p is not missing value then set sub to subrole of p
			end try
			try
				if name of p is not missing value then set ttl to name of p
			end try
			try
				if description of p is not missing value then set dsc to description of p
			end try
			try
				if value of p is not missing value then set val to (value of p) as text
			end try
			try
				set en to (enabled of p) as text
			end try
			try
				set aid to value of attribute "AXIdentifier" of el
				if aid is missing value then set aid to ""
			end try
		end tell
	end try
	set descLine to r
	if sub is not "" then set descLine to descLine & "/" & sub
	if aid is not "" then set descLine to descLine & "  id=\"" & aid & "\""
	if ttl is not "" then set descLine to descLine & "  title=\"" & (my shorten(ttl, 60)) & "\""
	if dsc is not "" and dsc is not ttl then set descLine to descLine & "  desc=\"" & (my shorten(dsc, 60)) & "\""
	if val is not "" then set descLine to descLine & "  value=\"" & (my shorten(val, 60)) & "\""
	if en is "false" then set descLine to descLine & "  disabled"
	return descLine
end describe

on indent(depth)
	set s to ""
	repeat depth times
		set s to s & "  "
	end repeat
	return s
end indent

----------------------------------------------------------------------
-- GUI: QUIT
----------------------------------------------------------------------

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
end quitSystemSettings
