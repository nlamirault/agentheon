#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gen-hermes-profiles.sh — turn each Agentheon agent (agents/*.md) into a
# Hermes agent profile (https://hermes-agent.nousresearch.com).
#
# Tested against Hermes Agent v0.20.5. For every agent it:
#   1. creates a profile home under $HERMES_HOME/profiles/<name>
#   2. sets the model + toolsets in that profile's config.yaml
#   3. overwrites the profile's SOUL.md with the agent's persona/instructions
#   4. records the tagline as the profile --description (kanban role routing)
#
# Secrets (.env) are NEVER touched — add keys via `hermes -p <name> setup`.
#
# Env overrides:
#   HERMES_HOME       profiles root parent (default: ~/.hermes)
#   MODEL_OPUS        concrete id for `model: opus`   (default: anthropic/claude-opus)
#   MODEL_SONNET      concrete id for `model: sonnet` (default: anthropic/claude-sonnet)
#   HERMES_RESERVED   replacement for the reserved name "hermes" (default: hermes-agent)
#   NO_ALIAS=1        pass --no-alias (skip ~/.local/bin wrapper scripts)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"

MODEL_OPUS="${MODEL_OPUS:-anthropic/claude-opus}"
MODEL_SONNET="${MODEL_SONNET:-anthropic/claude-sonnet}"
HERMES_RESERVED="${HERMES_RESERVED:-hermes-agent}"

command -v hermes >/dev/null 2>&1 || { echo "✗ hermes CLI not found — install Hermes Agent first"; exit 1; }

# --- frontmatter helpers --------------------------------------------------

fm_scalar() { # file key -> first scalar value, quotes stripped
  awk -v k="$2" '
    /^---$/ { c++; next }
    c==1 && $0 ~ "^"k":" { sub("^"k":[ \t]*", ""); gsub(/^"|"$/, ""); print; exit }' "$1"
}

fm_tools() { # file -> one Claude-tool name per line
  awk '
    /^---$/ { c++; next }
    c==1 && /^tools:/ { intools=1; next }
    c==1 && intools && /^[a-zA-Z]/ { intools=0 }
    c==1 && intools && /^[ \t]*-[ \t]*/ { sub(/^[ \t]*-[ \t]*/, ""); gsub(/^"|"$/, ""); print }' "$1"
}

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

# --- main -----------------------------------------------------------------

[[ "${NO_ALIAS:-0}" == 1 ]] && extra_create=(--no-alias) || extra_create=()

shopt -s nullglob
for file in "${AGENTS_DIR}"/*.md; do
  name="$(fm_scalar "$file" name)"
  [[ -z "$name" ]] && { echo "⚠  no name in $file, skipping"; continue; }

  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  [[ "$slug" == "hermes" ]] && { slug="$HERMES_RESERVED"; echo "ℹ  '$name' → profile '$slug' (name 'hermes' is reserved)"; }

  case "$(fm_scalar "$file" model)" in
    opus)   model="$MODEL_OPUS" ;;
    sonnet) model="$MODEL_SONNET" ;;
    *)      model="$(fm_scalar "$file" model)" ;;
  esac

  tagline="$(fm_scalar "$file" tagline)"
  domain="$(fm_scalar "$file" domain)"
  title="$(fm_scalar "$file" title)"
  toolsets="$(fm_tools "$file" | map_toolsets)"

  if profile_exists "$slug"; then
    echo "ℹ  profile '$slug' exists — updating in place"
  else
    hermes profile create "$slug" "${extra_create[@]}" --description "$domain — $tagline" >/dev/null
  fi

  hermes -p "$slug" config set model "$model" >/dev/null
  hermes -p "$slug" config set toolsets "$toolsets" >/dev/null

  # Resolve the profile's real directory from its config path and drop SOUL.md.
  cfg="$(hermes -p "$slug" config path 2>/dev/null)"
  pdir="$(dirname "$cfg")"
  {
    echo "# ${name} — ${title}"
    echo
    echo "**Domain:** ${domain}"
    echo
    echo "> ${tagline}"
    echo
    agent_body "$file"
  } > "${pdir}/SOUL.md"

  echo "🟢 ${name} → ${pdir}  (model=${model}, toolsets=${toolsets})"
done

echo
echo "Next:"
echo "  hermes -p <name> setup    # add API keys (.env)"
echo "  hermes -p <name> chat     # run the agent"
echo "  hermes profile list       # see them all"
