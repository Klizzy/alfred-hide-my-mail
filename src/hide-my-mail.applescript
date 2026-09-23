#!/usr/bin/osascript
-- Hide My Mail for Alfred — v2.0
-- Creates an iCloud "Hide My Email" address with the given label and copies it to the clipboard.
-- Both macOS Sequoia (15.x) and Tahoe (26.x) open the iCloud pane directly and find the Hide My Email card by its
-- accessibility identifier (NAVIGATION below); the sheet steps are each version's proven sequence.
--
-- Usage:  osascript src/hide-my-mail.applescript "My Label"
--         osascript src/hide-my-mail.applescript --selftest | --version

property kVersion : "2.0"
property kMaxTicks : 100 -- 100 x 0.1 s = 10 s per wait
property kPressWaitTicks : 30 -- 3 s after a press before it counts as lost and is repeated
property kMaxPresses : 3 -- presses per button; 3 x 3 s stays within the old 10 s wait
property kIssuesUrl : "https://github.com/Klizzy/alfred-hide-my-mail/issues"
property kDiagnosisFile : "~/Desktop/hide-my-mail-diagnosis.txt"

-- Button names in every supported language; the first match wins, so no locale detection is needed.
-- en/de: verified by the maintainer on Sequoia. fr/es: Apple support pages, not verified on a live system.
property kCreateNames : {"Create New Address", "Neue Adresse erstellen", "Créer une nouvelle adresse", "Crear nueva dirección"}
property kContinueNames : {"Continue", "Fortfahren", "Continuer", "Continuar"}
property kCopyNames : {"Copy Address", "Adresse kopieren", "Copier l'adresse", "Copiar dirección"}
property kDoneNames : {"Done", "Fertig", "Terminé", "OK", "Listo"}

----------------------------------------------------------------------
-- NAVIGATION — iCloud pane and Hide My Email card, both branches
----------------------------------------------------------------------

property kICloudPaneId : "com.apple.systempreferences.AppleIDSettings:icloud"
property kTilePrefix : "six-pack-card-"
-- AXIdentifiers of the Hide My Email card in the iCloud+ Features grid. The suffix is the card's visible
-- title, so it is localised, and Apple writes "E‑Mail" with U+2011 NON-BREAKING HYPHEN — both hyphen variants
-- are listed. en/de: from live dumps (Sequoia 15.8, Tahoe 26.6). fr/es: Apple's marketing names, unverified.
property kHideMyEmailTileIds : {"six-pack-card-Hide My Email", "six-pack-card-E‑Mail-Adresse verbergen", "six-pack-card-E-Mail-Adresse verbergen", "six-pack-card-Masquer mon adresse e‑mail", "six-pack-card-Masquer mon adresse e-mail", "six-pack-card-Ocultar mi correo electrónico"}
property kSettleTicks : 10 -- the card count must be unchanged for 10 x 0.1 s before guessing by sheet shape
property kProbeNodes : 12 -- containers the sheet-text probe may visit (4 batched reads each)
property navLog : {}
property navStart : missing value -- set by createAddress; nav lines then carry [+Ns]

-- One line per navigation step, kept in memory; on failure it goes into the diagnosis file, on success it is dropped.
on navNote(msg)
	set prefix to ""
	if navStart is not missing value then set prefix to "[+" & ((current date) - navStart) & "s] "
	set end of navLog to prefix & (msg as text)
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
	-- try: right after launch System Events may not know the process yet (-1728); keep polling instead of failing.
	set haveWindow to false
	repeat with i from 1 to kMaxTicks
		try
			tell application "System Events" to tell application process "System Settings"
				set haveWindow to (exists window 1)
			end tell
		end try
		if haveWindow then exit repeat
		my waitTick(i, "System Settings window")
	end repeat
	my navNote("window: " & my windowTitle())
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
-- Pass 1 (up to 3 s for the card to appear): the card whose id is in kHideMyEmailTileIds, re-pressed if the press is lost.
-- Pass 2 (unknown locale): once the grid stopped changing, press the cards last-to-first and keep the first
-- whose sheet has the Hide My Email shape; dismiss the others. The error lists every card id so the
-- notification alone tells a maintainer which id to add to kHideMyEmailTileIds.
on pressHideMyEmailTile(contentGroupIndex, useAXPress)
	-- Pass 1. On a cold start the grid renders twice; a press on the first render can be lost or throw (-10000).
	-- Nothing after 3 s → re-read the grid and press the current card again (≤ kMaxPresses). A sheet that is
	-- up but not recognised yet is waited for, never pressed through.
	set presses to 0
	set lastAid to ""
	repeat 30 times
		repeat with b in my hideMyEmailCandidates(contentGroupIndex)
			set aid to my tileId(b)
			if aid is in kHideMyEmailTileIds then
				set presses to presses + 1
				set lastAid to aid
				my navNote("pressing " & aid & " (attempt " & presses & ")")
				try
					my pressTile(b, useAXPress)
				on error e number n
					my navNote("pressing " & aid & " failed (" & n & ": " & e & ")")
				end try
				set sheetUp to my waitForHideMyEmailSheet(kPressWaitTicks)
				set nextMove to my afterPress(sheetUp, my anySheetOpen(), presses)
				if nextMove is "wait" then
					set sheetUp to my waitForHideMyEmailSheet(kMaxTicks - kPressWaitTicks)
					set nextMove to my afterPress(sheetUp, false, kMaxPresses)
				end if
				if nextMove is "done" then
					my navNote("Hide My Email sheet open")
					return aid
				end if
				if nextMove is "give up" then my failHideMyEmailSheet(aid, presses)
				exit repeat -- "press again": re-read the grid, the pressed card may have been replaced
			end if
		end repeat
		delay 0.1
	end repeat
	if presses > 0 then my failHideMyEmailSheet(lastAid, presses)

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
		with timeout of 2 seconds
			tell application "System Events" to tell application process "System Settings"
				return (exists group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1)
			end tell
		end timeout
	end try
	return false
end hideMyEmailSheetOpen

on anySheetOpen()
	try
		with timeout of 2 seconds
			tell application "System Events" to tell application process "System Settings"
				return (exists sheet 1 of window 1)
			end tell
		end timeout
	end try
	return false
end anySheetOpen

-- First non-empty text of sheet 1 — tells the reader which sheet opened. "" if none.
-- Called at the process level on purpose (a partial reference inside a `tell <element>` would chain onto it).
on sheetFirstText()
	try
		tell application "System Events" to tell application process "System Settings"
			return my firstTextIn(sheet 1 of window 1)
		end tell
	end try
	return ""
end sheetFirstText

-- Breadth-first over at most kProbeNodes containers, four batched reads each (the children, then role, name and
-- value of every child), 2 s per read. Returns the first non-empty name or value of an AXStaticText/AXHeading.
-- Best effort: never throws.
-- Replaces the unbounded whole-subtree read, which stalled 5 s and returned "" on the real Hide My Email sheet.
on firstTextIn(axContainer)
	set queue to {axContainer}
	set visited to 0
	try
		repeat while (count of queue) > 0 and visited < kProbeNodes
			set node to item 1 of queue
			set queue to rest of queue
			set visited to visited + 1
			set kids to {}
			set rs to {}
			set ns to {}
			set vs to {}
			try
				with timeout of 2 seconds
					tell application "System Events"
						set kids to every UI element of node
						set rs to role of every UI element of node
						set ns to name of every UI element of node
						set vs to value of every UI element of node
					end tell
				end timeout
			end try
			set n to count of kids
			if n > 0 and (count of rs) is n and (count of ns) is n and (count of vs) is n then
				repeat with i from 1 to n
					set t to ""
					if (item i of rs) is "AXStaticText" then
						set t to my probeText(item i of vs)
						if t is "" then set t to my probeText(item i of ns)
					else if (item i of rs) is "AXHeading" then
						set t to my probeText(item i of ns) -- a heading's value is its level ("1"), not text
					end if
					if t is not "" then return t
				end repeat
			end if
			repeat with k in kids
				set end of queue to contents of k
			end repeat
		end repeat
	end try
	return ""
end firstTextIn

-- missing value → ""; anything else as text; never throws.
on probeText(v)
	try
		if v is missing value then return ""
		return v as text
	end try
	return ""
end probeText

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

-- Next move after a press and its short wait. Pure (no Apple Events) so the self-test pins it.
-- targetReady: the expected screen is up. opening: something else is on its way (a sheet, or the pressed
-- button is gone) — wait for it instead of pressing again, a second press could hit the next screen.
on afterPress(targetReady, opening, presses)
	if targetReady then return "done"
	if opening then return "wait"
	if presses < kMaxPresses then return "press again"
	return "give up"
end afterPress

-- Polls hideMyEmailSheetOpen for up to maxTicks x 0.1 s, by wall clock too, so a slow read cannot stretch it.
on waitForHideMyEmailSheet(maxTicks)
	set t0 to current date
	repeat maxTicks times
		if my hideMyEmailSheetOpen() then return true
		if ((current date) - t0) > (maxTicks / 10) then return false
		delay 0.1
	end repeat
	return false
end waitForHideMyEmailSheet

on failHideMyEmailSheet(aid, presses)
	my navNote("after pressing " & aid & " " & presses & "x: sheet open: " & (my anySheetOpen() as text) & "; sheet text: " & my sheetFirstText())
	error "Timeout waiting for Hide My Email sheet (after pressing " & aid & ")"
end failHideMyEmailSheet

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
		return "Failed: macOS " & major & " is not supported by v" & kVersion & ". Use release v.1.1 / v.1.0 (Sonoma 14)."
	end if

	set clipBefore to my clipboardText()
	set shownAddress to ""
	set navLog to {}
	set navStart to current date
	try
		my launchSystemSettings()
		my openICloudPane(my contentGroupIndexFor(major))
		if branchName is "tahoe" then
			set shownAddress to my runTahoe(labelText)
		else
			set shownAddress to my runSequoia(labelText)
		end if
		delay 0.5
		set clipAfter to my clipboardText()

		-- Quit only on the success path: the error path needs System Settings alive for captureDiagnosis().
		if my looksLikeAddress(clipAfter) and clipAfter is not clipBefore then
			my quitSystemSettings()
			return "Created " & clipAfter & " — copied to your clipboard"
		end if
		if shownAddress is not "" then
			error "the address " & shownAddress & " was shown but nothing new was copied to the clipboard"
		end if
		error "the flow finished but the clipboard did not change"
	on error errMsg
		set diagNote to my captureDiagnosis("Failed: " & errMsg & linefeed & "Navigation log:" & linefeed & my navLogText())
		my quitSystemSettings()
		if diagNote starts with "Diagnosis saved" then
			return "Failed: " & errMsg & ". " & diagNote & " Attach it to an issue at " & kIssuesUrl
		end if
		return "Failed: " & errMsg & ". " & diagNote & " Please attach " & kDiagnosisFile & " to an issue at " & kIssuesUrl
	end try
end createAddress

----------------------------------------------------------------------
-- SEQUOIA 15.x — card by identifier (shared), then v1.2's proven sheet sequence (click + positional) with timeouts.
----------------------------------------------------------------------

on runSequoia(labelText)
	set shownAddress to ""
	-- 1+2. Hide My Email card by AXIdentifier; the sheet is open and verified when this returns.
	my pressHideMyEmailTile(2, false)
	tell application "System Events"
		tell application process "System Settings"
			-- 3. Sheet: Create New Address (by name in any language; v1.2's UI element 5 only after 3 s).
			tell UI element 1 of scroll area 1 of sheet 1 of window 1
				tell group 1 of group 1
					set createBtn to missing value
					repeat with i from 1 to kMaxTicks
						try
							set createBtn to my pickNamed(buttons of group 1, kCreateNames)
							if createBtn is missing value and i ≥ 30 and (exists UI element 5 of group 1) then set createBtn to UI element 5 of group 1
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
			end tell

			-- The generated address is usually visible on this screen; grab it for the notification (best effort).
			-- Called at the process level on purpose: passed from inside a `tell <element>` block this partial
			-- reference would chain onto that element and System Events would throw -1728 at the call site.
			try
				set shownAddress to my addressShownIn(sheet 1 of window 1)
			end try

			-- 5. v1.2's four confirmation clicks, alternating group 2 / group 1. Stops early if the sheet closes.
			tell UI element 1 of scroll area 1 of sheet 1 of window 1
				tell group 1 of group 2 of group 1
					repeat with stepNo from 1 to 4
						repeat with i from 1 to kMaxTicks
							if not (my sheetOpen(1)) then exit repeat
							if stepNo mod 2 is 1 then
								if (exists UI element 1 of group 2) then exit repeat
							else
								if (exists UI element 1 of group 1) then exit repeat
							end if
							my waitTick(i, "confirmation step " & stepNo)
						end repeat
						if not (my sheetOpen(1)) then exit repeat
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
-- TAHOE 26.x — card by identifier (shared), then PR #6's sequence (AXPress, named buttons) plus PR #7's
-- sheet-index detection and address scrape. Positional fallbacks are v1.2's indices.
----------------------------------------------------------------------

on runTahoe(labelText)
	set shownAddress to ""
	tell application "System Events"
		tell application process "System Settings"
			-- 1. Hide My Email card by AXIdentifier (shared; AXPress because Tahoe tiles ignore `click`, PR #6).
			my pressHideMyEmailTile(3, true)

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
			end tell

			-- The generated address is usually visible on this screen; grab it for the notification (best effort).
			-- Called at the process level on purpose: passed from inside a `tell <element>` block this partial
			-- reference would chain onto that element and System Events would throw -1728 at the call site.
			try
				set shownAddress to my addressShownIn(sheet createSheet of window 1)
			end try
			delay 0.3

			tell UI element 1 of scroll area 1 of sheet createSheet of window 1
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

					-- 7. Done (group 2). Best effort: the sheet may already have closed after Copy,
					-- and on 26.6.x closing it can make `buttons of group 2` error. Copy already succeeded.
					try
						if my sheetOpen(createSheet) then
							set btn to my pickNamed(buttons of group 2, kDoneNames)
							if btn is missing value and (exists UI element 1 of group 2) then set btn to UI element 1 of group 2
							if btn is not missing value then perform action "AXPress" of btn
						end if
					end try
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
	my check(report, "contentGroupIndexFor(15) is 2 (Sequoia content column)", my contentGroupIndexFor(15) is 2)
	my check(report, "contentGroupIndexFor(26) is 3 (Tahoe content column)", my contentGroupIndexFor(26) is 3)
	my check(report, "contentGroupIndexFor(27) is 3 (newer versions use the newest layout)", my contentGroupIndexFor(27) is 3)
	my check(report, "kHideMyEmailTileIds has the English id", "six-pack-card-Hide My Email" is in kHideMyEmailTileIds)
	my check(report, "kHideMyEmailTileIds has the German id with U+2011", ("six-pack-card-E" & (character id 8209) & "Mail-Adresse verbergen") is in kHideMyEmailTileIds)
	my check(report, "kHideMyEmailTileIds has the German id with ASCII hyphen", "six-pack-card-E-Mail-Adresse verbergen" is in kHideMyEmailTileIds)
	my check(report, "every tile id starts with kTilePrefix", my allStartWith(kHideMyEmailTileIds, kTilePrefix))
	set navLog to {}
	set navStart to missing value
	my navNote("first")
	my navNote("second")
	my check(report, "navNote/navLogText join with linefeed", my navLogText() is "first" & linefeed & "second")
	set navLog to {}
	set navStart to current date
	my navNote("x")
	my check(report, "navNote prefixes elapsed seconds while navStart is set", my navLogText() starts with "[+" and my navLogText() ends with "s] x")
	set navLog to {}
	set navStart to missing value
	my check(report, "settingsGone returns a boolean", class of (my settingsGone()) is boolean)
	my check(report, "afterPress: target up → done", my afterPress(true, false, 1) is "done")
	my check(report, "afterPress: something opening → wait, never press again", my afterPress(false, true, 1) is "wait")
	my check(report, "afterPress: something opening on the last press → still wait", my afterPress(false, true, kMaxPresses) is "wait")
	my check(report, "afterPress: nothing happened → press again", my afterPress(false, false, 1) is "press again")
	my check(report, "afterPress: nothing happened after kMaxPresses → give up", my afterPress(false, false, kMaxPresses) is "give up")
	set t0 to current date
	set sheetSeen to my waitForHideMyEmailSheet(3)
	my check(report, "waitForHideMyEmailSheet returns a boolean within ~1 s", class of sheetSeen is boolean and ((current date) - t0) ≤ 2)
	my check(report, "firstTextIn is best effort: returns \"\" on a non-element", my firstTextIn(missing value) is "")
	my check(report, "hideMyEmailCandidates returns a list even without System Settings", class of (my hideMyEmailCandidates(2)) is list)
	my check(report, "looksLikeAddress accepts x.y@icloud.com", my looksLikeAddress("x.y@icloud.com"))
	my check(report, "looksLikeAddress rejects plain text", not my looksLikeAddress("hello world"))
	my check(report, "looksLikeAddress rejects text with spaces", not my looksLikeAddress("a b@icloud.com"))
	my check(report, "looksLikeAddress rejects empty", not my looksLikeAddress(""))
	my check(report, "looksLikeAddress rejects text with a linefeed", not my looksLikeAddress("a@b.c" & linefeed & "d@e.f"))
	my check(report, "addressShownIn is best effort: returns \"\" instead of throwing on a non-element", my addressShownIn(missing value) is "")
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

on allStartWith(textList, prefix)
	repeat with t in textList
		if (t as text) does not start with prefix then return false
	end repeat
	return (count of textList) > 0
end allStartWith

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

-- Best effort: first static text under `axContainer` whose value looks like an address. "" if none.
-- The parameter must NOT be named `container`: that is System Events terminology and would shadow the
-- parameter inside the tell block below, making this handler always return "".
on addressShownIn(axContainer)
	try
		with timeout of 5 seconds
			tell application "System Events"
				repeat with el in (entire contents of axContainer)
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

-- Index-aware: on Tahoe 26.6.x the create dialog can be sheet 2, so callers pass the sheet they work on.
on sheetOpen(sheetIndex)
	tell application "System Events" to tell application process "System Settings"
		return (exists sheet sheetIndex of window 1)
	end tell
end sheetOpen

----------------------------------------------------------------------
-- SYSTEM SETTINGS LIFECYCLE
----------------------------------------------------------------------

-- LaunchServices can report a dying instance as gone while its process still answers System Events; ask both.
-- pgrep -U: only this user's process counts — another logged-in user's instance is out of killall's reach.
on settingsGone()
	if application "System Settings" is running then return false
	return (do shell script "pgrep -x -U \"$(id -u)\" 'System Settings' >/dev/null && echo alive || echo gone") is "gone"
end settingsGone

-- Polls settingsGone every 0.1 s for up to `ticks` ticks. Returns at once when System Settings is not running.
on waitUntilGone(ticks)
	repeat ticks times
		if my settingsGone() then return true
		delay 0.1
	end repeat
	return my settingsGone()
end waitUntilGone

-- Graceful quit first (lets a finished sheet commit), then killall, then kill -9: a hung instance ignores
-- SIGTERM, and the next launch would otherwise activate into it while it dies (-1728 on the process).
on quitSystemSettings()
	try
		with timeout of 3 seconds
			tell application "System Settings" to quit
		end timeout
	end try
	if my waitUntilGone(20) then return
	do shell script "killall 'System Settings' 2>/dev/null || true"
	if my waitUntilGone(30) then return
	do shell script "killall -9 'System Settings' 2>/dev/null || true"
	my waitUntilGone(20)
end quitSystemSettings

-- Clean start: quit, relaunch, front, wait until System Events sees the process. The pane is opened by
-- openICloudPane, which also waits for the iCloud+ grid instead of trusting `exists window 1`.
on launchSystemSettings()
	my quitSystemSettings()
	tell application "System Settings"
		activate
		delay 0.5
	end tell
	set started to false
	repeat with i from 1 to kMaxTicks
		try
			tell application "System Events" to set started to (exists application process "System Settings")
		end try
		if started then exit repeat
		my waitTick(i, "System Settings to start")
	end repeat
	my navNote("System Settings started")
end launchSystemSettings

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
