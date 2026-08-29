---
name: create-commit
allowed-tools: Bash(*), Read(*), AskUserQuestion(*)
argument-hint: "[message] [--emoji]"
description: Create a git commit following conventional commit standards with automatic scope detection
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

# Create Git Commit

Create a git commit with a properly formatted conventional commit message, including automatic scope detection based on
changed files.

## Workflow

0. **Branch Guard (MANDATORY — run FIRST, before anything else)**

   Check the current branch:

   ```bash
   git branch --show-current
   ```

   **STOP immediately** if the current branch is a protected branch:
   - `master`
   - `main`
   - `develop`
   - `release/*`
   - `hotfix/*`

   Do NOT proceed with any staging, diffing, or committing. Instead:

   ```text
   ❌ Cannot commit directly to protected branch: <branch-name>

   Direct commits to '<branch-name>' are forbidden.
   Create a feature branch first:

     git checkout -b <suggested-branch-name>

   Suggested branch name based on context: feat/<topic> or fix/<topic>
   ```

   Suggest a branch name derived from the staged/unstaged file paths or ask the user.
   Only continue after the user has switched to a non-protected branch.

1. **Review Staged and Unstaged Changes**

   Before creating a commit, always inspect changes:

   ```bash
   # Review staged changes
   git --no-pager diff --staged

   # Review unstaged changes
   git --no-pager diff

   # Combined view of all changes
   git --no-pager diff HEAD
   ```

   Display a summary of:
   - Number of files changed
   - Files modified (with paths)
   - Whether changes are staged or unstaged

2. **Stage Changes (if needed)**

   If there are unstaged changes, ask user if they want to stage all changes:
   - **If yes**: Run `git add -A`
   - **If no**: Ask which files to stage, or abort if no files are staged

3. **Detect Commit Type**

   Analyze the changed files to suggest appropriate commit type:

   | File Pattern/Change Type                               | Suggested Type |
   | ------------------------------------------------------ | -------------- |
   | New feature files                                      | `feat`         |
   | Bug fix in existing code                               | `fix`          |
   | Only `.md` files or `docs/`                            | `docs`         |
   | Formatting changes only                                | `style`        |
   | Code restructuring                                     | `refactor`     |
   | Performance improvements                               | `perf`         |
   | Test files only                                        | `test`         |
   | Build/config files                                     | `build`        |
   | CI/CD configs (`.github/workflows/`, `.gitlab-ci.yml`) | `ci`           |
   | Dependency updates, tooling                            | `chore`        |
   | Reverting previous commit                              | `revert`       |
   | Security-related changes                               | `security`     |

   If unclear, default to `chore` or ask user to clarify.

4. **Detect Scope**

   Analyze changed file paths to suggest scope:

   | File Pattern                       | Suggested Scope       |
   | ---------------------------------- | --------------------- |
   | `src/api/*`, `api/*`               | `api`                 |
   | `src/components/*`, `components/*` | `ui`                  |
   | `src/services/*`                   | `services`            |
   | `src/utils/*`, `lib/*`             | `utils`               |
   | `tests/*`, `*_test.*`, `*.test.*`  | `test`                |
   | `*.config.*`, `config/*`           | `config`              |
   | `docs/*`, `*.md`                   | `docs`                |
   | `cmd/*`                            | `cli`                 |
   | `internal/*`                       | `internal`            |
   | `pkg/*`                            | `pkg`                 |
   | `plugins/*`                        | plugin name from path |
   | `.rules/*`                         | `rules`               |

   If files span multiple directories, use the most specific common component or omit scope.

5. **Generate or Validate Commit Message**

   **If message argument provided:**
   - Validate format: `<type>(<scope>): <description>` or `<type>: <description>`
   - Check type is valid
   - Check description starts with lowercase
   - Check description doesn't end with period
   - If invalid, show errors and ask for correction
   - After validation, always ask for a commit body (REQUIRED): explain "why" this change is needed and summarize what
     changed

   **If no message argument:**
   - Present detected type and scope
   - Ask user for description
   - Ask user for body (REQUIRED): explain "why" this change is needed and summarize what changed
   - Construct message: `<type>(<scope>): <description>`
   - Validate and confirm with user

   **Body writing rules:**
   - Do NOT include specific counts or numbers (e.g. "32 files", "125 SKILL.md blocks") — use qualitative language instead ("all affected", "every plugin", "across all skills")
   - Explain *why*, not *how many*

6. **Link Issue Tracker (optional)**

   After collecting the commit body, ask:

   > "Is this commit related to a GitHub issue, Linear ticket, Jira ticket, or any other issue tracker?"

   - **If yes**: Ask for the reference (URL or ID)
   - **If no**: Skip footer — do not add any issue reference

   Format the footer based on the tracker type detected from the URL or ID provided:

   | Tracker   | Input example                                         | Footer format                                               |
   | --------- | ----------------------------------------------------- | ----------------------------------------------------------- |
   | GitHub    | `#123` or `https://github.com/org/repo/issues/123`    | `Closes: #123` (if fix/feat) or `Related: #123`             |
   | Linear    | `TEAM-123` or `https://linear.app/team/issue/TEAM-123`| `Linear: TEAM-123`                                          |
   | Jira      | `PROJ-123` or `https://yourorg.atlassian.net/browse/` | `Jira: PROJ-123`                                            |
   | GitLab    | `#123` or `https://gitlab.com/group/repo/-/issues/123`| `Related: #123`                                             |
   | Other URL | Any full URL                                          | `Refs: <URL>`                                               |

   **Closing keywords** (use when the commit directly resolves the issue):
   - GitHub: `Closes: #123`, `Fixes: #123`
   - GitLab: `Closes: #123`

   **Non-closing reference** (use for partial work or related context):
   - `Related: #123`, `Refs: <URL>`, `Linear: TEAM-123`, `Jira: PROJ-123`

   If the user provides multiple issue references, add one footer line per reference.

7. **Add Emoji (if --emoji flag present)**

   Prepend appropriate emoji based on commit type:
   - ✨ `feat`: New features
   - 🐛 `fix`: Bug fixes
   - 📝 `docs`: Documentation changes
   - ♻️ `refactor`: Code restructuring
   - 🎨 `style`: Code formatting
   - ⚡️ `perf`: Performance improvements
   - ✅ `test`: Adding/correcting tests
   - 🧑‍💻 `chore`: Tooling, configuration
   - 🚧 `wip`: Work in progress
   - 🔥 `remove`: Removing code/files
   - 🚑 `hotfix`: Critical fixes
   - 🔒 `security`: Security improvements
   - 🏗️ `build`: Build system changes
   - 👷 `ci`: CI/CD changes
   - ⏪ `revert`: Revert previous commit

8. **Create Commit**

   **ALWAYS** execute the git commit command with the `-s` flag to add Signed-off-by line.
   Since a body is mandatory, **always use a heredoc** to preserve multi-line formatting:

   ```bash
   git commit -s -m "$(cat <<'EOF'
   type(scope): description

   Body explaining why this change is needed and what was changed.

   Closes: #123
   EOF
   )"
   ```

   Or with emoji:

   ```bash
   git commit -s -m "$(cat <<'EOF'
   <emoji> type(scope): description

   Body explaining why this change is needed and what was changed.

   Linear: TEAM-123
   EOF
   )"
   ```

   The `-s` flag adds a Signed-off-by trailer to the commit message with the committer's name and email.

   Additionally, if GPG signing is configured (`git config --global commit.gpgsign true`),
   the commit will also be cryptographically signed.

   The commit Message Format:

   ```text
   <type>(<scope>): <description>

   <mandatory body>

   [issue tracker footer — omit if not applicable]

   Signed-off-by: Your Name <your.email@example.com>
   ```

10. **Display Success Message**

    ```text
    ✅ Commit Created Successfully

    Type:        <type>
    Scope:       <scope> (or "none" if not provided)
    Description: <description>
    Emoji:       <emoji> (if --emoji flag used)
    Issue:       <tracker reference> (or "none" if not provided)

    Message: <full-commit-message>

    Commit SHA: <sha>
    Signed-off-by: <name> <email>

    Note: Commit includes DCO sign-off (-s flag)
         GPG signature added if configured

    Next steps:
    - Review commit: git show HEAD
    - Amend if needed: git commit --amend
    - Push to remote: git push (when ready)
    ```

## Commit Validation Script

Before creating the commit, validate the message with the bundled script:

```bash
echo "<proposed-message>" | python3 ${CLAUDE_SKILL_ROOT}/scripts/validate_commit_msg.py -
```

The script checks: correct type, lowercase description, no trailing period, subject line length, blank line before body.
Show the output to the user and fix any reported issues before proceeding.

## Session Memory

At the start of each session, check for recent commit history to suggest consistent scopes and types:

```bash
HISTORY_FILE="${CLAUDE_PLUGIN_DATA}/commit-history.json"
```

**Reading history (at session start):**
If `$HISTORY_FILE` exists, read the last 10 entries and use them to:

- Suggest the same scope for the same file paths (consistency within a project)
- Notice if the user typically uses a particular type for certain file patterns

**Writing history (after each successful commit):**
Append a record to `$HISTORY_FILE`:

```json
{"timestamp": "ISO-8601", "sha": "...", "type": "feat", "scope": "api", "description": "...", "files": ["src/api/..."]}
```

Keep the file to the last 50 entries (trim older entries on write). The file persists across sessions — this is what
allows scope suggestions to improve over time.

If `$CLAUDE_PLUGIN_DATA` is not set or writing fails, skip silently — history is a convenience, not a requirement.

## Validation Rules

### Commit Message Format

1. **Type**: Required
   - Must be one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security
   - Must be lowercase
   - Must be followed by colon (with optional scope in parentheses)

2. **Scope**: Optional
   - If present, must be within parentheses after type
   - Should be lowercase alphanumeric with hyphens
   - Should be relevant to the codebase structure

3. **Description**: Required
   - Must be present after colon and space
   - Should start with lowercase letter
   - Should use imperative mood ("add" not "adds" or "added")
   - Should not end with period
   - Limit to 20 words or ~72 characters
   - Be descriptive and concise
   - Describe ONLY the files changed

### Valid Examples

```text
feat(api): implement OAuth2 login flow

Replaces basic authentication with OAuth2 authorization code flow.
Adds token exchange and refresh handling to the user session model.

fix(auth): resolve race condition in cache

The cache was being written concurrently without a lock, causing
occasional stale reads under high load. Adds a mutex around writes.

chore(deps): update dependencies to latest versions

Bumps all direct dependencies to their latest stable versions to
address known CVEs and pick up upstream bug fixes.
```

### Invalid Examples

```text
Add new feature                 # Missing type
feat Add new feature            # Missing colon
FEAT: add new feature           # Uppercase type
feat(): add new feature         # Empty scope
feat: Add new feature           # Capitalized description
feat: add new feature.          # Period at end
update: add new feature         # Invalid type
feat(User-Auth): add profile    # Uppercase in scope
feat:add new feature            # Missing space after colon
feat: added new feature         # Past tense (not imperative)
feat: add new feature           # Missing body (body is mandatory)
```

## Scope Detection Logic

Parse changed file paths and map to suggested scopes:

```bash
# Get list of changed files
git diff --staged --name-only

# Analyze patterns
for file in changed_files:
  if file matches "src/api/*" or "api/*":
    suggest scope: api
  elif file matches "src/components/*":
    suggest scope: ui
  elif file matches "tests/*":
    suggest scope: test
  # ... continue pattern matching
```

If multiple scopes detected, suggest the most common or ask user to choose.

## Interactive Flow Example

```text
📝 Creating Git Commit

Changed files:
  ✓ src/api/auth.ts (staged)
  ✓ src/api/users.ts (staged)
  ✓ tests/api/auth.test.ts (staged)

Detected type: feat (new functionality detected)
Detected scope: api (most files in src/api/)

Enter commit description (imperative mood, lowercase):
> add OAuth2 authentication endpoint

Enter commit body (REQUIRED — explain why and summarize what changed):
> Implements the OAuth2 authorization code flow to replace the existing
> basic auth mechanism. Adds token exchange, refresh handling, and
> updates the user session model accordingly.

Is this commit related to a GitHub issue, Linear ticket, Jira ticket, or other tracker? (y/n): y
Enter the issue reference or URL:
> https://github.com/org/repo/issues/42

Proposed message:
feat(api): add OAuth2 authentication endpoint

Implements the OAuth2 authorization code flow to replace the existing
basic auth mechanism. Adds token exchange, refresh handling, and
updates the user session model accordingly.

Closes: #42

Validate:
✅ Valid conventional commit format
✅ Imperative mood
✅ Lowercase description
✅ No trailing period
✅ Under 72 characters (41)
✅ Body present
✅ Issue reference present

Create commit with this message? (y/n): y

✅ Commit created: feat(api): add OAuth2 authentication endpoint
   SHA: abc123def456
   Signed-off-by: John Doe <john.doe@example.com>
   Issue: Closes: #42
```

## Error Handling

- **On protected branch (master/main/develop)**: STOP — refuse to commit, suggest feature branch name, abort
- **No changes staged**: Ask user to stage changes or abort
- **Invalid commit type**: Show valid types, ask for correction
- **Invalid format**: Show format requirements with examples
- **Missing body**: Prompt user for body — do not create commit without one
- **Commit fails**: Display git error message
- **Not in git repository**: Display error "Not in a git repository"

## Tools Usage

- **Bash**: Execute git commands for diff, add, commit
- **Read**: Read git config or file contents if needed for analysis
- **AskUserQuestion**: Prompt user for commit details, confirmations

## Important Notes

- ALWAYS review changes before committing
- NEVER commit without user confirmation
- NEVER push to remote unless user explicitly requests it
- ALWAYS validate commit message format
- **ALWAYS use `-s` flag to sign commits with DCO (Developer Certificate of Origin)**
- GPG signing is additional and automatic if configured
- Provide clear, actionable feedback at each step
- Keep commit message professional and informative
- Use imperative, present-tense style

## Before committing, verify

- [ ] Current branch is NOT master/main/develop/release/hotfix (REQUIRED — abort if it is)
- [ ] Used `-s` flag with git commit (REQUIRED)
- [ ] Type is correct (`feat`, `fix`, `chore`, etc.)
- [ ] Scope is meaningful and accurate
- [ ] Description is imperative present tense
- [ ] Description is under 72 characters
- [ ] No capitalization at start of description
- [ ] No period at end of description
- [ ] Body is present and explains "why" and what changed (REQUIRED)
- [ ] User was asked about related issue tracker (GitHub, Linear, Jira, etc.)
- [ ] Issue footer added if applicable (`Closes:`, `Fixes:`, `Linear:`, `Jira:`, `Refs:`)
- [ ] `Signed-off-by` line will be added automatically by `-s` flag
- [ ] Breaking changes marked with `!` or `BREAKING CHANGE:`
