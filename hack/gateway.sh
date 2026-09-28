#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gateway.sh — manage the SINGLE Hermes messaging gateway that serves every
# Agentheon deity (see ADR-0005). A Hermes gateway is the process that fires a
# profile's cron jobs and delivers their output. Rather than running one gateway
# per cron-owning deity, Agentheon runs ONE gateway on the `default` profile as a
# profile MULTIPLEXER: it ticks and serves every named deity profile at once.
#
# Each deity is a SATELLITE profile (gateway.enabled=false, set by
# gen-hermes-profiles.sh) that shares the default gateway's listener. Hermes
# refuses to start a second per-profile gateway while the multiplexer serves it
# (two pollers on one token / port fights), so the default gateway is the only
# one this script manages.
#
# The default profile's env lives in $HERMES_HOME/.env (the root .env belongs to
# the default profile alone). The Bitwarden bootstrap token (BWS_ACCESS_TOKEN)
# for the gateway is written there on install.
#
# Usage:
#   hack/gateway.sh install       # configure default as multiplexer + install the gateway
#   hack/gateway.sh list          # list all profiles and gateway status (multiplexer + satellites)
#   hack/gateway.sh start         # start the default multiplex gateway
#   hack/gateway.sh stop          # stop it
#   hack/gateway.sh restart       # restart it
#   hack/gateway.sh status        # show its status
#   hack/gateway.sh help
#
# Extra hermes flags pass through, e.g.:
#   hack/gateway.sh install --start-now
#   hack/gateway.sh install --force
#   hack/gateway.sh start --system
#
# Wire the platform (Slack/Telegram) secrets into the default profile only:
#   BWS_GATEWAY_PROJECT_ID=<uuid> BWS_ACCESS_TOKEN=<tok> hack/gateway.sh install
#
# Env:
#   HERMES_HOME       profiles root parent (default: ~/.hermes)
#   BWS_ACCESS_TOKEN  Bitwarden Secrets Manager token, written to the default .env on install
#   BWS_GATEWAY_PROJECT_ID  Bitwarden PLATFORM project id (Slack/Telegram secrets). When set,
#                     a `secrets.bitwarden` block pointing at it is written into the DEFAULT
#                     profile so only the gateway resolves the platform tokens (ADR-0006). It
#                     must differ from BWS_PROJECT_ID (the providers project used by deities).
#   BWS_PROJECT_ID    Bitwarden PROVIDERS project id — read only to reject reusing it here.
#   BWS_SERVER_URL    Bitwarden server URL (default: https://vault.bitwarden.com)
#   BWS_TOKEN_ENV     env var holding the access token (default: BWS_ACCESS_TOKEN)
#   NO_COLOR=1        disable ANSI colour (also auto-off when stdout is not a tty)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"
HOME_DIR="${HERMES_HOME:-${HOME}/.hermes}"
DEFAULT_ENV="${HOME_DIR}/.env"
BWS_GATEWAY_PROJECT_ID="${BWS_GATEWAY_PROJECT_ID:-}"
BWS_PROJECT_ID="${BWS_PROJECT_ID:-}"
BWS_SERVER_URL="${BWS_SERVER_URL:-https://vault.bitwarden.com}"
BWS_TOKEN_ENV="${BWS_TOKEN_ENV:-BWS_ACCESS_TOKEN}"

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

# cron_owners -> deity slugs that own at least one cron (agents/<slug>/crons/*.md),
# ordered. These are the satellites the multiplexer actually fires jobs for; the
# rest are served but simply have nothing scheduled.
cron_owners() {
  local d slug
  shopt -s nullglob
  for d in "${AGENTS_DIR}"/*/crons; do
    slug="$(basename "$(dirname "$d")")"
    compgen -G "${d}/*.md" >/dev/null 2>&1 && printf '%s\n' "$slug"
  done | sort -u
}

# write_default_env — upsert BWS_ACCESS_TOKEN into the default profile's .env
# ($HERMES_HOME/.env), preserving any other keys. No-op when the token is unset.
write_default_env() {
  [[ -n "${BWS_ACCESS_TOKEN:-}" ]] || { warn "BWS_ACCESS_TOKEN unset — leaving ${DEFAULT_ENV} untouched"; return 0; }
  mkdir -p "${HOME_DIR}"
  local tmp; tmp="$(mktemp)"
  [[ -f "$DEFAULT_ENV" ]] && grep -v '^BWS_ACCESS_TOKEN=' "$DEFAULT_ENV" > "$tmp" 2>/dev/null || true
  printf 'BWS_ACCESS_TOKEN=%s\n' "${BWS_ACCESS_TOKEN}" >> "$tmp"
  mv "$tmp" "$DEFAULT_ENV"
  chmod 600 "$DEFAULT_ENV"
  ok "wrote BWS_ACCESS_TOKEN → ${DEFAULT_ENV}"
}

# write_default_secrets_block — point the DEFAULT profile at the Bitwarden PLATFORM
# project (BWS_GATEWAY_PROJECT_ID) so ONLY the gateway resolves the Slack/Telegram
# secrets (ADR-0006). Deity profiles keep their own providers-project block
# (agentheon.sh); this block is the default profile's alone. No-op when the
# platform project id is unset (plain-.env delivery still works). Written with
# `hermes config set` (dotted keys), matching how the gateway toggles are set.
write_default_secrets_block() {
  [[ -n "$BWS_GATEWAY_PROJECT_ID" ]] || {
    warn "BWS_GATEWAY_PROJECT_ID unset — not wiring a platform secrets block; the default profile must get Slack/Telegram tokens another way (plain ${DEFAULT_ENV})"
    return 0
  }
  # Guard: the platform project must never be the providers project, or the
  # platform tokens leak into every deity and the gateway refuses to start.
  if [[ -n "$BWS_PROJECT_ID" && "$BWS_GATEWAY_PROJECT_ID" == "$BWS_PROJECT_ID" ]]; then
    die "BWS_GATEWAY_PROJECT_ID must differ from BWS_PROJECT_ID — the platform project cannot be the providers project (ADR-0006)"
  fi
  info "wiring default profile → Bitwarden platform project ${CYAN}${BWS_GATEWAY_PROJECT_ID}${R}"
  hermes config set secrets.bitwarden.enabled true --force >/dev/null
  hermes config set secrets.bitwarden.access_token_env "$BWS_TOKEN_ENV" --force >/dev/null
  hermes config set secrets.bitwarden.project_id "$BWS_GATEWAY_PROJECT_ID" --force >/dev/null
  hermes config set secrets.bitwarden.server_url "$BWS_SERVER_URL" --force >/dev/null
  hermes config set secrets.bitwarden.cache_ttl_seconds 300 --force >/dev/null
  hermes config set secrets.bitwarden.override_existing true --force >/dev/null
  ok "default profile: secrets.bitwarden.project_id = ${BWS_GATEWAY_PROJECT_ID} (platform tokens, gateway-only)"
}

# --- commands ---------------------------------------------------------------

# install — turn the default profile into a multiplexer, then install its gateway.
# The multiplexer serves ALL named profiles (no allowlist); a profile with no
# crons simply has nothing to fire. To restrict it, set
# gateway.multiplex_profile_allowlist in the default config.yaml by hand (it is a
# YAML list, which `hermes config set` cannot write).
cmd_install() {
  info "configuring ${B}default${R} profile as a cron gateway multiplexer"
  write_default_env
  write_default_secrets_block
  # The default profile OWNS the listener (enabled), and multiplexes every named
  # deity profile. Satellites are pinned gateway.enabled=false by
  # gen-hermes-profiles.sh — this is the other side of that split.
  hermes config set gateway.enabled true --force >/dev/null
  hermes config set gateway.multiplex_profiles true --force >/dev/null
  ok "default profile: gateway.enabled = true, gateway.multiplex_profiles = true"

  local owners; owners="$(cron_owners | paste -sd' ' -)"
  [[ -n "$owners" ]] && info "cron-owning deities the multiplexer will fire: ${CYAN}${owners}${R}"

  if hermes gateway install "$@"; then
    ok "default multiplex gateway installed"
  else
    die "gateway install failed"
  fi
}

cmd_list() { hermes gateway list "$@"; }

# start/stop/restart/status act on the single default gateway — no per-profile
# fan-out. `hermes gateway list` shows the satellites it serves.
cmd_svc()    { hermes gateway "$1" "${@:2}"; }
cmd_status() { hermes gateway status "$@"; }

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
