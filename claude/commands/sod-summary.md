Start my day by reviewing outstanding work, open PRs, and today's priorities. Be direct — if something needs chasing or a decision, say so clearly. Don't let me gloss over things.

## Step 0 — Gather everything in one go

Run the fetch script. It runs all the `gh` calls, worklog read, project-board query, and per-PR detail fetches in parallel and emits a single JSON document. One permission prompt, ~3 seconds, no waiting between sub-prompts.

```bash
~/.claude/scripts/sod-summary-fetch.sh
```

The output JSON has these top-level keys:

- `today` — today's date (YYYY-MM-DD)
- `user` — my GitHub login
- `worklog` — full text of `~/.claude/worklog.md` (or empty)
- `session_summaries` — paths of `summary.md` files modified in the last 3 days
- `open_prs` — `gh pr list --author @me --state open` payload
- `pr_details` — map keyed by PR number, with `mergeable`, `mergeStateStatus`, `reviewRequests`, `reviews`
- `project_board` — items on the KT Main board assigned to me, filtered to active (non-Done) statuses

Use this JSON for everything below. Only fetch extra data if something is genuinely missing — don't re-run individual `gh` commands that the script already covered.

## Step 1 — Worklog carry-over

From `worklog`, find any `- [ ]` unchecked items from previous days (anything before today's date heading). Surface these — they're carry-over actions that need a decision: done, still relevant, or can be dropped?

Don't action them yet — hold them for the priority list in Step 5.

## Step 2 — Review open pull requests

From `open_prs` and `pr_details`, work through each PR:

**Drafts and WIP (title contains "WIP:"):**
- Note these separately — ask me for status on any that haven't had a commit or comment in more than two business days
- If stale, help me update the linked issue status to "Blocked" if appropriate
- **Draft + already approved is not necessarily wrong** — it often means the change is reviewed and ready, but waiting on something external (e.g. an OS/dependency upgrade gating deployment). Check the linked issue body before flagging it as a problem.

**All other open PRs:**
- No reviewer assigned (check the `reviewRequests` field in the PR list payload, not `assignees` — empty `reviewRequests` means no reviewer has been requested) → flag immediately, this needs fixing now
- Reviewer assigned but no review after two business days → prompt me to chase or add another reviewer
- Changes requested → top priority, flag prominently in Step 5
- Approved but not merged:
  - Is QA needed? For simple/low-risk changes, confirm it's been tested and suggest merging
  - For anything more complex, prompt me to assign to QA if not already done
  - Check whether there are deployment concerns (migration, ordering, backwards compat) before suggesting merge
- `mergeStateStatus` of `BLOCKED` usually means missing review/CI — investigate before suggesting merge
- `mergeable: CONFLICTING` → flag it, I need to rebase

## Step 3 — Check the project board

From `project_board`, group and prioritise (the script already filters out `Done` and `Done in branch`):

- **In Progress** — primary focus, what I'm actively doing
- **Ready to work on** — queued and ready, show after In Progress
- **Review/QA** — flag any that have been in this status for more than two business days without movement; prompt me to chase
- **Blocked** — for anything blocked more than two business days, ask whether the blocker is resolved; if so, help move it to In Progress

If a ticket has a date/deadline in its title or labels and that date has passed, **flag it loudly** — overdue items are the easiest thing for me to lose track of.

## Step 4 — Check recent session memory

From `session_summaries`, optionally Read any paths whose filename or directory hint at the in-progress tickets, to pick up context on where things were left off. Don't read them all reflexively — only if a summary path looks relevant.

## Step 5 — Today's priority list

Produce a clear, ordered list of what to work on today. Strict priority order:

1. **PRs with changes requested** — unblock my reviewers first, this is always top priority
2. **Carry-over worklog actions** — unchecked items from previous days that are still relevant
3. **In Progress tickets** — ordered by priority/board order; flag overdue ones at the top
4. **PRs needing a reviewer chase** — these are quick, do them early
5. **Stale WIP/draft PRs** — need a status update or decision (skipping legitimate hold-for-deploy ones)
6. **Blocked tickets to re-check** — anything that might now be unblocked

**Format:** Each item must be followed by the GitHub URL on the next line, indented to match the item text (don't put it on the same line — long URLs wrap badly in my terminal). Use the `url` field from the JSON. Example:

> 1. **Decide & merge PR #12914** — draft+approved is ambiguous, resolve it.
>    https://github.com/kaarbontech/drains/pull/12914

Flag anything time-sensitive or risky prominently above the numbered list.

## Step 6 — Quick gut-check

Ask:

> "Anything not in the system that's on your mind — conversations from yesterday, things someone mentioned, anything you're vaguely worried about?"

If anything comes up, either add it to the relevant ticket/PR as a comment, or note it in `~/.claude/worklog.md` under today's date.

Then: "Right, you know what you're doing today. Go get it."

## Step 7 — Mark today as planned

Once the summary is complete, write today's date to the marker file. The SessionStart nudge hook reads this to know `/sod-summary` has run today, so it stays quiet for the rest of the day.

```bash
date +%Y-%m-%d > ~/.claude/sod-summary-last-run
```
