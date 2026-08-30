---
name: create-issue
allowed-tools: AskUserQuestion(*), Bash(*), Read(*)
argument-hint: "[title]"
description: Create a GitHub issue with structured body template, automatic label assignment, and kind-based formatting
disable-model-invocation: true
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - git
  - github
  task: [configure]
  persona: [developer]
  workload: [developer-tools]
---

# Create GitHub Issue

Create a GitHub issue with a structured body adapted to the issue kind, and automatic label assignment from the shared
label taxonomy.

## Workflow

1. **Determine Issue Title**
   - If title argument provided: use it directly, then confirm with user
   - If no title argument: ask the user:
     > "What is the issue title?"
   - Title should be concise, descriptive, and in plain English (no enforced format)
   - Title must not be empty

2. **Determine Issue Kind**

   Ask the user to choose the kind:

   > "What kind of issue is this?"
   >
   > 1. `bug` — Something is broken or behaving incorrectly
   > 2. `feature` — A new capability or enhancement
   > 3. `documentation` — Missing or incorrect docs
   > 4. `question` — A question or discussion
   > 5. `cleanup` — Technical debt, refactoring, or tooling
   > 6. `support` — A support request

   Map the user's choice to the corresponding `kind/` label value.

3. **Collect Body Content**

   Based on the kind chosen, prompt the user for the relevant fields and assemble the body.

   **kind/bug:**

   ```text
   Ask:
   - "Describe the bug" (required)
   - "Steps to reproduce" (required)
   - "Expected behavior" (required)
   - "Actual behavior" (required)
   - "Environment / additional context" (optional — skip if user says no)
   ```

   Body template:

   ```markdown
   ## Description

   <user's description>

   ## Steps to Reproduce

   <steps provided by user, formatted as a numbered list>

   ## Expected Behavior

   <expected behavior>

   ## Actual Behavior

   <actual behavior>

   ## Environment

   <environment/context, or omit section if not provided>
   ```

   **kind/feature:**

   ```text
   Ask:
   - "Describe the feature or enhancement" (required)
   - "What problem does it solve?" (required)
   - "Acceptance criteria (what does done look like?)" (required)
   - "Additional context" (optional — skip if user says no)
   ```

   Body template:

   ```markdown
   ## Description

   <feature description>

   ## Problem

   <problem it solves>

   ## Acceptance Criteria

   <criteria as a checklist>
   - [ ] <criterion 1>
   - [ ] <criterion 2>

   ## Additional Context

   <context, or omit section if not provided>
   ```

   **kind/documentation:**

   ```text
   Ask:
   - "What documentation is missing or incorrect?" (required)
   - "Where is it located (file, URL, section)?" (optional)
   - "What should it say or cover?" (required)
   ```

   Body template:

   ```markdown
   ## Description

   <what is missing or incorrect>

   ## Location

   <file, URL, or section, or omit if not provided>

   ## Proposed Content

   <what it should say or cover>
   ```

   **kind/question:**

   ```text
   Ask:
   - "What is your question?" (required)
   - "Any relevant context?" (optional)
   ```

   Body template:

   ```markdown
   ## Question

   <the question>

   ## Context

   <context, or omit section if not provided>
   ```

   **kind/cleanup:**

   ```text
   Ask:
   - "Describe the cleanup or refactoring needed" (required)
   - "Why is it needed?" (required)
   - "Affected files or areas" (optional)
   ```

   Body template:

   ```markdown
   ## Description

   <cleanup description>

   ## Motivation

   <why it is needed>

   ## Affected Areas

   <files or areas, or omit if not provided>
   ```

   **kind/support:**

   ```text
   Ask:
   - "Describe what you need help with" (required)
   - "What have you already tried?" (optional)
   ```

   Body template:

   ```markdown
   ## Description

   <what help is needed>

   ## What I've Tried

   <attempts so far, or omit if not provided>
   ```

4. **Determine Labels**

   Fetch available labels from the repository: `gh label list --limit 100`

   If label fetching fails, skip label assignment silently.

   Otherwise, select one label from each group:

   **kind/** — use the kind chosen in step 2:
   - bug → `kind/bug`
   - feature → `kind/feature`
   - documentation → `kind/documentation`
   - question → `kind/question`
   - cleanup → `kind/cleanup`
   - support → `kind/support`

   **lifecycle/** — default to:
   - `lifecycle/active`

   **priority/** — ask the user:

   > "What priority is this issue?"
   >
   > 1. `critical` — Must be resolved immediately
   > 2. `high` — Important, resolve before other work
   > 3. `medium` — Normal priority (default)
   > 4. `low` — Nice to have, no urgency
   > 5. `backlog` — Not planned for near future

   Map to `priority/<value>`.

   **status/** — default to:
   - `status/available`

   Build `--label` flags only for labels that exist in the repository's label list. Skip missing labels silently.

5. **Confirm and Create Issue**

   Display a summary for confirmation:

   ```text
   📋 Issue Summary

   Title:    <title>
   Kind:     <kind>
   Priority: <priority>
   Labels:   kind/<x>, lifecycle/active, priority/<x>, status/available

   Body preview:
   <first ~10 lines of body>
   ...

   Create this issue? (y/n)
   ```

   If confirmed, create via GitHub CLI:

   ```bash
   gh issue create \
     --title "<title>" \
     --label "<kind/xxx>" \
     --label "lifecycle/active" \
     --label "<priority/xxx>" \
     --label "status/available" \
     --body "$(cat <<'EOF'
   <assembled body>
   EOF
   )"
   ```

   Only include `--label` flags for labels confirmed to exist in step 4.

6. **Display Success Message**

   ```text
   ✅ Issue Created Successfully

   Title:    <title>
   URL:      <issue-url>
   Labels:   <kind/xxx>, lifecycle/active, <priority/xxx>, status/available

   Next steps:
   - View issue: gh issue view <number>
   - Start work:  git checkout -b <type>/<issue-slug>
   ```

## Error Handling

- **Empty title**: Ask again — do not proceed without a title
- **GitHub CLI unavailable**: Display error, suggest installing `gh`
- **Label not found**: Skip that label silently, do not error
- **Issue creation fails**: Display the gh error message and suggest checking repository permissions
- **User aborts at confirmation**: Exit cleanly with "Issue creation cancelled."

## Label Groups Reference

All projects share a common label taxonomy. Labels follow `category/value` namespacing:

| Group        | Values                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------ |
| `kind/`      | bug, cleanup, deprecation, discussion, documentation, feature, question, renovate, support |
| `lifecycle/` | active, frozen, rotten, stale, waiting                                                     |
| `priority/`  | backlog, critical, high, low, medium                                                       |
| `status/`    | abandoned, available, blocked, in_progress, on_hold, proposal, review_needed               |

## Tools Usage

- **Bash**: Execute `gh` commands for label fetching and issue creation
- **Read**: Read git configuration or repository files if needed
- **GitHub CLI (gh)**: Required for issue creation and label lookup

## Important Notes

- **status/available** is the correct default for new issues (no one assigned yet)
- **lifecycle/active** is the correct default lifecycle state
- Always confirm with the user before creating the issue
- Body sections marked as optional should be omitted entirely (including the heading) when the user skips them
- Format reproduction steps and acceptance criteria as lists for readability
- NEVER create the issue without user confirmation
