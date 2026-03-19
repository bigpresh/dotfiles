Append a quick note to today's worklog. No fuss, no questions.

The note to log is: $ARGUMENTS

Run the following, which ensures today's date heading exists and appends the note under it:

```bash
WORKLOG=~/.claude/worklog.md
TODAY=$(date +%Y-%m-%d)
NOTE="$ARGUMENTS"

# Create file if it doesn't exist
touch "$WORKLOG"

# Add today's heading if not already present
if ! grep -q "^## $TODAY" "$WORKLOG"; then
  echo "" >> "$WORKLOG"
  echo "## $TODAY" >> "$WORKLOG"
fi

# Append the note
echo "- $NOTE" >> "$WORKLOG"

echo "Logged."
```

Do not say anything else. Just run the command and confirm with "Logged." — the user is busy.
