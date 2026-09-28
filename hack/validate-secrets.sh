#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# validate-secrets.sh — assert the ADR-0006 invariant against a live Hermes home:
# platform tokens (SLACK_*, TELEGRAM_*) live ONLY in the default profile env
# ($HERMES_HOME/.env), never in the shared secrets file or any satellite profile
# env. Outbound messaging is Zeus's job alone; a platform token reachable by a
# satellite profile makes that deity configure the platform, and the multiplex
# gateway (ADR-0005) refuses to start ("one credential cannot be consumed twice").
#
# This checks the RUNTIME home, not the repo — the shared file and profile .env
# files are created out of band on the host.
#
# Usage:  hack/validate-secrets.sh [HERMES_HOME]
#   HERMES_HOME defaults to $HERMES_HOME, else ~/.hermes.
#
# Exit: 0 clean, 1 a platform token leaked into a shared/satellite scope.

HOME_DIR="${1:-${HERMES_HOME:-${HOME}/.hermes}}"
SHARED_SECRETS="${HOME_DIR}/.shared-secrets.env"
PROFILES_DIR="${HOME_DIR}/profiles"

# The env keys that must never be reachable by a satellite profile.
PLATFORM_TOKEN_RE='\b(SLACK|TELEGRAM)_[A-Z_]+'

errors=0
err() { echo "🔴 $1"; errors=$((errors + 1)); }

# leaked_keys FILE -> comma-joined, upper-cased platform token names in FILE.
leaked_keys() {
  grep -oiE "$PLATFORM_TOKEN_RE" "$1" 2>/dev/null \
    | tr '[:lower:]' '[:upper:]' | sort -u | paste -sd, - || true
}

if [[ ! -d "$HOME_DIR" ]]; then
  echo "🟠 no Hermes home at ${HOME_DIR} — nothing to validate"
  exit 0
fi

# 1. The shared file feeds every profile — it must carry provider/LLM keys only.
if [[ -e "$SHARED_SECRETS" ]]; then
  leaked="$(leaked_keys "$SHARED_SECRETS")"
  [[ -n "$leaked" ]] \
    && err ".shared-secrets.env leaks platform token(s): ${leaked} — move to ${HOME_DIR}/.env (default profile only)"
fi

# 2. A satellite profile env (real file OR symlink target) must never resolve a
#    platform token. A symlink to the shared file is covered by check 1; a real
#    per-profile .env is checked directly here.
shopt -s nullglob
for env in "${PROFILES_DIR}"/*/.env; do
  slug="$(basename "$(dirname "$env")")"
  leaked="$(leaked_keys "$env")"
  [[ -n "$leaked" ]] \
    && err "profiles/${slug}/.env leaks platform token(s): ${leaked} — only the default profile may hold these"
done

if [[ "$errors" -gt 0 ]]; then
  echo "🔴 ${errors} secret-scoping error(s) — see ADR-0006"
  exit 1
fi
echo "🟢 platform tokens are scoped to the default profile (ADR-0006)"
