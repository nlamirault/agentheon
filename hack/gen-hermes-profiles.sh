#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gen-hermes-profiles.sh — turn each Agentheon agent (agents/*/README.md) into a
# Hermes agent profile (https://hermes-agent.nousresearch.com).
#
# Tested against Hermes Agent v0.20.5. For every agent it:
#   1. creates a profile home under $HERMES_HOME/profiles/<name>
#   2. sets model, toolsets, reasoning, and skills in config.yaml
#   3. writes the profile's SOUL.md — identity ONLY (who it is, how it speaks,
#      what it avoids: Identity / Style / Avoid / Defaults), per the Hermes SOUL
#      guide; persona fields are translated into prose voice
#   4. writes AGENTS.md — the project operating guide (scope, handoff routes,
#      shared-context pointers, skills, finalization gate, agent body); this is
#      where the SOUL guide says project mechanics belong, not in SOUL.md
#      Both use a managed block so hand-edits OUTSIDE it survive regeneration
#   5. records domain + tagline as the profile --description (kanban routing)
# It also seeds the shared team context (team/company.md) into
# $HERMES_HOME/team/company/agentheon.md, which every SOUL.md points to.
#
# Safe regen: content between the AGENTHEON:BEGIN/END markers is regenerated;
# anything you add below the block is preserved. A SOUL.md with no markers is
# backed up to SOUL.md.bak before the block is prepended.
#
# Secrets (.env) are NEVER touched — add keys via `hermes -p <name> setup`.
#
# Env overrides:
#   HERMES_HOME       profiles root parent (default: ~/.hermes)
#   MODEL_OPUS        concrete id for `model: opus`   (default: openrouter/meta/muse-spark-1.3)
#   MODEL_SONNET      concrete id for `model: sonnet` (default: openrouter/meta/muse-spark-1.3)
#   MODEL_BASE_URL    OpenAI-compatible endpoint       (default: https://openrouter.ai/api/v1)
#   NO_ALIAS=1        pass --no-alias (skip ~/.local/bin wrapper scripts)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
TEAM_DIR="${ROOT}/team"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
COMPANY_DIR="${HOME_DIR}/team/company"

MODEL_OPUS="${MODEL_OPUS:-openrouter/meta/muse-spark-1.3}"
MODEL_SONNET="${MODEL_SONNET:-openrouter/meta/muse-spark-1.3}"
MODEL_BASE_URL="${MODEL_BASE_URL:-https://openrouter.ai/api/v1}"

command -v hermes >/dev/null 2>&1 || { echo "✗ hermes CLI not found — install Hermes Agent first"; exit 1; }

# --- frontmatter helpers --------------------------------------------------

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

fm_tools() { fm_list "$1" tools; }
agent_body() { awk '/^---$/ { c++; next } c>=2 { print }' "$1"; }

# Claude Code tool names -> Hermes toolsets (deduped, hermes-cli always first).
map_toolsets() {
  local t hs; declare -A seen=([hermes-cli]=1); local out="hermes-cli"
  while read -r t; do
    case "$t" in
      Read|Write|Edit|Glob|Grep) hs="files" ;;
      Bash)                       hs="shell" ;;
      Task)                       hs="orchestration" ;;
      Web*|WebFetch|WebSearch)    hs="web" ;;
      *)                          hs="files" ;;
    esac
    [[ -n "${seen[$hs]:-}" ]] && continue
    seen[$hs]=1; out+=",${hs}"
  done
  [[ -n "${seen[memory]:-}" ]] || out+=",memory"
  printf '%s' "$out"
}

profile_exists() { hermes profile list 2>/dev/null | grep -qw "$1"; }

# --- persona derivation: frontmatter traits -> SOUL voice -----------------
# SOUL.md is identity (who the agent is, how it speaks, what it avoids). These
# helpers turn the machine-readable persona fields into prose voice; project
# mechanics are kept OUT of SOUL.md and written to AGENTS.md instead.

# Dot-joined tokens -> spaced, lower-cased prose. "Decisive.Regal.Sparse" ->
# "decisive, regal, sparse"; "NoFiller" -> "no filler".
humanize_tokens() {
  printf '%s' "$1" | sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' -e 's/\./, /g' \
    | tr '[:upper:]' '[:lower:]'
}

# "O70 C90 E65 A40 N15" -> voice traits. Only clearly high (>=60) or low (<=40)
# dimensions become traits; mid values stay unsaid so the voice reads specific.
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

# comm_style + big_five -> stylistic "Avoid" bullets (voice only). Always yields
# at least one bullet.
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

# --- pass 1: build the sibling lookup used to render handoff routes --------

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

# Generated routing matrix — Hermes' machine-readable assignment table.
build_routing() {
  echo "<!-- Generated by hack/gen-hermes-profiles.sh — do not edit; regenerated on every run. -->"
  echo "# Agentheon — Routing Matrix"
  echo
  echo "Zeus uses this to route work. Ordered by role; hand-offs per agent."
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
  if [[ -f "$soul" ]] && grep -q "AGENTHEON:BEGIN" "$soul" && grep -q "AGENTHEON:END" "$soul"; then
    # Managed block present: regenerate it in place, preserve everything else.
    awk -v genf="$gen" '
      BEGIN { while ((getline l < genf) > 0) g = g l "\n" }
      /AGENTHEON:BEGIN/ { printf "%s", g; skip=1; next }
      /AGENTHEON:END/   { skip=0; next }
      !skip { print }' "$soul" > "$soul.tmp" && mv "$soul.tmp" "$soul"
  elif [[ ! -f "$soul" ]] || grep -q "created by Nous Research" "$soul"; then
    # No SOUL.md yet, or the pristine Hermes default — write ours outright.
    { cat "$gen"; echo; echo "<!-- Add hand-written guidance below this line; it survives regeneration. -->"; } > "$soul"
  else
    # A hand-written SOUL.md with no markers: back it up and preserve it below.
    cp "$soul" "$soul.bak"
    { cat "$gen"; echo; echo "<!-- Custom additions preserved from your previous SOUL.md (backup: SOUL.md.bak). -->"; echo; cat "$soul.bak"; } > "$soul"
  fi
}

# AGENTS.md is entirely ours (project mechanics) — no pristine-Hermes default to
# detect, so just regenerate the managed block and preserve hand edits outside it.
write_agents() { # pdir  gen-block-file
  local f="$1/AGENTS.md" gen="$2"
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
  mkdir -p "$COMPANY_DIR"
  cp "$TEAM_DIR"/*.md "$COMPANY_DIR"/ 2>/dev/null || true
  build_routing > "$COMPANY_DIR/routing.md"
  echo "🔵 seeded shared context → ${COMPANY_DIR}/ (company, workflow, handoff-template, routing)"
fi

# --- pass 2: create/update each profile -----------------------------------

[[ "${NO_ALIAS:-0}" == 1 ]] && extra_create=(--no-alias) || extra_create=()

for file in "${AGENTS_DIR}"/*/README.md; do
  name="$(fm_scalar "$file" name)"
  [[ -z "$name" ]] && { echo "⚠  no name in $file, skipping"; continue; }

  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

  case "$(fm_scalar "$file" model)" in
    opus)   model="$MODEL_OPUS" ;;
    sonnet) model="$MODEL_SONNET" ;;
    *)      model="$(fm_scalar "$file" model)" ;;
  esac

  title="$(fm_scalar "$file" title)"
  domain="$(fm_scalar "$file" domain)"
  tagline="$(fm_scalar "$file" tagline)"
  tone="$(fm_scalar "$file" tone)"
  archetype="$(fm_scalar "$file" archetype)"
  big_five="$(fm_scalar "$file" big_five)"
  comm_style="$(fm_scalar "$file" comm_style)"
  default="$(fm_scalar "$file" default)"
  reasoning="$(fm_scalar "$file" reasoning)"
  # An explicit `toolsets:` frontmatter list is honored verbatim and bypasses
  # map_toolsets (which force-injects hermes-cli). Use it to build a
  # least-privilege profile — e.g. Zeus or an executive that must ONLY delegate
  # and read, never run the CLI/git. Absent the override, derive from `tools:`.
  mapfile -t toolset_override < <(fm_list "$file" toolsets)
  if [[ ${#toolset_override[@]} -gt 0 ]]; then
    toolsets="${toolset_override[*]}"
  else
    toolsets="$(fm_tools "$file" | map_toolsets)"
  fi
  mapfile -t does      < <(fm_list "$file" does)
  mapfile -t does_not  < <(fm_list "$file" does_not)
  mapfile -t handoffs  < <(fm_list "$file" handoffs)
  mapfile -t skills    < <(fm_list "$file" skills)
  mapfile -t aliases   < <(fm_list "$file" aliases)

  if profile_exists "$slug"; then
    echo "ℹ  profile '$slug' exists — updating in place"
  else
    hermes profile create "$slug" "${extra_create[@]}" --description "$domain — $tagline" >/dev/null
  fi

  # Register frontmatter aliases as alternate names for this profile.
  if [[ ${#aliases[@]} -gt 0 ]]; then
    for a in "${aliases[@]}"; do
      hermes profile alias "$slug" --name "$a" >/dev/null 2>&1 \
        || echo "⚠  alias '$a' → '$slug' not set (already exists?)"
    done
  fi

  hermes -p "$slug" config set model "$model" >/dev/null
  hermes -p "$slug" config set base_url "$MODEL_BASE_URL" >/dev/null
  hermes -p "$slug" config set toolsets "$toolsets" >/dev/null
  [[ -n "$reasoning" ]] && hermes -p "$slug" config set reasoning "$reasoning" --force >/dev/null
  [[ ${#skills[@]} -gt 0 ]] && hermes -p "$slug" config set skills "$(IFS=,; echo "${skills[*]}")" --force >/dev/null

  # Every deity is a SATELLITE profile: the single gateway that fires and delivers
  # crons runs on the `default` profile as a multiplexer (see ADR-0005). Pin each
  # deity's own gateway off so it shares the default listener and never tries to
  # bind its own platforms — Hermes refuses a second per-profile gateway while the
  # multiplexer serves it, and this makes the intent explicit in config.yaml.
  hermes -p "$slug" config set gateway.enabled false --force >/dev/null

  pdir="$(dirname "$(hermes -p "$slug" config path 2>/dev/null)")"

  # SOUL.md — identity only (Identity / Style / Avoid / Defaults), per the Hermes
  # SOUL guide. Persona frontmatter is translated into prose voice; project
  # mechanics go to AGENTS.md below.
  voice="$(big_five_to_voice "$big_five")"
  arche="$(humanize_tokens "$archetype")"
  comm="$(humanize_tokens "$comm_style")"
  gen="$(mktemp)"
  {
    echo "<!-- AGENTHEON:BEGIN — generated from agents/${slug}/README.md by hack/gen-hermes-profiles.sh; do not edit inside this block, it is overwritten. -->"
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
    echo "<!-- AGENTHEON:BEGIN — generated from agents/${slug}/README.md by hack/gen-hermes-profiles.sh; do not edit inside this block, it is overwritten. -->"
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
    # Finalization gate — every profile self-checks before returning a result.
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

  echo "🟢 ${name} → ${pdir}  (model=${model}, reasoning=${reasoning:-default}, toolsets=${toolsets}${aliases:+, aliases=$(IFS=,; echo "${aliases[*]}")})"
done

echo
echo "Next:"
echo "  hermes -p <name> setup    # add API keys (.env)"
echo "  hermes -p <name> chat     # run the agent"
echo "  hermes profile list       # see them all"
