# Conventional Commits Guide

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for all commit messages.

## Commit Message Format

```text
<type>(<scope>): <description>

<mandatory body>

[optional footer]
```

## Commit Types

| Type       | Usage                        | Example                                     |
| ---------- | ---------------------------- | ------------------------------------------- |
| `feat`     | New feature                  | `feat(monitoring): add CloudWatch alarms`   |
| `fix`      | Bug fix                      | `fix(iam): correct role trust policy`       |
| `docs`     | Documentation only           | `docs(readme): update installation steps`   |
| `style`    | Formatting (no logic change) | `style(terraform): fix indentation`         |
| `refactor` | Code refactoring             | `refactor(lambda): simplify error handling` |
| `perf`     | Performance improvement      | `perf(query): optimize database indexes`    |
| `test`     | Adding/modifying tests       | `test(api): add integration tests`          |
| `chore`    | Maintenance tasks            | `chore(deps): update AWS provider`          |
| `ci`       | CI/CD changes                | `ci(github): add terraform validation`      |
| `security` | Security patches             | `security(s3): enable encryption at rest`   |

## Scope (Optional but Recommended)

The scope specifies the affected module, service, or area:

**Examples:**

- Module names: `cilium`, `api-gateway`, `loki`, `mimir`
- Resources: `rds`, `s3`, `iam`, `vpc`, `lambda`
- Environments: `prod`, `preprod`, `master`
- Services: `api`, `frontend`, `backend`
- Area: `terraform`, `kubernetes`, `helm`,

## Commit Message Rules

1. **Imperative present tense**: Use "add" not "added" or "adds"
2. **No capitalization**: Don't capitalize first letter of description
3. **No period**: No period at end of description
4. **Max 72 characters**: Keep first line under 72 characters
5. **Mandatory body**: Always include a body explaining the "why" and summarizing what changed
6. **Reference issue tracker**: If related to a tracked issue, include the appropriate footer (see below)

## Issue Tracker Footers

When a commit is related to a tracked issue, include a footer referencing it. The footer is placed after the body,
separated by a blank line.

| Tracker   | Footer format              | Notes                                  |
| --------- | -------------------------- | -------------------------------------- |
| GitHub    | `Closes: #123`             | Automatically closes the issue on merge|
| GitHub    | `Fixes: #123`              | Same effect as `Closes:`               |
| GitHub    | `Related: #123`            | Reference without closing              |
| GitLab    | `Closes: #123`             | Automatically closes the issue on merge|
| Linear    | `Linear: TEAM-123`         | Links to Linear ticket                 |
| Jira      | `Jira: PROJ-123`           | Links to Jira issue                    |
| Any URL   | `Refs: <URL>`              | Generic tracker reference              |

Multiple footers are allowed — add one line per reference.

**Use closing keywords** (`Closes:`, `Fixes:`) when the commit fully resolves the issue.
**Use non-closing keywords** (`Related:`, `Refs:`, `Linear:`, `Jira:`) for partial work or context.

## Using Git Commit with Heredoc

For complex commit messages, use heredoc to maintain formatting:

```bash
git commit -m "$(cat <<'EOF'
feat(monitoring): add CloudWatch alarms for MSK clusters

Adds CloudWatch alarms to detect MSK broker health and resource saturation.
The following alarms are implemented:
- Broker count below threshold
- Disk usage above 80%
- CPU usage sustained above 90%

Closes: #123
EOF
)"
```

Or referencing a Linear ticket:

```bash
git commit -m "$(cat <<'EOF'
fix(api): handle nil pointer in auth middleware

The auth middleware panicked when the token was missing from the context.
Added a nil check before dereferencing the user struct.

Linear: BACKEND-456
EOF
)"
```

## Atomic Commits

Follow these principles:

1. **One commit = one logical change**
2. **Avoid large commits mixing multiple changes**
3. **Separate code changes from formatting**
4. **Each commit should be independently deployable if possible**

<!--

## Emoji

Only add emoji when user explicitly requests with `--emoji` flag or mentions emoji:

- ✨ feat: New features
- 🐛 fix: Bug fixes
- 📝 doc: Documentation changes
- ♻️ refactor: Code restructuring without changing functionality
- 🎨 style: Code formatting, missing semicolons, etc.
- ⚡️ perf: Performance improvements
- ✅ test: Adding or correcting tests
- 🧑‍💻 chore: Tooling, configuration, maintenance
- 🚧 wip: Work in progress
- 🔥 remove: Removing code or files
- 🚑 hotfix: Critical fixes
- 🔒 security: Security improvements

-->

## Commit Message Checklist

Before committing, verify:

- [ ] Type is correct (`feat`, `fix`, `chore`, etc.)
- [ ] Scope is meaningful and accurate
- [ ] Description is imperative present tense
- [ ] Description is under 72 characters
- [ ] No capitalization at start of description
- [ ] No period at end of description
- [ ] Body is present and explains "why" and what changed (REQUIRED)
- [ ] Issue tracker footer added if applicable (`Closes:`, `Fixes:`, `Linear:`, `Jira:`, `Refs:`)
- [ ] Breaking changes marked with `!` or `BREAKING CHANGE:`
