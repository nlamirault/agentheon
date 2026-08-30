---
name: create-pr
allowed-tools: AskUserQuestion(*), Bash(*), Read(*)
argument-hint: "[title]"
description: Create a pull request from the current branch with validation, squash merge strategy, and automatic label assignment
disable-model-invocation: true
metadata:
  author: nlamirault
  version: "1.2.0"
  service:
  - git
  - github
  task: [configure]
  persona: [developer]
  workload: [developer-tools]
---

# Create Pull Request

Create a pull request from the current branch with automatic validation, label assignment, and squash merge strategy.

## Workflow

1. **Verify Current Branch**
   - Check the current branch name using `git branch --show-current`
   - STOP immediately if on `main` or `master` branch
   - Display error: "Cannot create PR from protected branch. Switch to a feature branch first."

2. **Determine PR Title**
   - If title argument provided: use it directly
   - If no title argument: generate from recent commit messages
     - Get the most recent commit message: `git log -1 --pretty=%s`
     - Use it as the PR title

3. **Validate Conventional Commit Format**
   - Check that PR title follows pattern: `<type>(<scope>): <description>` or `<type>: <description>`
   - Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security
   - If invalid format:
     - Display error with example: `"Invalid format. Use: feat(scope): description"`
     - Ask user to provide a valid title or abort

4. **Check Remote Branch Status**
   - Verify branch is pushed to remote: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
   - If not pushed:
     - Push branch: `git push -u origin <branch-name>`
     - Confirm push succeeded before continuing

5. **Determine Labels**

   Fetch available labels from the repository: `gh label list --limit 100`

   If label fetching fails (no access / no labels), skip label assignment silently.

   Otherwise, select one label from each of the following groups based on the PR content and commit type:

   **kind/** — select based on the conventional commit type:
   - `feat` → `kind/feature`
   - `fix` → `kind/bug`
   - `docs` → `kind/documentation`
   - `chore` or `build` or `ci` → `kind/cleanup`
   - `refactor` or `perf` → `kind/cleanup`
   - `style` → `kind/cleanup`
   - `revert` → `kind/bug`
   - `security` → `kind/bug`
   - `test` → `kind/cleanup`

   **lifecycle/** — select based on PR state:
   - Default: `lifecycle/active`
   - If PR is a draft or work-in-progress: `lifecycle/waiting`

   **priority/** — select based on commit type and urgency signals:
   - `fix` with words like "critical", "urgent", "hotfix", "security" in title → `priority/critical`
   - `fix` or `security` → `priority/high`
   - `feat` → `priority/medium`
   - `docs`, `chore`, `style`, `refactor`, `test`, `build`, `ci`, `perf` → `priority/low`

   **status/** — default to:
   - `status/in_progress`

   Build the `--label` flags from only those labels that exist in the repository's label list. Skip any label that doesn't
   exist (do not error).

6. **Create Pull Request**

   **IMPORTANT:** PR body must ONLY contain the Summary section with bullet points. Do NOT add additional sections like
   "Changes", "Details", etc.

   **Option A: Using GitHub CLI (preferred)**

   ```bash
   gh pr create --title "<title>" --assignee @me --label "<kind/xxx>" --label "<lifecycle/xxx>" --label "<priority/xxx>" --label "<status/xxx>" --body "$(cat <<'EOF'
   ## Summary

   - [Brief bullet point 1]
   - [Brief bullet point 2]
   - [Brief bullet point 3]

   EOF
   )"
   ```

   Only include `--label` flags for labels that were confirmed to exist in step 5.

   **Option B: Using GitHub MCP (fallback)**
   - Use `mcp__github__create_pull_request` with:
     - owner: extracted from git remote
     - repo: extracted from git remote
     - title: PR title
     - head: current branch name
     - base: "main" (or "master" if main doesn't exist)
     - body: PR description (Summary section only)
   - After creation, assign current user: `gh pr edit <pr-number> --add-assignee @me`
   - After creation, apply labels via: `gh pr edit <pr-number> --add-label "<label>"`

7. **Display Success Message**

   ```text
   ✅ Pull Request Created Successfully

   Title: <title>
   Branch: <branch-name>
   URL: <pr-url>
   Assignee: @me
   Labels: <kind/xxx>, <lifecycle/xxx>, <priority/xxx>, <status/xxx>
   Merge Strategy: Squash (recommended)

   The PR is ready for review and can be merged once:
   - All required reviews are approved
   - All CI checks pass
   ```

## Error Handling

- **On protected branch**: Stop immediately, instruct user to create feature branch
- **Invalid title format**: Show example, request correct format
- **Branch not pushed**: Automatically push with confirmation
- **GitHub CLI unavailable**: Fall back to GitHub MCP tools
- **Label not found**: Skip that label silently, do not error
- **PR creation fails**: Display error, suggest checking repository permissions

## Validation Rules

### Branch Name

- Must NOT be `main` or `master`
- Should follow pattern: `feat/*`, `fix/*`, `docs/*`, `chore/*`, etc.

### PR Title Format

- Pattern: `<type>(<scope>): <description>` or `<type>: <description>`
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security
- Scope: optional, alphanumeric with hyphens
- Description: present tense, no capitalization, no period, under 72 characters

## Label Groups Reference

All projects share a common label taxonomy. Labels follow `category/value` namespacing:

| Group        | Values                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------ |
| `kind/`      | bug, cleanup, deprecation, discussion, documentation, feature, question, renovate, support |
| `lifecycle/` | active, frozen, rotten, stale, waiting                                                     |
| `priority/`  | backlog, critical, high, low, medium                                                       |
| `status/`    | abandoned, available, blocked, in_progress, on_hold, proposal, review_needed               |

## Tools Usage

- **Bash**: Execute git commands, GitHub CLI commands
- **Read**: Read git configuration, repository files if needed
- **GitHub CLI (gh)**: Preferred method for PR creation and label management
- **GitHub MCP**: Fallback for PR creation if gh unavailable

## Important Notes

- **PR body format**: ONLY include "## Summary" section with bullet points. Do NOT add extra sections
- **Assignee**: ALWAYS assign the PR to the current user (`--assignee @me`). This is mandatory, not optional
- **Labels**: Always assign one label per group (kind, lifecycle, priority, status) when those labels exist
- **status/in_progress** is the default status label for newly created PRs
- Squash merge is the recommended merge strategy for this repository
- NEVER include Slack notifications or integrations
- Validate all inputs before creating PR
- Use heredoc pattern for multiline PR descriptions
- Handle errors gracefully with clear user feedback
