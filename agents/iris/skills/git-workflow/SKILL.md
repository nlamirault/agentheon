---
name: git-workflow
description: This skill should be used when the user asks to "create a pull request", "make a PR", "write a commit message", "commit changes", "what's the commit format", "can I commit to main", "branch protection", "conventional commits", or mentions Git workflow, PR creation, or commit message standards. Provides comprehensive guidance on branch protection, conventional commits, and pull request workflows.
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - git
  - github
  task: [configure, review]
  persona: [developer]
  workload: [developer-tools]
allowed-tools: Write Read LS Glob Bash(git:*) Bash(gh:*) AskUserQuestion(*) mcp__github__*
---

# Git Workflow Best Practices

## Overview

Git workflow encompasses three critical areas for engineering teams:

1. **Branch Protection** - Prevent accidental commits to protected branches
2. **Conventional Commits** - Standardized commit message format for clear change history
3. **Pull Request Workflow** - Automated PR creation with code review and integration

This skill provides high-level guidance with references to detailed documentation for each topic.

---

## Branch Protection

**Critical Rule:** Never commit directly to protected branches.

Protected branches: `main`, `master`, `develop`, `release/*`, `hotfix/*`

**MANDATORY — run FIRST before any staging, diffing, or committing:**

```bash
git branch --show-current
```

**STOP immediately** if the current branch is protected. Do NOT proceed. Instead output:

```text
❌ Cannot commit directly to protected branch: <branch-name>

Direct commits to '<branch-name>' are forbidden.
Create a feature branch first:

  git checkout -b <suggested-branch-name>

Suggested branch name based on context: feat/<topic> or fix/<topic>
```

Suggest a branch name derived from staged/unstaged file paths or ask the user. Only continue after the user has switched to a non-protected branch.

All development work must occur on feature branches following naming conventions:

- `feat/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation changes
- `chore/*` - Maintenance tasks

**📖 For complete details, see:** `references/branch-protection.md`

- Pre-commit verification scripts
- Branch naming conventions
- Protection enforcement strategies
- Recovery procedures if committed to main

---

## Commit Proposal Workflow

When the user runs `/create-commit` or asks to commit changes, **always** follow this interactive proposal flow before
executing `git commit`.

### Arguments

| Argument | Effect |
|---|---|
| `--ia` | Add an `Assisted-by:` trailer naming the AI model that helped author this commit. Value defaults to the current model (e.g. `Claude Sonnet 4.6`). Accepts an optional value: `--ia="GPT-4o"` overrides the default. |

If `--ia` is present, set `IA_TRAILER=true` and resolve the model name:
- No value → use the current session model (e.g. `Claude Sonnet 4.6`)
- `--ia=<value>` or `--ia <value>` → use the provided string verbatim

### Step 0 — Branch guard (MANDATORY FIRST)

See Branch Protection above. **Stop immediately if on a protected branch.**

### Step 1 — Analyze staged changes

Run these commands to understand the diff:

```bash
git --no-pager diff --staged
git status
```

Display: number of files changed, file paths, staged vs unstaged status.

If there are unstaged changes, ask the user if they want to stage all changes:
- **Yes**: `git add -A`
- **No**: Ask which files to stage, or abort if nothing staged

### Step 2 — Auto-detect scope

Analyze changed file paths:

| File pattern | Scope |
|---|---|
| `src/api/*`, `api/*` | `api` |
| `src/components/*`, `components/*` | `ui` |
| `src/services/*` | `services` |
| `src/utils/*`, `lib/*` | `utils` |
| `tests/*`, `*_test.*`, `*.test.*` | `test` |
| `*.config.*`, `config/*` | `config` |
| `docs/*`, `*.md` | `docs` |
| `plugins/<name>/*` | plugin name from path |
| `.rules/*` | `rules` |

If files span multiple directories, use the most specific common component. If truly cross-cutting, omit scope.

### Step 3 — Propose commit details

Present a structured proposal to the user using this exact format:

```text
📝 Commit proposal
─────────────────────────────────
Type        : <feat | fix | docs | style | refactor | perf | test | build | ci | chore | security>
Scope       : <auto-detected or omitted>
Description : <imperative, lowercase, ≤72 chars — no period at end>
Body        : <mandatory — explain WHY this change is needed and what changed>
Assisted-by : <model name>  ← only shown when --ia flag is present
─────────────────────────────────
Full message:

<type>(<scope>): <description>

<body>

Signed-off-by: <name> <email>
Assisted-by: <model name>  ← only included when --ia flag is present
```

**Detection rules:**

| Field | How to detect |
|---|---|
| **Type** | Nature of the diff: new functionality → `feat`, bug fix → `fix`, only docs/comments → `docs`, test files only → `test`, CI/CD config → `ci`, build files → `build`, refactoring with no behaviour change → `refactor`, etc. |
| **Scope** | Auto-detected from file paths (see Step 2 table). |
| **Description** | Concise summary in imperative present tense (e.g. "add", "fix", "update"). Lowercase first letter. No trailing period. ≤72 chars. |
| **Body** | **Mandatory.** Explain the *why* and summarize what changed. Wrap at 72 chars. Do NOT include specific counts or numbers (e.g. "32 files", "125 blocks") — use qualitative language ("all affected", "across all plugins"). |

### Step 4 — Ask for confirmation

After presenting the proposal, ask:

> "Does this commit message look good? Reply **yes** to confirm, or tell me what to change."

**Do not run `git commit` until the user explicitly approves.**

If the user requests changes, update the proposal and ask again. Only commit once confirmed.

### Step 5 — Execute commit with DCO sign-off

**Always use `-s` flag.** Body is mandatory — always use heredoc.

**Without `--ia`:**

```bash
git commit -s -m "$(cat <<'EOF'
type(scope): description

Body explaining why this change is needed and what was changed.
EOF
)"
```

**With `--ia` (append `Assisted-by:` trailer after `Signed-off-by:`):**

```bash
git commit -s -m "$(cat <<'EOF'
type(scope): description

Body explaining why this change is needed and what was changed.

Assisted-by: Claude Sonnet 4.6
EOF
)"
```

The `-s` flag adds `Signed-off-by: Name <email>` automatically. The `Assisted-by:` trailer must appear **after** `Signed-off-by:` in the trailers block. If GPG signing is configured (`commit.gpgsign = true`), the commit is also cryptographically signed.

**Validation checklist before committing:**

- [ ] Current branch is NOT a protected branch
- [ ] Type is valid and lowercase
- [ ] Scope is auto-detected and accurate
- [ ] Description is imperative present tense, lowercase, ≤72 chars, no period
- [ ] Body is present and explains *why*
- [ ] `-s` flag will be used
- [ ] If `--ia` was passed: `Assisted-by:` trailer present with correct model name

---

## Conventional Commits

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages.

**Format:**

```text
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Common Types:**

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting (no code change)
- `refactor` - Code restructuring
- `perf` - Performance improvement
- `test` - Tests
- `build` - Build system
- `ci` - CI/CD changes
- `chore` - Maintenance
- `security` - Security improvements

**Quick Example:**

```bash
git commit -m "feat(api): add user authentication endpoint"
```

**📖 For complete details, see:** `references/conventional-commits.md`

**🎨 For emoji mappings (Gitmoji, GitCommitMoji, platform emojis), see:** `references/emoji-guide.md`

- Full type reference with examples
- Scope guidelines
- Description formatting rules
- Body and footer conventions
- Multi-line commit patterns with heredoc
- Breaking changes syntax

---

## Pull Request Workflow

Standard workflow for creating and merging pull requests:

1. **Create feature branch** from `main`
2. **Make changes** and commit with conventional format
3. **Push branch** to remote
4. **Create PR** using GitHub CLI or GitHub MCP
5. **Enable auto-merge** with squash strategy (always)

**Quick PR Creation:**

```bash
# Push branch
git push -u origin feat/my-feature

# Check if repository has labels (skip --label if none exist)
gh label list

# Create PR with GitHub CLI (add --label if labels exist)
gh pr create --title "feat(scope): description" --body "Summary of changes"
gh pr create --title "feat(scope): description" --body "Summary of changes" --label "enhancement"

# Enable auto-merge with squash
gh pr merge <PR-NUMBER> --auto --squash -R owner/repo
```

**Alternative: GitHub MCP**

```text
mcp__github__create_pull_request with:
- owner: "organization"
- repo: "repository-name"
- title: "feat(scope): description"
- head: "branch-name"
- base: "main"
- body: "PR description"
```

**📖 For complete details, see:** `references/pull-request.md`

- Complete 5-step workflow
- PR title and description templates
- Auto-merge configuration with GitHub CLI
- Auto-merge using GitHub MCP tools
- Pre-PR and post-PR checklists
- Troubleshooting merge conflicts and CI failures

---

## Quick Reference

### Essential Commands

```bash
# Check current branch (do this before committing!)
git branch --show-current

# Create and switch to feature branch
git checkout -b feat/my-feature

# Commit with conventional format + DCO sign-off (mandatory)
git commit -s -m "$(cat <<'EOF'
feat(scope): description

Body explaining why.
EOF
)"

# Commit with AI attribution (--ia flag)
git commit -s -m "$(cat <<'EOF'
feat(scope): description

Body explaining why.

Assisted-by: Claude Sonnet 4.6
EOF
)"

# Push and set upstream
git push -u origin feat/my-feature

# Create PR (GitHub CLI)
gh pr create --title "feat: description"

# Enable auto-merge with squash
gh pr merge <NUMBER> --auto --squash
```

### Validation Checklist

**Before Committing:**

- [ ] Current branch is NOT a protected branch (`main`, `master`, `develop`, `release/*`, `hotfix/*`)
- [ ] Commit message follows conventional format
- [ ] Scope auto-detected from changed file paths
- [ ] Description uses imperative present tense
- [ ] Body present and explains *why*
- [ ] `-s` flag used (DCO sign-off)
- [ ] No secrets or sensitive data

**Before Creating PR:**

- [ ] All changes committed to feature branch
- [ ] Branch pushed to remote
- [ ] PR title follows conventional format
- [ ] Checked repository labels (`gh label list`) and added relevant ones

**After Creating PR:**

- [ ] Auto-merge enabled with squash strategy
- [ ] All CI checks are running

---

## Tools Integration

This workflow uses:

- **Git** - Standard version control operations
- **GitHub CLI (`gh`)** - Command-line PR creation and management
- **GitHub MCP** - Programmatic PR and issue management via Model Context Protocol

---

## Reference Documentation

For detailed guidance on specific topics:

| Reference                                | Content                                                                             |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| **`references/branch-protection.md`**    | Comprehensive branch protection rules, pre-commit hooks, and enforcement strategies |
| **`references/conventional-commits.md`** | Complete conventional commit specification with types, scopes, and formatting rules |
| **`references/pull-request.md`**         | Detailed PR workflow with GitHub CLI and MCP integration, including troubleshooting |
| **`references/emoji-guide.md`**          | Full emoji reference for developer automation: language/platform emojis, git commit conventions (Gitmoji, GitCommitMoji, emoji-commit), and complete GitHub emoji cheat sheet |

---

## Common Questions

**Q: Can I commit to main for a hotfix?**
A: No. `main`, `master`, `develop`, `release/*`, and `hotfix/*` are all protected. Always create a `fix/*` branch. See `references/branch-protection.md` for the rationale.

**Q: What if I forget the commit format?** A: Use `/validate-commit` command to check your message format, or consult
`references/conventional-commits.md` for examples.

**Q: How do I enable auto-merge?** A: After creating a PR, run `gh pr merge <NUMBER> --auto --squash`. See
`references/pull-request.md` for complete instructions.

**Q: What if I accidentally committed to main?**
A: See the troubleshooting section in `references/branch-protection.md` for recovery procedures.

---

This skill provides the foundation for consistent Git workflows across engineering teams. For detailed patterns,
examples, and edge cases, consult the reference files listed above.
