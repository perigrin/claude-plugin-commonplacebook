---
name: photos
description: Use when the user asks to view, search, or organize photos in Photos.app
---

# Photos.app Management

Interact with macOS Photos.app via AppleScript.

## List Albums

```bash
osascript -e 'tell application "Photos"
  get name of every album
end tell'
```

## Get Recent Photos

### Photos from last N days
```bash
osascript -e 'tell application "Photos"
  set cutoffDate to (current date) - 1 * days
  set output to ""
  set allItems to every media item
  repeat with anItem in allItems
    if date of anItem > cutoffDate then
      set output to output & (date of anItem) & " - " & (filename of anItem) & "\n"
    end if
  end repeat
  return output
end tell'
```

Note: Can be slow with large libraries. Adjust days as needed.

### Get last N photos (faster)
```bash
osascript -e 'tell application "Photos"
  set allItems to every media item
  set itemCount to count of allItems
  set startIndex to itemCount - 9  -- last 10
  if startIndex < 1 then set startIndex to 1
  set output to ""
  repeat with i from startIndex to itemCount
    set anItem to item i of allItems
    set output to output & (date of anItem) & " - " & (filename of anItem) & "\n"
  end repeat
  return output
end tell'
```

## Get Photo Details

### Get info about specific photo
```bash
osascript -e 'tell application "Photos"
  set allItems to every media item whose filename is "IMG_3287.HEIC"
  repeat with anItem in allItems
    set photoDate to date of anItem
    set photoName to filename of anItem
    set photoDesc to description of anItem
    return "Date: " & photoDate & ", File: " & photoName & ", Description: " & photoDesc
  end repeat
end tell'
```

## Photos in Album

### List photos in specific album
```bash
osascript -e 'tell application "Photos"
  tell album "ALBUM_NAME"
    set output to ""
    repeat with anItem in every media item
      set output to output & (date of anItem) & " - " & (filename of anItem) & "\n"
    end repeat
    return output
  end tell
end tell'
```

### Count photos in album
```bash
osascript -e 'tell application "Photos"
  tell album "ALBUM_NAME"
    return count of media items
  end tell
end tell'
```

## Create Album

```bash
osascript -e 'tell application "Photos"
  make new album named "NEW_ALBUM_NAME"
end tell'
```

## Add Photo to Album

Note: Cannot add photos by filename alone - need to find the media item first.

```bash
osascript -e 'tell application "Photos"
  set thePhoto to first media item whose filename is "IMG_3287.HEIC"
  add {thePhoto} to album "ALBUM_NAME"
end tell'
```

## Search Photos by Date Range

```bash
osascript -e 'tell application "Photos"
  set startDate to date "1/1/2026"
  set endDate to date "1/10/2026"
  set output to ""
  repeat with anItem in every media item
    set photoDate to date of anItem
    if photoDate ≥ startDate and photoDate ≤ endDate then
      set output to output & photoDate & " - " & (filename of anItem) & "\n"
    end if
  end repeat
  return output
end tell'
```

## Get Photo Metadata

```bash
osascript -e 'tell application "Photos"
  set anItem to first media item whose filename is "IMG_3287.HEIC"
  set props to properties of anItem
  return props
end tell'
```

Available properties:
- `date` - when photo was taken
- `filename` - original filename
- `description` - user-added description
- `favorite` - is it favorited
- `keywords` - tags/keywords
- `altitude`, `location` - GPS data if available
- `width`, `height` - dimensions

## Set Photo Description

```bash
osascript -e 'tell application "Photos"
  set anItem to first media item whose filename is "IMG_3287.HEIC"
  set description of anItem to "Family dinner at the beach"
end tell'
```

## Favorite/Unfavorite Photo

```bash
osascript -e 'tell application "Photos"
  set anItem to first media item whose filename is "IMG_3287.HEIC"
  set favorite of anItem to true
end tell'
```

## Tips

- Photos.app must be running (or will launch automatically)
- Large library operations can be slow - use date filters when possible
- Use `filename is` for exact match, or iterate and check
- Cannot directly import photos via AppleScript - use `open` command instead:
  ```bash
  open -a Photos /path/to/photo.jpg
  ```
- Export is not well-supported via AppleScript - use Photos app directly
