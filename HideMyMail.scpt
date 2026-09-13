on run argv
  set emailLabel to (argv as string)
  if emailLabel is "" then error "No label provided" number 1

  do shell script "killall 'System Settings' 2>/dev/null || true"
  tell application "System Events"
    repeat 20 times
      if not (exists process "System Settings") then exit repeat
      delay 0.3
    end repeat
  end tell

  do shell script "open 'x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud'"

  tell application "System Events"
    repeat 30 times
      try
        if exists process "System Settings" then
          if (count of windows of process "System Settings") ≥ 1 then exit repeat
        end if
      end try
      delay 0.4
    end repeat
    tell process "System Settings"
      set frontmost to true
      try
        set size of window 1 to {900, 720}
      end try
    end tell
  end tell

  set featGroup to missing value
  tell application "System Events"
    tell process "System Settings"
      repeat 40 times
        try
          set contentScroll to scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1
          repeat with elem in UI elements of contentScroll
            try
              if (class of elem is group) and (value of static text 1 of elem is "iCloud+ Features") then
                set featGroup to elem
                exit repeat
              end if
            end try
          end repeat
          if featGroup is not missing value then exit repeat
        end try
        delay 0.4
      end repeat
      if featGroup is missing value then error "Could not find iCloud+ Features section (Accessibility? signed into iCloud+?)"
      set hideBtn to missing value
      try
        repeat with i from 1 to (count of buttons of featGroup)
          try
            if (value of attribute "AXIdentifier" of button i of featGroup) is "six-pack-card-Hide My Email" then
              set hideBtn to button i of featGroup
              exit repeat
            end if
          end try
        end repeat
      end try
      if hideBtn is missing value then set hideBtn to button 5 of featGroup
      click hideBtn
    end tell
  end tell

  tell application "System Events"
    tell process "System Settings"
      repeat 40 times
        try
          if (count of sheets of window 1) ≥ 1 then exit repeat
        end try
        delay 0.4
      end repeat
      if (count of sheets of window 1) < 1 then error "Timed out waiting for Hide My Email sheet"
      repeat 40 times
        try
          set _btn to button "Create New Address" of group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1
          exit repeat
        end try
        delay 0.4
      end repeat
      set mainGroup to group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1
      click button "Create New Address" of mainGroup
    end tell
  end tell

  set createSheetIndex to 0
  tell application "System Events"
    tell process "System Settings"
      repeat 40 times
        try
          repeat with i from 1 to (count of sheets of window 1)
            try
              set _base to group 1 of UI element 1 of scroll area 1 of sheet i of window 1
              set _email to value of static text 1 of UI element 5 of group 1 of _base
              if _email is not "" and _email contains "@" then
                set createSheetIndex to i
                exit repeat
              end if
            end try
          end repeat
          if createSheetIndex > 0 then exit repeat
        end try
        delay 0.4
      end repeat
      if createSheetIndex is 0 then error "Timed out waiting for Create New Address dialog"
    end tell
  end tell

  set generatedEmail to ""
  tell application "System Events"
    tell process "System Settings"
      set createBase to group 1 of UI element 1 of scroll area 1 of sheet createSheetIndex of window 1
      set mainContent to group 1 of createBase
      set generatedEmail to value of static text 1 of UI element 5 of mainContent
      set labelField to text field 1 of UI element 8 of mainContent
      set focused of labelField to true
      delay 0.2
      set value of labelField to emailLabel
      delay 0.3
      set navGroup to group 2 of createBase
      click button "Continue" of group 2 of group 1 of navGroup
    end tell
  end tell

  do shell script "printf %s " & quoted form of generatedEmail & " | pbcopy"
  delay 1
  do shell script "killall 'System Settings' 2>/dev/null || true"
  return generatedEmail
end run
