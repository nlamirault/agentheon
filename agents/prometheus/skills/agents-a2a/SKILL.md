---
name: "agents-a2a"
description: "Best practices for developing agents using A2A (Agent Development Kit)."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - agent
  - ai
  task: [configure, build]
  persona: [developer, ml-engineer]
  workload: [ai]
---

# Agents / A2A Best Practices

You are an expert in developing agents using the Agent to Agent (A2A) framework.

## Guiding Principles

- **Modular Design:** Break down complex agent functionalities into smaller, manageable, and reusable components or
  sub-agents.
- **Clear Communication:** Define explicit communication protocols and data exchange formats between agents to ensure
  seamless interaction.
- **State Management:** Implement robust state management to track the agent's internal state and the overall
  conversation flow.
- **Error Handling:** Design agents with comprehensive error handling mechanisms to gracefully manage unexpected
  situations and failures.
- **Testability:** Ensure agents are easily testable through unit, integration, and end-to-end tests to maintain
  reliability and correctness.
- **Observability:** Incorporate logging, tracing, and metrics to provide visibility into agent behavior and
  performance.

## Best Practices

- **Agent Configuration:**
  - Externalize configurations using `AgentConfig` or similar structures.
  - Utilize environment variables for sensitive information or deployment-specific settings.
  - Avoid hardcoding values directly within the agent's logic.

- **Input/Output Handling:**
  - Clearly define the expected input schema and output format for each agent.
  - Validate inputs to prevent unexpected behavior or security vulnerabilities.
  - Use well-defined data structures for inter-agent communication.

- **Tool Usage:**
  - Design agents to effectively leverage external tools or functions.
  - Encapsulate tool invocation logic to keep agent's core reasoning clear.
  - Handle tool errors and retries gracefully.

- **Prompt Engineering:**
  - Craft clear, concise, and unambiguous prompts for large language models (LLMs) if used.
  - Experiment with different prompting strategies to optimize agent performance and response quality.
  - Version control prompts to track changes and improvements.

- **Security:**
  - Adhere to the principle of least privilege for agent permissions and access to resources.
  - Implement secure handling of sensitive data and credentials.
  - Regularly audit agent interactions and access logs.

- **Performance Optimization:**
  - Optimize agent logic and tool usage to minimize latency and resource consumption.
  - Consider caching mechanisms for frequently accessed data or expensive computations.
  - Monitor agent performance in production and iterate on improvements.

## Code Structure

- Organize agent code into logical directories and files (e.g., `agents/<agent_name>/`).
- Separate concerns: agent logic, tool definitions, configuration, and tests should reside in distinct modules.

## Example Agent Structure

```text
agents/
├── my_agent/
│   ├── __init__.py
│   ├── agent.py          # Main agent logic
│   ├── config.py         # AgentConfig definition
│   ├── tools.py          # Tool definitions
│   └── tests/
│       ├── __init__.py
│       └── test_agent.py # Unit and integration tests
├── another_agent/
│   ├── ...
```
