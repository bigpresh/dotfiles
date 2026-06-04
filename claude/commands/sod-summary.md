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
- `open_prs` — `gh pr list --author @me --state open` payload (PRs I authored)
- `pr_details` — map keyed by PR number, with `mergeable`, `mergeStateStatus`, `reviewRequests`, `reviews`
- `review_requests` — open PRs across all kaarbontech repos requesting my review (PRs I should review)
- `project_board` — items on the KT Main board assigned to me, filtered to active (non-Done) statuses
- `stale_issues` — top 5 open issues assigned to me that look like candidates for "is this actually done?" triage (already filtered for snoozed and recently-updated; scored by board status + activity pattern)
- `snooze_file` — path to the JSON file storing snooze decisions (`~/.claude/sod-issue-snooze.json`)

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

## Step 2b — PRs awaiting my review

From `review_requests`, surface any PRs that need my attention. These are quick-win, "drink-your-coffee" tasks — colleagues are blocked waiting on me, so unblocking them is high-leverage.

- **Non-draft PRs** — list each one with author, repo, title, age (compute from `updatedAt`). Flag anything older than 2 business days as needing review *today*.
- **Draft PRs** — usually noise (the author isn't really ready). Mention them briefly *only* if they've been requesting review for more than a week, as a candidate for asking the author whether the request can be dropped. Don't surface fresh draft requests at all.
- If `review_requests` is empty, just say "No PRs awaiting your review." and move on — no need to dwell.

These slot into the priority list at position 2 (after changes-requested PRs on my own work, before in-progress tickets) — see Step 5.

## Step 3 — Check the project board

From `project_board`, group and prioritise (the script already filters out `Done` and `Done in branch`):

- **In Progress** — primary focus, what I'm actively doing
- **Ready to work on** — queued and ready, show after In Progress
- **Review/QA** — flag any that have been in this status for more than two business days without movement; prompt me to chase
- **Blocked** — for anything blocked more than two business days, ask whether the blocker is resolved; if so, help move it to In Progress

If a ticket has a date/deadline in its title or labels and that date has passed, **flag it loudly** — overdue items are the easiest thing for me to lose track of.

## Step 3b — Stale-issue triage

From `stale_issues`, present each candidate one at a time for a quick triage decision. These are open issues assigned to me with no recent activity — likely candidates for "done but never closed", or "actually still open?" check-ins. The script has already excluded snoozed and recently-updated issues, so anything here genuinely deserves a glance.

**Don't dump all five at once.** Present them sequentially, with a one-liner and the URL, and ask for a decision per issue. Format:

> **Issue #N** — "title" (repo, X days since update, on-board: yes/no, Y comments)
>     URL
> Decision: **Close** (looks done) / **Snooze 1 week** / **Snooze 2 weeks** / **Snooze until... / Still working on it** / **Skip — open it in a tab**

Use `AskUserQuestion` with the five common options. Default snooze is **1 week**.

**Acting on the decision:**

- **Close** — run `gh issue close <number> --repo <owner/repo> --comment "<optional comment>"`. Ask me whether to add a comment first if there's no obvious linked PR explaining the resolution.
- **Snooze N weeks / until DATE** — update the snooze file. Read it, add/replace the entry for the issue URL, write it back. Schema:
  ```json
  {
    "https://github.com/kaarbontech/drains/issues/12345": {
      "until": "2026-06-01",
      "reason": "<short note, optional>"
    }
  }
  ```
  Use the `snooze_file` path from the JSON output. Always preserve other entries when writing.
- **Still working on it** — equivalent to "snooze 1 week" with reason "in progress".
- **Skip — open in a tab** — print the URL for me to open manually, take no other action.

**Stop after the user has triaged all five, or says they're done with triage.** Don't loop forever. If a user says "enough for today", stop and continue to the rest of the SOD summary.

This triage is interactive — slot it in **after** the priority list in Step 5, as a "coffee triage" section the user can choose to engage with or skip. Don't block the morning summary on completing it.

## Step 4 — Check recent session memory

From `session_summaries`, optionally Read any paths whose filename or directory hint at the in-progress tickets, to pick up context on where things were left off. Don't read them all reflexively — only if a summary path looks relevant.

## Step 5 — Today's priority list

Produce a clear, ordered list of what to work on today. Strict priority order:

1. **PRs with changes requested** — unblock my reviewers first, this is always top priority
2. **PRs awaiting my review** (from `review_requests`, non-draft) — colleagues are blocked on me, these are usually quick wins, do them early
3. **Carry-over worklog actions** — unchecked items from previous days that are still relevant
4. **In Progress tickets** — ordered by priority/board order; flag overdue ones at the top
5. **PRs needing a reviewer chase** — these are quick, do them early
6. **Stale WIP/draft PRs** — need a status update or decision (skipping legitimate hold-for-deploy ones)
7. **Blocked tickets to re-check** — anything that might now be unblocked

**Format:** Each item must be followed by the GitHub URL on the next line, indented to match the item text (don't put it on the same line — long URLs wrap badly in my terminal). Use the `url` field from the JSON. Example:

> 1. **Decide & merge PR #12914** — draft+approved is ambiguous, resolve it.
>    https://github.com/kaarbontech/drains/pull/12914

Flag anything time-sensitive or risky prominently above the numbered list.

## Step 5b — Coffee triage (stale assigned issues)

After the priority list, if `stale_issues` is non-empty, offer the triage from Step 3b:

> "While you're drinking your coffee — N stale assigned issues worth a quick look. Want to triage them now, or skip for today?"

Only proceed if the user agrees. If they decline, just note the count and move on. If they agree, walk through them one at a time using `AskUserQuestion` per issue, acting on each decision before moving to the next. Stop as soon as the user says they've had enough or all are done.

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
