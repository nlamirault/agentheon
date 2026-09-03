---
name: "shell-best-practices"
description: "Enforce idiomatic shell script style, structure, and testing discipline"
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service: [bash, shell]
  task: [review, build]
  persona: [developer, devops]
  workload: [infrastructure, developer-tools]
---

# Shell Scripting / Best Practices

## Guiding Principles

- **Shebang:** Start scripts with a proper shebang (e.g., `#!/bin/bash` or `#!/usr/bin/env bash` for Bash, `#!/bin/sh`
  for POSIX compatibility).
- **Error Handling:**
  - Use `set -e` (errexit) to exit immediately if a command exits with a non-zero status.
  - Use `set -u` (nounset) to treat unset variables as an error.
  - Use `set -o pipefail` to cause a pipeline to return the exit status of the last command that exited with a non-zero
    status.
  - Implement explicit error checking (`if ! command; then ... fi`) for critical operations.
- **Variable Quoting:** Always quote variable expansions (`"$variable"`) to prevent word splitting and globbing issues,
  unless specifically intended.
- **Command Substitution:** Prefer `$(command)` over backticks `` `command` `` for command substitution; it nests better
  and is more readable.
- **Readability:** Use meaningful variable names (lowercase or uppercase convention). Add comments (`#`) to explain
  complex logic. Use indentation (spaces or tabs) consistently.
- **Functions:** Define reusable logic in functions for better organization and testability.
- **Argument Parsing:** Use `getopt` or `getopts` for parsing command-line options and arguments in more complex
  scripts.
- **Avoid Parsing `ls`:** Do not parse the output of `ls`. Use globbing (`*`) or `find` for filename manipulation.
- **Use Linters:** Use tools like `shellcheck` to statically analyze scripts for common errors and pitfalls.
- **Portability:** If aiming for POSIX compatibility, avoid Bash-specific features (e.g., `[[ ... ]]`, `((...))`,
  arrays, `local` keyword without `-`). Stick to `#!/bin/sh` and POSIX utilities/syntax.
