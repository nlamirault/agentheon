#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# agentheon-profiles.sh — browse the Agentheon deity catalog from the source of
# truth (agents/*/README.md), not Hermes. `hermes profile list` only prints
# aliases; this lists every profile with its slug, title, domain and model, and
# describes a single profile the way the site does
# (https://agentheon.lamirault.xyz/agents/<slug>/).
#
# Usage:
#   hack/agentheon-profiles.sh [list]            # list all profiles (by order)
#   hack/agentheon-profiles.sh describe <name>   # detail one profile
#   hack/agentheon-profiles.sh help
#
# <name> is a slug (athena) or any alias (architecture, planning).
#
# Env:
#   NO_COLOR=1   disable ANSI colour (also auto-off when stdout is not a tty)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
# shellcheck source=hack/lib-frontmatter.sh
. "${ROOT}/hack/lib-frontmatter.sh"

# --- colour -----------------------------------------------------------------
if [[ -t 1 && "${NO_COLOR:-0}" != 1 ]]; then
  B=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; YEL=$'\033[33m'; R=$'\033[0m'
else
  B=""; DIM=""; CYAN=""; YEL=""; R=""
fi

die() { echo "error: $*" >&2; exit 1; }

readme() { echo "${AGENTS_DIR}/$1/README.md"; }

# resolve NAME (slug or alias) -> slug, or empty if unknown.
resolve() {
  local want; want="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  [[ -f "$(readme "$want")" ]] && { echo "$want"; return 0; }
  local f slug a
  for f in "${AGENTS_DIR}"/*/README.md; do
    slug="$(basename "$(dirname "$f")")"
    while IFS= read -r a; do
      [[ "$(echo "$a" | tr '[:upper:]' '[:lower:]')" == "$want" ]] && { echo "$slug"; return 0; }
    done < <(fm_list "$f" aliases)
  done
  return 1
}

# --- list -------------------------------------------------------------------
cmd_list() {
  local f slug order name title domain model aliases
  printf '%s%-4s %-12s %-16s %-32s %-7s %s%s\n' \
    "$B" "#" "SLUG" "TITLE" "DOMAIN" "MODEL" "ALIASES" "$R"
  {
    for f in "${AGENTS_DIR}"/*/README.md; do
      slug="$(basename "$(dirname "$f")")"
      order="$(fm_scalar "$f" order)"; order="${order:-999}"
      title="$(fm_scalar "$f" title)"
      domain="$(fm_scalar "$f" domain)"
      model="$(fm_scalar "$f" model)"
      aliases="$(fm_list "$f" aliases | paste -sd, - 2>/dev/null)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$order" "$slug" "$title" "$domain" "$model" "$aliases"
    done
  } | sort -n | while IFS=$'\t' read -r order slug title domain model aliases; do
    printf '%-4s %s%-12s%s %-16s %-32s %-7s %s%s%s\n' \
      "$order" "$CYAN" "$slug" "$R" "$title" "$domain" "$model" "$DIM" "$aliases" "$R"
  done
  echo
  echo "${DIM}$(ls -d "${AGENTS_DIR}"/*/ | wc -l | tr -d ' ') profiles. Detail: $(basename "$0") describe <slug>${R}"
}

# --- describe ---------------------------------------------------------------
field()  { local v; v="$(fm_scalar "$1" "$2")"; [[ -n "$v" ]] && printf '  %s%-11s%s %s\n' "$B" "$3" "$R" "$v"; }
listsec() {
  local f="$1" key="$2" label="$3" any=0 item
  while IFS= read -r item; do
    [[ $any -eq 0 ]] && { printf '\n%s%s%s\n' "$B" "$label" "$R"; any=1; }
    printf '  • %s\n' "$item"
  done < <(fm_list "$f" "$key")
}

cmd_describe() {
  [[ $# -ge 1 ]] || die "describe needs a profile name (slug or alias)"
  local slug; slug="$(resolve "$1")" \
    || die "unknown profile '$1' — try: $(basename "$0") list"
  local f; f="$(readme "$slug")"

  local emoji name title domain tagline
  emoji="$(fm_scalar "$f" emoji)"
  name="$(fm_scalar "$f" name)"
  title="$(fm_scalar "$f" title)"
  domain="$(fm_scalar "$f" domain)"
  tagline="$(fm_scalar "$f" tagline)"

  printf '\n%s%s %s%s %s— %s%s\n' "$B" "$emoji" "$CYAN" "$name" "$R$B" "$title" "$R"
  printf '%s%s%s\n\n' "$DIM" "$domain" "$R"
  [[ -n "$tagline" ]] && printf '%s"%s"%s\n\n' "$YEL" "$tagline" "$R"

  printf '  %s%-11s%s %s\n' "$B" "slug" "$R" "$slug"
  field "$f" model       "model"
  field "$f" reasoning   "reasoning"
  field "$f" order       "order"
  field "$f" archetype   "archetype"
  field "$f" big_five    "big_five"
  field "$f" comm_style  "comm_style"
  field "$f" tone        "tone"

  local aliases; aliases="$(fm_list "$f" aliases | paste -sd', ' - 2>/dev/null)"
  [[ -n "$aliases" ]] && printf '  %s%-11s%s %s\n' "$B" "aliases" "$R" "$aliases"

  listsec "$f" tools     "Tools"
  listsec "$f" does      "Does"
  listsec "$f" does_not  "Does not"
  listsec "$f" handoffs  "Hands off to"
  listsec "$f" skills    "Skills"

  # README body (everything after the closing frontmatter '---').
  printf '\n%s%s%s\n' "$B" "Profile" "$R"
  awk 'c>=2{print} /^---$/{c++}' "$f" | awk 'NF{p=1} p' | cat -s | sed 's/^/  /'
  echo
}

# --- main -------------------------------------------------------------------
case "${1:-list}" in
  list|ls)          cmd_list ;;
  describe|show|d)  shift; cmd_describe "$@" ;;
  help|-h|--help)
    awk '/^set -euo/{s=1;next} s&&/^#/{p=1;sub(/^# ?/,"");print;next} s&&p&&!/^#/{exit}' "$0" ;;
  *) die "unknown command '$1' — use: list | describe <name> | help" ;;
esac
