# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

# lib-frontmatter.sh — shared YAML-frontmatter readers and persona derivation for
# the agent tooling. Source it; do not execute. Parsers are intentionally small:
# the frontmatter is machine-generated-friendly (one scalar or list per key, no
# nesting). The persona helpers turn the machine-readable persona fields
# (archetype, big_five, comm_style) into SOUL.md prose and behavioral sections;
# they are the single source of truth for both generators (agentheon.sh file-drop
# path and hack/gen-hermes-profiles.sh CLI path), so a change lands in one place.

# fm_scalar FILE KEY -> first scalar value for KEY, surrounding quotes stripped.
fm_scalar() {
  awk -v k="$2" '
    /^---$/ { c++; next }
    c==1 && $0 ~ "^"k":" { sub("^"k":[ \t]*", ""); gsub(/^"|"$/, ""); print; exit }' "$1"
}

# fm_list FILE KEY -> one YAML list item per line, surrounding quotes stripped.
fm_list() {
  awk -v k="$2" '
    /^---$/ { c++; next }
    c==1 && $0 ~ "^"k":" { inlist=1; next }
    c==1 && inlist && /^[a-zA-Z]/ { inlist=0 }
    c==1 && inlist && /^[ \t]*-[ \t]*/ { sub(/^[ \t]*-[ \t]*/, ""); gsub(/^"|"$/, ""); print }' "$1"
}

# fm_tools FILE -> the `tools:` list, one per line.
fm_tools() { fm_list "$1" tools; }

# agent_body FILE -> everything after the frontmatter block (the prose body).
agent_body() { awk '/^---$/ { c++; next } c>=2 { print }' "$1"; }

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
# Boundaries" block, edited in one place. The path resolves at call time from
# $BASELINE_CONTRACT if the caller set it, else from $TEAM_DIR; empty (section
# omitted) if the file is absent, so the generator never hard-fails on a missing
# contract.
baseline_contract() {
  local cf="${BASELINE_CONTRACT:-${TEAM_DIR:-}/baseline-contract.md}"
  [[ -f "$cf" ]] || return 0
  awk '/CONTRACT:BEGIN/ { f=1; next } /CONTRACT:END/ { f=0 } f' "$cf"
}
