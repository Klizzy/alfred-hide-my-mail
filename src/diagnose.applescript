#!/usr/bin/osascript
-- Hide My Mail diagnosis — v2.0
-- Writes ~/Desktop/hide-my-mail-diagnosis.txt: environment + a recursive dump of the System Settings
-- accessibility tree with AppleScript-style addressing on every line, so a maintainer can update the
-- element paths in hide-my-mail.applescript without access to the reporter's Mac.
--
--   (no args)              full mode: restart System Settings, open the iCloud pane, press the Hide My Email
--                          card (nothing is created), report each step and the opened sheet, dump, quit.
--                          This is what the `hide-diagnose` keyword runs.
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

-- BEGIN SHARED NAVIGATION
----------------------------------------------------------------------
-- Identical in src/hide-my-mail.applescript and src/diagnose.applescript. Edit it HERE, then run
-- `bash tests/sync-shared-block.sh`; tests/headless.sh fails when the two copies differ.
-- Uses kMaxTicks from the enclosing script (100 ticks = 10 s in hide-my-mail.applescript, 50 = 5 s in diagnose.applescript).
----------------------------------------------------------------------

property kICloudPaneId : "com.apple.systempreferences.AppleIDSettings:icloud"
property kTilePrefix : "six-pack-card-"
-- AXIdentifiers of the Hide My Email card in the iCloud+ Features grid. The suffix is the card's visible
-- title, so it is localised, and Apple writes "E‑Mail" with U+2011 NON-BREAKING HYPHEN — both hyphen variants
-- are listed. en/de: from live dumps (Sequoia 15.8, Tahoe 26.6). fr/es: Apple's marketing names, unverified.
property kHideMyEmailTileIds : {"six-pack-card-Hide My Email", "six-pack-card-E‑Mail-Adresse verbergen", "six-pack-card-E-Mail-Adresse verbergen", "six-pack-card-Masquer mon adresse e‑mail", "six-pack-card-Masquer mon adresse e-mail", "six-pack-card-Ocultar mi correo electrónico"}
property kSettleTicks : 10 -- the card count must be unchanged for 10 x 0.1 s before guessing by sheet shape
property navLog : {}

-- One line per navigation step. The main script hands the log to the failure diagnosis, diagnose prints it.
on navNote(msg)
	set end of navLog to (msg as text)
end navNote

on navLogText()
	set AppleScript's text item delimiters to linefeed
	set s to navLog as text
	set AppleScript's text item delimiters to ""
	return s
end navLogText

-- Call at the end of a `repeat with i from 1 to kMaxTicks` wait loop: sleeps 0.1 s, errors on the last tick.
on waitTick(i, stepName)
	if i ≥ kMaxTicks then error "Timeout waiting for " & stepName
	delay 0.1
end waitTick

-- Content column of the System Settings split view: Sequoia 15 hosts it in group 2, Tahoe 26 in group 3.
on contentGroupIndexFor(major)
	if major ≥ 26 then return 3
	return 2
end contentGroupIndexFor

-- Reveal the iCloud pane and wait until the iCloud+ Features grid is on screen. `exists window 1` is not a
-- readiness signal: on a cold start System Settings still shows the pane it was closed on for a moment.
-- Fallback: select the sidebar row that carries the pane id (locale independent, no positional clicks).
on openICloudPane(contentGroupIndex)
	tell application "System Settings"
		try
			reveal pane id kICloudPaneId
			my navNote("reveal pane " & kICloudPaneId & ": ok")
		on error e
			my navNote("reveal pane " & kICloudPaneId & ": FAILED (" & e & ")")
		end try
	end tell
	repeat with i from 1 to kMaxTicks
		tell application "System Events" to tell application process "System Settings"
			if (exists window 1) then exit repeat
		end tell
		my waitTick(i, "System Settings window")
	end repeat
	if my waitForICloudGrid(contentGroupIndex, 30) then
		my navNote("iCloud+ cards: " & my cardIdsText(contentGroupIndex))
		return
	end if
	my navNote("no iCloud+ grid after reveal (window: " & my windowTitle() & "); selecting the iCloud sidebar row")
	if my selectSidebarRow(kICloudPaneId) then
		my navNote("sidebar row " & kICloudPaneId & " selected")
	else
		my navNote("no sidebar row with id " & kICloudPaneId)
	end if
	if my waitForICloudGrid(contentGroupIndex, kMaxTicks) then
		my navNote("iCloud+ cards: " & my cardIdsText(contentGroupIndex))
		return
	end if
	error "Timeout waiting for iCloud pane (window: " & my windowTitle() & ")"
end openICloudPane

-- Open the Hide My Email sheet and return the pressed card's id.
-- Pass 1 (up to 3 s, the cards render asynchronously): the card whose id is in kHideMyEmailTileIds.
-- Pass 2 (unknown locale): once the grid stopped changing, press the cards last-to-first and keep the first
-- whose sheet has the Hide My Email shape; dismiss the others. The error lists every card id so the
-- notification alone tells a maintainer which id to add to kHideMyEmailTileIds.
on pressHideMyEmailTile(contentGroupIndex, useAXPress)
	repeat 30 times
		repeat with b in my hideMyEmailCandidates(contentGroupIndex)
			set aid to my tileId(b)
			if aid is in kHideMyEmailTileIds then
				my pressTile(b, useAXPress)
				my navNote("pressed " & aid)
				repeat with j from 1 to kMaxTicks
					if my hideMyEmailSheetOpen() then exit repeat
					if j ≥ kMaxTicks then my navNote("after pressing " & aid & ": sheet open: " & (my anySheetOpen() as text) & "; sheet text: " & my sheetFirstText())
					my waitTick(j, "Hide My Email sheet (after pressing " & aid & ")")
				end repeat
				my navNote("Hide My Email sheet open")
				return aid
			end if
		end repeat
		delay 0.1
	end repeat

	my navNote("no known Hide My Email id among: " & my cardIdsText(contentGroupIndex) & " — trying the cards by sheet shape")
	my waitForSettledGrid(contentGroupIndex)
	set ids to my cardIdsText(contentGroupIndex)
	set cands to my hideMyEmailCandidates(contentGroupIndex)
	repeat with idx from (count of cands) to 1 by -1
		set b to item idx of cands
		set aid to my tileId(b)
		my pressTile(b, useAXPress)
		repeat 30 times
			if my anySheetOpen() then exit repeat
			delay 0.1
		end repeat
		if my hideMyEmailSheetOpen() then
			my navNote("pressed " & aid & ": sheet shape matches Hide My Email")
			return aid
		end if
		my navNote("pressed " & aid & ": not it (sheet text: " & my sheetFirstText() & ")")
		if my anySheetOpen() then my dismissSheet()
		if not my waitForICloudGrid(contentGroupIndex, 10) then
			-- The card navigated away (e.g. Family). Come back to the iCloud pane.
			try
				tell application "System Settings" to reveal pane id kICloudPaneId
			end try
			if not my waitForICloudGrid(contentGroupIndex, 30) then
				my navNote("no iCloud+ grid after re-reveal; selecting the iCloud sidebar row")
				my selectSidebarRow(kICloudPaneId)
				if not my waitForICloudGrid(contentGroupIndex, kMaxTicks) then error "Timeout waiting for iCloud pane after dismissing " & aid
			end if
		end if
	end repeat
	error "Hide My Email tile not found among the iCloud+ cards (" & ids & ")"
end pressHideMyEmailTile

-- Buttons of the iCloud+ Features grid whose AXIdentifier starts with kTilePrefix, in grid order.
-- {} when the grid is not on screen (other pane, System Settings not running, no Accessibility).
on hideMyEmailCandidates(contentGroupIndex)
	set found to {}
	try
		tell application "System Events" to tell application process "System Settings"
			tell group 3 of scroll area 1 of group 1 of group contentGroupIndex of splitter group 1 of group 1 of window 1
				repeat with b in buttons
					if (my tileId(b)) starts with kTilePrefix then set end of found to contents of b
				end repeat
			end tell
		end tell
	end try
	return found
end hideMyEmailCandidates

on tileId(b)
	try
		tell application "System Events"
			set aid to value of attribute "AXIdentifier" of b
			if aid is missing value then return ""
			return aid as text
		end tell
	end try
	return ""
end tileId

on cardIdsText(contentGroupIndex)
	set ids to {}
	repeat with b in my hideMyEmailCandidates(contentGroupIndex)
		set end of ids to my tileId(b)
	end repeat
	set AppleScript's text item delimiters to ", "
	set s to ids as text
	set AppleScript's text item delimiters to ""
	return s
end cardIdsText

on waitForICloudGrid(contentGroupIndex, maxTicks)
	repeat maxTicks times
		if (count of my hideMyEmailCandidates(contentGroupIndex)) > 0 then return true
		delay 0.1
	end repeat
	return false
end waitForICloudGrid

-- Returns once the card count has been unchanged for kSettleTicks ticks, or after kMaxTicks ticks.
on waitForSettledGrid(contentGroupIndex)
	set lastCount to -1
	set stable to 0
	repeat kMaxTicks times
		set n to count of my hideMyEmailCandidates(contentGroupIndex)
		if n is lastCount then
			set stable to stable + 1
			if stable ≥ kSettleTicks then return
		else
			set stable to 0
			set lastCount to n
		end if
		delay 0.1
	end repeat
end waitForSettledGrid

-- Sidebar row whose static text carries `paneId` as AXIdentifier (the sidebar ids are pane ids).
on selectSidebarRow(paneId)
	try
		tell application "System Events" to tell application process "System Settings"
			tell outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1
				repeat with r in rows
					try
						if (value of attribute "AXIdentifier" of static text 1 of UI element 1 of r) is paneId then
							select r
							return true
						end if
					end try
				end repeat
			end tell
		end tell
	end try
	return false
end selectSidebarRow

on windowTitle()
	try
		tell application "System Events" to tell application process "System Settings"
			return (name of window 1) as text
		end tell
	end try
	return "?"
end windowTitle

-- The Hide My Email sheet has `UI element 1 of scroll area 1` directly under the sheet with two nested groups
-- (Sequoia and Tahoe). Other iCloud+ sheets nest their scroll area inside a group (Private Relay) and fail this.
on hideMyEmailSheetOpen()
	try
		tell application "System Events" to tell application process "System Settings"
			return (exists group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1)
		end tell
	end try
	return false
end hideMyEmailSheetOpen

on anySheetOpen()
	try
		tell application "System Events" to tell application process "System Settings"
			return (exists sheet 1 of window 1)
		end tell
	end try
	return false
end anySheetOpen

-- First non-empty static text of sheet 1 — tells the reader which sheet opened. "" if none.
-- Called at the process level on purpose (a partial reference inside a `tell <element>` would chain onto it).
on sheetFirstText()
	try
		tell application "System Events" to tell application process "System Settings"
			return my firstTextIn(sheet 1 of window 1)
		end tell
	end try
	return ""
end sheetFirstText

on firstTextIn(axContainer)
	try
		with timeout of 5 seconds
			tell application "System Events"
				repeat with el in (entire contents of axContainer)
					try
						if (role of el) is "AXStaticText" then
							set v to value of el
							if v is not missing value and (v as text) is not "" then return v as text
						end if
					end try
				end repeat
			end tell
		end timeout
	end try
	return ""
end firstTextIn

-- Escape closes every iCloud+ sheet. True once no sheet is open.
on dismissSheet()
	tell application "System Settings" to activate
	tell application "System Events" to key code 53
	repeat 30 times
		if not my anySheetOpen() then return true
		delay 0.1
	end repeat
	return false
end dismissSheet

-- `click` works on Sequoia; Tahoe tiles ignore it and need AXPress (PR #6).
on pressTile(b, useAXPress)
	tell application "System Events"
		if useAXPress then
			perform action "AXPress" of b
		else
			click b
		end if
	end tell
end pressTile

-- END SHARED NAVIGATION

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
	my check(results, "roleToClass(AXCell) is UI element (System Events has no cell class)", my roleToClass("AXCell") is "UI element")
	my check(results, "shorten keeps short text", my shorten("abc", 10) is "abc")
	my check(results, "shorten truncates with ellipsis", my shorten("abcdefghij", 5) is "abcde…")
	my check(results, "shorten flattens newlines", my shorten("a" & linefeed & "b", 10) is "a b")
	my check(results, "environmentSummary mentions macOS", my environmentSummary() contains "macOS ")
	my check(results, "environmentSummary mentions Accessibility", my environmentSummary() contains "Accessibility")
	set tmp to do shell script "mktemp"
	my writeReport({"line one", "line two"}, tmp)
	my check(results, "writeReport writes UTF-8 lines", (read (POSIX file tmp) as «class utf8») is "line one" & linefeed & "line two")
	do shell script "rm -f " & quoted form of tmp

	my check(results, "contentGroupIndexFor(15) is 2", my contentGroupIndexFor(15) is 2)
	my check(results, "contentGroupIndexFor(26) is 3", my contentGroupIndexFor(26) is 3)
	my check(results, "kHideMyEmailTileIds has the German id with U+2011", ("six-pack-card-E" & (character id 8209) & "Mail-Adresse verbergen") is in kHideMyEmailTileIds)
	set navLog to {}
	my navNote("x")
	my check(results, "navLogText joins navLog", my navLogText() is "x")
	set navLog to {}

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
	-- No AXCell entry on purpose: System Events has no `cell` class, so AXCell falls through to "UI element"
	-- below — a dumped `cell 1 of …` address would not compile.
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
-- GUI: NAVIGATION (full mode only) — same shared steps as hide-my-mail.applescript up to the open sheet;
-- creates nothing. Every step lands in the report, including which card was pressed and which sheet opened.
----------------------------------------------------------------------

on openHideMyEmail()
	set major to (do shell script "sw_vers -productVersion | cut -d. -f1") as integer
	set contentGroupIndex to my contentGroupIndexFor(major)
	set end of report to "--- navigation (full mode) ---"
	set navLog to {}

	my quitSystemSettings()
	tell application "System Settings"
		activate
		delay 0.5
	end tell
	try
		my openICloudPane(contentGroupIndex)
		my pressHideMyEmailTile(contentGroupIndex, major ≥ 26)
	on error e
		my navNote("ERROR: " & e)
	end try
	delay 1

	repeat with ln in navLog
		set end of report to (ln as text)
	end repeat
	set end of report to "sheet open: " & (my anySheetOpen() as text) & "; looks like Hide My Email sheet: " & (my hideMyEmailSheetOpen() as text) & "; sheet text: " & my sheetFirstText()
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
