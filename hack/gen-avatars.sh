#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# gen-avatars.sh — render one SVG avatar per deity from its README frontmatter.
#
# Each deity's identity (name, title, emoji, color) already lives in
# agents/<slug>/README.md frontmatter — the single source of truth. This script
# reads it and emits a co-located agents/<slug>/avatar.svg built to DESIGN.md:
# the deity card / app-icon — an obsidian surface (#141416) rounded-rect with a
# 14px radius, an accent hairline (the card border warmed to the deity's
# --agent color), an elevated #1c1c20 glyph tile holding the emoji, the name in
# Inter 600 (#e8e8ea, never pure white), and the title as a JetBrains Mono
# uppercase role in the accent. Flat fills only — no gradient, no circle. No
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

# render_avatar NAME TITLE EMOJI COLOR -> SVG document on stdout.
# Built to DESIGN.md: obsidian surface card, 14px radius, accent hairline,
# elevated glyph tile, Inter 600 name, mono uppercase role in the accent.
render_avatar() {
  local name title emoji color role
  name="$(xml_escape "$1")"
  title="$(xml_escape "$2")"
  emoji="$(xml_escape "$3")"
  color="$4"
  role="$(printf '%s' "$title" | tr '[:lower:]' '[:upper:]')"

  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 240" width="240" height="240" role="img" aria-label="${name} — ${title}">
  <title>${name} — ${title}</title>
  <rect x="8" y="8" width="224" height="224" rx="14" fill="#141416" stroke="${color}" stroke-width="1.5"/>
  <rect x="76" y="40" width="88" height="88" rx="10" fill="#1c1c20" stroke="#2a2a30" stroke-width="1"/>
  <text x="120" y="84" font-size="50" text-anchor="middle" dominant-baseline="central">${emoji}</text>
  <text x="120" y="172" font-family="Inter, ui-sans-serif, system-ui, sans-serif" font-size="22" font-weight="600" fill="#e8e8ea" text-anchor="middle">${name}</text>
  <text x="120" y="196" font-family="'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace" font-size="11" font-weight="500" letter-spacing="1.3" fill="${color}" text-anchor="middle">${role}</text>
</svg>
SVG
}

stale=0
shopt -s nullglob
for readme in "${AGENTS_DIR}"/*/README.md; do
  name="$(fm_scalar "$readme" name)"; [[ -z "$name" ]] && continue
  title="$(fm_scalar "$readme" title)"
  emoji="$(fm_scalar "$readme" emoji)"
  color="$(fm_scalar "$readme" color)"
  out="$(dirname "$readme")/avatar.svg"

  if [[ "${1:-}" == "--check" ]]; then
    if ! diff -q <(render_avatar "$name" "$title" "$emoji" "$color") "$out" >/dev/null 2>&1; then
      echo "🔴 ${out#"${ROOT}/"} is out of date — run: ./hack/gen-avatars.sh" >&2
      stale=1
    fi
  else
    render_avatar "$name" "$title" "$emoji" "$color" > "$out"
    echo "🟢 wrote ${out#"${ROOT}/"}"
  fi
done

if [[ "${1:-}" == "--check" ]]; then
  [[ "$stale" -eq 0 ]] && echo "🟢 all avatars are in sync"
  exit "$stale"
fi
