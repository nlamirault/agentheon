<h1 align="center">
  <img src="web/public/logo-wordmark.png" alt="Agentheon" width="440" />
</h1>

<p align="center">
  <a href="https://github.com/nlamirault/agentheon/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache-2.0" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/nlamirault/agentheon"><img src="https://api.scorecard.dev/projects/github.com/nlamirault/agentheon/badge" alt="OpenSSF Scorecard" /></a>
</p>

Agentheon is a pantheon of Greek-deity software-engineering agents. **Hermes**
orchestrates; each specialist owns one domain and hands off to the next along
defined routes, advancing only through PASS/FAIL quality gates.

## Features

- **Single entrypoint** — Hermes routes every request; it never does specialist work.
- **Single-domain agents** — 17 deities, one domain each (planning, build, test,
  review, security, data, observability, docs, and more).
- **Quality gates** — plan → build → test → review → comply, each with a
  PASS/FAIL verdict. Nothing ships unverified.
- **Context-preserving handoffs** — every transition carries full context via a
  structured handoff template.
- **Generated routing matrix** — `team/routing.md` is compiled from each agent's
  frontmatter, giving Hermes a machine-readable map.

## Documentation

Full docs live in [`docs/`](docs/README.md), organized with the
[Diátaxis](https://diataxis.fr/) framework:

| I want to...                      | Go to                                             |
| --------------------------------- | ------------------------------------------------- |
| Learn Agentheon from scratch      | [Tutorials](docs/tutorials/)                      |
| Accomplish a specific task        | [How-to Guides](docs/how-to/)                     |
| Look up an agent or convention    | [Reference](docs/reference/agents.md)             |
| Understand how the pantheon works | [Explanation](docs/explanation/architecture.md)   |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
See [CONTRIBUTING](CONTRIBUTING.md)

## License

See [LICENSE](LICENSE)
