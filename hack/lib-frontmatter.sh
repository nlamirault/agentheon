# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

# lib-frontmatter.sh — shared YAML-frontmatter readers for the agent tooling.
# Source it; do not execute. Parsers are intentionally small: the frontmatter
# is machine-generated-friendly (one scalar or list per key, no nesting).

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
