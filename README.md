<h1 align="center">
  <img src="web/public/logo-wordmark.png" alt="Agentheon" width="440" />
</h1>

<p align="center">
  <a href="https://github.com/nlamirault/agentheon/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache-2.0" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/nlamirault/agentheon"><img src="https://api.scorecard.dev/projects/github.com/nlamirault/agentheon/badge" alt="OpenSSF Scorecard" /></a>
</p>

Agentheon is a pantheon of Greek-deity software-engineering agents. **Zeus**
orchestrates; **executives** own domains and delegate down to **specialists**,
who each own one domain and hand off along defined routes, advancing only through
PASS/FAIL quality gates.

## Features

- **Single entrypoint** — Zeus routes every request; it never does specialist work.
- **Two-tier pantheon** — 28 deities: Zeus (orchestrator), six executives
  (CEO/CTO/COO/CFO/CMO/CRO), and specialists who own one domain each (planning,
  build, test, review, security, data, observability, docs, cost, networking,
  performance, supply chain, developer tooling, and more).
- **Quality gates** — plan → build → test → review → comply, each with a
  PASS/FAIL verdict. Nothing ships unverified.
- **Context-preserving handoffs** — every transition carries full context via a
  structured handoff template.
- **Generated routing matrix** — `team/routing.md` is compiled from each agent's
  frontmatter, giving Zeus a machine-readable map.

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
