#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gen-avatars.sh — render one SVG avatar per deity from its README frontmatter.
#
# Each deity's identity (name, title, emoji, color) already lives in
# agents/<slug>/README.md frontmatter — the single source of truth. This script
# reads it and emits a co-located agents/<slug>/avatar.svg in the Agentheon logo
# idiom: the temple-and-caduceus line-art from web/public/logo.svg, tinted from
# Hermes gold to the deity's own accent, set on the favicon's obsidian
# (#0a0a0b) rounded frame. Below the mark: the name in Inter 600 (#e8e8ea, never
# pure white) and the title as a JetBrains Mono uppercase role in the accent.
# Every deity shares the one mark — only the tint and name differ — so the whole
# pantheon reads as one family with the logo. Flat gold-family line-art, no
# external assets. Committed and checkable so humans, docs, and CI see the same
# marks the frontmatter describes.
#
#   gen-avatars.sh            # write every agents/<slug>/avatar.svg
#   gen-avatars.sh --check    # exit non-zero if any avatar is stale

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${ROOT}/agents"

# shellcheck source=hack/lib-frontmatter.sh
. "${ROOT}/hack/lib-frontmatter.sh"

# xml_escape STRING -> escape the XML metacharacters that appear in free text.
xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

# render_avatar NAME TITLE COLOR -> SVG document on stdout.
# The Agentheon temple-and-caduceus mark (web/public/logo.svg), tinted to the
# deity accent, on the favicon's obsidian rounded frame, over name + mono role.
render_avatar() {
  local name title color role
  name="$(xml_escape "$1")"
  title="$(xml_escape "$2")"
  color="$3"
  role="$(printf '%s' "$title" | tr '[:lower:]' '[:upper:]')"

  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 240" width="240" height="240" role="img" aria-label="${name} — ${title}">
  <title>${name} — ${title}</title>
  <rect x="8" y="8" width="224" height="224" rx="32" fill="#0a0a0b" stroke="${color}" stroke-width="1.5" stroke-opacity="0.9"/>
  <g transform="translate(120 82) scale(0.82) translate(-60 -55)">
    <g fill="none" stroke="${color}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">
      <path d="M60,13 L102,44 L18,44 Z"/>
      <line x1="16" y1="50" x2="104" y2="50"/>
      <line x1="30" y1="54" x2="30" y2="90"/>
      <line x1="44" y1="54" x2="44" y2="90"/>
      <line x1="76" y1="54" x2="76" y2="90"/>
      <line x1="90" y1="54" x2="90" y2="90"/>
      <line x1="22" y1="95" x2="98" y2="95"/>
      <line x1="16" y1="102" x2="104" y2="102"/>
    </g>
    <line x1="60" y1="13" x2="60" y2="91" stroke="${color}" stroke-width="4" stroke-linecap="round"/>
    <g fill="${color}" opacity="0.94">
      <path d="M59,40 Q45,30 38,33 Q49,38 59,36 Z"/>
      <path d="M61,40 Q75,30 82,33 Q71,38 61,36 Z"/>
    </g>
    <g fill="none" stroke="${color}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">
      <path d="M60,89 C47,82 47,71 60,64 C73,57 73,53 62,52"/>
      <path d="M60,89 C73,82 73,71 60,64 C47,57 47,53 58,52"/>
    </g>
    <g fill="${color}">
      <circle cx="60" cy="9" r="4.4"/>
      <circle cx="62" cy="52" r="2.5"/>
      <circle cx="58" cy="52" r="2.5"/>
    </g>
  </g>
  <text x="120" y="176" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="22" font-weight="600" fill="#e8e8ea" text-anchor="middle">${name}</text>
  <text x="120" y="200" font-family="'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace" font-size="11" font-weight="500" letter-spacing="1.3" fill="${color}" text-anchor="middle">${role}</text>
</svg>
SVG
}

stale=0
shopt -s nullglob
for readme in "${AGENTS_DIR}"/*/README.md; do
  name="$(fm_scalar "$readme" name)"; [[ -z "$name" ]] && continue
  title="$(fm_scalar "$readme" title)"
  color="$(fm_scalar "$readme" color)"
  out="$(dirname "$readme")/avatar.svg"

  if [[ "${1:-}" == "--check" ]]; then
    if ! diff -q <(render_avatar "$name" "$title" "$color") "$out" >/dev/null 2>&1; then
      echo "🔴 ${out#"${ROOT}/"} is out of date — run: ./hack/gen-avatars.sh" >&2
      stale=1
    fi
  else
    render_avatar "$name" "$title" "$color" > "$out"
    echo "🟢 wrote ${out#"${ROOT}/"}"
  fi
done

if [[ "${1:-}" == "--check" ]]; then
  [[ "$stale" -eq 0 ]] && echo "🟢 all avatars are in sync"
  exit "$stale"
fi
