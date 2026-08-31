#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# validate-crons.sh — lint every scheduled task (agents/*/crons/*.md) against the
# cron frontmatter schema so the schedule never drifts from what Hermes installs.
#
# A cron lives beside the deity that owns it, so the owning agent is the parent
# profile directory (agents/<slug>/crons/<name>.md) — derived from the path,
# never a frontmatter field.
#
# Checks:
#   - required scalar fields present
#   - name slug matches its filename (<name>.md)
#   - name unique across all crons
#   - schedule is a 5-field cron expression
#   - the owning directory is a real deity (agents/<slug>/README.md exists)
#   - deliver is a supported channel
#   - the body (the prompt Hermes runs) is non-empty
#
# Exit: 0 all good, 1 one or more errors.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"

# shellcheck source=hack/lib-frontmatter.sh
. "${ROOT}/hack/lib-frontmatter.sh"

# cron_body FILE -> everything after the closing frontmatter fence.
cron_body() { awk '/^---$/ { c++; next } c>=2 { print }' "$1"; }

REQUIRED=(name schedule skill deliver summary)
DELIVER_CHANNELS=" telegram slack email stdout "
errors=0
err() { echo "🔴 $1"; errors=$((errors + 1)); }

declare -A SLUGS
count=0
shopt -s nullglob
for file in "${AGENTS_DIR}"/*/crons/*.md; do
  count=$((count + 1))
  slug="$(basename "$(dirname "$(dirname "$file")")")"
  base="$(basename "$file" .md)"
  rel="agents/${slug}/crons/${base}.md"

  for key in "${REQUIRED[@]}"; do
    [[ -z "$(fm_scalar "$file" "$key")" ]] && err "${rel}: missing required field '${key}'"
  done

  name="$(fm_scalar "$file" name)"
  [[ -z "$name" ]] && continue

  [[ "$name" == "$base" ]] || err "${rel}: name '${name}' does not match filename '${base}'"
  [[ -n "${SLUGS[$name]:-}" ]] && err "${rel}: duplicate cron name '${name}'"
  SLUGS[$name]=1

  [[ -f "${AGENTS_DIR}/${slug}/README.md" ]] \
    || err "${rel}: owning directory '${slug}' is not a deity (no agents/${slug}/README.md)"

  schedule="$(fm_scalar "$file" schedule)"
  fields="$(echo "$schedule" | awk '{print NF}')"
  [[ "$fields" == "5" ]] || err "${rel}: schedule '${schedule}' is not a 5-field cron expression"

  deliver="$(fm_scalar "$file" deliver)"
  [[ -n "$deliver" && "$DELIVER_CHANNELS" != *" $deliver "* ]] \
    && err "${rel}: deliver '${deliver}' is not a supported channel (${DELIVER_CHANNELS# })"

  [[ -z "$(cron_body "$file" | tr -d '[:space:]')" ]] \
    && err "${rel}: empty body — the cron prompt is required"
done

if [[ "$count" -eq 0 ]]; then
  echo "🟢 no crons to validate"
  exit 0
fi
if [[ "$errors" -gt 0 ]]; then
  echo "🔴 ${errors} error(s)"
  exit 1
fi
echo "🟢 all crons valid (${count})"
