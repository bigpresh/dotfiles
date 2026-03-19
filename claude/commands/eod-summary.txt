Generate an end-of-day summary of everything worked on today, then help draft a brief update for my boss.

## Step 1 — Establish "today"

Get today's date for filtering:
```bash
date +%Y-%m-%d
```

Also check when the last EOD summary was run (if the marker exists):
```bash
cat ~/.claude/.last-eod-marker 2>/dev/null || echo "No previous marker found"
```

## Step 2 — Gather session memory files from today

Search across all project session memory locations for files modified today:
```bash
find ~/.claude/projects -name "summary.md" -newer ~/.claude/projects -newer /tmp -newer ~/.claude/.last-eod-marker 2>/dev/null | head -50
```

If the marker doesn't exist, fall back to files modified in the last 24 hours:
```bash
find ~/.claude/projects -name "summary.md" -mtime -1 2>/dev/null | head -50
find ~/.claude/session-memory -name "*.md" -mtime -1 2>/dev/null | head -50
```

Read every file found. Don't summarise yet — just collect.

## Step 3 — Gather git activity across known repos

Check git logs from today across my known codebases:
```bash
for repo in ~/git/drains ~/git/puppet; do
  if [ -d "$repo/.git" ]; then
    echo "=== $repo ==="
    git -C "$repo" log --since="6am today" --oneline --all --author="$(git -C $repo config user.email)" 2>/dev/null || echo "(no commits)"
  fi
done
```

Also check for any PRs or issues touched today:
```bash
gh pr list --author @me --updated=">=$(date +%Y-%m-%d)" --state all --json number,title,state,url 2>/dev/null
gh issue list --assignee @me --updated=">=$(date +%Y-%m-%d)" --json number,title,state,url 2>/dev/null
```

Note: `gh` commands may need to be run from within a repo — if they fail, try from `~/git/drains` first.

## Step 4 — Synthesise what was done

From everything gathered, produce a clear picture of the day:

- **What was worked on** — grouped by project/repo, not by session
- **What was completed** — anything merged, deployed, closed
- **What's in progress** — PRs open, tickets being worked on
- **What's blocked or waiting** — anything waiting on review, QA, someone else
- **Any risks or things to flag** — deployment concerns, things that need a decision, anything that could bite someone later

Be honest about gaps — if the session memory is thin for part of the day (e.g. sysadmin work done without Claude), note that and ask me to fill in anything missing before drafting the boss update.

## Step 5 — Ask me to fill in gaps

Say something like:

> "Here's what I can see from today. Before I draft your boss update, is there anything I've missed — things you did without me, conversations, decisions made, fires fought?"

Give me a chance to add context. This is important — sysadmin firefighting and Slack conversations won't be in the session memory.

## Step 6 — Draft the boss update

Once the picture is complete, draft a brief update email/message suitable for sending to my boss. It should be:

- **Short** — a few bullet points, not an essay
- **Outcome-focused** — what moved forward, not a blow-by-blow of what I did
- **Honest about blockers** — if something is waiting on someone else, say so clearly
- **Forward-looking** — one line on what's next / planned for tomorrow

Format it as something I can copy-paste or lightly edit, not a formal email — my boss and I communicate fairly informally.

Ask me to confirm before finalising: "Does this capture the day accurately, or anything to tweak?"

## Step 7 — Mental unload prompt

After the boss update is sorted, ask:

> "Is there anything still bouncing around in your head that you're worried about dropping — anything that needs to be written down before you close the laptop?"

If I mention anything, help me capture it — either as a GitHub issue comment, a note in the relevant ticket, or a quick TODO in a worklog file. The goal is that nothing important lives only in my head overnight.

## Step 8 — Update the EOD marker

Once done, update the timestamp marker so tomorrow's run knows where today ended:
```bash
date -Iseconds > ~/.claude/.last-eod-marker
```

Tell me it's done and wish me a good evening. I've earned it.
