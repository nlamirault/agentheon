#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gateway.sh — manage the Hermes messaging gateway across every Agentheon deity
# profile. The profile list is the source of truth (agents/*/README.md); each
# deity is an isolated Hermes profile under $HERMES_HOME/profiles/<slug>/ that
# loads ONLY its own .env, so a shared secret (BWS_ACCESS_TOKEN, used by
# Bitwarden Secrets Manager) must be written per profile before install.
#
# `hermes -p <slug>` is a GLOBAL flag — it precedes the subcommand
# (hermes -p zeus gateway install), it is not `gateway install -p`.
#
# Usage:
#   hack/gateway.sh install [slug...]   # write .env (BWS_ACCESS_TOKEN) + install service
#   hack/gateway.sh list                # list all profiles and gateway status
#   hack/gateway.sh start   [slug...]   # start gateway service (all if no slug)
#   hack/gateway.sh stop    [slug...]   # stop gateway service (all if no slug)
#   hack/gateway.sh restart [slug...]   # restart gateway service (all if no slug)
#   hack/gateway.sh status  [slug...]   # show gateway status (all if no slug)
#   hack/gateway.sh help
#
# With no slug, install/start/stop/restart/status act on ALL profiles.
# Extra hermes flags pass through, e.g.:
#   hack/gateway.sh install --force
#   hack/gateway.sh start --system
#
# Env:
#   HERMES_HOME       profiles root parent (default: ~/.hermes)
#   BWS_ACCESS_TOKEN  Bitwarden Secrets Manager token, written to each .env on install
#   NO_COLOR=1        disable ANSI colour (also auto-off when stdout is not a tty)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
PROFILES_DIR="${HOME_DIR}/profiles"

# --- colour -----------------------------------------------------------------
if [[ -t 1 && "${NO_COLOR:-0}" != 1 ]]; then
  B=$'\033[1m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; R=$'\033[0m'
else
  B=""; DIM=""; CYAN=""; GRN=""; YEL=""; RED=""; R=""
fi

die()  { echo "${RED}error:${R} $*" >&2; exit 1; }
warn() { echo "${YEL}⚠${R}  $*" >&2; }
info() { echo "${CYAN}ℹ${R}  $*"; }
ok()   { echo "${GRN}✓${R}  $*"; }

command -v hermes >/dev/null 2>&1 || die "hermes CLI not found — install Hermes Agent first"

# all_slugs -> every deity slug, ordered by frontmatter `order`.
all_slugs() {
  local f slug order
  for f in "${AGENTS_DIR}"/*/README.md; do
    slug="$(basename "$(dirname "$f")")"
    order="$(awk '/^---$/{c++;next} c==1&&/^order:/{sub(/^order:[ \t]*/,"");print;exit}' "$f")"
    printf '%s\t%s\n' "${order:-999}" "$slug"
  done | sort -n | cut -f2
}

# split_args ARGS... -> populate FLAGS[] (leading -*) and SLUGS[] (the rest).
FLAGS=(); SLUGS=()
split_args() {
  local a
  for a in "$@"; do
    if [[ "$a" == -* ]]; then FLAGS+=("$a"); else SLUGS+=("$a"); fi
  done
}

# targets -> chosen slugs (SLUGS[] if given, else every profile).
targets() {
  if [[ ${#SLUGS[@]} -gt 0 ]]; then printf '%s\n' "${SLUGS[@]}"; else all_slugs; fi
}

# write_env SLUG — upsert BWS_ACCESS_TOKEN into the profile's .env, preserving
# any other keys. No-op when the token is unset; skips uninstalled profiles.
write_env() {
  local slug="$1" dir="${PROFILES_DIR}/$1" env="${PROFILES_DIR}/$1/.env"
  [[ -d "$dir" ]] || { warn "profile '$slug' not installed ($dir missing) — run gen-hermes-profiles.sh first"; return 1; }
  [[ -n "${BWS_ACCESS_TOKEN:-}" ]] || { warn "BWS_ACCESS_TOKEN unset — leaving ${slug}/.env untouched"; return 0; }
  local tmp; tmp="$(mktemp)"
  [[ -f "$env" ]] && grep -v '^BWS_ACCESS_TOKEN=' "$env" > "$tmp" 2>/dev/null || true
  printf 'BWS_ACCESS_TOKEN=%s\n' "${BWS_ACCESS_TOKEN}" >> "$tmp"
  mv "$tmp" "$env"
  chmod 600 "$env"
}

# --- commands ---------------------------------------------------------------
cmd_install() {
  split_args "$@"
  local slug rc=0
  while IFS= read -r slug; do
    info "installing gateway for ${CYAN}${slug}${R}"
    write_env "$slug" || { rc=1; continue; }
    if hermes -p "$slug" gateway install "${FLAGS[@]}"; then
      ok "${slug} gateway installed"
    else
      warn "${slug} gateway install failed"; rc=1
    fi
  done < <(targets)
  return "$rc"
}

cmd_list() { hermes gateway list "$@"; }

# start/stop/restart: hermes has a native --all, so with no slug we defer to it
# (one service-manager call) instead of looping.
cmd_svc() {
  local action="$1"; shift
  split_args "$@"
  if [[ ${#SLUGS[@]} -eq 0 ]]; then
    hermes gateway "$action" --all "${FLAGS[@]}"
    return
  fi
  local slug rc=0
  for slug in "${SLUGS[@]}"; do
    info "${action} ${CYAN}${slug}${R}"
    hermes -p "$slug" gateway "$action" "${FLAGS[@]}" || { warn "${slug} ${action} failed"; rc=1; }
  done
  return "$rc"
}

cmd_status() {
  split_args "$@"
  if [[ ${#SLUGS[@]} -eq 0 ]]; then
    hermes gateway status "${FLAGS[@]}"
    return
  fi
  local slug
  for slug in "${SLUGS[@]}"; do
    printf '\n%s%s%s\n' "$B" "$slug" "$R"
    hermes -p "$slug" gateway status "${FLAGS[@]}" || true
  done
}

# --- main -------------------------------------------------------------------
case "${1:-help}" in
  install)          shift; cmd_install "$@" ;;
  list|ls)          shift; cmd_list "$@" ;;
  start)            shift; cmd_svc start "$@" ;;
  stop)             shift; cmd_svc stop "$@" ;;
  restart)          shift; cmd_svc restart "$@" ;;
  status)           shift; cmd_status "$@" ;;
  help|-h|--help)
    awk '/^set -euo/{s=1;next} s&&/^#/{p=1;sub(/^# ?/,"");print;next} s&&p&&!/^#/{exit}' "$0" ;;
  *) die "unknown command '$1' — use: install | list | start | stop | restart | status | help" ;;
esac
