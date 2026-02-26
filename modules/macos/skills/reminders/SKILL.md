---
name: reminders
description: Use when the user asks to view, add, complete, or manage reminders
---

# Reminders.app Management

Interact with macOS Reminders.app via AppleScript.

## List Reminder Lists

First, discover the user's reminder lists:
```bash
osascript -e 'tell application "Reminders" to get name of lists'
```

## List Reminders

### All incomplete reminders
```bash
osascript -e 'tell application "Reminders"
  set output to ""
  repeat with r in (every reminder whose completed is false)
    set output to output & (name of r) & "\n"
  end repeat
  return output
end tell'
```

### Incomplete reminders from specific list
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set output to ""
    repeat with r in (every reminder whose completed is false)
      set output to output & (name of r) & "\n"
    end repeat
    return output
  end tell
end tell'
```

### Reminders with due dates
```bash
osascript -e 'tell application "Reminders"
  set output to ""
  repeat with r in (every reminder whose completed is false and due date is not missing value)
    set output to output & (name of r) & " - Due: " & (due date of r) & "\n"
  end repeat
  return output
end tell'
```

### Overdue reminders
```bash
osascript -e 'tell application "Reminders"
  set output to ""
  set rightNow to current date
  repeat with r in (every reminder whose completed is false and due date is not missing value)
    if due date of r < rightNow then
      set output to output & (name of r) & " - Due: " & (due date of r) & "\n"
    end if
  end repeat
  return output
end tell'
```

### Completed reminders
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set output to ""
    repeat with r in (every reminder whose completed is true)
      set output to output & (name of r) & "\n"
    end repeat
    return output
  end tell
end tell'
```

## Add Reminders

### Simple reminder
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    make new reminder with properties {name:"REMINDER_TEXT"}
  end tell
end tell'
```

### Reminder with due date
```bash
osascript -e 'tell application "Reminders"
  tell list "TODOs"
    make new reminder with properties {name:"Call dentist", due date:date "1/15/2026 9:00 AM"}
  end tell
end tell'
```

### Reminder with priority
Priority: 0 (none), 1-4 (high), 5 (medium), 6-9 (low)

```bash
osascript -e 'tell application "Reminders"
  tell list "TODOs"
    make new reminder with properties {name:"Urgent task", priority:1}
  end tell
end tell'
```

### Reminder with notes
```bash
osascript -e 'tell application "Reminders"
  tell list "TODOs"
    make new reminder with properties {name:"Project review", body:"Check all milestones and update status"}
  end tell
end tell'
```

### Full reminder with all options
```bash
osascript -e 'tell application "Reminders"
  tell list "TODOs"
    make new reminder with properties {name:"Submit report", due date:date "1/15/2026 5:00 PM", priority:1, body:"Include Q4 metrics"}
  end tell
end tell'
```

## Complete a Reminder

```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set completed of (first reminder whose name is "REMINDER_TEXT") to true
  end tell
end tell'
```

### Complete by partial name match
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    repeat with r in (every reminder whose name contains "dentist")
      set completed of r to true
    end repeat
  end tell
end tell'
```

## Uncomplete a Reminder

```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set completed of (first reminder whose name is "REMINDER_TEXT") to false
  end tell
end tell'
```

## Delete a Reminder

```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    delete (first reminder whose name is "REMINDER_TEXT")
  end tell
end tell'
```

### Delete all completed reminders in a list
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    delete (every reminder whose completed is true)
  end tell
end tell'
```

## Modify a Reminder

### Change due date
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set due date of (first reminder whose name is "REMINDER_TEXT") to date "1/20/2026 9:00 AM"
  end tell
end tell'
```

### Update priority
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set priority of (first reminder whose name is "REMINDER_TEXT") to 1
  end tell
end tell'
```

### Add/update notes
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set body of (first reminder whose name is "REMINDER_TEXT") to "Updated notes here"
  end tell
end tell'
```

## Move Reminder to Different List

```bash
osascript -e 'tell application "Reminders"
  set theReminder to first reminder of list "SOURCE_LIST" whose name is "REMINDER_TEXT"
  move theReminder to list "DESTINATION_LIST"
end tell'
```

## Create a New List

```bash
osascript -e 'tell application "Reminders"
  make new list with properties {name:"NEW_LIST_NAME"}
end tell'
```

## Get Reminder Details

```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    set r to first reminder whose name is "REMINDER_TEXT"
    return "Name: " & (name of r) & ", Due: " & (due date of r) & ", Priority: " & (priority of r) & ", Notes: " & (body of r)
  end tell
end tell'
```

## Count Reminders

### Count incomplete in list
```bash
osascript -e 'tell application "Reminders"
  tell list "LIST_NAME"
    return count of (every reminder whose completed is false)
  end tell
end tell'
```

### Count all incomplete
```bash
osascript -e 'tell application "Reminders"
  return count of (every reminder whose completed is false)
end tell'
```

## Tips

- Always discover list names first with `osascript -e 'tell application "Reminders" to get name of lists'`
- List names are case-sensitive
- Use `name contains` for partial matching
- Due date format: "MM/DD/YYYY HH:MM AM/PM"
- Priority: 0=none, 1-4=high, 5=medium, 6-9=low
- `body` property holds the notes/description
- Reminders sync with iCloud - changes appear on all devices
