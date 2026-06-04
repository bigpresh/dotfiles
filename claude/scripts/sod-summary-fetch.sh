#!/usr/bin/env bash
# Gather everything /sod-summary needs in one go and emit a single JSON document.
#
# Why a single script: each gh / find / cat call would otherwise need its own
# permission prompt, and waiting between them is ADHD hell. One script = one
# (whitelisted) prompt; fetches run in parallel for speed.
#
# Output shape (stdout, JSON):
#   {
#     today, user, worklog,
#     session_summaries: ["<path>", ...],
#     open_prs: [...],         # gh pr list payload (PRs I authored)
#     pr_details: { "<num>": { mergeable, mergeStateStatus, reviewRequests, reviews } },
#     review_requests: [...],  # open PRs across all repos requesting my review
#     project_board: [...],    # filtered to my non-Done items
#     stale_issues: [...],     # top candidates for "is this actually done?" triage (top 5,
#                              # scored, excludes recently-updated and currently-snoozed)
#     snooze_file: "<path>"    # path to ~/.claude/sod-issue-snooze.json for the skill to update
#   }
#
# Snooze file: ~/.claude/sod-issue-snooze.json — map of issue URL -> { until: "YYYY-MM-DD",
# reason: "..." }. Issues with `until` >= today are filtered out of stale_issues. The skill
# (not this script) updates the file in response to user triage decisions.

set -uo pipefail

PROJECT_NODE_ID="PVT_kwDOA5JC8M4AxdEl"   # KT Main project board
SNOOZE_FILE="$HOME/.claude/sod-issue-snooze.json"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Sane defaults so jq assembly never trips on a missing/empty fetch.
: > "$TMPDIR/worklog.txt"
: > "$TMPDIR/sessions.txt"
: > "$TMPDIR/user.txt"
echo '[]' > "$TMPDIR/prs.json"
echo '[]' > "$TMPDIR/review_requests.json"
echo '[]' > "$TMPDIR/assigned_issues.json"
echo '{"data":{"node":{"items":{"nodes":[]}}}}' > "$TMPDIR/board.json"

(
  if [[ -f "$HOME/.claude/worklog.md" ]]; then
    cat "$HOME/.claude/worklog.md" > "$TMPDIR/worklog.txt"
  fi
) &

(
  find "$HOME/.claude/projects" -name "summary.md" -mtime -3 2>/dev/null \
    > "$TMPDIR/sessions.txt" || true
) &

(
  gh api /user --jq .login 2>/dev/null > "$TMPDIR/user.txt" || true
) &

(
  gh pr list --author @me --state open \
    --json number,title,isDraft,reviewDecision,createdAt,updatedAt,url,labels,reviewRequests \
    > "$TMPDIR/prs.json" 2>/dev/null \
    || echo '[]' > "$TMPDIR/prs.json"
) &

(
  # Open PRs across all kaarbontech repos requesting my review.
  # `gh search prs` covers all repos in one call (faster than per-repo iteration).
  gh search prs --review-requested=@me --state=open \
    --json number,title,author,url,repository,updatedAt,createdAt,isDraft \
    > "$TMPDIR/review_requests.json" 2>/dev/null \
    || echo '[]' > "$TMPDIR/review_requests.json"
) &

(
  # All open issues assigned to me — used to surface stale candidates that may already
  # be done but never closed. We pull commentsCount as a cheap "has anything happened
  # here?" signal alongside updatedAt.
  gh search issues --assignee=@me --state=open --limit=100 \
    --json number,title,url,repository,createdAt,updatedAt,labels,commentsCount \
    > "$TMPDIR/assigned_issues.json" 2>/dev/null \
    || echo '[]' > "$TMPDIR/assigned_issues.json"
) &

(
  gh api graphql -f query='
query {
  node(id: "'"$PROJECT_NODE_ID"'") {
    ... on ProjectV2 {
      items(first: 100) {
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
}' > "$TMPDIR/board.json" 2>/dev/null || true
) &

wait

# Per-PR detail in parallel (depends on prs.json being ready).
PR_NUMBERS=$(jq -r '.[].number' "$TMPDIR/prs.json" 2>/dev/null || true)
mkdir -p "$TMPDIR/pr_details"
for pr in $PR_NUMBERS; do
  (
    gh pr view "$pr" \
      --json mergeable,mergeStateStatus,reviewRequests,reviews \
      > "$TMPDIR/pr_details/$pr.json" 2>/dev/null || true
  ) &
done
wait

USER_LOGIN=$(cat "$TMPDIR/user.txt")

# Filter the project board to my active (non-Done) items, flattening shape.
BOARD_FILTERED=$(jq --arg user "$USER_LOGIN" '
  [ (.data.node.items.nodes // [])[]
    | select(.content != null)
    | select(((.content.assignees.nodes // []) | map(.login) | index($user)) != null)
    | . as $item
    | {
        number: .content.number,
        title:  .content.title,
        url:    .content.url,
        status: (($item.fieldValues.nodes // [])[]? | select(.field.name == "Status") | .name),
        labels: [(.content.labels.nodes // [])[].name]
      }
    | select(.status != null and .status != "Done" and .status != "Done in branch")
  ]' "$TMPDIR/board.json" 2>/dev/null || echo '[]')

# Build pr_details map keyed by PR number string.
PR_DETAILS='{}'
for pr in $PR_NUMBERS; do
  if [[ -s "$TMPDIR/pr_details/$pr.json" ]]; then
    PR_DETAILS=$(jq --arg n "$pr" --slurpfile d "$TMPDIR/pr_details/$pr.json" \
      '. + {($n): $d[0]}' <<<"$PR_DETAILS")
  fi
done

# Load snooze map (defaults to empty object if missing/invalid).
if [[ -s "$SNOOZE_FILE" ]] && jq -e . "$SNOOZE_FILE" >/dev/null 2>&1; then
  SNOOZE_JSON=$(cat "$SNOOZE_FILE")
else
  SNOOZE_JSON='{}'
fi

# Score and rank stale issues. Drop currently-snoozed and recently-updated ones,
# then score by board status + activity-then-stalled and return top 5.
# Scoring:
#   +3  on project board as "In Progress"
#   +2  last activity 14-90 days ago (stalled-after-activity sweet spot)
#   +1  has any comments (someone engaged with it at some point)
#   -1  very old (>365 days) with no recent activity — probably needs different handling
STALE_ISSUES=$(jq --argjson snooze "$SNOOZE_JSON" \
                  --argjson board "$BOARD_FILTERED" \
                  --arg today "$(date +%Y-%m-%d)" '
  def days_since(d): ((now - (d | fromdateiso8601)) / 86400);
  ($board | map(select(.status == "In Progress") | .url)) as $in_progress_urls
  | [ .[]
      | . as $i
      # Skip recently-updated (<14 days) — probably in flight.
      | select(days_since($i.updatedAt) >= 14)
      # Skip currently-snoozed: snooze entry with `until` >= today.
      | select(
          ($snooze[$i.url] // null) == null
          or ($snooze[$i.url].until // "0000-00-00") < $today
        )
      | . + {
          days_since_update: (days_since($i.updatedAt) | floor),
          on_board_in_progress: (($in_progress_urls | index($i.url)) != null),
          score: (
            (if ($in_progress_urls | index($i.url)) then 3 else 0 end)
            + (if (days_since($i.updatedAt) >= 14 and days_since($i.updatedAt) <= 90) then 2 else 0 end)
            + (if ($i.commentsCount // 0) > 0 then 1 else 0 end)
            + (if days_since($i.updatedAt) > 365 then -1 else 0 end)
          )
        }
    ]
  | sort_by(-.score, .updatedAt)
  | .[0:5]
' "$TMPDIR/assigned_issues.json" 2>/dev/null || echo '[]')

jq -n \
  --arg today "$(date +%Y-%m-%d)" \
  --arg user "$USER_LOGIN" \
  --arg snooze_file "$SNOOZE_FILE" \
  --rawfile worklog "$TMPDIR/worklog.txt" \
  --rawfile sessions "$TMPDIR/sessions.txt" \
  --slurpfile prs "$TMPDIR/prs.json" \
  --slurpfile review_requests "$TMPDIR/review_requests.json" \
  --argjson board "$BOARD_FILTERED" \
  --argjson pr_details "$PR_DETAILS" \
  --argjson stale_issues "$STALE_ISSUES" \
  '{
    today: $today,
    user: $user,
    worklog: $worklog,
    session_summaries: ($sessions | split("\n") | map(select(length > 0))),
    open_prs: $prs[0],
    pr_details: $pr_details,
    review_requests: $review_requests[0],
    project_board: $board,
    stale_issues: $stale_issues,
    snooze_file: $snooze_file
  }'
