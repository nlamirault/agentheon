#!/usr/bin/env python3
"""
validate_commit_msg.py — Validate a commit message against Conventional Commits spec.

Used by the create-commit skill to verify messages before committing.

Usage:
  python3 validate_commit_msg.py "feat(api): add user endpoint"
  python3 validate_commit_msg.py -   (read from stdin)
  git log --format=%s -1 | python3 validate_commit_msg.py -

Exit codes:
  0 = valid
  1 = invalid
"""

import re
import sys

VALID_TYPES = {
    "feat", "fix", "docs", "style", "refactor", "perf",
    "test", "build", "ci", "chore", "revert", "security",
}

# <type>(<scope>): <description>  OR  <type>!: <description>  (breaking)
SUBJECT_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?: (?P<description>.+)$"
)


def validate(message: str) -> list[str]:
    """Returns a list of error strings. Empty = valid."""
    errors = []
    lines = message.strip().splitlines()

    if not lines:
        return ["Commit message is empty"]

    subject = lines[0]

    # Check subject line
    m = SUBJECT_RE.match(subject)
    if not m:
        errors.append(
            f"Subject line '{subject}' doesn't match <type>(<scope>): <description>\n"
            f"  Example: feat(auth): add JWT refresh endpoint"
        )
        return errors  # Can't check further without a valid parse

    commit_type = m.group("type")
    description = m.group("description")

    if commit_type not in VALID_TYPES:
        errors.append(
            f"Unknown type '{commit_type}'. Valid types: {', '.join(sorted(VALID_TYPES))}"
        )

    if not description:
        errors.append("Description is empty after the colon")
    else:
        if description[0].isupper():
            errors.append(
                f"Description should start with lowercase: '{description}'\n"
                f"  Change to: '{description[0].lower() + description[1:]}'"
            )
        if description.endswith("."):
            errors.append("Description should not end with a period")
        if len(description) > 72:
            errors.append(
                f"Description is {len(description)} chars (max 72). Be more concise."
            )

    if len(subject) > 100:
        errors.append(f"Subject line is {len(subject)} chars (recommended max 100)")

    # Check blank line between subject and body
    if len(lines) > 1:
        if lines[1].strip():
            errors.append(
                "Line 2 must be blank (separating subject from body)\n"
                "  Add an empty line after the subject"
            )

    return errors


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        message = sys.stdin.read()
    else:
        message = " ".join(sys.argv[1:])

    errors = validate(message)

    if not errors:
        print("✅ Commit message is valid")
        sys.exit(0)
    else:
        print(f"❌ Commit message has {len(errors)} issue(s):\n")
        for i, err in enumerate(errors, 1):
            print(f"  {i}. {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()
