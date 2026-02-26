---
name: calendar
description: Use when the user asks to view, add, or manage calendar events
---

# Calendar Management

Interact with macOS Calendar.app and view events using icalBuddy.

## Discover Available Calendars

First, discover the user's calendars:
```bash
icalBuddy -nc calendars
```

## List Events

### Today's events
```bash
icalBuddy -f eventsToday
```

### Events for next N days
```bash
icalBuddy -f eventsToday+7
```

### Events in date range
```bash
icalBuddy -f 'eventsFrom:2026-01-15 to:2026-01-20'
```

## Add Events

Use AppleScript to add events:

```bash
osascript -e 'tell application "Calendar"
  tell calendar "CALENDAR_NAME"
    make new event with properties {summary:"EVENT_TITLE", start date:date "MM/DD/YYYY HH:MM AM/PM", end date:date "MM/DD/YYYY HH:MM AM/PM"}
  end tell
end tell'
```

### Example: Add a meeting
```bash
osascript -e 'tell application "Calendar"
  tell calendar "Home"
    make new event with properties {summary:"Team Standup", start date:date "1/15/2026 10:00 AM", end date:date "1/15/2026 10:30 AM", description:"Daily sync"}
  end tell
end tell'
```

### With location and notes
```bash
osascript -e 'tell application "Calendar"
  tell calendar "Home"
    make new event with properties {summary:"Lunch", start date:date "1/15/2026 12:00 PM", end date:date "1/15/2026 1:00 PM", location:"Cafe", description:"Meet with Bob"}
  end tell
end tell'
```

## Delete Events

```bash
osascript -e 'tell application "Calendar"
  tell calendar "CALENDAR_NAME"
    delete (every event whose summary is "EVENT_TITLE")
  end tell
end tell'
```

### Delete specific event by date
```bash
osascript -e 'tell application "Calendar"
  tell calendar "Home"
    delete (every event whose summary is "Team Standup" and start date is date "1/15/2026 10:00 AM")
  end tell
end tell'
```

## Tips

- Always confirm calendar name exists before adding (use `icalBuddy -nc calendars`)
- Date format for AppleScript: "MM/DD/YYYY HH:MM AM/PM"
- Use `icalBuddy` for reading (faster, simpler output)
- Use AppleScript for writing (add/delete/modify)
