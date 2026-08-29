#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

#
# validate-prompt.sh - Validates infographic prompt structure and completeness
#
# Usage: validate-prompt.sh <prompt-file>
#
# Checks for:
# - Required sections (Topic, Audience, Visual Style, Layout, Dimensions)
# - Text content specified explicitly
# - Color specifications
# - Clear structure
#
# Exit codes:
# 0 - Prompt is valid
# 1 - Prompt has warnings (usable but could be improved)
# 2 - Prompt has errors (missing required elements)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
PASSES=0

# Validation functions
check_section() {
    local section="$1"
    local file="$2"
    local description="$3"

    if grep -qi "^${section}:" "$file" || grep -qi "^${section} -" "$file"; then
        echo -e "${GREEN}✓${NC} ${description}"
        ((PASSES++))
        return 0
    else
        echo -e "${RED}✗${NC} ${description}"
        ((ERRORS++))
        return 1
    fi
}

check_section_warning() {
    local section="$1"
    local file="$2"
    local description="$3"

    if grep -qi "$section" "$file"; then
        echo -e "${GREEN}✓${NC} ${description}"
        ((PASSES++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} ${description} (recommended but not required)"
        ((WARNINGS++))
        return 1
    fi
}

check_color_format() {
    local file="$1"

    if grep -qE "#[0-9A-Fa-f]{6}" "$file"; then
        echo -e "${GREEN}✓${NC} Color codes specified in hex format"
        ((PASSES++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} No hex color codes found (recommended for precise colors)"
        ((WARNINGS++))
        return 1
    fi
}

check_dimensions() {
    local file="$1"

    if grep -qiE "[0-9]+\s*x\s*[0-9]+" "$file"; then
        echo -e "${GREEN}✓${NC} Dimensions specified"
        ((PASSES++))
        return 0
    else
        echo -e "${RED}✗${NC} Dimensions not specified (WIDTHxHEIGHT format)"
        ((ERRORS++))
        return 1
    fi
}

check_prompt_length() {
    local file="$1"
    local word_count=$(wc -w < "$file")

    if [ "$word_count" -lt 50 ]; then
        echo -e "${RED}✗${NC} Prompt too short (${word_count} words) - needs more detail"
        ((ERRORS++))
        return 1
    elif [ "$word_count" -lt 100 ]; then
        echo -e "${YELLOW}⚠${NC} Prompt is brief (${word_count} words) - consider adding more detail"
        ((WARNINGS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} Prompt length adequate (${word_count} words)"
        ((PASSES++))
        return 0
    fi
}

check_vague_language() {
    local file="$1"
    local vague_terms=("nice" "good" "cool" "modern" "professional" "clean" "nice-looking")
    local found_vague=0

    for term in "${vague_terms[@]}"; do
        if grep -qi "\b${term}\b" "$file"; then
            if [ $found_vague -eq 0 ]; then
                echo -e "${YELLOW}⚠${NC} Found vague language that could be more specific:"
                found_vague=1
            fi
            echo "    - '${term}' (be more specific about what this means)"
        fi
    done

    if [ $found_vague -eq 1 ]; then
        ((WARNINGS++))
        return 1
    else
        echo -e "${GREEN}✓${NC} No vague language detected"
        ((PASSES++))
        return 0
    fi
}

# Main validation
main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <prompt-file>"
        exit 2
    fi

    local prompt_file="$1"

    # Check file exists
    if [ ! -f "$prompt_file" ]; then
        echo -e "${RED}Error: File '$prompt_file' not found${NC}"
        exit 2
    fi

    echo -e "${BLUE}=== Infographic Prompt Validator ===${NC}"
    echo -e "Analyzing: ${prompt_file}\n"

    # Required sections
    echo -e "${BLUE}Required Sections:${NC}"
    check_section "Topic" "$prompt_file" "Topic specified"
    check_section "Audience" "$prompt_file" "Audience specified"
    check_section "Visual Style" "$prompt_file" "Visual style specified"
    check_section "Layout" "$prompt_file" "Layout pattern specified"
    check_dimensions "$prompt_file"
    echo ""

    # Recommended sections
    echo -e "${BLUE}Recommended Sections:${NC}"
    check_section_warning "Title" "$prompt_file" "Title text provided"
    check_section_warning "Color" "$prompt_file" "Color palette specified"
    check_section_warning "Purpose" "$prompt_file" "Purpose stated"
    check_color_format "$prompt_file"
    echo ""

    # Quality checks
    echo -e "${BLUE}Quality Checks:${NC}"
    check_prompt_length "$prompt_file"
    check_vague_language "$prompt_file"
    echo ""

    # Summary
    echo -e "${BLUE}=== Validation Summary ===${NC}"
    echo -e "${GREEN}Passes:${NC}   $PASSES"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${RED}Errors:${NC}   $ERRORS"
    echo ""

    # Exit code logic
    if [ $ERRORS -gt 0 ]; then
        echo -e "${RED}❌ Prompt has errors and needs revision${NC}"
        echo "Fix the errors above before using this prompt."
        exit 2
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ Prompt is usable but has warnings${NC}"
        echo "Consider addressing warnings for better results."
        exit 1
    else
        echo -e "${GREEN}✅ Prompt looks good!${NC}"
        echo "This prompt should generate high-quality results."
        exit 0
    fi
}

main "$@"
