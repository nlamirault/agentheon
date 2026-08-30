# Pull Request Workflow

## Workflow

Follow these steps to create a Pull Request:

1. **Branch Management**: Check the current branch to avoid working directly
   on `main`.
   - Run `git branch --show-current`.
   - If the current branch is `main`, create and switch to a new descriptive
     branch:

     ```bash
     git checkout -b <new-branch-name>
     ```

2. **Locate Template**: Search for a pull request template in the repository.
   - Check `.github/pull_request_template.md`
   - Check `.github/PULL_REQUEST_TEMPLATE.md`
   - If multiple templates exist (e.g., in `.github/PULL_REQUEST_TEMPLATE/`),
     ask the user which one to use or select the most appropriate one based on
     the context (e.g., `bug_fix.md` vs `feature.md`).

3. **Read Template**: Read the content of the identified template file.

4. **Draft Description**: Create a PR description that strictly follows the
   template's structure.
   - **Headings**: Keep all headings from the template.
   - **Checklists**: Review each item. Mark with `[x]` if completed. If an item
     is not applicable, leave it unchecked or mark as `[ ]` (depending on the
     template's instructions) or remove it if the template allows flexibility
     (but prefer keeping it unchecked for transparency).
   - **Content**: Fill in the sections with clear, concise summaries of your
     changes.
   - **Related Issues**: Link any issues fixed or related to this PR (e.g.,
     "Fixes #123").

5. **Preflight Check**: Before creating the PR, run the workspace preflight
   script to ensure all build, lint, and test checks pass.

   ```bash
   npm run preflight
   ```

   If any checks fail, address the issues before proceeding to create the PR.

6. **Check Labels**: Before creating the PR, check if the repository has labels
   defined and select the most appropriate ones.

   ```bash
   # List all labels in the repository
   gh label list
   ```

   If labels exist, identify the relevant ones based on the PR content:
   - Match the conventional commit type to a label (e.g., `feat` → `enhancement`,
     `fix` → `bug`, `docs` → `documentation`, `ci` → `ci/cd`, `chore` → `chore`)
   - Add any scope-specific or priority labels if available
   - If no labels exist, skip this step

7. **Create PR**: Use the `gh` CLI to create the PR. To avoid shell escaping issues with multi-line Markdown, write the
   description to a temporary file first.

   ```bash
   # 1. Write the drafted description to a temporary file
   # 2. Create the PR using the --body-file flag (add --label if labels exist)
   gh pr create --title "type(scope): succinct description" --body-file <temp_file_path>
   # With labels:
   gh pr create --title "type(scope): succinct description" --body-file <temp_file_path> --label "enhancement,documentation"
   # 3. Remove the temporary file
   rm <temp_file_path>
   ```

   - **Title**: Ensure the title follows the
     [Conventional Commits](https://www.conventionalcommits.org/) format if the
     repository uses it (e.g., `feat(ui): add new button`,
     `fix(core): resolve crash`).
   - **Labels**: Only add labels that actually exist in the repository (verified
     via `gh label list` in the previous step). Never invent label names.

## Principles

- **Compliance**: Never ignore the PR template. It exists for a reason.
- **Completeness**: Fill out all relevant sections.
- **Accuracy**: Don't check boxes for tasks you haven't done.
