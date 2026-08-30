#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# eval-routing.sh — routing eval harness for Zeus.
#
# The pantheon builds evals for everything except itself. This harness proves
# Zeus routes to the right specialist, and guards against regressions whenever an
# agent's domain, aliases, or hand-offs change.
#
# Two modes:
#   (default) STATIC — no LLM. Verifies the golden set is well-formed and covers
#             every specialist: each expected agent exists, and every non-Zeus
#             agent has at least one case. CI-safe, deterministic, free.
#   --live    LIVE — requires the hermes CLI and a configured 'zeus' profile.
#             Sends each prompt to Zeus and checks the routed agent matches.
#
# Cases: hack/evals/routing-cases.tsv  (prompt <TAB> expected-slug)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
CASES="${ROOT}/hack/evals/routing-cases.tsv"
MODE="static"
[[ "${1:-}" == "--live" ]] && MODE="live"

[[ -f "$CASES" ]] || { echo "🔴 cases file not found: $CASES" >&2; exit 1; }

# Known agent slugs, from the directory names (source of truth).
declare -A AGENT
shopt -s nullglob
for d in "${AGENTS_DIR}"/*/; do AGENT["$(basename "$d")"]=1; done

# Read cases (skip comments/blanks) into parallel arrays.
declare -a PROMPTS EXPECTED
declare -A COVERED
while IFS=$'\t' read -r prompt expected; do
  [[ -z "${prompt// }" || "${prompt:0:1}" == "#" ]] && continue
  [[ -z "${expected// }" ]] && { echo "🔴 malformed case (no expected agent): ${prompt}" >&2; exit 1; }
  expected="${expected//[[:space:]]/}"
  PROMPTS+=("$prompt"); EXPECTED+=("$expected"); COVERED["$expected"]=1
done < "$CASES"

total=${#PROMPTS[@]}
[[ $total -eq 0 ]] && { echo "🔴 no cases parsed from $CASES" >&2; exit 1; }

fail=0

# --- static: cases reference real agents, and coverage is complete --------

for e in "${EXPECTED[@]}"; do
  [[ -n "${AGENT[$e]:-}" ]] || { echo "🔴 case expects unknown agent '${e}'"; fail=$((fail + 1)); }
done
for slug in "${!AGENT[@]}"; do
  [[ "$slug" == "zeus" ]] && continue
  [[ -n "${COVERED[$slug]:-}" ]] || { echo "🔴 no routing case covers agent '${slug}'"; fail=$((fail + 1)); }
done

if [[ "$MODE" == "static" ]]; then
  echo
  if [[ $fail -eq 0 ]]; then
    echo "🟢 static: ${total} cases, all expected agents exist, every specialist covered"
    echo "   run with --live to route each prompt through Zeus"
    exit 0
  fi
  echo "🔴 static: ${fail} problem(s) in the golden set"
  exit 1
fi

# --- live: route each prompt through Zeus via hermes -----------------------

command -v hermes >/dev/null 2>&1 || { echo "🔴 --live needs the hermes CLI (not found)" >&2; exit 1; }

pass=0
for i in "${!PROMPTS[@]}"; do
  prompt="${PROMPTS[$i]}"; expected="${EXPECTED[$i]}"
  # Ask Zeus who it would route to. We only need the decision, not execution.
  out="$(hermes -p zeus chat --once "Which single agent do you route this to? Answer with only the agent name. Request: ${prompt}" 2>/dev/null || true)"
  got="$(echo "$out" | tr '[:upper:]' '[:lower:]' | grep -oE "$(printf '%s' "${!AGENT[@]}" | tr ' ' '|')" | head -1 || true)"
  if [[ "$got" == "$expected" ]]; then
    pass=$((pass + 1))
  else
    echo "🔴 [${expected} != ${got:-?}] ${prompt}"
    fail=$((fail + 1))
  fi
done

echo
echo "Live routing: ${pass}/${total} passed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
