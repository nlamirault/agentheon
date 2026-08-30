---
name: mermaid-diagrams
description: >
  Create professional software diagrams using Mermaid's text-based syntax. Use this skill whenever
  the user wants to create, visualize, or document software architecture, system flows, or processes
  as diagrams. Supported diagram types: Sequence Diagrams (API flows, auth flows, microservice
  interactions), Flowcharts (processes, algorithms, CI/CD pipelines, decision trees), and
  Architecture Diagrams (cloud infrastructure, CICD pipelines, service topology, network diagrams).
  Trigger on phrases like "create a diagram", "draw a sequence diagram", "visualize my architecture",
  "show the flow", "diagram this", "mermaid diagram", "flowchart for", "architecture diagram", or
  whenever a user describes a system, flow, or process and would benefit from a visual. Also trigger
  proactively when the user describes a complex system interaction, API design, deployment pipeline,
  or infrastructure setup — even if they haven't explicitly asked for a diagram.
license: Apache-2.0
allowed-tools: Read Write AskUserQuestion
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - markdown
  - github
  task: [document, build]
  persona: [developer, technical-writer]
  workload: [documentation]
---

# Mermaid Diagram Creator

You create professional, readable software diagrams using Mermaid's text-based syntax.

## Step 1 — Clarify the diagram type

If the user hasn't specified which type of diagram they need, ask:

> "Which type of diagram would you like?
>
> 1. **Sequence Diagram** — interactions between components over time (API calls, auth flows, microservice communication)
> 2. **Flowchart** — processes, algorithms, decision trees, CI/CD pipelines, user journeys
> 3. **Architecture Diagram** — cloud infrastructure, service topology, CICD pipelines, network diagrams"

If the user's description clearly implies a type, you can skip asking and proceed directly.

## Step 2 — Load the reference guide

Before generating, read the appropriate reference file for full syntax details:

| Diagram type | Reference file                        |
| ------------ | ------------------------------------- |
| Sequence     | `references/sequence-diagrams.md`     |
| Flowchart    | `references/flowcharts.md`            |
| Architecture | `references/architecture-diagrams.md` |

## Step 3 — Gather requirements (if needed)

Ask clarifying questions only if key information is missing:

- What are the main **components/actors** involved?
- What is the **direction of flow** (e.g., left-to-right, top-to-bottom)?
- Any **groupings** (e.g., environments, layers, services)?
- Should it show **error paths / alternative flows** (for sequences/flowcharts)?

If the user has given enough context, proceed directly.

## Step 4 — Generate the diagram

Produce a Mermaid code block in a markdown fence:

```mermaid
<diagram code here>
```

After the code block:

- Briefly explain the main elements/choices made
- Mention what can be customized (e.g., "I can add error paths, change direction, or add styling")
- Offer a preview link: `[Preview on Mermaid Live](https://mermaid.live)` — remind the user to paste the code there

## Quality standards

- **Meaningful labels**: use clear, action-oriented text for nodes and messages
- **Logical grouping**: use subgraphs (flowcharts) or groups (architecture) to cluster related elements
- **Consistent conventions**: decision nodes as diamonds, start/end as rounded shapes, databases as cylinders
- **Appropriate complexity**: show enough detail to be useful, but split into multiple diagrams if it gets crowded
- **Color hints** (flowcharts): use subtle coloring to distinguish start/end, errors, databases
- **Correct syntax**: always double-check edge notation, especially for architecture diagrams (`A:R --> L:B`)

## Iteration

After showing the diagram, invite feedback:

- "Want me to add/remove anything?"
- "Should I adjust the layout direction?"
- "Want a version with error handling / alternative paths?"

Refine until the user is satisfied.

## Additional Resources

- `references/sequence-diagrams.md` — Full syntax for sequence diagrams
- `references/flowcharts.md` — Full syntax for flowcharts
- `references/architecture-diagrams.md` — Full syntax for architecture diagrams
