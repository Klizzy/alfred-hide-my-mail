#!/usr/bin/osascript
-- Hide My Mail diagnosis — v2.0
-- Writes ~/Desktop/hide-my-mail-diagnosis.txt: environment + a recursive dump of the System Settings
-- accessibility tree with AppleScript-style addressing on every line, so a maintainer can update the
-- element paths in hide-my-mail.applescript without access to the reporter's Mac.
-- Dumps whatever is on screen now; never restarts, navigates or quits System Settings.
--
--   --capture <context>    what hide-my-mail.applescript runs on failure (context = error + navigation log)
--   (no args)              the same without a context, for a maintainer at the terminal
--   --selftest             headless checks

property kVersion : "2.0"
property kMaxDepth : 14
property kMaxElements : 1500
property kOutputName : "hide-my-mail-diagnosis.txt"
property kBatchTimeout : 10 -- s for one batched read of a parent's children
property kReadTimeout : 5 -- s for one single-element read
property kRetryBudget : 30 -- single-element re-reads allowed per dump (0.3 s each)
property kElideRoles : {"AXList", "AXOutline", "AXTable"}
property kElideAbove : 12 -- containers with more children than this are shortened…
property kElideHead : 6 -- …to their first kElideHead children plus the last one

property elementCount : 0
property failedReads : 0
property retriesLeft : 30
property report : {}

on run argv
	if (count of argv) ≥ 1 and (item 1 of argv) is "--selftest" then return my runSelfTest()

	set context to ""
	if (count of argv) ≥ 2 and (item 1 of argv) is "--capture" then set context to (item 2 of argv) as text

	set report to {}
	set elementCount to 0
	set end of report to "=== Hide My Mail diagnosis (v" & kVersion & ", mode: capture) ==="
	set end of report to my environmentSummary()
	if context is not "" then set end of report to "Context: " & context
	set end of report to ""

	try
		my dumpSystemSettings()
	on error e
		set end of report to "ERROR while dumping: " & e
	end try

	set outPath to (POSIX path of (path to desktop)) & kOutputName
	my writeReport(report, outPath)
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

	my check(results, "errorTag formats number and message", my errorTag(-1719, "Invalid index.") is "? [err -1719: Invalid index.]")
	my check(results, "errorTag shortens long messages", (length of my errorTag(-1728, my repeatText("x", 200))) < 120)
	my check(results, "shouldElide: long AXList", my shouldElide("AXList", 217))
	my check(results, "shouldElide: long AXOutline", my shouldElide("AXOutline", 45))
	my check(results, "shouldElide: AXList at the threshold is not elided", not my shouldElide("AXList", kElideAbove))
	my check(results, "shouldElide: empty AXList", not my shouldElide("AXList", 0))
	my check(results, "shouldElide: AXGroup is never elided (the sheet's main group holds the create button)", not my shouldElide("AXGroup", 24))
	my check(results, "elisionLine names the range and the class", my elisionLine(7, 216, "static text", 7, 216) is "[UI element 7…216 | static text 7…216]  … 210 more static texts not listed")
	my check(results, "itemOr returns the item", my itemOr({"a", "b"}, 2, "") is "b")
	my check(results, "itemOr falls back on missing value list", my itemOr(missing value, 1, "z") is "z")
	my check(results, "itemOr falls back on missing value item", my itemOr({missing value}, 1, "z") is "z")
	my check(results, "itemOr falls back on out-of-range index", my itemOr({"a"}, 5, "z") is "z")
	tell application "System Events" to set fakeProps to {role:"AXButton", subrole:"AXCloseButton", name:"OK", description:"Taste", value:missing value, enabled:false}
	set fakeDesc to my describeFromProps(fakeProps, "go back")
	my check(results, "describeFromProps reads the record without Apple Events", (axRole of fakeDesc) is "AXButton" and (descLine of fakeDesc) is "AXButton/AXCloseButton  id=\"go back\"  title=\"OK\"  desc=\"Taste\"  disabled")
	set fakeDesc to my describeFromProps({}, missing value)
	my check(results, "describeFromProps on an empty record yields ? with no id", (axRole of fakeDesc) is "?" and (descLine of fakeDesc) is "?")
	my check(results, "siblingNths counts per class", my siblingNths({"group", "button", "group", "static text", "group"}, {true, true, true, true, true}) is {1, 1, 2, 1, 3})
	my check(results, "siblingNths: an unknown role in the middle turns it and every later sibling into ?", my siblingNths({"group", "UI element", "group", "button"}, {true, false, true, true}) is {1, "?", "?", "?"})
	my check(results, "siblingNths: an unknown role in last position changes nothing earlier", my siblingNths({"group", "group", "UI element"}, {true, true, false}) is {1, 2, "?"})
	my check(results, "inElidedRun: past the head in a same-class run", my inElidedRun(true, 8, 20, "static text", "static text"))
	my check(results, "inElidedRun: without a head class nothing is elided", not my inElidedRun(true, 8, 20, "static text", ""))
	my check(results, "inElidedRun: the last child is always listed", not my inElidedRun(true, 20, 20, "static text", "static text"))
	my check(results, "inElidedRun: the head is always listed", not my inElidedRun(true, kElideHead, 20, "static text", "static text"))
	my check(results, "inElidedRun: other classes are listed", not my inElidedRun(true, 8, 20, "button", "static text"))
	my check(results, "inElidedRun: nothing is elided when elision is off", not my inElidedRun(false, 8, 20, "static text", "static text"))
	set fakeDesc to my failedDesc("AXGroup", "? [err -1719: Invalid index.]")
	my check(results, "failedDesc keeps a role read after the failure", (axRole of fakeDesc) is "AXGroup" and (descLine of fakeDesc) is "AXGroup  ? [err -1719: Invalid index.]")
	set fakeDesc to my failedDesc("", "? [err -1719: Invalid index.]")
	my check(results, "failedDesc without a role is the bare error tag", (axRole of fakeDesc) is "" and (descLine of fakeDesc) is "? [err -1719: Invalid index.]")
	my check(results, "elisionLine prints ?…? when a run's class count is not trusted", my elisionLine(54, 216, "static text", "?", "?") is "[UI element 54…216 | static text ?…?]  … 163 more static texts not listed")
	my check(results, "elisionLine prints ?…? when only one end is ?", my elisionLine(54, 216, "static text", 53, "?") is "[UI element 54…216 | static text ?…?]  … 163 more static texts not listed")

	-- planChildren: the real bookkeeping dumpChildren runs between the batched read and the recursion.
	set stClass to "static text"
	repeat with pos from 1 to 4
		set kidN to item pos of {1, 2, 5, 6}
		set rowClasses to my repeatList(stClass, kidN)
		my check(results, "planChildren: AXList with " & kidN & " children lists them all", my planText(rowClasses, my repeatList(true, kidN), "AXList") is my joinWith(my seqLabels(stClass, 1, kidN), " / "))
	end repeat
	my check(results, "planChildren: no children, no operations", my planText({}, {}, "AXList") is "")
	set want to my seqLabels(stClass, 1, 6) & {my elisionLine(7, 12, stClass, 7, 12), "[UI element 13 | static text 13]"}
	my check(results, "planChildren: 13 static texts → 1…6, one line for 7…12, then 13", my planText(my repeatList(stClass, 13), my repeatList(true, 13), "AXList") is my joinWith(want, " / "))
	set rowClasses to my repeatList(stClass, 217)
	set item 100 of rowClasses to "button"
	set want to my seqLabels(stClass, 1, 6) & {my elisionLine(7, 99, stClass, 7, 99), "[UI element 100 | button 1]", my elisionLine(101, 216, stClass, 100, 215), "[UI element 217 | static text 216]"}
	my check(results, "planChildren: 217 rows, a button at 100 splits the run, the last row is listed", my planText(rowClasses, my repeatList(true, 217), "AXList") is my joinWith(want, " / "))
	my check(results, "planChildren: an AXGroup with 24 children is never shortened", my planText(my repeatList(stClass, 24), my repeatList(true, 24), "AXGroup") is my joinWith(my seqLabels(stClass, 1, 24), " / "))
	my check(results, "planChildren: a window's sheet comes first, labels keep AX index and class count", my planText({"group", "sheet", "group"}, {true, true, true}, "AXWindow") is "[UI element 2 | sheet 1] / [UI element 1 | group 1] / [UI element 3 | group 2]")
	set rowClasses to my repeatList(stClass, 20)
	set item 10 of rowClasses to "UI element"
	set rowKnown to my repeatList(true, 20)
	set item 10 of rowKnown to false
	set want to my seqLabels(stClass, 1, 6) & {my elisionLine(7, 9, stClass, 7, 9), "[UI element 10 | UI element ?]", my elisionLine(11, 19, stClass, "?", "?"), "[UI element 20 | static text ?]"}
	my check(results, "planChildren: an unreadable row 10 of 20 breaks the run by class but not the shortening", my planText(rowClasses, rowKnown, "AXList") is my joinWith(want, " / "))

	-- describeKids/classifyKids: dumpChildren's per-child bookkeeping from a successful batch (no Apple Events).
	try
		tell application "System Events" to set fakeProps to {role:"AXGroup", name:"A"}
		set kidDescs to my describeKids({kids:{"k1", "k2", "k3"}, props:{fakeProps, {}, fakeProps}, ids:{"x", missing value, "z"}, readError:""})
		set kidInfo to my classifyKids(kidDescs)
		my check(results, "describeKids builds one description per child from the batch", (count of kidDescs) is 3 and (descLine of item 1 of kidDescs) is "AXGroup  id=\"x\"  title=\"A\"" and (descLine of item 2 of kidDescs) is "?")
		my check(results, "classifyKids maps roles to classes and flags unknown roles", (kidClasses of kidInfo) is {"group", "UI element", "group"} and (roleKnown of kidInfo) is {true, false, true})
	on error errMsg number errNum
		my check(results, "describeKids/classifyKids run without error: " & my errorTag(errNum, errMsg), false)
	end try

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

-- planChildren's operations rendered the way dumpChildren writes them, joined by " / ". An error comes back as
-- its errorTag, so a crashing planner fails its check instead of aborting the self-test.
on planText(kidClasses, roleKnown, parentRole)
	try
		set ops to my planChildren(kidClasses, roleKnown, parentRole)
		set acc to {}
		repeat with pos from 1 to (count of ops)
			set op to item pos of ops
			if (opKind of op) is "elide" then
				set end of acc to my elisionLine(firstIdx of op, lastIdx of op, cls of op, firstNth of op, lastNth of op)
			else
				set end of acc to "[" & my childLabel(op) & "]"
			end if
		end repeat
		return my joinWith(acc, " / ")
	on error errMsg number errNum
		set AppleScript's text item delimiters to ""
		return my errorTag(errNum, errMsg)
	end try
end planText

-- "[UI element i | <cls> i]" for i in a..b: the labels of a same-class run starting at child 1.
on seqLabels(cls, a, b)
	set acc to {}
	repeat with i from a to b
		set end of acc to "[UI element " & i & " | " & cls & " " & i & "]"
	end repeat
	return acc
end seqLabels

on repeatList(v, n)
	set acc to {}
	repeat n times
		set end of acc to v
	end repeat
	return acc
end repeatList

on joinWith(lst, sep)
	set AppleScript's text item delimiters to sep
	set s to lst as text
	set AppleScript's text item delimiters to ""
	return s
end joinWith

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

on repeatText(t, n)
	set s to ""
	repeat n times
		set s to s & t
	end repeat
	return s
end repeatText

-- What the dump prints instead of a bare "?" when System Events cannot read an element.
on errorTag(errNum, errMsg)
	return "? [err " & errNum & ": " & (my shorten(errMsg, 80)) & "]"
end errorTag

-- Lists/outlines/tables longer than kElideAbove are shortened; groups never are (the sheet's main group
-- holds the create button and the address).
on shouldElide(axRole, kidCount)
	return (axRole is in kElideRoles) and (kidCount > kElideAbove)
end shouldElide

-- One line standing for children firstIdx..lastIdx, all of class `cls`, so their addresses stay composable.
-- The `UI element a…b` range is always exact; the class range reads `?…?` when either end's count is untrusted.
on elisionLine(firstIdx, lastIdx, cls, firstNth, lastNth)
	set nthRange to (firstNth as text) & "…" & (lastNth as text)
	if firstNth is "?" or lastNth is "?" then set nthRange to "?…?"
	return "[UI element " & firstIdx & "…" & lastIdx & " | " & cls & " " & nthRange & "]  … " & (lastIdx - firstIdx + 1) & " more " & cls & "s not listed"
end elisionLine

-- item idx of lst, or fallback when lst is missing value, too short, or the item is missing value.
on itemOr(lst, idx, fallback)
	try
		if lst is missing value then return fallback
		set v to item idx of lst
		if v is missing value then return fallback
		return v
	end try
	return fallback
end itemOr

-- Class-nth of every child ("group 3" → 3). A child whose role could not be read may belong to any class, so
-- from that child on no count can be trusted: it and every later sibling get "?" ("UI element N" stays exact).
on siblingNths(kidClasses, roleKnown)
	set nthList to {}
	set broken to false
	repeat with idx from 1 to (count of kidClasses)
		if not (item idx of roleKnown) then set broken to true
		if broken then
			set end of nthList to "?"
		else
			set nth to 0
			repeat with j from 1 to idx
				if (item j of kidClasses) is (item idx of kidClasses) then set nth to nth + 1
			end repeat
			set end of nthList to nth
		end if
	end repeat
	return nthList
end siblingNths

-- True when child idx (of n) is folded into an elision line: past the head, not the last child, same class as
-- child kElideHead. An untrusted ("?") class-nth may join the run: the `UI element a…b` range stays exact.
on inElidedRun(elide, idx, n, cls, headCls)
	if not elide then return false
	return idx > kElideHead and idx < n and cls is headCls
end inElidedRun

-- The pure part of dumpChildren (no Apple Events): given each child's class and whether its role was read,
-- returns what to write, in file order — {opKind:"dump", idx:, cls:, nth:} for a child listed in full,
-- {opKind:"elide", firstIdx:, lastIdx:, cls:, firstNth:, lastNth:} for one elision line. Sheets come first;
-- lists/outlines/tables longer than kElideAbove keep children 1…kElideHead, the last child and any child of
-- a class other than child kElideHead's.
on planChildren(kidClasses, roleKnown, parentRole)
	set n to count of kidClasses
	set nths to my siblingNths(kidClasses, roleKnown)
	set visitOrder to {}
	repeat with idx from 1 to n
		if (item idx of kidClasses) is "sheet" then set end of visitOrder to idx
	end repeat
	set hasSheets to (count of visitOrder) > 0
	repeat with idx from 1 to n
		if (item idx of kidClasses) is not "sheet" then set end of visitOrder to idx
	end repeat
	-- Lists/outlines/tables never contain sheets, so visitOrder is the identity whenever elide is true.
	set elide to (not hasSheets) and my shouldElide(parentRole, n)
	set headCls to ""
	if n ≥ kElideHead then set headCls to item kElideHead of kidClasses
	set ops to {}
	set runStart to 0
	repeat with pos from 1 to n
		set idx to item pos of visitOrder
		set cls to item idx of kidClasses
		if my inElidedRun(elide, idx, n, cls, headCls) then
			if runStart is 0 then set runStart to idx
		else
			if runStart > 0 then
				set end of ops to {opKind:"elide", firstIdx:runStart, lastIdx:idx - 1, cls:headCls, firstNth:item runStart of nths, lastNth:item (idx - 1) of nths}
				set runStart to 0
			end if
			set end of ops to {opKind:"dump", idx:idx, cls:cls, nth:item idx of nths}
		end if
	end repeat
	return ops
end planChildren

-- Address of a "dump" op relative to its parent, e.g. "UI element 3 | group 2".
on childLabel(op)
	return "UI element " & (idx of op) & " | " & (cls of op) & " " & (nth of op)
end childLabel

-- Per-child class and whether its role was read (an unknown role maps to class "UI element").
on classifyKids(descs)
	set kidClasses to {}
	set roleKnown to {}
	repeat with idx from 1 to (count of descs)
		set r to axRole of (item idx of descs)
		set end of kidClasses to my roleToClass(r)
		set end of roleKnown to (r is not "" and r is not "?")
	end repeat
	return {kidClasses:kidClasses, roleKnown:roleKnown}
end classifyKids

-- Report entry for an element whose read failed. `knownRole` is "" when not even its role could be read.
on failedDesc(knownRole, tagText)
	if knownRole is "" then return {axRole:"", descLine:tagText}
	return {axRole:knownRole, descLine:knownRole & "  " & tagText}
end failedDesc

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
-- GUI: DUMP
----------------------------------------------------------------------

on dumpSystemSettings()
	if application "System Settings" is not running then
		set end of report to "System Settings is not running — nothing to dump."
		return
	end if
	set retriesLeft to kRetryBudget
	set failedReads to 0
	tell application "System Events" to tell application process "System Settings"
		set winCount to count of windows
		set end of report to "--- accessibility tree (" & winCount & " window(s); depth ≤ " & kMaxDepth & ", ≤ " & kMaxElements & " elements) ---"
		set end of report to "Each line: <indent>[UI element N | <class> M]  role  id=…  title=…  desc=…  value=…   — compose paths bottom-up, e.g. 'group 3 of scroll area 1 of … of window 1'."
		set end of report to "Sheets are listed before the rest of their window. Lists, outlines and tables with more than " & kElideAbove & " children show the first " & kElideHead & " and the last one; a '…' line stands for the rest. '? [err N: …]' = System Events could not read that element (its role in front when that could still be read); after an element of unknown role the sibling counts read '?'."
		repeat with w from 1 to winCount
			set d to my describeOne(window w)
			my dumpTree(window w, 0, "window " & w, axRole of d, descLine of d)
		end repeat
	end tell
	if elementCount ≥ kMaxElements then set end of report to "(stopped after " & kMaxElements & " elements)"
	if failedReads > 0 then set end of report to "(" & failedReads & " read(s) failed — see the '? [err' lines)"
end dumpSystemSettings

-- Recursive. `label` is this element's own address relative to its parent (e.g. "group 3"). `axRole` and
-- `descLine` were read by the parent's batch (or by describeOne for a window).
on dumpTree(el, depth, label, axRole, descLine)
	if depth > kMaxDepth then return
	if elementCount ≥ kMaxElements then return
	set elementCount to elementCount + 1
	set end of report to (my indent(depth)) & "[" & label & "]  " & descLine
	my dumpChildren(el, depth, axRole)
end dumpTree

-- Children of one parent: batched read, then the pure planChildren (sibling counts, sheets first, long lists
-- shortened), then the lines and the recursion. Errors cost one line, never the rest of the dump (spec D3).
on dumpChildren(el, depth, parentRole)
	set batch to my fetchChildren(el)
	set kids to kids of batch
	set n to count of kids
	if n is 0 then
		if (readError of batch) is not "" then
			set failedReads to failedReads + 1
			set end of report to (my indent(depth + 1)) & "(children unavailable: " & (readError of batch) & ")"
		end if
		return
	end if

	try
		set descs to my describeKids(batch)
		set kidInfo to my classifyKids(descs)
		set ops to my planChildren(kidClasses of kidInfo, roleKnown of kidInfo, parentRole)
	on error errMsg number errNum
		set failedReads to failedReads + 1
		set end of report to (my indent(depth + 1)) & "(children unavailable: " & my errorTag(errNum, errMsg) & ")"
		return
	end try

	repeat with pos from 1 to (count of ops)
		set opIdx to "?"
		try
			set op to item pos of ops
			if (opKind of op) is "elide" then
				set opIdx to firstIdx of op
				set end of report to (my indent(depth + 1)) & my elisionLine(firstIdx of op, lastIdx of op, cls of op, firstNth of op, lastNth of op)
			else
				set opIdx to idx of op
				set d to item opIdx of descs
				my dumpTree(item opIdx of kids, depth + 1, my childLabel(op), axRole of d, descLine of d)
			end if
		on error errMsg number errNum
			set failedReads to failedReads + 1
			set end of report to (my indent(depth + 1)) & "[UI element " & opIdx & "]  " & my errorTag(errNum, errMsg)
		end try
	end repeat
end dumpChildren

-- One description per child: from the batch when it succeeded (no Apple Events when the ids batch did too),
-- one by one otherwise.
on describeKids(batch)
	set descs to {}
	repeat with idx from 1 to (count of (kids of batch))
		if (props of batch) is missing value then
			set end of descs to my describeOne(item idx of (kids of batch))
		else
			-- The identifier batch fails as a whole (or is nulled on a count mismatch): read ids one by one then.
			if (ids of batch) is missing value then
				set aid to my readIdentifier(item idx of (kids of batch))
			else
				set aid to my itemOr(ids of batch, idx, "")
			end if
			set end of descs to my describeFromProps(item idx of (props of batch), aid)
		end if
	end repeat
	return descs
end describeKids

-- Three Apple Events per parent instead of four per child: children, their `properties`, their AXIdentifiers.
-- `props`/`ids` are missing value when a batch failed or its count does not match the children (tree changed
-- between reads) — the caller then describes one by one. `readError` is set only when even the children fetch failed.
on fetchChildren(el)
	set kids to {}
	set props to missing value
	set ids to missing value
	set readError to ""
	try
		with timeout of kBatchTimeout seconds
			tell application "System Events"
				set kids to every UI element of el
				if (count of kids) > 0 then
					set props to properties of every UI element of el
					try
						set ids to value of attribute "AXIdentifier" of every UI element of el
					end try
				end if
			end tell
		end timeout
	on error errMsg number errNum
		if (count of kids) is 0 then set readError to my errorTag(errNum, errMsg)
		set props to missing value
	end try
	if props is not missing value and (count of props) is not (count of kids) then set props to missing value
	if ids is not missing value and (count of ids) is not (count of kids) then set ids to missing value
	return {kids:kids, props:props, ids:ids, readError:readError}
end fetchChildren

-- One element on its own (a window, or a child whose parent's batch failed). A failure is recorded as
-- '? [err N: message]' and retried once after 0.3 s while the dump-wide budget lasts — on Tahoe the WebKit
-- part of the tree drops out for a moment and comes back.
on describeOne(el)
	repeat with attempt from 1 to 2
		try
			with timeout of kReadTimeout seconds
				tell application "System Events"
					set p to properties of el
					set aid to missing value
					try
						set aid to value of attribute "AXIdentifier" of el
					end try
				end tell
			end timeout
			return my describeFromProps(p, aid)
		on error errMsg number errNum
			if attempt is 2 or retriesLeft ≤ 0 then
				set failedReads to failedReads + 1
				-- Keep the class if at all possible: without it every later sibling's class-nth is unknown.
				return my failedDesc(my readRole(el), my errorTag(errNum, errMsg))
			end if
			set retriesLeft to retriesLeft - 1
			delay 0.3
		end try
	end repeat
	return {axRole:"", descLine:"?"}
end describeOne

-- Single attempts, no retry, not counted against retriesLeft. "" / missing value when unreadable.
on readRole(el)
	try
		with timeout of 2 seconds
			tell application "System Events" to set r to role of el
		end timeout
		if r is missing value then return ""
		return r as text
	end try
	return ""
end readRole

on readIdentifier(el)
	try
		with timeout of 2 seconds
			tell application "System Events" to set aid to value of attribute "AXIdentifier" of el
		end timeout
		return aid
	end try
	return missing value
end readIdentifier

-- Builds the report line from a `properties` record. No Apple Events: the tell block only supplies terminology.
on describeFromProps(p, aid)
	set r to "?"
	set sub to ""
	set ttl to ""
	set dsc to ""
	set val to ""
	set en to ""
	tell application "System Events"
		try
			if role of p is not missing value then set r to role of p
		end try
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
	end tell
	if aid is missing value then set aid to ""
	set descLine to r
	if sub is not "" then set descLine to descLine & "/" & sub
	if aid is not "" then set descLine to descLine & "  id=\"" & aid & "\""
	if ttl is not "" then set descLine to descLine & "  title=\"" & (my shorten(ttl, 60)) & "\""
	if dsc is not "" and dsc is not ttl then set descLine to descLine & "  desc=\"" & (my shorten(dsc, 60)) & "\""
	if val is not "" then set descLine to descLine & "  value=\"" & (my shorten(val, 60)) & "\""
	if en is "false" then set descLine to descLine & "  disabled"
	return {axRole:r, descLine:descLine}
end describeFromProps

on indent(depth)
	set s to ""
	repeat depth times
		set s to s & "  "
	end repeat
	return s
end indent
