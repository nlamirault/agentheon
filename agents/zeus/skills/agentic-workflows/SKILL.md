---
name: "agentic-workflows"
description: "Creates GitHub Agentic Workflows (gh-aw) for AI-powered repository automation. Use this skill whenever the user wants to automate issue labeling, set up AI-powered issue triage, configure agentic GitHub workflows, generate gh-aw workflow files, or automate any GitHub repository task with an AI agent. Trigger on: 'issue triage', 'automated labels', 'agentic workflow', 'gh-aw', 'automate issue classification', 'triage issues automatically', 'label new issues', 'GitHub AI agent', or any request for GitHub repository automation using AI agents."
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - github
  task: [configure, automate]
  persona: [developer, maintainer]
  workload: [developer-tools]
license: "Apache-2.0"
---

# GitHub Agentic Workflows (gh-aw)

Generate [gh-aw](https://github.github.com/gh-aw/) workflow files that run AI agents inside GitHub Actions for automated repository management.

## What gh-aw Is

A GitHub Next framework: AI agents run in GitHub Actions with layered security guardrails:

- **Read-only agent tokens** — the AI can only read; writes happen via separate scoped jobs
- **`safe-outputs` allowlist** — explicitly declares which actions the agent may take (labels, comments, etc.), blocking prompt injection escalation
- **`lockdown: true`** — restricts toolsets when processing untrusted content (public issues, PRs)
- **Containerized firewall** — network egress limited to a domain allowlist

A gh-aw workflow is a single `.md` file: YAML frontmatter = execution config, markdown body = agent instructions.

## Naming Convention

All gh-aw workflow files use a `name:` field following this pattern:

```yaml
name: "Agent / <Workflow Name>"
```

Examples: `"Agent / Issue Triage"`, `"Agent / PR Triage"`, `"Agent / PR Stale"`.
This groups all agent workflows under a shared `Agent /` prefix in the GitHub Actions UI.

## Available Agents

| Agent | Reference | Asset template |
|---|---|---|
| **Issue Triage** — classify unlabeled issues with `kind/*` labels | `references/issue-triage-agent.md` | `assets/issue-triage-agent.md` |
| **PR Triage** — classify open PRs with `kind/*`, `size/*`, `priority/*` labels | `references/pr-triage-agent.md` | `assets/pr-triage-agent.md` |
| **PR Stale** — warn and close PRs stale 30+ days via `lifecycle/stale` → `lifecycle/rotten` → close | `references/pr-stale-agent.md` | `assets/pr-stale-agent.md` |

When the user requests a specific agent, read the corresponding reference file for the full workflow, label taxonomy, and customization options.

## Common Security Principles

Apply to all agents:

- Set `lockdown: true` whenever the agent processes content from untrusted public users (issues, PR descriptions, comments)
- Never grant `issues: write` or `pull-requests: write` in `permissions:` — gh-aw handles writes in isolated post-execution jobs
- Keep `safe-outputs` allowlists as narrow as possible — only include the labels/actions the agent actually needs
- For scheduled batch workflows, prefer `on: schedule` over event triggers to reduce the attack surface

## References

- [gh-aw documentation](https://github.github.com/gh-aw/)
- Label definitions: `$CLAUDE_PLUGIN_ROOT/../project-bootstrap/assets/settings.yml`
