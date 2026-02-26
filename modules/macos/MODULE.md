# macOS Module

Skills for interacting with macOS applications.

## Available Skills

### calendar
View, add, and manage calendar events in Calendar.app.
- Uses `icalBuddy` for reading events (fast)
- Uses AppleScript for adding/modifying events
- Always discover available calendars first

### reminders
View, add, complete, and manage reminders in Reminders.app.
- All operations via AppleScript
- Always discover available reminder lists first
- Supports priorities, due dates, and notes

### photos
View, search, and organize photos in Photos.app.
- All operations via AppleScript
- Can be slow with large libraries - use filters when possible
- Supports albums, favorites, descriptions, and date ranges

## Requirements

- macOS system
- icalBuddy (for calendar skill) - optional but recommended
- Calendar.app, Reminders.app, Photos.app must be accessible

## Tips

- All skills use AppleScript and require appropriate permissions
- First-run may prompt for permissions to access Calendar/Reminders/Photos
- Operations sync with iCloud if enabled
