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
#   SOUL.md        Identity ONLY — who the agent is, how it speaks, what it
#                  avoids (Identity / Style / Avoid / Defaults), per the Hermes
#                  SOUL guide. Persona fields (archetype, big_five, comm_style)
#                  are translated into prose voice. No file paths, skills, or
#                  workflow here — those weaken a SOUL file.
#   AGENTS.md      Project operating guide — scope (do / do not), handoff routes,
#                  shared-context pointers, recommended skills, the finalization
#                  gate, then the agent body. This is where the Hermes SOUL guide
#                  says project mechanics belong, not in SOUL.md.
#                  Both use a managed block so hand edits OUTSIDE it survive.
#
# It also installs each agent's vendored skills (agents/<name>/skills/*) into that
# profile's own skill store ($HERMES_HOME/profiles/<name>/skills/agentheon/),
# scopes them via config.yaml `skills:`, seeds shared team context (team/*.md)
# into $HERMES_HOME/team/company/, and rebuilds the routing matrix that Zeus uses
# to dispatch work.
#
# It also installs each agent's scheduled tasks (agents/<name>/crons/*.md) into
# $HERMES_HOME/crons/: each is a portable spec (schedule + skill + delivery
# channel + prompt) and, when the hermes CLI is present, is registered with the
# runtime as that agent via `hermes -p <name> cron create`. Without the CLI the
# spec is written and the register step is skipped with a warning (same policy
# as aliases). The owning agent is the profile the cron lives under.
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
# Secrets: plaintext .env is NEVER touched (add keys with `hermes -p <name>
# setup`). Optionally set AGENTHEON_SECRETS=bitwarden (+ BWS_PROJECT_ID) to emit
# a `secrets.bitwarden` block into every config.yaml, so provider keys live once
# in a Bitwarden project instead of per-profile .env. See ADR-0003. The access
# token stays in the shell (BWS_ACCESS_TOKEN), never written to any file here.
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

MODEL_OPUS="${MODEL_OPUS:-nous-portal/tencent/hy3:free}"
MODEL_SONNET="${MODEL_SONNET:-nous-portal/tencent/hy3:free}"

# External secret source (ADR-0003). Off by default: profiles keep the plain
# .env flow. Set AGENTHEON_SECRETS=bitwarden to emit a `secrets.bitwarden` block
# into every profile's config.yaml so provider keys live once in a Bitwarden
# project instead of duplicated per-profile. The access TOKEN is never written
# here — only the name of the env var that holds it (resolved from the shell at
# runtime); project_id/server_url come from env so no personal IDs are committed.
SECRETS_BACKEND="${AGENTHEON_SECRETS:-}"                       # ""=off | bitwarden
BWS_PROJECT_ID="${BWS_PROJECT_ID:-}"
BWS_SERVER_URL="${BWS_SERVER_URL:-https://vault.bitwarden.com}"
BWS_TOKEN_ENV="${BWS_TOKEN_ENV:-BWS_ACCESS_TOKEN}"

MODE="filedrop"   # filedrop | cli
DRY_RUN=0

OK="🟢"; INFO="🔵"; WARN="🟠"; KO="🔴"
SKILL="🧩"; CRON="⏰"

usage() {
  cat <<'EOF'
agentheon.sh — install the Agentheon pantheon into a Hermes Agent home.

Derives every profile from agents/*/README.md frontmatter and installs it under
$HERMES_HOME/profiles/<name>/ (config.yaml + profile.yaml + SOUL.md + AGENTS.md), then
seeds shared team context and rebuilds the routing matrix. Each agent's
scheduled tasks (agents/<name>/crons/*.md) are installed into $HERMES_HOME/crons/
(and registered with the hermes CLI when present).

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
  MODEL_OPUS      provider/model for `model: opus`    (default: nous-portal/tencent/hy3:free)
  MODEL_SONNET    provider/model for `model: sonnet`  (default: nous-portal/tencent/hy3:free)
  AGENTHEON_SECRETS  secret source to wire in          (default: off; "bitwarden")
  BWS_PROJECT_ID     Bitwarden project id              (required if bitwarden)
  BWS_SERVER_URL     Bitwarden server URL              (default: https://vault.bitwarden.com)
  BWS_TOKEN_ENV      env var holding the access token  (default: BWS_ACCESS_TOKEN)

Secrets: plaintext .env is NEVER touched (add keys with `hermes -p <name>
setup`). With AGENTHEON_SECRETS=bitwarden, a `secrets.bitwarden` block is emitted
into every config.yaml so provider keys resolve from a Bitwarden project at
runtime; the access token stays in the shell, never written to a file. ADR-0003.
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

# --- persona derivation: frontmatter traits -> SOUL voice -----------------
# SOUL.md is identity: who the agent is, how it speaks, what it avoids (Hermes
# SOUL guide). These helpers turn the machine-readable persona fields into prose
# voice. Project mechanics (scope, handoffs, skills, workflow) are kept OUT of
# SOUL.md and written to AGENTS.md instead.

# Dot-joined tokens -> spaced, lower-cased prose. "Decisive.Regal.Sparse" ->
# "decisive, regal, sparse"; "NoFiller" -> "no filler".
humanize_tokens() {
  printf '%s' "$1" | sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' -e 's/\./, /g' \
    | tr '[:upper:]' '[:lower:]'
}

# "O70 C90 E65 A40 N15" -> "precise and thorough, reserved..., blunt and direct".
# Only clearly high (>=60) or low (<=40) dimensions become traits; mid values are
# left unsaid so the voice reads specific, not like filler.
big_five_to_voice() {
  local tok dim val phrase joined=""
  for tok in $1; do
    dim="${tok:0:1}"; val="${tok:1}"
    [[ "$val" =~ ^[0-9]+$ ]] || continue
    phrase=""
    case "$dim" in
      O) if   ((val>=60)); then phrase="open to novel approaches"; elif ((val<=40)); then phrase="conventional and proven"; fi ;;
      C) if   ((val>=60)); then phrase="precise and thorough";     elif ((val<=40)); then phrase="flexible and improvisational"; fi ;;
      E) if   ((val>=60)); then phrase="outgoing and expressive";  elif ((val<=40)); then phrase="reserved, economical with words"; fi ;;
      A) if   ((val>=60)); then phrase="warm and accommodating";   elif ((val<=40)); then phrase="blunt and direct"; fi ;;
      N) if   ((val>=60)); then phrase="cautious, quick to flag risk"; elif ((val<=40)); then phrase="calm and confident under pressure"; fi ;;
    esac
    [[ -n "$phrase" ]] && joined+="${joined:+, }${phrase}"
  done
  printf '%s' "$joined"
}

# comm_style + big_five -> stylistic "Avoid" bullets (voice only, never project
# scope). Always yields at least one bullet.
persona_avoid() {
  local cs="$1" bf="$2" a c n
  local -a out=()
  if [[ "$cs" =~ [Nn]o[Ff]iller|[Cc]risp|[Ss]parse|[Tt]erse ]]; then
    out+=("Filler, hedging, and long preambles.")
  fi
  a="$(printf '%s' "$bf" | grep -oE 'A[0-9]+' | tr -dc '0-9' || true)"
  c="$(printf '%s' "$bf" | grep -oE 'C[0-9]+' | tr -dc '0-9' || true)"
  n="$(printf '%s' "$bf" | grep -oE 'N[0-9]+' | tr -dc '0-9' || true)"
  if [[ -n "$a" ]] && ((a<=40)); then out+=("Softening a clear judgment — say the direct thing."); fi
  if [[ -n "$a" ]] && ((a>=60)); then out+=("Bluntness that reads as cold — stay warm."); fi
  if [[ -n "$c" ]] && ((c>=80)); then out+=("Vague, hand-wavy answers — be specific and exact."); fi
  if [[ -n "$n" ]] && ((n<=30)); then out+=("Manufacturing false urgency or alarm."); fi
  if [[ ${#out[@]} -eq 0 ]]; then out+=("Generic filler like 'be helpful' or 'be clear' — commit to a specific voice."); fi
  printf '%s\n' "${out[@]}"
}

# Install an agent's vendored skills into that profile's own Hermes skill store
# so `hermes -p <slug>` actually loads them. Hermes resolves profile skills from
# the profile home (<pdir>/skills/), NOT the shared ~/.hermes/skills/ store, so
# each agents/<slug>/skills/<name>/ dir (with SKILL.md) is copied to
# <pdir>/skills/agentheon/<name>/, where Hermes discovers it as a local, enabled
# skill. Skills listed in frontmatter but NOT vendored (e.g. Hermes built-ins)
# are left alone — they resolve from the built-in store.
install_skills() { # agent-dir  dest-dir  skill-name...
  local adir="$1" dest="$2"; shift 2
  local s src
  for s in "$@"; do
    src="${adir}/skills/${s}"
    if [[ ! -f "${src}/SKILL.md" ]]; then
      echo "   ${WARN} skill '${s}' not vendored under ${src} — assuming built-in, skipping copy"
      continue
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "   would: install skill '${s}' → ${dest}/${s}/"
    else
      rm -rf "${dest:?}/${s}"
      cp -R "$src" "${dest}/${s}"
      echo "   ${SKILL} skill '${s}' → ${dest}/${s}/"
    fi
  done
}

# Install an agent's scheduled tasks (agents/<slug>/crons/*.md). Each is a
# portable spec written to $HERMES_HOME/crons/<name>.yaml (schedule + skill +
# delivery channel + the verbatim prompt) and, when the hermes CLI is present,
# registered with the runtime as that agent via `hermes -p <slug> cron create`.
# The owning agent is the profile this cron lives under — never a frontmatter
# field. Without the CLI the spec is written and the register step is skipped
# with a warning (the same policy as aliases).
install_crons() { # agent-dir  slug  crons-home
  local adir="$1" slug="$2" chome="$3"
  local file cname cschedule cskill cdeliver cprompt
  shopt -s nullglob
  for file in "${adir}/crons"/*.md; do
    cname="$(fm_scalar "$file" name)"
    [[ -z "$cname" ]] && { echo "   ${WARN} no name in $file, skipping"; continue; }
    cschedule="$(fm_scalar "$file" schedule)"
    cskill="$(fm_scalar "$file" skill)"
    cdeliver="$(fm_scalar "$file" deliver)"
    # Drop the blank line the frontmatter fence leaves at the top of the body.
    cprompt="$(agent_body "$file" | sed -e '/./,$!d')"

    if [[ "$DRY_RUN" == 1 ]]; then
      echo "   would: write ${chome}/${cname}.yaml"
    else
      mkdir -p "$chome"
      {
        echo "# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>"
        echo "# SPDX-License-Identifier: Apache-2.0"
        echo "#"
        echo "# Generated by agentheon.sh from agents/${slug}/crons/${cname}.md — do not edit by hand."
        echo "name: ${cname}"
        echo "schedule: \"${cschedule}\""
        echo "agent: ${slug}"
        echo "skill: ${cskill}"
        echo "deliver: ${cdeliver}"
        echo "prompt: |"
        printf '%s\n' "$cprompt" | sed 's/^/  /'
      } > "${chome}/${cname}.yaml"
    fi

    if [[ "$HAVE_HERMES" == 1 ]]; then
      run hermes -p "$slug" cron create "$cschedule" "$cprompt" \
        --name "$cname" --deliver "$cdeliver" --skill "$cskill" \
        || echo "   ${WARN} cron '${cname}' not registered (see CLI error above)"
    else
      echo "   ${WARN} cron '${cname}' needs the hermes CLI to register — wrote spec only"
    fi

    echo "   ${CRON} cron '${cname}' → ${chome}/${cname}.yaml  (schedule='${cschedule}', deliver=${cdeliver}, skill=${cskill})"
  done
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

# AGENTS.md is entirely ours (project mechanics), so there is no pristine-Hermes
# default to detect — just regenerate the managed block and preserve any hand
# edits outside it.
write_agents() { # pdir  gen-block-file
  local f="$1/AGENTS.md" gen="$2"
  if [[ "$DRY_RUN" == 1 ]]; then echo "   would: write ${f}"; return; fi
  if [[ -f "$f" ]] && grep -q "AGENTHEON:BEGIN" "$f" && grep -q "AGENTHEON:END" "$f"; then
    awk -v genf="$gen" '
      BEGIN { while ((getline l < genf) > 0) g = g l "\n" }
      /AGENTHEON:BEGIN/ { printf "%s", g; skip=1; next }
      /AGENTHEON:END/   { skip=0; next }
      !skip { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    { cat "$gen"; echo; echo "<!-- Add hand-written project notes below this line; they survive regeneration. -->"; } > "$f"
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

# Build the external-secret-source block once — it is identical for every
# profile (secrets are matched by name from the Bitwarden project at runtime),
# so adding a provider never touches this file: add a named secret in the vault.
# See ADR-0003. Empty unless AGENTHEON_SECRETS selects a backend.
SECRETS_BLOCK=""
if [[ "$SECRETS_BACKEND" == "bitwarden" ]]; then
  [[ -n "$BWS_PROJECT_ID" ]] || { echo "${KO} AGENTHEON_SECRETS=bitwarden requires BWS_PROJECT_ID"; exit 1; }
  # Leading newline baked in here (ANSI-C $'\n' works in assignment context but
  # NOT inside the config.yaml heredoc below), so it injects as plain ${SECRETS_BLOCK}.
  SECRETS_BLOCK=$'\n'"$(cat <<YAML
secrets:
  bitwarden:
    enabled: true
    access_token_env: ${BWS_TOKEN_ENV}
    project_id: ${BWS_PROJECT_ID}
    server_url: ${BWS_SERVER_URL}
    cache_ttl_seconds: 300
    override_existing: true
YAML
)"
  echo "${INFO} secret source: bitwarden (project ${BWS_PROJECT_ID}, token env ${BWS_TOKEN_ENV}) → emitted into every config.yaml"
elif [[ -n "$SECRETS_BACKEND" ]]; then
  echo "${KO} unknown AGENTHEON_SECRETS='${SECRETS_BACKEND}' (supported: bitwarden)"; exit 1
fi

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
  archetype="$(fm_scalar "$file" archetype)"
  big_five="$(fm_scalar "$file" big_five)"
  comm_style="$(fm_scalar "$file" comm_style)"
  default="$(fm_scalar "$file" default)"
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

  # Install the agent's vendored skills into this profile's own skill store, then
  # scope them via the config.yaml `skills:` key below. Without this, `skills:`
  # names nothing on disk and `hermes -p <slug>` loads no skills.
  skills_dest="${pdir}/skills/agentheon"
  if [[ ${#skills[@]} -gt 0 ]]; then
    run mkdir -p "$skills_dest"
    install_skills "$(dirname "$file")" "$skills_dest" "${skills[@]}"
  fi

  # Install this agent's scheduled tasks (agents/<slug>/crons/*.md), if any.
  install_crons "$(dirname "$file")" "$slug" "${HOME_DIR}/crons"

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
          || echo "${WARN} alias '${a}' → '${slug}' not set (see CLI error above)"
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
$(for ts in $toolsets; do echo "  - ${ts}"; done)$([[ ${#skills[@]} -gt 0 ]] && printf '\nskills: %s' "$(IFS=,; echo "${skills[*]}")")
memory:
  memory_enabled: true${SECRETS_BLOCK}
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

  # SOUL.md — identity only (who you are, how you speak, what you avoid), per the
  # Hermes SOUL guide. Persona frontmatter is translated into prose voice here;
  # project mechanics go to AGENTS.md below, never into SOUL.md.
  voice="$(big_five_to_voice "$big_five")"
  arche="$(humanize_tokens "$archetype")"
  comm="$(humanize_tokens "$comm_style")"
  gen="$(mktemp)"
  {
    echo "<!-- AGENTHEON:BEGIN — generated from agents/${slug}/README.md by agentheon.sh; do not edit inside this block, it is overwritten. -->"
    echo "# ${name} — ${title}"
    echo
    echo "## Identity"
    echo "You are ${name}, ${title} of the Agentheon, keeper of ${domain}."
    [[ -n "$arche" ]] && echo "Your character is ${arche}."
    echo
    echo "> ${tagline}"
    echo
    echo "## Style"
    [[ -n "$tone" ]]  && echo "${tone}"
    [[ -n "$voice" ]] && echo "You are ${voice}."
    [[ -n "$comm" ]]  && echo "You communicate in a ${comm} register."
    echo
    echo "## Avoid"
    persona_avoid "$comm_style" "$big_five" | sed 's/^/- /'
    echo
    echo "## Defaults"
    if [[ -n "$default" ]]; then
      echo "${default}"
    else
      echo "When a request is ambiguous, lead with your most likely reading, state the assumption in one line, and proceed — ask only when the ambiguity would change the outcome."
    fi
    echo "<!-- AGENTHEON:END -->"
  } > "$gen"
  write_soul "$pdir" "$gen"
  rm -f "$gen"

  # AGENTS.md — project operating guide. Everything the Hermes SOUL guide says to
  # keep OUT of SOUL.md (scope, handoffs, file paths, skills, workflow) lives here.
  agen="$(mktemp)"
  {
    echo "<!-- AGENTHEON:BEGIN — generated from agents/${slug}/README.md by agentheon.sh; do not edit inside this block, it is overwritten. -->"
    echo "# ${name} — operating guide"
    echo
    echo "**Domain:** ${domain}"
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
    echo "## Before you finish (finalization gate)"
    echo "Do not return a result until all of these are true:"
    echo "- [ ] The request is actually answered — not deflected, not partial."
    echo "- [ ] You were the right agent; if not, hand off instead of guessing."
    echo "- [ ] Required shared context (above) was loaded."
    echo "- [ ] Any handoff carries a filled \`handoff-template.md\` block."
    echo "- [ ] Every claim is backed by evidence (output, diff, screenshot) — not assertion."
    echo "- [ ] The user is told what was done and what happens next."
    echo
    echo "---"
    echo
    agent_body "$file"
    echo "<!-- AGENTHEON:END -->"
  } > "$agen"
  write_agents "$pdir" "$agen"
  rm -f "$agen"

  echo "${OK} ${name} → ${pdir}  (model=${provider}/${model}, reasoning=${reasoning}, toolsets=${toolsets// /,}${aliases:+, aliases=$(IFS=,; echo "${aliases[*]}")})"
  count=$((count + 1))
done

echo
echo "${OK} installed ${count} profiles into ${PROFILES_DIR}"
echo
echo "Next:"
if [[ "$SECRETS_BACKEND" == "bitwarden" ]]; then
  echo "  export ${BWS_TOKEN_ENV}=...    # bootstrap token in your shell (never committed)"
  echo "  # add a provider = add a named secret (e.g. XAI_API_KEY) in Bitwarden project ${BWS_PROJECT_ID}"
else
  echo "  hermes -p <name> setup    # add API keys (.env)"
fi
echo "  hermes -p <name> chat     # run the agent"
echo "  hermes profile list       # see them all"
