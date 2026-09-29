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
# Delivery target grammar as the installed Hermes CLI accepts it
# (`hermes cron create --deliver`): a bare keyword, or a `base:suffix` form for
# `platform:chat_id` and `bot-chat[:profile]`. Satellite deities hold no platform
# token (ADR-0006), so they deliver via `bot-chat:default` — the output is
# injected into the default (gateway) profile's Bot Chat and the gateway, the sole
# token holder, transmits it. Validate the BASE keyword; the suffix is free-form.
DELIVER_CHANNELS=" origin local telegram discord signal platform bot-chat "
errors=0
err() { echo "🔴 $1"; errors=$((errors + 1)); }

# The single source of truth for the owner scope every cron's {{TARGETS}}
# placeholder expands to (see docs/reference/crons.md).
TARGETS_FILE="${ROOT}/team/cron-targets.yaml"
[[ -f "$TARGETS_FILE" ]] \
  || err "team/cron-targets.yaml is missing — crons cannot resolve their owner scope"
[[ -f "$TARGETS_FILE" ]] && ! grep -q '^owners:' "$TARGETS_FILE" \
  && err "team/cron-targets.yaml has no 'owners:' block"

# The owner names under `owners:` — the single source a cron's {{TARGETS}} block
# expands to. A cron body must never bake these names into a literal
# `--owner <name>` flag: that duplicates the owner list and drifts the moment
# cron-targets.yaml changes. Bodies reference the injected Targets table instead.
OWNERS=""
[[ -f "$TARGETS_FILE" ]] && OWNERS="$(awk '
  /^owners:/ { inb=1; next }
  inb && /^[^[:space:]]/ { inb=0 }
  inb && /^[[:space:]]+[A-Za-z0-9_-]+:/ { gsub(/[[:space:]]/, ""); sub(/:.*/, ""); print }' "$TARGETS_FILE")"

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
  # Match the base keyword only; `platform:chat_id` / `bot-chat:profile` carry a
  # free-form suffix after the first colon.
  deliver_base="${deliver%%:*}"
  [[ -n "$deliver" && "$DELIVER_CHANNELS" != *" $deliver_base "* ]] \
    && err "${rel}: deliver '${deliver}' is not a supported channel (${DELIVER_CHANNELS# })"

  [[ -z "$(cron_body "$file" | tr -d '[:space:]')" ]] \
    && err "${rel}: empty body — the cron prompt is required"

  # Owner scope must come from the shared {{TARGETS}} placeholder, never a
  # hardcoded owner list baked into the prompt.
  grep -q '{{TARGETS}}' "$file" \
    || err "${rel}: prompt is missing the {{TARGETS}} placeholder (owner scope comes from team/cron-targets.yaml)"

  # ...and it must not also hardcode an owner name in a `--owner` flag: that
  # re-duplicates the list {{TARGETS}} exists to own. Reference the Targets table.
  for owner in $OWNERS; do
    grep -q -- "--owner ${owner}" "$file" \
      && err "${rel}: hardcodes '--owner ${owner}' — use the owners from the {{TARGETS}} table, not a literal name"
  done
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
