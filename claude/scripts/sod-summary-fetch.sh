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
#     pr_details: { "<num>": { mergeable, mergeStateStatus, reviewRequests, reviews,
#                              last_comments, pending_reviews,
#                              longest_wait_days } },
#                              # last_comments = up to the 3 most recent issue-style comments
#                              # (author/createdAt/body) so the summary can see how the
#                              # discussion was left — e.g. a CHANGES_REQUESTED review that
#                              # the author has already answered is Reuben's ball, not mine.
#                              # pending_reviews / longest_wait_days: see "Review clocks" below.
#     review_requests: [...],  # open PRs across all repos requesting my review, each annotated
#                              # with my_review_requested_at / days_waiting_on_me
#     project_board: [...],    # filtered to my non-Done items
#     stale_issues: [...],     # top candidates for "is this actually done?" triage (top 5,
#                              # scored, excludes recently-updated and currently-snoozed)
#     snooze_file: "<path>"    # path to ~/.claude/sod-issue-snooze.json for the skill to update
#   }
#
# Snooze file: ~/.claude/sod-issue-snooze.json — map of issue URL -> { until: "YYYY-MM-DD",
# reason: "..." }. Issues with `until` >= today are filtered out of stale_issues. The skill
# (not this script) updates the file in response to user triage decisions.
#
# Review clocks: "how long has this been waiting for review?" must be measured from the
# moment the review was REQUESTED, never from the PR's createdAt. A PR can sit for a week
# with no reviewer and then get one this morning — reading createdAt turns a same-day
# request into a bogus "7 days, go and chase them". The GitHub PR/search payloads carry no
# request timestamp at all (reviewRequests is a bare login list), so we walk the issue
# timeline per PR and reduce review_requested / review_request_removed events into the
# current pending-request state. Re-requesting a review after changes emits a fresh
# review_requested, so the latest event per reviewer is correctly "when the ball went back
# to them". Where no event can be found we fall back to createdAt and flag it
# (requested_at_is_fallback: true) so a guess is never mistaken for a measurement.

set -uo pipefail

PROJECT_NODE_ID="PVT_kwDOA5JC8M4AxdEl"   # KT Main project board
SNOOZE_FILE="$HOME/.claude/sod-issue-snooze.json"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Emit the review-request/removal events for one PR as ndjson to $3.
# $1 = owner/repo (or "{owner}/{repo}" to let gh resolve the cwd repo), $2 = PR number.
# Teams have a null requested_reviewer, so fall back to the team name.
fetch_review_events() {
  gh api "repos/$1/issues/$2/timeline" --paginate \
    --jq '.[]
          | select(.event == "review_requested" or .event == "review_request_removed")
          | {event, created_at,
             reviewer: (.requested_reviewer.login // .requested_team.name // "unknown")}' \
    > "$3" 2>/dev/null || : > "$3"
}

# Sane defaults so jq assembly never trips on a missing/empty fetch.
: > "$TMPDIR/worklog.txt"
: > "$TMPDIR/sessions.txt"
: > "$TMPDIR/user.txt"
echo '[]' > "$TMPDIR/prs.json"
echo '[]' > "$TMPDIR/review_requests.json"
echo '[]' > "$TMPDIR/assigned_issues.json"
: > "$TMPDIR/board_nodes.ndjson"

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
  # The board holds ~1000 items and GraphQL caps pages at 100, so walk the
  # cursor until exhausted (bounded at 20 pages as a runaway guard), appending
  # each page's item nodes to an ndjson stream. Failures warn on stderr rather
  # than being swallowed: an empty/partial board should look like an error,
  # not like "nothing assigned to you".
  cursor=""
  for page in $(seq 1 20); do
    after=""
    [[ -n "$cursor" ]] && after=', after: "'"$cursor"'"'
    resp=$(gh api graphql -f query='
query {
  node(id: "'"$PROJECT_NODE_ID"'") {
    ... on ProjectV2 {
      items(first: 100'"$after"') {
        pageInfo { hasNextPage endCursor }
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
}') || {
      echo "sod-summary-fetch: board page $page fetch failed — project_board will be incomplete" >&2
      break
    }
    echo "$resp" | jq -c '.data.node.items.nodes[]' >> "$TMPDIR/board_nodes.ndjson"
    hasNext=$(echo "$resp" | jq -r '.data.node.items.pageInfo.hasNextPage')
    cursor=$(echo "$resp" | jq -r '.data.node.items.pageInfo.endCursor')
    [[ "$hasNext" == "true" ]] || break
    if [[ "$page" -eq 20 ]]; then
      echo "sod-summary-fetch: board has >2000 items — project_board truncated at 20 pages" >&2
    fi
  done
) &

wait

# Per-PR detail in parallel (depends on prs.json being ready).
PR_NUMBERS=$(jq -r '.[].number' "$TMPDIR/prs.json" 2>/dev/null || true)
mkdir -p "$TMPDIR/pr_details" "$TMPDIR/pr_timeline" "$TMPDIR/rr_timeline"
for pr in $PR_NUMBERS; do
  (
    gh pr view "$pr" \
      --json mergeable,mergeStateStatus,reviewRequests,reviews,comments \
      > "$TMPDIR/pr_details/$pr.json" 2>/dev/null || true
  ) &
  ( fetch_review_events '{owner}/{repo}' "$pr" "$TMPDIR/pr_timeline/$pr.ndjson" ) &
done

# Same treatment for PRs awaiting MY review — these are cross-repo, so pass an explicit
# owner/repo. Keyed by repo+number to avoid number collisions between repos.
while IFS=$'\t' read -r rr_repo rr_num; do
  [[ -n "$rr_repo" && -n "$rr_num" ]] || continue
  ( fetch_review_events "$rr_repo" "$rr_num" \
      "$TMPDIR/rr_timeline/${rr_repo//\//_}#${rr_num}.ndjson" ) &
done < <(jq -r '.[] | [(.repository.nameWithOwner // .repository.name), .number]
                     | @tsv' "$TMPDIR/review_requests.json" 2>/dev/null || true)
wait

USER_LOGIN=$(cat "$TMPDIR/user.txt")

# Filter the project board to my active (non-Done) items, flattening shape.
# -s slurps the ndjson stream of item nodes into one array (empty file -> []).
BOARD_FILTERED=$(jq -s --arg user "$USER_LOGIN" '
  [ .[]
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
  ]' "$TMPDIR/board_nodes.ndjson" 2>/dev/null || echo '[]')

# jq prelude shared by every "how long has this been waiting?" calculation.
#   pending_requests  — reduce a chronological review_requested/review_request_removed
#                       stream into { reviewer: <when the ball last went to them> }.
#                       A later removal deletes the entry; a re-request overwrites it.
#   business_days_since — David's chase thresholds are all "two business days", so a raw
#                       calendar count over a weekend would cry wolf every Monday.
JQ_PRELUDE='
  def pending_requests:
    reduce .[] as $e ({};
      if $e.event == "review_requested" then .[$e.reviewer] = $e.created_at
      elif $e.event == "review_request_removed" then del(.[$e.reviewer])
      else . end);
  def days_waiting($iso):
    (((now - ($iso | fromdateiso8601)) / 86400) | floor);
  # Whole weekdays ELAPSED, deliberately conservative: a request made at 16:00 yesterday
  # reads 0, not 1, because they have not yet had a full day with it. Rounding the other
  # way would manufacture a "chase them" a day early — the exact false alarm this whole
  # review-clock change exists to kill. Do not "fix" this into ceil().
  def business_days_since($iso):
    ($iso | fromdateiso8601) as $start
    | if now <= $start then 0
      else ([ range(0; ((now - $start) / 86400 | floor) + 1)
              | ($start + (. * 86400)) | gmtime | strftime("%u") | tonumber
              | select(. < 6) ] | length - 1) as $n
           | (if $n < 0 then 0 else $n end)
      end;
  def annotate_wait($at; $fallback):
    ($at // $fallback) as $when
    | { requested_at: $when,
        requested_at_is_fallback: ($at == null),
        days_waiting: days_waiting($when),
        business_days_waiting: business_days_since($when) };
'

# Build pr_details map keyed by PR number string. Trim the full comment history
# down to the last 3 (full bodies — the sign-off line is usually the punchline).
# pending_reviews attaches a real requested-at clock to each still-outstanding reviewer,
# and longest_wait_days is the "should I chase?" number the skill thresholds on.
PR_DETAILS='{}'
for pr in $PR_NUMBERS; do
  if [[ -s "$TMPDIR/pr_details/$pr.json" ]]; then
    pr_created=$(jq -r --argjson n "$pr" \
      'map(select(.number == $n)) | .[0].createdAt // empty' "$TMPDIR/prs.json")
    PR_DETAILS=$(jq --arg n "$pr" \
      --arg created "$pr_created" \
      --slurpfile d "$TMPDIR/pr_details/$pr.json" \
      --slurpfile tl "$TMPDIR/pr_timeline/$pr.ndjson" \
      "$JQ_PRELUDE"'
      ($tl | pending_requests) as $req
      | . + {($n): ($d[0]
             | .last_comments = ((.comments // [])[-3:]
                                 | map({author: .author.login, createdAt, body}))
             | del(.comments)
             | .pending_reviews = [ (.reviewRequests // [])[]
                 | ((.login // .name // "unknown")) as $who
                 | { reviewer: $who }
                   + annotate_wait($req[$who]; $created) ]
             | .longest_wait_days =
                 ([ .pending_reviews[].business_days_waiting ] | max))}' <<<"$PR_DETAILS")
  fi
done

# Annotate PRs awaiting MY review with when *my* review was requested, so "colleagues
# blocked on me" is measured from the ask rather than from whenever the PR was opened.
REVIEW_REQUESTS=$(jq '.' "$TMPDIR/review_requests.json" 2>/dev/null || echo '[]')
while IFS=$'\t' read -r rr_repo rr_num; do
  [[ -n "$rr_repo" && -n "$rr_num" ]] || continue
  tl_file="$TMPDIR/rr_timeline/${rr_repo//\//_}#${rr_num}.ndjson"
  [[ -f "$tl_file" ]] || continue
  REVIEW_REQUESTS=$(jq --arg repo "$rr_repo" --argjson num "$rr_num" \
    --arg user "$USER_LOGIN" \
    --slurpfile tl "$tl_file" \
    "$JQ_PRELUDE"'
    ($tl | pending_requests) as $req
    | map(
        if ((.repository.nameWithOwner // .repository.name) == $repo and .number == $num)
        then . + (annotate_wait($req[$user]; .createdAt)
                  | { my_review_requested_at: .requested_at,
                      my_review_requested_at_is_fallback: .requested_at_is_fallback,
                      days_waiting_on_me: .days_waiting,
                      business_days_waiting_on_me: .business_days_waiting })
        else . end)' <<<"$REVIEW_REQUESTS")
done < <(jq -r '.[] | [(.repository.nameWithOwner // .repository.name), .number]
                     | @tsv' "$TMPDIR/review_requests.json" 2>/dev/null || true)

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
  --argjson review_requests "$REVIEW_REQUESTS" \
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
    review_requests: $review_requests,
    project_board: $board,
    stale_issues: $stale_issues,
    snooze_file: $snooze_file
  }'
