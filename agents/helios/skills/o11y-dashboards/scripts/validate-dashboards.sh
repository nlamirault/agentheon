#!/bin/bash
# SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
# SPDX-License-Identifier: Apache-2.0

# validate-dashboards.sh
#
# Quick validation script for Grafana dashboards
# Validates dashboards against Grafana Dashboard Linter rules
#
# Usage:
#   ./validate-dashboards.sh [dashboard-directory]
#   ./validate-dashboards.sh                    # Uses current directory
#   ./validate-dashboards.sh /path/to/dashboards
#   ./validate-dashboards.sh --help

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}🔍 $1${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Grafana Dashboard Validation Script

Usage:
    $0 [OPTIONS] [DIRECTORY]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -s, --strict        Strict mode (warnings become errors)
    -f, --fix           Auto-fix issues where possible
    -c, --config FILE   Use custom lint configuration file

Arguments:
    DIRECTORY           Directory containing dashboard JSON files
                        (default: current directory)

Examples:
    $0                              # Validate dashboards in current directory
    $0 ./dashboards                 # Validate dashboards in specific directory
    $0 --strict --verbose ./dashboards
    $0 --config .lint ./dashboards

Exit Codes:
    0 - All dashboards passed validation
    1 - Validation failed
    2 - No dashboards found
    3 - dashboard-linter not installed
EOF
}

# Parse command-line arguments
VERBOSE=""
STRICT=""
FIX=""
CONFIG=""
DASHBOARD_DIR="."

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        -s|--strict)
            STRICT="--strict"
            shift
            ;;
        -f|--fix)
            FIX="--fix"
            shift
            ;;
        -c|--config)
            CONFIG="--config $2"
            shift 2
            ;;
        -*)
            print_error "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            DASHBOARD_DIR="$1"
            shift
            ;;
    esac
done

# Main validation
print_header "Grafana Dashboard Validation"
echo ""

# Check if directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    print_error "Directory not found: $DASHBOARD_DIR"
    exit 1
fi

print_info "Dashboard directory: $DASHBOARD_DIR"
echo ""

# Check if dashboard-linter is installed
if ! command -v dashboard-linter &> /dev/null; then
    print_warning "dashboard-linter not found"
    echo ""
    print_info "Installing dashboard-linter..."

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Please install Go first:"
        echo "  https://golang.org/doc/install"
        exit 3
    fi

    # Install dashboard-linter
    if go install github.com/grafana/dashboard-linter@latest; then
        print_success "dashboard-linter installed successfully"
        echo ""
    else
        print_error "Failed to install dashboard-linter"
        exit 3
    fi
fi

# Find dashboard files
print_info "Searching for dashboard files..."
DASHBOARD_FILES=$(find "$DASHBOARD_DIR" -name "*.json" -type f 2>/dev/null)

if [ -z "$DASHBOARD_FILES" ]; then
    print_warning "No dashboard files (*.json) found in $DASHBOARD_DIR"
    exit 2
fi

# Count dashboards
DASHBOARD_COUNT=$(echo "$DASHBOARD_FILES" | wc -l | tr -d ' ')
print_success "Found $DASHBOARD_COUNT dashboard(s)"
echo ""

# List dashboards if verbose
if [ -n "$VERBOSE" ]; then
    print_info "Dashboards to validate:"
    echo "$DASHBOARD_FILES" | while read -r file; do
        echo "  - $file"
    done
    echo ""
fi

# Check for .lint configuration file
if [ -z "$CONFIG" ] && [ -f ".lint" ]; then
    print_info "Found .lint configuration file"
    CONFIG="--config .lint"
    echo ""
fi

# Run linter
print_header "Running dashboard-linter..."
echo ""

FAILED_COUNT=0
PASSED_COUNT=0

# Lint each dashboard
echo "$DASHBOARD_FILES" | while read -r dashboard; do
    if [ -n "$dashboard" ]; then
        DASHBOARD_NAME=$(basename "$dashboard")

        if [ -n "$VERBOSE" ]; then
            echo "Validating: $DASHBOARD_NAME"
        fi
        dashboard-linter lint $VERBOSE $STRICT $FIX $CONFIG $dashboard
    fi
done
