#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# validate-agents.sh — lint every agent profile (agents/*/README.md) against the
# frontmatter schema so 21+ profiles never drift. Fails on any error; skills that
# are vendored at install time only warn.
#
# Checks:
#   - required scalar fields present
#   - model      in {opus, sonnet}
#   - reasoning  in {high, medium, low}
#   - order      unique positive integer
#   - color      #rrggbb hex
#   - name slug matches its directory
#   - name and each alias unique across all agents
#   - handoffs reference an existing agent, never self
#   - every non-Zeus agent is reachable (listed in some agent's handoffs)
#
# Exit: 0 all good, 1 one or more errors.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"

# shellcheck source=hack/lib-frontmatter.sh
. "${ROOT}/hack/lib-frontmatter.sh"

REQUIRED=(name title domain emoji color model order reasoning tagline)
errors=0
warnings=0
err()  { echo "🔴 $1"; errors=$((errors + 1)); }
warn() { echo "🟠 $1"; warnings=$((warnings + 1)); }

declare -A SLUGS ORDERS ALIAS_OWNER
declare -a ALL_SLUGS
declare -A HANDOFF_TARGETS

shopt -s nullglob
files=("${AGENTS_DIR}"/*/README.md)
[[ ${#files[@]} -eq 0 ]] && { err "no agents found under ${AGENTS_DIR}"; exit 1; }

# --- pass 1: per-agent field validation -----------------------------------

for file in "${files[@]}"; do
  dir="$(basename "$(dirname "$file")")"
  name="$(fm_scalar "$file" name)"
  rel="agents/${dir}/README.md"

  for key in "${REQUIRED[@]}"; do
    [[ -z "$(fm_scalar "$file" "$key")" ]] && err "${rel}: missing required field '${key}'"
  done
  [[ -z "$name" ]] && continue
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

  [[ "$slug" == "$dir" ]] || err "${rel}: name '${name}' (slug '${slug}') does not match directory '${dir}'"
  [[ -n "${SLUGS[$slug]:-}" ]] && err "${rel}: duplicate agent name '${name}'"
  SLUGS[$slug]=1
  ALL_SLUGS+=("$slug")

  model="$(fm_scalar "$file" model)"
  case "$model" in opus | sonnet) ;; *) err "${rel}: model '${model}' not in {opus, sonnet}" ;; esac

  reasoning="$(fm_scalar "$file" reasoning)"
  case "$reasoning" in high | medium | low) ;; *) err "${rel}: reasoning '${reasoning}' not in {high, medium, low}" ;; esac

  color="$(fm_scalar "$file" color)"
  [[ "$color" =~ ^#[0-9a-fA-F]{6}$ ]] || err "${rel}: color '${color}' is not a #rrggbb hex value"

  order="$(fm_scalar "$file" order)"
  if [[ "$order" =~ ^[0-9]+$ ]]; then
    [[ -n "${ORDERS[$order]:-}" ]] && err "${rel}: duplicate order '${order}' (also ${ORDERS[$order]})"
    ORDERS[$order]="$name"
  else
    err "${rel}: order '${order}' is not a positive integer"
  fi

  while read -r a; do
    [[ -z "$a" ]] && continue
    [[ -n "${ALIAS_OWNER[$a]:-}" ]] && err "${rel}: alias '${a}' already used by ${ALIAS_OWNER[$a]}"
    [[ -n "${SLUGS[$a]:-}" && "$a" != "$slug" ]] && err "${rel}: alias '${a}' collides with an agent name"
    ALIAS_OWNER[$a]="$name"
  done < <(fm_list "$file" aliases)

  # Skills are vendored at install time; only warn if a declared skill dir is absent.
  while read -r sk; do
    [[ -z "$sk" ]] && continue
    [[ -d "${AGENTS_DIR}/${dir}/skills/${sk}" ]] || warn "${rel}: skill '${sk}' not vendored on disk (installed later)"
  done < <(fm_list "$file" skills)
done

# --- pass 2: cross-agent handoff graph ------------------------------------

for file in "${files[@]}"; do
  dir="$(basename "$(dirname "$file")")"
  name="$(fm_scalar "$file" name)"
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  rel="agents/${dir}/README.md"
  while read -r h; do
    [[ -z "$h" ]] && continue
    [[ "$h" == "$slug" ]] && err "${rel}: agent hands off to itself ('${h}')"
    [[ -n "${SLUGS[$h]:-}" ]] || err "${rel}: handoff '${h}' is not an existing agent"
    HANDOFF_TARGETS[$h]=1
  done < <(fm_list "$file" handoffs)
done

# Every specialist must be reachable — routed to by at least one agent (Zeus).
for slug in "${ALL_SLUGS[@]}"; do
  [[ "$slug" == "zeus" ]] && continue
  [[ -n "${HANDOFF_TARGETS[$slug]:-}" ]] || err "agent '${slug}' is an orphan — no agent hands off to it (add it to Zeus)"
done

echo
if [[ $errors -eq 0 ]]; then
  echo "🟢 ${#ALL_SLUGS[@]} agents valid (${warnings} warning(s))"
  exit 0
fi
echo "🔴 ${errors} error(s), ${warnings} warning(s) across ${#ALL_SLUGS[@]} agents"
exit 1
