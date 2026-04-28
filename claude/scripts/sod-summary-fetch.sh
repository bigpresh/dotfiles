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
#     open_prs: [...],         # gh pr list payload
#     pr_details: { "<num>": { mergeable, mergeStateStatus, reviewRequests, reviews } },
#     project_board: [...]     # filtered to my non-Done items
#   }

set -uo pipefail

PROJECT_NODE_ID="PVT_kwDOA5JC8M4AxdEl"   # KT Main project board

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Sane defaults so jq assembly never trips on a missing/empty fetch.
: > "$TMPDIR/worklog.txt"
: > "$TMPDIR/sessions.txt"
: > "$TMPDIR/user.txt"
echo '[]' > "$TMPDIR/prs.json"
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

jq -n \
  --arg today "$(date +%Y-%m-%d)" \
  --arg user "$USER_LOGIN" \
  --rawfile worklog "$TMPDIR/worklog.txt" \
  --rawfile sessions "$TMPDIR/sessions.txt" \
  --slurpfile prs "$TMPDIR/prs.json" \
  --argjson board "$BOARD_FILTERED" \
  --argjson pr_details "$PR_DETAILS" \
  '{
    today: $today,
    user: $user,
    worklog: $worklog,
    session_summaries: ($sessions | split("\n") | map(select(length > 0))),
    open_prs: $prs[0],
    pr_details: $pr_details,
    project_board: $board
  }'
