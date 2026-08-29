# Branch Protection

## Critical Rule: Never Commit to Master/Main

**NEVER commit directly to `master` or `main`** - ALL work must be on feature branches.

## Before ANY Commit: Protection Check

Before any commit operation, ALWAYS check the current branch:

```bash
git branch --show-current
```

**If on `master` or `main`, IMMEDIATELY stop and ask the user to create a feature branch.**

## Automated Check Script

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "main" ]; then
  echo "ERROR: Cannot commit to $CURRENT_BRANCH. Create a feature branch first."
  exit 1
fi
```

## Commit

Ask the user if you could commit the changes

## Adding files

Before adding files to the Git repository, ALWAYS ask the user

## Verification After Branch Creation

After creating a new branch, always verify:

```bash
git branch --show-current  # Must NOT be master or main
```

## When Protection Can Be Bypassed

NEVER
