on run argv
  tell application "System Settings"
    activate
    reveal pane id "com.apple.systempreferences.AppleIDSettings*AppleIDSettings"
  end tell
  tell application "System Events"
    tell application process "System Settings"
      tell splitter group 1 of group 1 of window 1
        tell group 2 to tell group 1 to tell scroll area 1 to tell group 3
          repeat until UI element 1 exists
            delay 0
          end repeat
          click UI element 1
          repeat until UI element 2 exists
            delay 0
          end repeat
          click UI element 2
        end tell
      end tell
      repeat until group 1 of group 1 of UI element 1 of scroll area 1 of sheet 1 of window 1 exists
        delay 0
      end repeat
      tell window 1 to tell sheet 1 to tell scroll area 1 to tell UI element 1
         tell group 1 of group 1
           click UI element 4 of group 1
           repeat until text field 1 of group 4 exists
             delay 0
           end repeat
           click text field 1 of group 4
           set value of text field 1 of group 4 to argv
         end tell
         tell group 1 to tell group 2 to tell group 1
           repeat until UI element "Fortfahren" of group 2 exists
             delay 0
           end repeat
           click UI element "Fortfahren" of group 2
           repeat until UI element "Adresse kopieren" of group 1 exists
             delay 0
           end repeat
           click UI element "Adresse kopieren" of group 1
           repeat until UI element "Fertig" of group 2 exists
             delay 0
           end repeat
           click UI element "Fertig" of group 2
           repeat until UI element "Fertig" of group 1 exists
             delay 0
           end repeat
           click UI element "Fertig" of group 1
         end tell
       end tell
    end tell
  end tell
  tell application "System Settings"
    delay 1
    quit
  end tell
end run
