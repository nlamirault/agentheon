---
name: "project-bootstrap"
description: "This skill should be used when the user asks to 'bootstrap a project', 'setup an open source project', 'create project structure', 'add project files', 'configure pre-commit hooks', 'setup GitHub Actions', 'initialize project with best practices', or mentions project automation, license management, or SPDX headers."
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - git
  - github
  task: [configure, build]
  persona: [developer]
  workload: [developer-tools]
license: "Apache-2.0"
---

# Project Bootstrap / Best Practices

Establish foundational configurations, automation, and best practices for open source software projects.

## Overview

This skill provides guidance for creating well-structured open source projects that follow industry best practices. It
covers essential configurations including pre-commit hooks, license management with SPDX headers, build automation via
Makefiles, and CI/CD workflows for GitHub Actions.

**Core capabilities:**

- Bootstrap new projects with complete file structure
- Validate existing projects for completeness
- Setup automation (prek, Renovate, Release Drafter, OSSF Scorecard)
- Configure license management with SPDX compliance
- Language-specific project templates (Python, Rust)

## When to Use This Skill

Use this skill when users need to:

- Create a new open source project from scratch
- Add missing essential files to existing projects
- Setup prek hooks for code quality
- Configure GitHub Actions workflows
- Implement SPDX-compliant license headers
- Validate project structure and completeness

## Essential Project Files

Every well-structured open source project should include these files. All templates are available in the `assets/`
directory.

### Core Documentation Files

**README.md** (`assets/README.md`)

- Project overview and description
- Quick start instructions
- Installation and usage guide
- Contributing guidelines reference

**LICENSE** (`assets/LICENSE`)

- Full license text (Apache-2.0 by default)
- Copyright information
- Legal terms and conditions

**CONTRIBUTING.md** (`assets/CONTRIBUTING.md`)

- How to contribute to the project
- Code style guidelines
- Pull request process
- Development setup instructions

**CODE_OF_CONDUCT.md** (`assets/CODE_OF_CONDUCT.md`)

- Community standards and expectations
- Behavior guidelines
- Enforcement policies

**SECURITY.md** (`assets/SECURITY.md`)

- Security policy
- Vulnerability reporting process
- Supported versions

**CITATION.cff** (`assets/CITATION.cff`)

- Citation information for academic use
- Author metadata
- Version and DOI information

### Legal and Compliance Files

**DCO** (`assets/DCO`)

- Developer Certificate of Origin
- Contribution attribution requirements

**CODEOWNERS** (`assets/CODEOWNERS`)

- Code ownership assignments
- Review requirements for specific paths

### Configuration Files

**.editorconfig** (`assets/editorconfig`)

- Editor configuration for consistent formatting
- Indentation, line endings, charset settings

**.gitignore** (`assets/gitignore`)

- Files and directories to exclude from git
- Common patterns for build artifacts and dependencies

**.pre-commit-config.yaml** (`assets/pre-commit-config.yaml`)

- Pre-commit hook configuration
- Automated code quality checks
- Security scanning hooks

**.taplo.toml** (`assets/taplo.toml`)

- Taplo TOML formatter configuration
- Formatting rules for all `.toml` files in the project

**.rumdl.toml** (`assets/rumdl.toml`)

- rumdl Markdown linter configuration
- Enabled/disabled rules and exclusion patterns

**.yamlfmt.yaml** (`assets/yamlfmt.yaml`)

- yamlfmt YAML formatter configuration
- Formatting rules for all `.yaml`/`.yml` files in the project

**.github/settings.yml** (`assets/settings.yml`)

- GitHub repository settings managed by the [probot/settings](https://probot.github.io/apps/settings/) GitHub App
- Declaratively configures: repository metadata, labels, milestones, collaborators, teams, and branch protection rules
- Must be placed at `.github/settings.yml` in the project — the Settings App reads this path automatically
- Placeholders to replace: `<PROJECT_NAME>`, description, homepage URL, topics, and the `private` boolean

**licenserc.toml** (`assets/licenserc.toml`)

- Apache SkyWalking Eyes configuration
- License header validation rules
- File exclusion patterns

**Makefile** (`assets/Makefile`)

- Standard build targets
- Development automation commands
- Common operations (test, lint, build, clean)

## License Management

### License Header Template

Create `hack/header.txt` with SPDX-compliant header:

```text
SPDX-FileCopyrightText: Copyright (C) <AUTHOR_NAME> <<AUTHOR_EMAIL>>
SPDX-License-Identifier: <LICENSE_ID>
```

**Supported licenses:**

- Apache-2.0 (recommended for open source)
- MIT
- GPL-3.0
- BSD-3-Clause

Replace placeholders with actual author information and chosen license identifier.

### License Validation

The `licenserc.toml` configuration enables automated license header validation using Apache SkyWalking Eyes. This
ensures all source files contain proper SPDX headers.

## GitHub Actions Workflows

Configure automated workflows for dependency management, releases, and security monitoring.

### Release Please Workflow

**File:** `.github/workflows/release-please.yml` (copy from `assets/ga-release-please.yml`)

Automatically generates release notes from pull requests. Requires configuration file:

**File:** `.github/release-please-config.json` (copy from `assets/github/release-please-config.json`)

And the manifest file:

**File:** `.release-please-manifest.json` (copy from `assets/github/release-please-manifest.json`)

Ask the user for which type of release is it and replace `release-type` in the `.github/release-please-config.json`
file. Ask the user for the current version of the project and replace `0.0.0` in `.release-please-manifest.json` by the
answer.

### OSSF Scorecard Workflow

**File:** `.github/workflows/ossf-scorecard.yml` (copy from `assets/ga-ossf.yml`)

Security monitoring and supply chain assessment. Provides OpenSSF Scorecard metrics for:

- Code review practices
- Dependency management
- Vulnerability scanning
- Branch protection
- Security policy presence

## Pre-commit Hooks

Pre-commit hooks automate code quality checks before commits. The configuration in `assets/pre-commit-config.yaml`
includes:

**Standard hooks:**

- Check for merge conflicts
- Fix end-of-file formatting
- Trim trailing whitespace
- Check for large files
- Detect private keys

**Formatter hooks:**

- `taplo` — TOML formatting (uses `.taplo.toml`)
- `yamlfmt` — YAML formatting (uses `.yamlfmt.yaml`)
- `rumdl` — Markdown linting (uses `.rumdl.toml`)

**Security hooks:**

- `gitleaks` — detect hardcoded secrets

**Installation:**

```bash
prek install
prek run -a
```

## Project Structure

Standard directory layout for open source projects:
`$CLAUDE_PLUGIN_ROOT/skills/project-bootstrap/references/project-structure.md`

## Workflow for Creating New Projects

### Step 1: Gather Requirements

Prompt user for essential information:

1. **Project name** - Used in configurations and documentation
2. **Target directory** - Where to create project structure
3. **Project type/language** - Python, Rust, or other (affects additional files)
4. **License type** - Apache-2.0, MIT, GPL-3.0, BSD-3-Clause
5. **Author information**:
   - Full name
   - Email address
   - GitHub username (optional)

### Step 2: Create Directory Structure

Create project root and essential directories:

```bash
mkdir -p <directory>/<project-name>
mkdir -p <directory>/<project-name>/.github/workflows
mkdir -p <directory>/<project-name>/hack
cd <directory>/<project-name>
```

### Step 3: Copy Essential Files

Copy all template files from `assets/` directory to project root:

- Copy `assets/CODE_OF_CONDUCT.md` to `CODE_OF_CONDUCT.md`
- Copy `assets/CODEOWNERS` to `.github/CODEOWNERS`
- Copy `assets/CONTRIBUTING.md` to `CONTRIBUTING.md`
- Copy `assets/DCO` to `DCO`
- Copy `assets/LICENSE` to `LICENSE`
- Copy `assets/README.md` to `README.md`
- Copy `assets/SECURITY.md` to `SECURITY.md`
- Copy `assets/CITATION.cff` to `CITATION.cff`
- Copy `assets/licenserc.toml` to `licenserc.toml`
- Copy `assets/editorconfig` to `.editorconfig`
- Copy `assets/gitignore` to `.gitignore`
- Copy `assets/pre-commit-config.yaml` to `.pre-commit-config.yaml`
- Copy `assets/Makefile` to `Makefile`
- Copy `assets/taplo.toml` to `.taplo.toml`
- Copy `assets/rumdl.toml` to `.rumdl.toml`
- Copy `assets/yamlfmt.yaml` to `.yamlfmt.yaml`
- Copy `assets/settings.yml` to `.github/settings.yml`

### Step 3b: Customize settings.yml

Open `.github/settings.yml` and replace the placeholder values:

| Placeholder | Replace with |
| --- | --- |
| `<PROJECT_NAME>` | Actual repository name |
| `description of the project` | Short project description |
| `URL of the project` | Project homepage URL (or remove line) |
| `some topics` | Comma-separated topic list |
| `true or false. Depends on user choice` | `true` (private) or `false` (public) |

Ask the user for the visibility (`private: true/false`) if not already known.

### Step 4: Create License Header

Create `hack/header.txt` with SPDX header using author information and chosen license.

### Step 5: Setup GitHub Actions

Copy workflow files:

- Copy `assets/ga-release-please.yml` to `.github/workflows/release-please.yml`
- Copy `assets/ga-ossf.yml` to `.github/workflows/ossf-scorecard.yml`

Copy configuration files:

- Copy `assets/github/release-please-config.json` to `.github/release-please-config.json`
- Copy `assets/github/release-please-manifest.json` to `.release-please-manifest.json`

### Step 6: Language-Specific Setup

If user specified a language, consult the appropriate reference file for additional setup:

- **Python projects**: Handled by delegation to `python:python-project` agent (see project-manager agent)
- **Go projects**: Handled by delegation to `go:go-project` agent (see project-manager agent)
- **Rust projects**: Handled by delegation to `rust:rust-project` agent (see project-manager agent)
- **OCaml projects**: Handled by delegation to `ocaml:ocaml-project` agent (see project-manager agent)

Apply language-specific configurations and files as documented in the reference.

### Step 7: Initialize Git Repository

If not already a git repository:

```bash
git init
git add .
git commit -m "chore: initial project setup

- Add pre-commit configuration
- Add license management (licenserc.toml)
- Add Makefile with standard targets
- Add GitHub Actions workflows
- Add essential documentation files"
```

### Step 8: Install Pre-commit Hooks

```bash
prek install
prek run -a
```

## Workflow for Validating Existing Projects

### Step 1: Gather Information

Prompt user for:

1. **Project directory** - Path to existing project
2. **License type** - Expected license (Apache-2.0, MIT, etc.)
3. **Author information** - For validation

### Step 2: Check Directory Structure

Verify essential directories exist:

```bash
ls <directory>/.github/workflows
ls <directory>/hack
```

### Step 3: Check Essential Files

Verify all required files exist by checking for presence of:

- README.md
- LICENSE
- CONTRIBUTING.md
- CODE_OF_CONDUCT.md
- SECURITY.md
- CITATION.cff
- DCO
- .github/CODEOWNERS
- .github/settings.yml
- .editorconfig
- .gitignore
- .pre-commit-config.yaml
- licenserc.toml
- Makefile
- hack/header.txt

**Report missing files** to user with simple checklist (✅ exists, ❌ missing).

### Step 4: Check GitHub Actions

Verify workflow files exist:

- .github/workflows/release-please.yml
- .github/workflows/ossf-scorecard.yml
- .github/release-please-config.json
- .release-please-manifest.json

### Step 5: Check Pre-commit Installation

```bash
cd <directory>
prek list
```

Report whether pre-commit hooks are installed.

### Step 6: Validation Summary

Provide summary report:

**Structure:**

- ✅/❌ .github/workflows/ directory
- ✅/❌ hack/header.txt
- ✅/❌ Essential files present

**Configuration:**

- ✅/❌ Pre-commit hooks installed
- ✅/❌ Git repository initialized

**Recommendation:** If files are missing, offer to create them using the project bootstrap workflow.

## Best Practices

### Automation First

Automate repetitive tasks:

- Pre-commit hooks for code quality
- CI/CD workflows for testing and deployment
- Dependency updates via Renovate (configured separately)
- Automated release notes

### Security by Default

Include security measures:

- Security scanning in pre-commit hooks
- OSSF Scorecard for supply chain security
- License management with SPDX compliance
- Developer Certificate of Origin (DCO)
- Security policy (SECURITY.md)

### Consistency

Maintain consistent structure:

- Standard file naming conventions
- Conventional commit messages
- Uniform documentation format
- Consistent code formatting via .editorconfig

### Documentation

Provide comprehensive documentation:

- Clear README with quick start
- Contributing guidelines
- Security policy
- Code of conduct
- Citation information for academic use

## Language-Specific References

For detailed language-specific setup instructions, consult:

### Python Projects

**Note:** Python-specific project setup is now handled by the `python:python-project` agent through delegation from the
`project-manager` agent. See:

- **Agent:** `plugins/python/agents/python-project.md`
- **Skill:** `plugins/python/skills/python-project-structure/SKILL.md`
- **Reference:** `plugins/python/skills/python-project-structure/references/new-project.md`

Python configurations handled by the agent include:

- Project structure (src/ layout, pyproject.toml)
- Dependency management (uv)
- Testing frameworks (pytest)
- Linting and formatting (ruff)
- Type checking (ty)

### Go Projects

**Note:** Go-specific project setup is now handled by the `go:go-project` agent through delegation from the
`project-manager` agent. See:

- **Agent:** `plugins/go/agents/go-project.md`
- **Skill:** `plugins/go/skills/go-project-packaging/SKILL.md`
- **Reference:** `plugins/go/skills/go-project-packaging/references/new-project.md`

Go configurations handled by the agent include:

- Go modules configuration (go.mod, go.sum)
- Project structure (cmd/, internal/, pkg/)
- Testing setup (go test)
- Linting (golangci-lint)
- Formatting (gofmt)
- Build automation (Makefile)
- GitHub Actions CI/CD workflows
- Docker containerization (multi-stage builds)

### Rust Projects

**Note:** Rust-specific project setup is now handled by the `rust:rust-project` agent through delegation from the
`project-manager` agent. See:

- **Agent:** `plugins/rust/agents/rust-project.md`
- **Skill:** `plugins/rust/skills/rust-project-structure/SKILL.md`
- **Reference:** `plugins/rust/skills/rust-project-structure/references/new-project.md`

Rust configurations handled by the agent include:

- Cargo.toml configuration and dependencies
- Project structure (src/, tests/, examples/)
- Linting (clippy) and formatting (rustfmt)
- Documentation generation (cargo doc)
- Testing setup (cargo test)
- Build automation (Makefile)
- GitHub Actions CI/CD workflows
- Docker containerization

### OCaml projects

**Note:** OCaml-specific project setup is now handled by the `ocaml:ocaml-project` agent through delegation from the
`project-manager` agent. See:

- **Agent:** `plugins/ocaml/agents/ocaml-project.md`
- **Skill:** `plugins/ocaml/skills/ocaml-project-structure/SKILL.md`
- **Reference:** `plugins/ocaml/skills/ocaml-project-structure/references/new-project.md`

OCaml configurations handled by the agent include:

- Dune configuration and dependencies using the dune-project file
- Prostructure (src/, bin/, lib/, ...)
- Documentation generation (with odoc)
- Build automation (Makefile)
- GitHub Actions CI/CD workflows

## Asset Files Reference

All template files are located in `$CLAUDE_PLUGIN_ROOT/skills/project-bootstrap/assets/`:

| Asset File                     | Target Location                      | Purpose                         |
| ------------------------------ | ------------------------------------ | ------------------------------- |
| CITATION.cff                   | CITATION.cff                         | Citation metadata               |
| CODE_OF_CONDUCT.md             | CODE_OF_CONDUCT.md                   | Community standards             |
| CODEOWNERS                     | .github/CODEOWNERS                   | Code ownership                  |
| CONTRIBUTING.md                | CONTRIBUTING.md                      | Contribution guidelines         |
| DCO                            | DCO                                  | Developer Certificate of Origin |
| LICENSE                        | LICENSE                              | Full license text               |
| README.md                      | README.md                            | Project overview                |
| SECURITY.md                    | SECURITY.md                          | Security policy                 |
| editorconfig                   | .editorconfig                        | Editor settings                 |
| gitignore                      | .gitignore                           | Git exclusions                  |
| pre-commit-config.yaml         | .pre-commit-config.yaml              | Pre-commit hooks                |
| taplo.toml                     | .taplo.toml                          | TOML formatter config           |
| rumdl.toml                     | .rumdl.toml                          | Markdown linter config          |
| yamlfmt.yaml                   | .yamlfmt.yaml                        | YAML formatter config           |
| licenserc.toml                 | licenserc.toml                       | License validation              |
| Makefile                       | Makefile                             | Build automation                |
| settings.yml                   | .github/settings.yml                 | GitHub repo settings (probot)   |
| ga-release-please.yml          | .github/workflows/release-please.yml | Release workflow                |
| release-please-config.json.yml | .github/release-please-config.json   | Release config                  |
| ga-ossf.yml                    | .github/workflows/ossf-scorecard.yml | Security workflow               |

## Additional Resources

### Reference Files

- **Go**: See `go:go-project` agent in Go plugin (`plugins/go/skills/go-project-structure/`)
- **Python**: See `python:python-project` agent in Python plugin (`plugins/python/skills/python-project-structure/`)
- **Rust**: See `rust:rust-project` agent in Rust plugin (`plugins/rust/skills/rust-project-structure/`)

### External Documentation

- [Pre-commit Documentation](https://pre-commit.com/)
- [SPDX License List](https://spdx.org/licenses/)
- [Apache SkyWalking Eyes](https://github.com/apache/skywalking-eyes)
- [Release Please Action](https://github.com/googleapis/release-please-action/)
- [OSSF Scorecard](https://github.com/ossf/scorecard)
- [GitHub Actions Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
