#!/usr/bin/env bash
# AI-DLC Process Checker
#
# Verifies that required artifacts for a given skill step exist, are non-empty,
# and that the state file reflects the expected completion status.
#
# Usage:
#   process-checker.sh <intent-dir> <skill-name> [--unit <unit-name>|--scope <scope-name>]
#
# Exit codes:
#   0 = PASS
#   1 = FAIL (one or more required artifacts missing/empty)
#   2 = Usage error
#
# Example:
#   ./scripts/process-checker.sh org-ai-kb/aidlc-docs/intent-001-payment-api requirements-analysis
#   ./scripts/process-checker.sh org-ai-kb/aidlc-docs/intent-001-payment-api functional-design --unit payment-processor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=1
USAGE=2

usage() {
  echo "Usage: $0 <intent-dir> <skill-name> [--unit <name>|--scope <name>]" >&2
  exit $USAGE
}

[[ $# -lt 2 ]] && usage

INTENT_DIR="$1"
SKILL="$2"
QUALIFIER=""
QUALIFIER_TYPE=""

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit)  QUALIFIER_TYPE="unit";  QUALIFIER="$2"; shift 2 ;;
    --scope) QUALIFIER_TYPE="scope"; QUALIFIER="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; usage ;;
  esac
done

# Resolve output directory for the skill
resolve_output_dir() {
  local skill="$1" qualifier_type="$2" qualifier="$3"

  case "$qualifier_type" in
    unit)  echo "$INTENT_DIR/construction/$qualifier/$skill" ;;
    scope) echo "$INTENT_DIR/inception/$skill/$qualifier" ;;
    *)
      case "$skill" in
        intent-bootstrap)      echo "$INTENT_DIR/bootstrap/intent-bootstrap" ;;
        workflow-composition)  echo "$INTENT_DIR/bootstrap/workflow-composition" ;;
        build-and-test)        echo "$INTENT_DIR/construction/build-and-test" ;;
        *)                     echo "$INTENT_DIR/inception/$skill" ;;
      esac
      ;;
  esac
}

# Required artifacts per skill
declare -A SKILL_ARTIFACTS
SKILL_ARTIFACTS["intent-bootstrap"]="bootstrap-context.md"
SKILL_ARTIFACTS["workflow-composition"]="workflow-rationale.md"
SKILL_ARTIFACTS["reverse-engineering"]="business-overview.md architecture.md tech-stack.md api-surface.md dependencies.md code-structure.md"
SKILL_ARTIFACTS["requirements-analysis"]="requirements.md"
SKILL_ARTIFACTS["user-stories"]="personas.md stories.md"
SKILL_ARTIFACTS["wireframes"]="screen-data-map.md screen-structure.md wireframe-guidance.md"
SKILL_ARTIFACTS["application-design"]="components.md component-methods.md component-dependencies.md services.md cross-cutting.md"
SKILL_ARTIFACTS["units-generation"]="units-of-work.md units-of-work-story-map.md sequencing.md"
SKILL_ARTIFACTS["functional-design"]="business-logic-model.md domain-entities.md business-rules.md"
SKILL_ARTIFACTS["nfr-assessment"]="nfr-requirements.md tech-stack-decisions.md"
SKILL_ARTIFACTS["nfr-design"]="nfr-design-patterns.md logical-components.md"
SKILL_ARTIFACTS["infrastructure-design"]="infrastructure-design.md deployment-architecture.md"
SKILL_ARTIFACTS["code-generation"]="code-generation-plan.md implementation-notes.md"
SKILL_ARTIFACTS["build-and-test"]="build-instructions.md unit-test-instructions.md integration-test-instructions.md performance-test-instructions.md build-and-test-summary.md"

# Also check intent root files for intent-bootstrap
INTENT_ROOT_ARTIFACTS["intent-bootstrap"]="intent-prompt.md intent.md workflow.md state/intent-state.md audit/intent-audit.md"
declare -A INTENT_ROOT_ARTIFACTS

OUT_DIR="$(resolve_output_dir "$SKILL" "$QUALIFIER_TYPE" "$QUALIFIER")"
ERRORS=()

# Check intent-dir exists
if [[ ! -d "$INTENT_DIR" ]]; then
  echo "FAIL: intent directory not found: $INTENT_DIR"
  exit $FAIL
fi

# Check skill artifacts in output dir
if [[ -v "SKILL_ARTIFACTS[$SKILL]" ]]; then
  for artifact in ${SKILL_ARTIFACTS[$SKILL]}; do
    path="$OUT_DIR/$artifact"
    if [[ ! -f "$path" ]]; then
      ERRORS+=("MISSING: $path")
    elif [[ ! -s "$path" ]]; then
      ERRORS+=("EMPTY:   $path")
    fi
  done
else
  echo "WARN: no artifact list for skill '$SKILL' — skipping artifact check"
fi

# Check intent root artifacts for intent-bootstrap
if [[ "$SKILL" == "intent-bootstrap" && -v "INTENT_ROOT_ARTIFACTS[$SKILL]" ]]; then
  for artifact in ${INTENT_ROOT_ARTIFACTS[$SKILL]}; do
    path="$INTENT_DIR/$artifact"
    if [[ ! -f "$path" ]]; then
      ERRORS+=("MISSING: $path")
    elif [[ ! -s "$path" ]]; then
      ERRORS+=("EMPTY:   $path")
    fi
  done
fi

# Check workflow.md at intent root
if [[ "$SKILL" == "intent-bootstrap" || "$SKILL" == "workflow-composition" ]]; then
  wf="$INTENT_DIR/workflow.md"
  if [[ ! -f "$wf" ]]; then
    ERRORS+=("MISSING: $wf")
  elif [[ ! -s "$wf" ]]; then
    ERRORS+=("EMPTY:   $wf")
  fi
fi

# Report
if [[ ${#ERRORS[@]} -eq 0 ]]; then
  echo "PASS: $SKILL${QUALIFIER:+ ($QUALIFIER_TYPE: $QUALIFIER)}"
  echo "  output-dir: $OUT_DIR"
  echo "  artifacts:  ${SKILL_ARTIFACTS[$SKILL]:-none}"
  exit $PASS
else
  echo "FAIL: $SKILL${QUALIFIER:+ ($QUALIFIER_TYPE: $QUALIFIER)}"
  for err in "${ERRORS[@]}"; do
    echo "  $err"
  done
  exit $FAIL
fi
