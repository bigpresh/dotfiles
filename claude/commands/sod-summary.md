Start my day by reviewing outstanding work, open PRs, and today's priorities. Be direct — if something needs chasing or a decision, say so clearly. Don't let me gloss over things.

## Step 0 — Read the worklog

Read `~/.claude/worklog.md` if it exists:
```bash
cat ~/.claude/worklog.md 2>/dev/null || echo "No worklog found"
```

Find any `- [ ]` unchecked items from previous days (anything before today's date heading). Surface these — they're carry-over actions that need a decision: done, still relevant, or can be dropped?

Don't action them yet — hold them for the summary in Step 4.

## Step 1 — Review open pull requests

```bash
GH_USER=$(gh api /user --jq .login)
gh api /users/$GH_USER/events 2>/dev/null | head -1 # confirms auth works
gh pr list --author @me --state open --json number,title,isDraft,reviewDecision,createdAt,assignees,url,labels
```

Work through each PR:

**Drafts and WIP (title contains "WIP:"):**
- Note these separately — ask me for status on any that haven't had a commit or comment in more than two business days
- If stale, help me update the linked issue status to "Blocked" if appropriate

**All other open PRs:**
- No reviewer assigned → flag immediately, this needs fixing now
- Reviewer assigned but no review after two business days → prompt me to chase or add another reviewer
- Changes requested → this is top priority, flag it prominently in Step 4
- Approved but not merged:
  - Is QA needed? For simple/low-risk changes, confirm it's been tested and suggest merging
  - For anything more complex, prompt me to assign to QA if not already done
  - Check whether there are deployment concerns (migration, ordering, backwards compat) before suggesting merge

## Step 2 — Check the project board

Fetch tickets assigned to me on the KT Main board (project ID 111):
```bash
GH_USER=$(gh api /user --jq .login)
gh api graphql -f query='
query {
  node(id: "PVT_kwDOA5JC8M4AxdEl") {
    ... on ProjectV2 {
      items(first: 50) {
        nodes {
          content {
            ... on Issue {
              number
              title
              url
              assignees(first: 5) { nodes { login } }
              labels(first: 5) { nodes { name } }
            }
          }
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
            }
          }
        }
      }
    }
  }
}' | jq --arg user "$GH_USER" '
  .data.node.items.nodes[] |
  select(.content.assignees.nodes[].login == $user) |
  . as $item |
  ($item.fieldValues.nodes[] | select(.field.name == "Status") | .name) as $status |
  select($status != "Done" and $status != "Done in branch" and $status != null) |
  {
    number: $item.content.number,
    title: $item.content.title,
    url: $item.content.url,
    status: $status,
    labels: [$item.content.labels.nodes[].name]
  }
'
```

This produces clean objects with `number`, `title`, `url`, `status`, and `labels` for each active ticket. Use the `status` field to group and prioritise: `In Progress` first, then `Review/QA`, then `Blocked`, then anything else. Ignore `Done` and `Done in branch` entirely.

From the board results, filter to tickets assigned to me. Group and prioritise as follows — ignore `Done` and `Done in branch` entirely:

- **In Progress** — primary focus, these are what you're actively doing
- **Ready to work on** — queued and ready, show after In Progress
- **Review/QA** — flag any that have been in this status for more than two business days without movement; prompt me to chase
- **Blocked** — for anything blocked more than two business days, ask whether the blocker is resolved; if so, help move it to In Progress

## Step 3 — Check recent session memory

Look for session memory files updated in the last couple of days that might have relevant context on in-progress work:
```bash
find ~/.claude/projects -name "summary.md" -mtime -2 2>/dev/null | head -20
```

Read any that seem relevant to the in-progress tickets. This gives context on where things were left off without needing to re-explain everything.

## Step 4 — Today's priority list

Produce a clear, ordered list of what to work on today. Strict priority order:

1. **PRs with changes requested** — unblock your reviewers first, this is always top priority
2. **Carry-over worklog actions** — unchecked items from previous days that are still relevant
3. **In Progress tickets** — ordered by priority/board order
4. **PRs needing a reviewer chase** — these are quick, do them early
5. **Stale WIP/draft PRs** — need a status update or decision
6. **Blocked tickets to re-check** — anything that might now be unblocked

Format this as a clean list I can refer back to during the day, with ticket/PR numbers and links. Flag anything time-sensitive or risky prominently.

## Step 5 — Quick gut-check

Before wrapping up, ask:

> "Anything not in the system that's on your mind — conversations from yesterday, things someone mentioned, anything you're vaguely worried about?"

If anything comes up, either add it to the relevant ticket/PR as a comment, or note it in `~/.claude/worklog.md` under today's date.

Then: "Right, you know what you're doing today. Go get it."
