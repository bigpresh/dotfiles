# Claude Code Workflow Commands

## Why these exist

These commands were built to address some specific working patterns that were causing problems:

- Starting work without fully understanding the spec, leading to rework
- Treating a raised PR as "done" rather than owning work through to deployment
- Losing track of tasks mid-flight, especially across multiple repos and worktrees
- The "I've done my bit" mentality — not chasing review, QA, and deployment over the line
- Foggy-brain days where having discrete, pre-broken-down chunks of work helps enormously
- Ad-hoc sysadmin and other work going unrecorded and disappearing from the EOD picture

The underlying philosophy is: **a piece of work isn't done until it's merged, deployed, and confirmed working** — not when the code is written, not when the PR is raised.

These commands create a lightweight daily ritual: start the day knowing what's on your plate, kick off new work properly, log things as you go, and end the day with a clear head and nothing important living only in your memory.

---

## Commands

### `/project:sod-summary` — Start of day

Run this first thing. It:

- Reads any carry-over actions from the worklog (`~/.claude/worklog.md`)
- Reviews all open PRs — flags any needing review chased, changes requested, or QA assigned
- Pulls your assigned tickets from the KT Main GitHub project board (org: `kaarbontech`, project 111), filtered to active statuses (In Progress, Ready to work on, Review/QA, Blocked)
- Checks recent session memory for context on in-progress work
- Produces a prioritised list of what to focus on today
- Asks if anything else is on your mind before you get heads-down

**Priority order it uses:**
1. PRs with changes requested (unblock your reviewers first)
2. Carry-over worklog actions from previous days
3. In Progress tickets
4. PRs needing a reviewer chase
5. Stale WIP/draft PRs
6. Blocked tickets that may now be unblocked

---

### `/project:ticket-kickoff` — Start a new piece of work

Run this before writing any code on a non-trivial ticket. It:

- Fetches the GitHub issue (pass the issue number, or it'll ask)
- Has a conversation with you about what the ticket is actually asking for — forces you to process the spec rather than skim it
- Flags ambiguities and things to clarify before starting
- Asks explicitly about deployment concerns: backwards compatibility, migrations, ordering dependencies, rollback
- Sanity-checks your implementation plan
- Posts a structured kickoff comment to the GitHub issue with requirements, plan, deployment notes, and a "done when" checklist
- Prompts you to run the plan by someone if the ticket is complex

The goal is to catch misunderstandings before they become wasted days, and to create a paper trail of what was agreed before work started.

---

### `/project:ticket-closeout` — Finish a piece of work properly

Run this when you think you're done — before you mentally move on. It:

- Fetches the issue and the kickoff comment
- Goes through every requirement and confirms it's been addressed
- Checks deployment concerns from the kickoff notes are handled
- Reviews PR status — has it been reviewed? Is CI passing? Has QA signed off?
- Prompts you to chase anything outstanding
- Reminds you that "done" means deployed and confirmed working, not PR raised

---

### `/project:worklog` — Log something quickly

Run this ad-hoc throughout the day to record things that won't show up in git or GitHub — sysadmin work, conversations, decisions made, things you helped with.

```
/project:worklog helped Doug get his SSH key set up
/project:worklog planning chat with Claude about ADHD-addled fuckwittery
/project:worklog investigated slow query on reports page, turned out to be missing index
```

Appends a timestamped entry under today's date in `~/.claude/worklog.md`. The EOD and SOD commands read this file, so these notes feed into your daily summary automatically.

---

### `/project:eod-summary` — End of day

Run this before closing the laptop. It:

- Reads session memory from all projects worked on today (across `~/.claude/projects/`)
- Checks git activity across all known repos and worktrees (`~/git/drains`, `~/git/puppet`)
- Pulls today's GitHub activity feed (commits pushed, PRs opened/reviewed, issue comments) across all repos
- Reads the worklog for anything logged during the day
- Asks you to fill in anything that's missing before drafting anything
- Drafts a brief, informal boss update — outcome-focused, honest about blockers, one line on tomorrow
- Asks if anything is still bouncing around in your head — captures it in the worklog so it's not lost overnight
- Updates `~/.claude/.last-eod-marker` so tomorrow's session knows where today ended

---

## Dependencies

These commands require the following to be installed and authenticated:

- **`gh` CLI** — `apt install gh`, then `gh auth login`
  - Requires scopes: `repo`, `read:org`, `read:project`
  - To add `read:project` to an existing token: `gh auth refresh --scopes read:project`
- **`jq`** — `apt install jq`
- **`git`** — already installed, but ensure `user.email` is configured in each repo

## Worklog file

The shared worklog lives at `~/.claude/worklog.md` — outside any specific repo so it's always accessible regardless of working directory. It's plain markdown, human-readable, and safe to edit manually. Format:

```markdown
## 2026-03-19

- [ ] Chase Dave for review on PR #12353
- helped Doug get his SSH key set up
- had planning chat about workflow improvements
```

`- [ ]` items are carry-over actions (surfaced by SOD). Plain `-` items are notes and log entries.
