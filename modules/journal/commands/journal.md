---
name: journal
description: Interview the user about their day and create a journal entry
---

# Daily Journal Interview

Interview the user about their day, based on analysis of their actual activity.

## Pre-Interview Analysis

Before asking questions, gather context:

1. **Check the day** - Is it a weekday (likely work) or weekend (likely projects/personal)?

2. **Check today's calendar** (if icalBuddy available):
   ```bash
   if command -v icalBuddy >/dev/null 2>&1; then
     icalBuddy -f eventsToday
   fi
   ```

3. **Check reminders** (if macOS Reminders.app available):
   ```bash
   if [[ "$OSTYPE" == "darwin"* ]]; then
     osascript -e 'tell application "Reminders"
       set output to ""
       repeat with r in (every reminder whose completed is false)
         set output to output & (name of r) & "\n"
       end repeat
       return output
     end tell' 2>/dev/null | head -20
   fi
   ```

4. **Scan recent git activity** across local repos:
   ```bash
   # Find git repos in ~/dev
   find ~/dev -maxdepth 2 -name ".git" -type d 2>/dev/null | while read gitdir; do
     repo=$(dirname "$gitdir")
     echo "=== $(basename "$repo") ==="
     git -C "$repo" log --oneline --since="midnight" --author="$(git config user.name)" 2>/dev/null | head -5
   done
   ```

5. **Check recently modified files** in active projects:
   ```bash
   find ~/dev -name "*.pm" -o -name "*.pl" -o -name "*.md" -mtime 0 2>/dev/null | head -20
   ```

6. **Check recent photos** (if macOS Photos.app available):
   ```bash
   if [[ "$OSTYPE" == "darwin"* ]]; then
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
     end tell' 2>/dev/null | head -20
   fi
   ```
   Note: This can be slow with large libraries. May need to adjust cutoff date based on last journal entry.

7. **Search episodic memory** for recent Claude conversations (if plugin available):
   Use the episodic-memory plugin to find what the user has been working on with Claude recently.

8. **Review any open PRs or issues** they might have worked on

## Contextual Interview

Based on the analysis, tailor questions:

### If calendar events detected:
- "I see you had [meeting/event]. How did that go?"
- "Anything noteworthy from [event]?"

### If reminders are due/overdue:
- "You've got [reminder] on your list - any progress on that?"
- "Anything blocking you on [reminder]?"

### If recent photos detected:
- "I see you took some photos recently. What was the occasion?"
- "Anything memorable about [photo context]?"

### If Claude conversation history found:
- "I see we were working on [project/topic] recently. How's that going?"
- "Any breakthroughs or blockers on [topic]?"
- "Want to capture any insights from that work?"

### If it's a workday (Mon-Fri) and no project activity detected:
- "How was work today?"
- "Any interesting problems, meetings, or conversations?"
- "Anything frustrating or energizing?"

### If project commits detected:
- "I see you were working on [project]. What were you trying to accomplish?"
- "How did it go? Any problems or breakthroughs?"
- "Any insights or patterns you noticed?"

### If writing/blog activity detected:
- "What were you writing about?"
- "Any new angles or ideas that emerged?"

### General prompts (pick what's relevant):
- "What's on your mind today?"
- "Anything you want to remember about today?"
- "Any ideas worth capturing?"
- "How are you feeling about things?"
- "Any connections to things you've been thinking about lately?"

Keep it conversational. Follow the thread of what they want to talk about.

## After the Interview

Create a journal entry at `journals/YYYY-MM-DD.md` with:

```markdown
---
title: Journal - [Date]
tags: ["journal"]
---

## Context

[Day of week, what activity was detected]

## Summary

[What happened, what's on their mind]

## Notes

[Key points, insights, ideas worth remembering]

## Connections

- [[related-note]] - [how it connects]
```

Add additional tags based on content (e.g., "work", "projects", "ideas", "personal").

Then:
1. Run `zk index --force`
2. Commit with message "Journal for YYYY-MM-DD"
3. Offer to add backlinks to related notes or create stub pages for new concepts
