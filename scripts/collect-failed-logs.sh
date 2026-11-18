#!/usr/bin/env bash
# Print the last 150 lines of every failed job in the current workflow run.
# Needs GH_TOKEN with actions:read.
set -euo pipefail

sleep 5 # logs of jobs that just finished can take a moment to show up

gh api "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/attempts/${GITHUB_RUN_ATTEMPT:-1}/jobs?per_page=100" \
  --jq '.jobs[] | select(.conclusion == "failure") | "\(.id) \(.name)"' |
  while read -r id name; do
    echo "===== failed job: $name ====="
    gh api "repos/$GITHUB_REPOSITORY/actions/jobs/$id/logs" \
      | sed -E 's/^[0-9T:.-]+Z //' \
      | tail -n 150 \
      || echo "(could not download this log)"
    echo
  done
