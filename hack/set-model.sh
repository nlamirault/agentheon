#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# set-model.sh — set the `model:` block in config.yaml for EVERY Hermes profile:
# the `default` profile ($HERMES_HOME/config.yaml) and every named deity profile
# ($HERMES_HOME/profiles/<slug>/config.yaml).
#
# It writes the nested keys via `hermes config set model.<key>`, so the result is:
#
#   model:
#     provider: openrouter
#     model: meta/muse-spark-1.3
#     reasoning_effort: high
#     default: meta/muse-spark-1.3
#     base_url: https://openrouter.ai/api/v1
#
# Using `hermes config set` (not a raw YAML patch) keeps this consistent with the
# rest of hack/ and lets Hermes own the schema. Named profiles are discovered by
# directory ($HERMES_HOME/profiles/*), so a profile with no config.yaml yet still
# gets one created by the first `set`.
#
# Usage:
#   hack/set-model.sh                 # apply to default + all named profiles
#   hack/set-model.sh --dry-run       # print what would change, touch nothing
#   hack/set-model.sh -p zeus         # apply to ONE named profile only
#   hack/set-model.sh --default-only  # apply to the default profile only
#   hack/set-model.sh help
#
# Env overrides (defaults shown):
#   MODEL_PROVIDER           openrouter
#   MODEL_ID                 meta/muse-spark-1.3
#   MODEL_REASONING_EFFORT   high
#   MODEL_DEFAULT            meta/muse-spark-1.3
#   MODEL_BASE_URL           https://openrouter.ai/api/v1
#   HERMES_HOME              profiles root parent (default: ~/.hermes)
#   NO_COLOR=1               disable ANSI colour (also auto-off when not a tty)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PROFILES_DIR="${HOME_DIR}/profiles"

MODEL_PROVIDER="${MODEL_PROVIDER:-openrouter}"
MODEL_ID="${MODEL_ID:-meta/muse-spark-1.3}"
MODEL_REASONING_EFFORT="${MODEL_REASONING_EFFORT:-high}"
MODEL_DEFAULT="${MODEL_DEFAULT:-meta/muse-spark-1.3}"
MODEL_BASE_URL="${MODEL_BASE_URL:-https://openrouter.ai/api/v1}"

# --- colour -----------------------------------------------------------------
if [[ -t 1 && "${NO_COLOR:-0}" != 1 ]]; then
  B=$'\033[1m'; CYAN=$'\033[36m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; R=$'\033[0m'
else
  B=""; CYAN=""; GRN=""; YEL=""; RED=""; R=""
fi

die()  { echo "${RED}error:${R} $*" >&2; exit 1; }
warn() { echo "${YEL}⚠${R}  $*" >&2; }
info() { echo "${CYAN}ℹ${R}  $*"; }
ok()   { echo "${GRN}✓${R}  $*"; }

command -v hermes >/dev/null 2>&1 || die "hermes CLI not found — install Hermes Agent first"

DRY_RUN=0

# The five keys of the model block, in the order they appear in config.yaml.
MODEL_KEYS=(provider model reasoning_effort default base_url)
model_val() {
  case "$1" in
    provider)         printf '%s' "$MODEL_PROVIDER" ;;
    model)            printf '%s' "$MODEL_ID" ;;
    reasoning_effort) printf '%s' "$MODEL_REASONING_EFFORT" ;;
    default)          printf '%s' "$MODEL_DEFAULT" ;;
    base_url)         printf '%s' "$MODEL_BASE_URL" ;;
  esac
}

# apply_model <label> [-p <slug>]  — set the whole model block for one profile.
# Pass no -p flag for the default profile.
apply_model() {
  local label="$1"; shift
  local k v
  for k in "${MODEL_KEYS[@]}"; do
    v="$(model_val "$k")"
    if [[ "$DRY_RUN" == 1 ]]; then
      printf '   %smodel.%s%s = %s\n' "$CYAN" "$k" "$R" "$v"
    else
      hermes "$@" config set "model.$k" "$v" --force >/dev/null
    fi
  done
  if [[ "$DRY_RUN" == 1 ]]; then
    info "would update ${B}${label}${R}"
  else
    ok "updated ${B}${label}${R}"
  fi
}

# named_profiles — slugs of every named profile, discovered by directory.
named_profiles() {
  local d
  shopt -s nullglob
  for d in "${PROFILES_DIR}"/*/; do
    printf '%s\n' "$(basename "$d")"
  done
}

apply_default() { apply_model "default" ; }

apply_named() {
  local slug found=0
  while read -r slug; do
    [[ -z "$slug" ]] && continue
    found=1
    apply_model "$slug" -p "$slug"
  done < <(named_profiles)
  [[ "$found" == 0 ]] && warn "no named profiles under ${PROFILES_DIR} — run hack/gen-hermes-profiles.sh first"
  return 0
}

usage() {
  awk '/^set -euo/{s=1;next} s&&/^#/{p=1;sub(/^# ?/,"");print;next} s&&p&&!/^#/{exit}' "$0"
}

# --- main -------------------------------------------------------------------
case "${1:-}" in
  help|-h|--help) usage; exit 0 ;;
  --dry-run)      DRY_RUN=1; shift ;;
esac

case "${1:-}" in
  --default-only)
    apply_default ;;
  -p)
    [[ -n "${2:-}" ]] || die "-p needs a profile slug"
    [[ -d "${PROFILES_DIR}/$2" ]] || warn "profile dir ${PROFILES_DIR}/$2 not found — creating config anyway"
    apply_model "$2" -p "$2" ;;
  "")
    info "setting model → ${B}${MODEL_ID}${R} (provider=${MODEL_PROVIDER}, reasoning_effort=${MODEL_REASONING_EFFORT})"
    apply_default
    apply_named ;;
  *)
    die "unknown argument '$1' — use: [--dry-run] [--default-only | -p <slug>] | help" ;;
esac
