#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# agentheon.sh — install the Agentheon pantheon into a Hermes Agent home.
#
# Meant to run on a VPS that hosts Hermes Agent (hermes-agent.nousresearch.com).
# Derives every profile from the single source of truth — agents/*/README.md frontmatter
# — and installs it under $HERMES_HOME/profiles/<name>/. For each agent it writes:
#
#   config.yaml    Hermes on-disk config: model (provider/model/reasoning_effort),
#                  toolsets, memory. Regenerated every run — never hand-edit.
#   profile.yaml   Portable descriptor (description + required skills), magnus919
#                  style, for review/portability. Hermes itself reads config.yaml.
#   SOUL.md        Persona, scope (do / do not), handoff routes, shared-context
#                  pointer, then the agent body — inside a managed block so hand
#                  edits OUTSIDE the block survive regeneration.
#
# It also seeds shared team context (team/*.md) into $HERMES_HOME/team/company/
# and rebuilds the routing matrix that Zeus uses to dispatch work.
#
# Aliases: each agent may declare `aliases:` in its frontmatter — alternate
# names that resolve to the profile (e.g. `hermes -p design ...` → aglaea).
# These are registered with `hermes profile alias` and therefore need the
# hermes CLI; the file-drop path warns and skips them when it is absent.
#
# Two install paths, same source:
#   (default)  file-drop — writes the files directly. Works with NO hermes CLI.
#              If the hermes CLI IS present, the profile is also registered
#              (hermes profile create) so it shows up in `hermes profile list`.
#   --cli      delegate to hack/gen-hermes-profiles.sh (imperative, requires the
#              hermes CLI; sets config through `hermes config set`).
#
# Secrets (.env) are NEVER touched — add keys with `hermes -p <name> setup`.
#
# Usage:
#   ./agentheon.sh [install] [--cli|--no-cli] [--dry-run] [--home DIR]
#   ./agentheon.sh --help

# --- setup ----------------------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${ROOT}/agents"
TEAM_DIR="${ROOT}/team"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
COMPANY_DIR="${HOME_DIR}/team/company"
PROFILES_DIR="${HOME_DIR}/profiles"

MODEL_OPUS="${MODEL_OPUS:-anthropic/claude-opus}"
MODEL_SONNET="${MODEL_SONNET:-anthropic/claude-sonnet}"

MODE="filedrop"   # filedrop | cli
DRY_RUN=0

OK="🟢"; INFO="🔵"; WARN="🟠"; KO="🔴"

usage() {
  cat <<'EOF'
agentheon.sh — install the Agentheon pantheon into a Hermes Agent home.

Derives every profile from agents/*/README.md frontmatter and installs it under
$HERMES_HOME/profiles/<name>/ (config.yaml + profile.yaml + SOUL.md), then
seeds shared team context and rebuilds the routing matrix.

Usage:
  ./agentheon.sh [install] [--cli|--no-cli] [--dry-run] [--home DIR]
  ./agentheon.sh --help

Options:
  install        Install/refresh all profiles (default action).
  --no-cli       File-drop only; no hermes CLI required (default).
  --cli          Delegate to hack/gen-hermes-profiles.sh (needs hermes CLI).
  --dry-run, -n  Show what would happen; write nothing.
  --home DIR     Hermes home (default: $HERMES_HOME or ~/.hermes).
  -h, --help     This help.

Env overrides:
  HERMES_HOME     profiles root parent               (default: ~/.hermes)
  MODEL_OPUS      provider/model for `model: opus`    (default: anthropic/claude-opus)
  MODEL_SONNET    provider/model for `model: sonnet`  (default: anthropic/claude-sonnet)

Secrets (.env) are NEVER touched — add keys with `hermes -p <name> setup`.
EOF
  exit "${1:-0}"
}

# --- arg parsing ----------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    install)      shift ;;
    --cli)        MODE="cli"; shift ;;
    --no-cli)     MODE="filedrop"; shift ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --home)       HOME_DIR="$2"; COMPANY_DIR="${HOME_DIR}/team/company"; PROFILES_DIR="${HOME_DIR}/profiles"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *)            echo "${KO} unknown argument: $1"; usage 1 ;;
  esac
done

run() { # echo + execute unless dry-run
  if [[ "$DRY_RUN" == 1 ]]; then echo "   would: $*"; else "$@"; fi
}

[[ -d "$AGENTS_DIR" ]] || { echo "${KO} agents/ not found under ${ROOT}"; exit 1; }

# --- --cli path: hand off to the imperative generator ---------------------

if [[ "$MODE" == "cli" ]]; then
  command -v hermes >/dev/null 2>&1 || { echo "${KO} --cli needs the hermes CLI, not found on PATH"; exit 1; }
  echo "${INFO} delegating to hack/gen-hermes-profiles.sh (CLI mode)"
  [[ "$DRY_RUN" == 1 ]] && { echo "   would: HERMES_HOME=${HOME_DIR} ${ROOT}/hack/gen-hermes-profiles.sh"; exit 0; }
  HERMES_HOME="$HOME_DIR" exec "${ROOT}/hack/gen-hermes-profiles.sh"
fi

# --- frontmatter helpers (file-drop path) ---------------------------------

fm_scalar() { # file key -> first scalar value, quotes stripped
  awk -v k="$2" '
    /^---$/ { c++; next }
    c==1 && $0 ~ "^"k":" { sub("^"k":[ \t]*", ""); gsub(/^"|"$/, ""); print; exit }' "$1"
}

fm_list() { # file key -> one YAML list item per line
  awk -v k="$2" '
    /^---$/ { c++; next }
    c==1 && $0 ~ "^"k":" { inlist=1; next }
    c==1 && inlist && /^[a-zA-Z]/ { inlist=0 }
    c==1 && inlist && /^[ \t]*-[ \t]*/ { sub(/^[ \t]*-[ \t]*/, ""); gsub(/^"|"$/, ""); print }' "$1"
}

agent_body() { awk '/^---$/ { c++; next } c>=2 { print }' "$1"; }

# Claude Code tool names -> Hermes toolsets (deduped, hermes-cli always first).
map_toolsets() {
  local t hs; declare -A seen=([hermes-cli]=1); local out="hermes-cli"
  while read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in
      Read|Write|Edit|Glob|Grep) hs="files" ;;
      Bash)                       hs="shell" ;;
      Task)                       hs="orchestration" ;;
      Web*|WebFetch|WebSearch)    hs="web" ;;
      *)                          hs="files" ;;
    esac
    [[ -n "${seen[$hs]:-}" ]] && continue
    seen[$hs]=1; out+=" ${hs}"
  done
  [[ -n "${seen[memory]:-}" ]] || out+=" memory"
  printf '%s' "$out"
}

split_model() { # "provider/model" -> "provider" "model"
  printf '%s %s' "${1%%/*}" "${1#*/}"
}

# --- pass 1: sibling lookup for handoff routes ----------------------------

declare -A NAME DOMAIN TAGLINE MODEL REASON HANDS ALIASES
shopt -s nullglob
for file in "${AGENTS_DIR}"/*/README.md; do
  n="$(fm_scalar "$file" name)"; [[ -z "$n" ]] && continue
  s="$(echo "$n" | tr '[:upper:]' '[:lower:]')"
  NAME[$s]="$n"; DOMAIN[$s]="$(fm_scalar "$file" domain)"; TAGLINE[$s]="$(fm_scalar "$file" tagline)"
  MODEL[$s]="$(fm_scalar "$file" model)"; REASON[$s]="$(fm_scalar "$file" reasoning)"
  HANDS[$s]="$(fm_list "$file" handoffs | paste -sd, - | sed 's/,/, /g')"
  ALIASES[$s]="$(fm_list "$file" aliases | paste -sd, - | sed 's/,/, /g')"
done

build_routing() {
  echo "<!-- Generated by agentheon.sh — do not edit; regenerated on every run. -->"
  echo "# Agentheon — Routing Matrix"
  echo
  echo "Zeus uses this to route work. Ordered by name; hand-offs per agent."
  echo
  echo "| Agent | Aliases | Domain | Model | Reasoning | Hands off to |"
  echo "|-------|---------|--------|-------|-----------|--------------|"
  for s in $(printf '%s\n' "${!NAME[@]}" | sort); do
    echo "| ${NAME[$s]} | ${ALIASES[$s]:-—} | ${DOMAIN[$s]} | ${MODEL[$s]:-?} | ${REASON[$s]:-default} | ${HANDS[$s]:-—} |"
  done
}

# --- SOUL.md assembly (managed block + safe regen) ------------------------

write_soul() { # pdir  gen-block-file
  local soul="$1/SOUL.md" gen="$2"
  if [[ "$DRY_RUN" == 1 ]]; then echo "   would: write ${soul}"; return; fi
  if [[ -f "$soul" ]] && grep -q "AGENTHEON:BEGIN" "$soul" && grep -q "AGENTHEON:END" "$soul"; then
    awk -v genf="$gen" '
      BEGIN { while ((getline l < genf) > 0) g = g l "\n" }
      /AGENTHEON:BEGIN/ { printf "%s", g; skip=1; next }
      /AGENTHEON:END/   { skip=0; next }
      !skip { print }' "$soul" > "$soul.tmp" && mv "$soul.tmp" "$soul"
  elif [[ ! -f "$soul" ]] || grep -q "created by Nous Research" "$soul"; then
    { cat "$gen"; echo; echo "<!-- Add hand-written guidance below this line; it survives regeneration. -->"; } > "$soul"
  else
    cp "$soul" "$soul.bak"
    { cat "$gen"; echo; echo "<!-- Custom additions preserved from your previous SOUL.md (backup: SOUL.md.bak). -->"; echo; cat "$soul.bak"; } > "$soul"
  fi
}

# --- team context seed ----------------------------------------------------

if [[ -d "$TEAM_DIR" ]]; then
  echo "${INFO} seeding shared context → ${COMPANY_DIR}/"
  run mkdir -p "$COMPANY_DIR"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "   would: cp ${TEAM_DIR}/*.md → ${COMPANY_DIR}/ + write routing.md"
  else
    cp "$TEAM_DIR"/*.md "$COMPANY_DIR"/ 2>/dev/null || true
    build_routing > "$COMPANY_DIR/routing.md"
  fi
  echo "${OK} shared context ready (company, workflow, handoff-template, routing)"
fi

# --- pass 2: write each profile -------------------------------------------

HAVE_HERMES=0
command -v hermes >/dev/null 2>&1 && HAVE_HERMES=1
[[ "$HAVE_HERMES" == 0 ]] && echo "${WARN} hermes CLI not found — writing files only (profiles won't auto-register in \`hermes profile list\`)"

count=0
for file in "${AGENTS_DIR}"/*/README.md; do
  name="$(fm_scalar "$file" name)"
  [[ -z "$name" ]] && { echo "${WARN} no name in $file, skipping"; continue; }

  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

  case "$(fm_scalar "$file" model)" in
    opus)   model_id="$MODEL_OPUS" ;;
    sonnet) model_id="$MODEL_SONNET" ;;
    *)      model_id="$(fm_scalar "$file" model)" ;;
  esac
  read -r provider model <<<"$(split_model "$model_id")"

  title="$(fm_scalar "$file" title)"
  domain="$(fm_scalar "$file" domain)"
  tagline="$(fm_scalar "$file" tagline)"
  tone="$(fm_scalar "$file" tone)"
  reasoning="$(fm_scalar "$file" reasoning)"; reasoning="${reasoning:-medium}"
  mapfile -t toolset_arr < <(fm_list "$file" tools)
  toolsets="$(printf '%s\n' "${toolset_arr[@]}" | map_toolsets)"
  mapfile -t does      < <(fm_list "$file" does)
  mapfile -t does_not  < <(fm_list "$file" does_not)
  mapfile -t handoffs  < <(fm_list "$file" handoffs)
  mapfile -t skills    < <(fm_list "$file" skills)
  mapfile -t aliases   < <(fm_list "$file" aliases)

  pdir="${PROFILES_DIR}/${slug}"
  run mkdir -p "$pdir"

  # Register with the CLI when available, so it lands in `hermes profile list`.
  if [[ "$HAVE_HERMES" == 1 ]]; then
    if hermes profile list 2>/dev/null | grep -qw "$slug"; then
      :
    else
      run hermes profile create "$slug" --description "${domain} — ${tagline}"
    fi
  fi

  # Aliases (frontmatter `aliases:`) — alternate names that resolve to this
  # profile, e.g. `hermes -p design ...` → aglaea. CLI-only feature; there is no
  # on-disk file to template, so it is registered only when the hermes CLI is
  # present. Re-adding an existing alias is tolerated (idempotent re-runs).
  if [[ ${#aliases[@]} -gt 0 ]]; then
    if [[ "$HAVE_HERMES" == 1 ]]; then
      for a in "${aliases[@]}"; do
        run hermes profile alias "$slug" --name "$a" \
          || echo "${WARN} alias '${a}' → '${slug}' not set (already exists?)"
      done
    else
      echo "${WARN} aliases for '${slug}' need the hermes CLI — skipping (${aliases[*]})"
    fi
  fi

  # config.yaml — the file Hermes actually reads. Regenerated every run.
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "   would: write ${pdir}/config.yaml"
  else
    cat > "$pdir/config.yaml" <<YAML
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0
#
# Generated by agentheon.sh from agents/${slug}/README.md — do not edit by hand.
# Re-run ./agentheon.sh to regenerate. Secrets live in .env (never touched).
model:
  provider: ${provider}
  model: ${model}
  reasoning_effort: ${reasoning}
toolsets:
$(for ts in $toolsets; do echo "  - ${ts}"; done)
memory:
  memory_enabled: true
YAML
  fi

  # profile.yaml — portable descriptor (magnus919 style). Hermes reads config.yaml,
  # not this; it exists for review, docs, and cross-tool portability.
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "   would: write ${pdir}/profile.yaml"
  else
    {
      echo "# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>"
      echo "# SPDX-License-Identifier: Apache-2.0"
      echo "#"
      echo "# Portable profile descriptor generated by agentheon.sh from agents/${slug}/README.md."
      echo "description: \"${domain} — ${tagline}\""
      if [[ ${#skills[@]} -gt 0 ]]; then
        echo "skills:"
        echo "  required:"
        for s in "${skills[@]}"; do echo "    - ${s}"; done
      fi
    } > "$pdir/profile.yaml"
  fi

  # SOUL.md — persona + managed block.
  gen="$(mktemp)"
  {
    echo "<!-- AGENTHEON:BEGIN — generated from agents/${slug}/README.md by agentheon.sh; do not edit inside this block, it is overwritten. -->"
    echo "# ${name} — ${title}"
    echo
    echo "**Domain:** ${domain}"
    [[ -n "$tone" ]] && echo "**Voice:** ${tone}"
    echo
    echo "> ${tagline}"
    echo
    if [[ ${#does[@]} -gt 0 ]]; then
      echo "## You do"; for d in "${does[@]}"; do echo "- ${d}"; done; echo
    fi
    if [[ ${#does_not[@]} -gt 0 ]]; then
      echo "## You do not"; for d in "${does_not[@]}"; do echo "- ${d}"; done; echo
    fi
    echo "## Hand off to"
    if [[ ${#handoffs[@]} -gt 0 ]]; then
      for h in "${handoffs[@]}"; do
        [[ -n "${NAME[$h]:-}" ]] && echo "- **${NAME[$h]}** (${DOMAIN[$h]}) — ${TAGLINE[$h]}" || echo "- **${h}**"
      done
    else
      echo "- Terminal role — no downstream handoffs."
    fi
    echo
    echo "## Shared context"
    echo "Read these shared team files before starting (in \`${COMPANY_DIR}/\`):"
    echo "- \`company.md\` — who we are, conventions, working principles"
    echo "- \`workflow.md\` — the plan→build→test→review loop and quality gates"
    echo "- \`handoff-template.md\` — the format for handing work to another agent"
    echo "- \`routing.md\` — the full agent routing matrix"
    echo
    if [[ ${#skills[@]} -gt 0 ]]; then
      echo "## Recommended skills"; for s in "${skills[@]}"; do echo "- ${s}"; done; echo
    fi
    echo "---"
    echo
    agent_body "$file"
    echo "<!-- AGENTHEON:END -->"
  } > "$gen"
  write_soul "$pdir" "$gen"
  rm -f "$gen"

  echo "${OK} ${name} → ${pdir}  (model=${provider}/${model}, reasoning=${reasoning}, toolsets=${toolsets// /,}${aliases:+, aliases=$(IFS=,; echo "${aliases[*]}")})"
  count=$((count + 1))
done

echo
echo "${OK} installed ${count} profiles into ${PROFILES_DIR}"
echo
echo "Next:"
echo "  hermes -p <name> setup    # add API keys (.env)"
echo "  hermes -p <name> chat     # run the agent"
echo "  hermes profile list       # see them all"
