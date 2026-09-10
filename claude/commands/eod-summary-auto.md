Generate an end-of-day summary of everything I worked on today and email me a DRAFT boss-update, ready for me to eyeball, tweak and forward to Leo.

This is the UNATTENDED, scheduled sibling of `/eod-summary`. It runs from cron with no human present, so **do not ask any questions and do not wait for input** — gather, draft, and send in one pass.

## Step 1 — Gather the day's activity

Run the fetch script (one whitelisted Bash call) and parse its JSON:

```bash
~/.claude/scripts/eod-summary-auto-fetch.sh
```

It returns: `today`, `user`, `git_commits` (per repo), `prs`, `issues`, `claude_activity` (my typed prompts today, grouped by project/worktree) and `session_summaries`. If `EOD_DATE` is set in the environment, everything is gathered for that day instead of today (used for dry-runs).

Read any `session_summaries` paths for extra context. Don't summarise yet — collect first.

## Step 2 — Synthesise what was done

From everything gathered, build an honest picture of the day, grouped by project/ticket (not by session):

- **What moved forward** — features, fixes, investigations, infra work
- **What completed** — anything merged, deployed, closed
- **What's in progress / waiting** — open PRs, tickets mid-flight, anything blocked on review/QA/someone else
- **Anything to flag** — deployment concerns, decisions needed, risks

Lean on the git commits and PR/issue titles for *what shipped*, and on `claude_activity` for *what I was working on and thinking about* — but summarise the substance, never quote my raw prompts or paste transcript noise.

## Step 3 — Draft the boss update

Write a brief update suitable for forwarding to my boss, Leo. It must be:

- **Short** — a handful of bullets grouped by project, not an essay
- **Outcome-focused** — what moved forward, not a blow-by-blow
- **Honest about blockers** — if something waits on someone else, say so
- **Forward-looking** — one line on what's next

Leo and I communicate informally, so keep it plain and human — no corporate flannel.

## Step 4 — Email the draft to me (only me)

Send it to **david.precious@kaarbontech.co.uk** and NOBODY else. It is a draft for me to review — never send anything to Leo directly.

Top the body with a clear banner so a half-baked draft can't be mistaken for a finished one, then the draft, then a short footer reminding me what's missing:

```bash
mail -s "EOD draft [<today>] — review before sending to Leo" david.precious@kaarbontech.co.uk <<'EOF'
========================================================
  AUTO-GENERATED DRAFT — review before forwarding to Leo
  Built from today's GitHub + Claude Code activity.
  It cannot see work done off-Claude (Slack, meetings,
  sysadmin firefighting, phone calls) — add those yourself.
========================================================

<the boss-update draft>

--
Add anything I missed, then forward to Leo. Reply to nobody — this only went to you.
EOF
```

Substitute the real date and the real draft (expand the heredoc content — don't send the literal placeholders).

## Step 5 — Handle a quiet day

If there is genuinely nothing to report (no commits, no PR/issue activity, no Claude conversations today), still send a short email so I know the routine ran:

> Subject: `EOD draft [<today>] — quiet day, nothing detected`
> Body: a one-liner saying no GitHub or Claude activity was detected today, and if I did work off-Claude I should jot it down myself.

## Step 6 — Finish

Print a one-line confirmation of what was sent (this lands in the cron log at `~/.claude/eod-auto.log`, which is the record of each run). Then stop. Do not ask follow-up questions and do not try to write any marker or state file under `~/.claude/` — that directory is write-guarded in unattended runs.
