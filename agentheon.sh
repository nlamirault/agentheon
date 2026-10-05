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
#   config.yaml    Hermes on-disk config: model (provider/model/reasoning_effort/default/base_url),
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
# setup`). A secret source is REQUIRED — the script refuses to run without one:
# pass --secrets bitwarden --bws-project-id UUID (or the AGENTHEON_SECRETS +
# BWS_PROJECT_ID env twins) to emit a `secrets.bitwarden` block into every
# config.yaml, so provider keys live once in a Bitwarden project instead of
# per-profile .env. See ADR-0003. The access token stays in the shell
# (BWS_ACCESS_TOKEN), never written to any file here.
#
# As a plaintext alternative, every profile's .env is symlinked to one shared
# file ($HERMES_HOME/.shared-secrets.env) at the end of the run, so a single
# env can serve all profiles. The shared file is created out of band, never
# written here. It holds provider/LLM keys ONLY — platform tokens
# (SLACK_*, TELEGRAM_*) must never live here, because the shared file feeds
# every profile and outbound messaging is Zeus's job alone (see ADR-0006):
# they belong solely in the default profile env ($HERMES_HOME/.env). A leak is
# flagged after linking.
#
# Usage:
#   ./agentheon.sh [install] [--cli|--no-cli] [--dry-run] [--home DIR]
#                  --secrets bitwarden --bws-project-id UUID
#   ./agentheon.sh --help

# --- setup ----------------------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${ROOT}/agents"
TEAM_DIR="${ROOT}/team"
CRON_TARGETS="${TEAM_DIR}/cron-targets.yaml"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
COMPANY_DIR="${HOME_DIR}/team/company"
PROFILES_DIR="${HOME_DIR}/profiles"

MODEL_OPUS="${MODEL_OPUS:-openrouter/meta/muse-spark-1.3}"
MODEL_SONNET="${MODEL_SONNET:-openrouter/meta/muse-spark-1.3}"
# OpenAI-compatible endpoint for the provider above. Emitted verbatim into every
# config.yaml as model.base_url. Defaults to OpenRouter to match MODEL_*.
MODEL_BASE_URL="${MODEL_BASE_URL:-https://openrouter.ai/api/v1}"
# Upper bound on tokens per request, emitted as model.max_tokens. Providers that
# reserve credits up-front (e.g. OpenRouter) charge against this ceiling, so a
# cap below the account's affordable limit avoids HTTP 402 "requires more
# credits" rejections before the call is even made. Default 32768.
MODEL_MAX_TOKENS="${MODEL_MAX_TOKENS:-32768}"

# Global model override (shares the hack/set-model.sh contract). When set, these
# override the per-agent opus/sonnet tier for EVERY profile — use them to point
# the whole pantheon at one model without editing frontmatter. Empty (default)
# keeps the tiered behavior: model resolves from each agent's `model:` frontmatter
# via MODEL_OPUS/MODEL_SONNET. Each key is independent: MODEL_ID is emitted
# verbatim as model.model (slashes kept, never split), provider comes from
# MODEL_PROVIDER, and reasoning from MODEL_REASONING_EFFORT (else per-agent).
MODEL_PROVIDER="${MODEL_PROVIDER:-}"
MODEL_ID="${MODEL_ID:-}"
MODEL_DEFAULT="${MODEL_DEFAULT:-}"
MODEL_REASONING_EFFORT="${MODEL_REASONING_EFFORT:-}"

# External secret source (ADR-0003). Off by default: profiles keep the plain
# .env flow. Set AGENTHEON_SECRETS=bitwarden to emit a `secrets.bitwarden` block
# into every deity profile's config.yaml so provider keys live once in a Bitwarden
# project instead of duplicated per-profile. The access TOKEN is never written
# here — only the name of the env var that holds it (resolved from the shell at
# runtime); project_id/server_url come from env so no personal IDs are committed.
#
# TWO projects (ADR-0006). BWS_PROJECT_ID is the PROVIDERS project (LLM keys) and
# is emitted into every deity profile — it must hold NO platform secret. Platform
# tokens (SLACK_*, TELEGRAM_*) live in a SEPARATE gateway project, wired only into
# the default profile by hack/gateway.sh (BWS_GATEWAY_PROJECT_ID) — never here,
# because this block reaches every satellite and a shared platform token trips
# Hermes' one-credential-one-consumer guard. The two ids MUST differ.
SECRETS_BACKEND="${AGENTHEON_SECRETS:-}"                       # ""=off | bitwarden
BWS_PROJECT_ID="${BWS_PROJECT_ID:-}"                          # providers project (all deity profiles)
BWS_GATEWAY_PROJECT_ID="${BWS_GATEWAY_PROJECT_ID:-}"         # platform project (default gateway only; validated here, wired by gateway.sh)
BWS_SERVER_URL="${BWS_SERVER_URL:-https://vault.bitwarden.com}"
BWS_TOKEN_ENV="${BWS_TOKEN_ENV:-BWS_ACCESS_TOKEN}"

MODE="filedrop"   # filedrop | cli
DRY_RUN=0

OK="🟢"; INFO="🔵"; WARN="🟠"; KO="🔴"
SKILL="🧩"; CRON="⏰"; LINK="🔗"

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
                 --secrets bitwarden --bws-project-id UUID
  ./agentheon.sh --help

A secret source is REQUIRED. --secrets (or AGENTHEON_SECRETS) must be set, and
--secrets bitwarden also requires --bws-project-id (or BWS_PROJECT_ID). The
script errors out if either is missing.

Options:
  install        Install/refresh all profiles (default action).
  --no-cli       File-drop only; no hermes CLI required (default).
  --cli          Delegate to hack/gen-hermes-profiles.sh (needs hermes CLI).
  --dry-run, -n  Show what would happen; write nothing.
  --home DIR     Hermes home (default: $HERMES_HOME or ~/.hermes).
  --secrets NAME    (required) Secret source to wire in (same as AGENTHEON_SECRETS; "bitwarden").
  --bws-project-id UUID  (required with bitwarden) PROVIDERS project id (same as
                         BWS_PROJECT_ID); emitted into every deity profile;
                         implies --secrets bitwarden when given.
  --bws-gateway-project-id UUID  (optional) PLATFORM project id (same as
                         BWS_GATEWAY_PROJECT_ID). Holds Slack/Telegram secrets;
                         NOT injected into deity profiles — validated here (must
                         differ from --bws-project-id) and wired into the default
                         profile by hack/gateway.sh (ADR-0006).
  -h, --help     This help.

Env overrides (flags above take precedence):
  HERMES_HOME     profiles root parent               (default: ~/.hermes)
  MODEL_OPUS      provider/model for `model: opus`    (default: openrouter/meta/muse-spark-1.3)
  MODEL_SONNET    provider/model for `model: sonnet`  (default: openrouter/meta/muse-spark-1.3)
  MODEL_BASE_URL  OpenAI-compatible endpoint (model.base_url) (default: https://openrouter.ai/api/v1)
  MODEL_MAX_TOKENS per-request token ceiling (model.max_tokens) (default: 32768)
  MODEL_PROVIDER  global override for model.provider (unset: use opus/sonnet tier)
  MODEL_ID        global override for model.model, verbatim (unset: use tier)
  MODEL_DEFAULT   global override for model.default  (unset: falls back to MODEL_ID)
  MODEL_REASONING_EFFORT  global override for model.reasoning_effort (unset: per-agent)
  AGENTHEON_SECRETS  secret source to wire in          (required; "bitwarden")
  BWS_PROJECT_ID     Bitwarden PROVIDERS project id    (required if bitwarden)
  BWS_GATEWAY_PROJECT_ID  Bitwarden PLATFORM project id (optional; must differ
                     from BWS_PROJECT_ID; wired into default by gateway.sh)
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
    --secrets)    SECRETS_BACKEND="$2"; shift 2 ;;
    # Bitwarden project id via flag (overrides $BWS_PROJECT_ID) and, unless a
    # backend was already chosen, implies --secrets bitwarden so the flag alone
    # is enough: ./agentheon.sh --bws-project-id <uuid>.
    --bws-project-id) BWS_PROJECT_ID="$2"; SECRETS_BACKEND="${SECRETS_BACKEND:-bitwarden}"; shift 2 ;;
    # Platform (gateway) project id. Not injected into any deity profile — only
    # validated here (must differ from the providers project) and echoed as the
    # value to hand hack/gateway.sh, which wires it into the default profile.
    --bws-gateway-project-id) BWS_GATEWAY_PROJECT_ID="$2"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *)            echo "${KO} unknown argument: $1"; usage 1 ;;
  esac
done

# --- required secrets configuration ---------------------------------------
# A secret source is mandatory: the script refuses to run without one. Values
# may come from the flags (--secrets / --bws-project-id) or their env twins
# (AGENTHEON_SECRETS / BWS_PROJECT_ID); flags win. This is validated up front,
# before any profile is written or the --cli path is taken.
case "$SECRETS_BACKEND" in
  "")        echo "${KO} --secrets is required (e.g. --secrets bitwarden, or AGENTHEON_SECRETS=bitwarden)"; usage 1 ;;
  bitwarden) [[ -n "$BWS_PROJECT_ID" ]] || { echo "${KO} --bws-project-id is required with --secrets bitwarden (or set BWS_PROJECT_ID)"; usage 1; } ;;
  *)         echo "${KO} unknown --secrets '${SECRETS_BACKEND}' (supported: bitwarden)"; usage 1 ;;
esac

# Two-project guard (ADR-0006): the providers project (injected into every deity)
# must never be the same project as the platform/gateway project, or the platform
# tokens leak back into every profile and Hermes refuses to start the duplicate.
if [[ -n "$BWS_GATEWAY_PROJECT_ID" && "$BWS_GATEWAY_PROJECT_ID" == "$BWS_PROJECT_ID" ]]; then
  echo "${KO} BWS_GATEWAY_PROJECT_ID must differ from BWS_PROJECT_ID — the platform project cannot be the providers project (ADR-0006)"
  usage 1
fi

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

# big_five -> "Under Pressure" paragraph, driven by Neuroticism (composure) and
# Conscientiousness (whether the agent protects its checks when time is short).
# A behavioral section, not voice: how this agent acts when a gate is failing or
# the clock is against it. Derived so all agents stay consistent.
big_five_to_pressure() {
  local bf="$1" n c line
  n="$(printf '%s' "$bf" | grep -oE 'N[0-9]+' | tr -dc '0-9' || true)"
  c="$(printf '%s' "$bf" | grep -oE 'C[0-9]+' | tr -dc '0-9' || true)"
  if   [[ -n "$n" ]] && ((n<=20)); then line="You stay calm and deliberate — you slow down rather than speed up, check your assumptions, and rank the problems by evidence before acting."
  elif [[ -n "$n" ]] && ((n<=40)); then line="You keep a steady hand — you triage to the highest-risk item first and state what is still unknown before you commit."
  elif [[ -n "$n" ]] && ((n>=60)); then line="You can over-escalate — name the single most likely failure, act on that, and resist raising more alarms than the evidence supports."
  else                                   line="You prioritize the highest-risk item first and report what remains uncertain rather than forcing false certainty."
  fi
  [[ -n "$c" ]] && ((c>=85)) && line+=" You protect the checks that matter even when time is short — never skip a gate or a verification to finish faster."
  printf '%s' "$line"
}

# big_five + comm_style -> "Disagreement" paragraph, driven by Agreeableness
# (how directly the agent pushes back) with a provenance/formal modifier. Defines
# how this agent disputes another's output — central to review and the quality
# gates, where an agent must be able to say "no" well.
big_five_to_disagreement() {
  local bf="$1" cs="$2" a line
  a="$(printf '%s' "$bf" | grep -oE 'A[0-9]+' | tr -dc '0-9' || true)"
  if   [[ -n "$a" ]] && ((a<=40)); then line="You say so directly and early — name the exact claim you dispute and give the evidence or test that would settle it. You do not defer to rank or soften a real objection into a suggestion."
  elif [[ -n "$a" ]] && ((a>=60)); then line="You surface the objection plainly but kindly — state the specific point, show your reasoning, and leave the other agent room to respond. Warmth never means withholding the disagreement."
  else                                   line="You pinpoint the specific premise or step you dispute and propose how to resolve it — evidence, a test, or the decision's owner. You engage the argument, not the agent."
  fi
  [[ "$cs" =~ [Pp]rovenance|[Ss]trict|[Ff]ormal|[Rr]igorous ]] && line+=" You back the objection with evidence, never assertion."
  printf '%s' "$line"
}

# big_five -> "Blind Spots" bullets: the failure modes implied by this agent's
# trait extremes, each paired with the compensating correction. A self-aware
# limits section (the reference's "compensate deliberately"), so a persona carries
# its own guard-rails instead of forcing the user to discover them.
big_five_to_blindspots() {
  local bf="$1" o c e a n
  local -a out=()
  o="$(printf '%s' "$bf" | grep -oE 'O[0-9]+' | tr -dc '0-9' || true)"
  c="$(printf '%s' "$bf" | grep -oE 'C[0-9]+' | tr -dc '0-9' || true)"
  e="$(printf '%s' "$bf" | grep -oE 'E[0-9]+' | tr -dc '0-9' || true)"
  a="$(printf '%s' "$bf" | grep -oE 'A[0-9]+' | tr -dc '0-9' || true)"
  n="$(printf '%s' "$bf" | grep -oE 'N[0-9]+' | tr -dc '0-9' || true)"
  [[ -n "$o" ]] && ((o>=85)) && out+=("High openness can scatter focus — resist redesigning what already works; change only what the task needs.")
  [[ -n "$o" ]] && ((o<=55)) && out+=("Low openness can reject the unfamiliar too fast — give a novel approach a fair hearing before dismissing it.")
  [[ -n "$c" ]] && ((c>=90)) && out+=("High conscientiousness can tip into gold-plating — stop at the acceptance criteria; done beats perfect.")
  [[ -n "$e" ]] && ((e<=35)) && out+=("Low expressiveness can under-communicate — say what you did and why, even when it feels obvious to you.")
  [[ -n "$e" ]] && ((e>=75)) && out+=("High expressiveness can over-explain — lead with the answer, then keep the context short.")
  [[ -n "$a" ]] && ((a<=40)) && out+=("Low agreeableness can read as cold or combative — keep the judgment, lose the edge.")
  [[ -n "$a" ]] && ((a>=75)) && out+=("High agreeableness can dodge hard truths — say the uncomfortable thing when the work needs it.")
  [[ -n "$n" ]] && ((n<=15)) && out+=("Very low anxiety can underweight real risk — actively look for what could go wrong before declaring done.")
  [[ ${#out[@]} -eq 0 ]] && out+=("Your traits are balanced — the main risk is drifting toward generic output; keep your domain's specific judgment sharp.")
  printf '%s\n' "${out[@]}"
}

# Extract the injectable section of the shared baseline safety contract
# (team/baseline-contract.md) — everything between the CONTRACT:BEGIN/END
# markers, so every agent's SOUL.md carries the identical "Non-Negotiable
# Boundaries" block, edited in one place. Empty (section omitted) if the file is
# absent, so the generator never hard-fails on a missing contract.
BASELINE_CONTRACT="${TEAM_DIR}/baseline-contract.md"
baseline_contract() {
  [[ -f "$BASELINE_CONTRACT" ]] || return 0
  awk '/CONTRACT:BEGIN/ { f=1; next } /CONTRACT:END/ { f=0 } f' "$BASELINE_CONTRACT"
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

# Build the shared "Targets" block from team/cron-targets.yaml — the single
# source of truth for which GitHub owners the crons operate over and how each is
# scoped. Every cron carries a `{{TARGETS}}` placeholder that install_crons
# replaces with this block, so the owner list is never duplicated across crons.
# `all`-scoped owners are used whole; `active`-scoped owners are narrowed at run
# time to non-archived, non-fork repos pushed within active_window_days, so the
# crons never spend budget on a personal account's dormant repos.
resolve_targets() {
  [[ -f "$CRON_TARGETS" ]] || { echo "   ${WARN} $CRON_TARGETS missing — crons keep {{TARGETS}} unexpanded" >&2; return 1; }
  local window rows owner scope
  window="$(awk -F': *' '/^active_window_days:/ {print $2; exit}' "$CRON_TARGETS")"
  window="${window:-180}"
  # owner: scope pairs indented under the `owners:` key.
  rows="$(awk '
    /^owners:/ { inb=1; next }
    inb && /^[A-Za-z]/ { inb=0 }
    inb && /^[ \t]+[A-Za-z0-9_-]+:/ { gsub(/[ \t]/, ""); print }' "$CRON_TARGETS")"
  [[ -z "$rows" ]] && { echo "   ${WARN} no owners in $CRON_TARGETS" >&2; return 1; }

  local table="" has_active=0
  while IFS=: read -r owner scope; do
    [[ -z "$owner" ]] && continue
    if [[ "$scope" == active ]]; then
      table+="| ${owner} | active repos only |"$'\n'
      has_active=1
    else
      table+="| ${owner} | all non-archived repos |"$'\n'
    fi
  done <<< "$rows"

  printf '%s\n' "## Targets — the GitHub owners this cron operates over"
  printf '%s\n\n' "Apply this scope to every GitHub query below. Do not widen it."
  printf '%s\n' "| Owner | Scope |"
  printf '%s\n' "|-------|-------|"
  printf '%s' "$table"
  [[ "$has_active" == 1 ]] && {
    printf '\n%s\n' "\"Active\" = non-archived, non-fork, pushed within the last ${window} days. For"
    printf '%s\n\n' "each active-scoped owner, resolve its active set ONCE at the start of the run:"
    printf '%s\n' '```'
    printf '%s\n' "gh repo list <owner> --no-archived --source --limit 300 --json name,pushedAt \\"
    printf '%s\n' "  --jq \"[.[] | select(.pushedAt >= (now - ${window}*86400 | strftime(\\\"%Y-%m-%dT%H:%M:%SZ\\\"))) | .name]\""
    printf '%s\n\n' '```'
    printf '%s\n' "Applying the scope:"
    printf '%s\n' "- Steps that list repos per owner (\`gh repo list <owner> ...\`): for an"
    printf '%s\n' "  active-scoped owner use only repos in its active set; for an all-scoped"
    printf '%s\n' "  owner use every non-archived repo as written."
    printf '%s\n' "- Steps that use \`gh search ... --owner <o>\`: gh search cannot restrict an"
    printf '%s\n' "  owner to a subset, so keep the --owner flags, then DROP any result whose"
    printf '%s\n' "  repo belongs to an active-scoped owner but is not in that owner's active set."
  }
}

TARGETS_BLOCK="$(resolve_targets)" || TARGETS_BLOCK=""

# Install an agent's scheduled tasks (agents/<slug>/crons/*.md). Each is a
# portable spec written to $HERMES_HOME/crons/<name>.yaml (schedule + skill +
# delivery channel + the verbatim prompt) and, when the hermes CLI is present,
# registered with the runtime as that agent via `hermes -p <slug> cron create`.
# The owning agent is the profile this cron lives under — never a frontmatter
# field. Without the CLI the spec is written and the register step is skipped
# with a warning (the same policy as aliases). The `{{TARGETS}}` placeholder in
# each prompt is expanded to the shared targets block (see resolve_targets).
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
    # Expand the shared {{TARGETS}} placeholder into the self-contained targets
    # block so the runtime prompt carries the owner scope without a file include.
    if [[ "$cprompt" == *'{{TARGETS}}'* ]]; then
      if [[ -n "$TARGETS_BLOCK" ]]; then
        cprompt="${cprompt//\{\{TARGETS\}\}/$TARGETS_BLOCK}"
      else
        echo "   ${WARN} cron '${cname}' has {{TARGETS}} but targets could not be resolved"
      fi
    fi

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
  echo "${INFO} secret source: bitwarden providers project ${BWS_PROJECT_ID} (token env ${BWS_TOKEN_ENV}) → emitted into every deity config.yaml"
  if [[ -n "$BWS_GATEWAY_PROJECT_ID" ]]; then
    echo "${INFO} platform project ${BWS_GATEWAY_PROJECT_ID} → wire into the default profile with:"
    echo "        BWS_GATEWAY_PROJECT_ID=${BWS_GATEWAY_PROJECT_ID} hack/gateway.sh install"
  else
    echo "${WARN} no BWS_GATEWAY_PROJECT_ID given — platform tokens (Slack/Telegram) are wired separately via hack/gateway.sh (ADR-0006)"
  fi
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

  # Global override (MODEL_PROVIDER/MODEL_ID/MODEL_DEFAULT/MODEL_REASONING_EFFORT):
  # layered on top of the tier resolution, per key. MODEL_ID is used verbatim (it
  # may contain slashes, e.g. google/gemma-4-31b-it:free) — NOT run through
  # split_model. Unset keys keep the tier/frontmatter value.
  [[ -n "$MODEL_PROVIDER" ]] && provider="$MODEL_PROVIDER"
  [[ -n "$MODEL_ID" ]]       && model="$MODEL_ID"
  model_default="${MODEL_DEFAULT:-${MODEL_ID:-$model}}"

  title="$(fm_scalar "$file" title)"
  domain="$(fm_scalar "$file" domain)"
  tagline="$(fm_scalar "$file" tagline)"
  tone="$(fm_scalar "$file" tone)"
  archetype="$(fm_scalar "$file" archetype)"
  big_five="$(fm_scalar "$file" big_five)"
  comm_style="$(fm_scalar "$file" comm_style)"
  default="$(fm_scalar "$file" default)"
  reasoning="$(fm_scalar "$file" reasoning)"; reasoning="${reasoning:-medium}"
  [[ -n "$MODEL_REASONING_EFFORT" ]] && reasoning="$MODEL_REASONING_EFFORT"
  # An explicit `toolsets:` frontmatter list is honored verbatim and bypasses
  # map_toolsets (which force-injects hermes-cli + memory). Use it to build a
  # least-privilege profile — e.g. an orchestrator that must ONLY delegate and
  # read, never run CLI/git. Absent the override, derive from `tools:` as before.
  mapfile -t toolset_override < <(fm_list "$file" toolsets)
  if [[ ${#toolset_override[@]} -gt 0 ]]; then
    toolsets="${toolset_override[*]}"
  else
    mapfile -t toolset_arr < <(fm_list "$file" tools)
    toolsets="$(printf '%s\n' "${toolset_arr[@]}" | map_toolsets)"
  fi
  mapfile -t does      < <(fm_list "$file" does)
  mapfile -t does_not  < <(fm_list "$file" does_not)
  mapfile -t handoffs  < <(fm_list "$file" handoffs)
  mapfile -t skills    < <(fm_list "$file" skills)
  mapfile -t aliases   < <(fm_list "$file" aliases)

  pdir="${PROFILES_DIR}/${slug}"

  # Register with the CLI FIRST, so Hermes creates the profile dir and its
  # identity file before anything else populates it. Hermes refuses
  # `profile create` when the target dir already exists without an identity file
  # ("carries no profile identity file … Move or remove that directory first"),
  # so vendoring skills or making the dir beforehand would break a fresh install.
  if [[ "$HAVE_HERMES" == 1 ]]; then
    if hermes profile list 2>/dev/null | grep -qw "$slug"; then
      :
    else
      # Not a registered profile. A dir here is orphaned scaffolding from an
      # interrupted run — Hermes has no identity file for it and refuses to
      # create over it. Everything in it is regenerated below, so move it aside
      # (non-destructive) and create cleanly.
      if [[ -e "$pdir" ]]; then
        if [[ "$DRY_RUN" == 1 ]]; then
          echo "   would: mv ${pdir} → ${pdir}.orphan.<ts> (unregistered leftover)"
        else
          bak="${pdir}.orphan.$(date +%Y%m%d%H%M%S)"
          mv "$pdir" "$bak"
          echo "   ${WARN} moved unregistered ${slug} dir aside → ${bak}"
        fi
      fi
      run hermes profile create "$slug" --description "${domain} — ${tagline}"
    fi
  fi

  # Ensure the dir exists for the file-drop-only path (no hermes CLI) and for
  # idempotent re-runs; a no-op right after `profile create`.
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
  default: ${model_default}
  base_url: ${MODEL_BASE_URL}
  max_tokens: ${MODEL_MAX_TOKENS}
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
    if [[ -n "$big_five" ]]; then
      echo "## Under Pressure"
      big_five_to_pressure "$big_five"
      printf '\n\n'
      echo "## Disagreement"
      big_five_to_disagreement "$big_five" "$comm_style"
      printf '\n\n'
      echo "## Blind Spots"
      echo "A strong persona carries its own limits so the user never has to discover them. Watch for these and compensate:"
      big_five_to_blindspots "$big_five" | sed 's/^/- /'
      echo
    fi
    echo "## Defaults"
    if [[ -n "$default" ]]; then
      echo "${default}"
    else
      echo "When a request is ambiguous, lead with your most likely reading, state the assumption in one line, and proceed — ask only when the ambiguity would change the outcome."
    fi
    contract="$(baseline_contract)"
    if [[ -n "$contract" ]]; then
      echo
      printf '%s\n' "$contract"
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

# --- shared secrets for profiles ------------------------------------------
# Point every named profile's .env at ONE shared env file
# ($HERMES_HOME/.shared-secrets.env). Named profiles load only their own
# profiles/<slug>/.env (never the root .env), so without this a plaintext
# provider key has to be duplicated per profile. Symlinking each profile's
# .env to a single shared file lets one plaintext env serve them all — the
# plaintext counterpart to the Bitwarden block above (ADR-0003). The shared
# file itself is never written here; create it with your keys out of band.
SHARED_SECRETS="${HOME_DIR}/.shared-secrets.env"
echo
echo "${INFO} linking profile .env → ${SHARED_SECRETS}"
[[ -e "$SHARED_SECRETS" ]] || echo "   ${WARN} ${SHARED_SECRETS} does not exist yet — links dangle until you create it"
for d in "${PROFILES_DIR}"/*/; do
  [[ -d "$d" ]] || continue
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "   would: ln -sf ${SHARED_SECRETS} ${d}.env"
  else
    ln -sf "$SHARED_SECRETS" "${d}.env"
    echo "   ${LINK} $(basename "$d")/.env → shared-secrets"
  fi
done

# Guard: platform tokens must NOT live in the shared file (ADR-0006). The shared
# env is symlinked into every satellite profile, so a SLACK_/TELEGRAM_ token
# placed here is consumed by every deity at once — Hermes' multiplex gateway then
# refuses to start ("one credential cannot be consumed twice"). Outbound
# messaging is Zeus's job alone; platform tokens belong only in the default
# profile env ($HERMES_HOME/.env). Flag a leak loudly (non-fatal — the operator
# owns this file).
if [[ -e "$SHARED_SECRETS" ]]; then
  leaked="$(grep -oiE '\b(SLACK|TELEGRAM)_[A-Z_]+' "$SHARED_SECRETS" 2>/dev/null \
    | tr '[:lower:]' '[:upper:]' | sort -u | paste -sd, - || true)"
  if [[ -n "$leaked" ]]; then
    echo
    echo "${KO} platform token(s) in ${SHARED_SECRETS}: ${leaked}"
    echo "   The shared env feeds EVERY profile, so a messaging token here makes"
    echo "   each deity configure the platform and the multiplex gateway refuses"
    echo "   to start (one credential cannot be consumed twice — ADR-0006)."
    echo "   Move it to the default profile env: ${HOME_DIR}/.env"
  fi
fi

echo
echo "Next:"
if [[ "$SECRETS_BACKEND" == "bitwarden" ]]; then
  echo "  export ${BWS_TOKEN_ENV}=...    # bootstrap token in your shell (never committed)"
  echo "  # add a provider = add a named secret (e.g. XAI_API_KEY) in Bitwarden project ${BWS_PROJECT_ID}"
else
  echo "  hermes -p <name> setup    # add API keys (.env)"
fi
echo "  \$EDITOR ${HOME_DIR}/.shared-secrets.env   # provider/LLM keys shared by every profile (symlinked)"
echo "  \$EDITOR ${HOME_DIR}/.env                   # default profile: platform tokens (SLACK_*/TELEGRAM_*) live here ONLY — ADR-0006"
echo "  hermes -p <name> chat     # run the agent"
echo "  hermes profile list       # see them all"
