on run argv
  set labelText to (argv as string)

  if application "System Settings" is running then
    tell application "System Settings" to quit
    delay 0.5
  end if

  tell application "System Settings"
    activate
    delay 0.5
    reveal pane id "com.apple.systempreferences.AppleIDSettings:icloud"
  end tell

  tell application "System Events"
    tell application process "System Settings"
      set featuresGroup to group 3 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1 of window 1

      set hideTile to missing value
      set waitCount to 0
      repeat until (hideTile is not missing value) or waitCount > 100
        try
          repeat with i from 1 to (count of buttons of featuresGroup)
            try
              if (value of attribute "AXIdentifier" of button i of featuresGroup) is "six-pack-card-Hide My Email" then
                set hideTile to button i of featuresGroup
                exit repeat
              end if
            end try
          end repeat
        end try
        if hideTile is missing value then
          delay 0.1
          set waitCount to waitCount + 1
        end if
      end repeat
      if hideTile is missing value then
        error "Hide My Email tile not found in iCloud+ Features"
      end if
      perform action "AXPress" of hideTile

      set waitCount to 0
      repeat until (exists button "Create New Address" of group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1) or waitCount > 100
        delay 0.1
        set waitCount to waitCount + 1
      end repeat
      perform action "AXPress" of button "Create New Address" of group 1 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1

      set waitCount to 0
      repeat until (exists text field 1 of group 4 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1) or waitCount > 100
        delay 0.1
        set waitCount to waitCount + 1
      end repeat
      tell text field 1 of group 4 of group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1
        set focused to true
        set value to labelText
      end tell

      delay 0.3
      perform action "AXPress" of button "Continue" of group 2 of group 1 of group 2 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1

      set waitCount to 0
      repeat until (exists button "Copy Address" of group 1 of group 1 of group 2 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1) or waitCount > 100
        delay 0.1
        set waitCount to waitCount + 1
      end repeat
      perform action "AXPress" of button "Copy Address" of group 1 of group 1 of group 2 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1

      delay 0.3
      perform action "AXPress" of button "Done" of group 2 of group 1 of group 2 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1
    end tell
  end tell

  tell application "System Settings"
    delay 0.5
    quit
  end tell
end run
