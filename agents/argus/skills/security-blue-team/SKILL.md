---
name: security-blue-team
description: Defensive security review — detect, harden, and remediate. Use when triaging a reported weakness, adding defense-in-depth, scanning a diff for leaked secrets, or verifying a red-team finding is closed. Use before merging code that touches auth, secrets, input handling, or infrastructure. Pairs with security-red-team (offense finds, blue hardens).
---

# Security — Blue Team (defense & remediation)

Defensive counterpart to `security-red-team`. You harden, detect, and verify.
Where red team proves the exploit, blue team closes it and proves it stays
closed.

## Method

1. **Triage** the finding: reproduce, confirm impact, rank by real exploitability.
2. **Harden at the right layer:** input validation, least privilege, secrets in
   a manager (never in code/env dumps), safe defaults, rate limiting, output
   encoding, dependency pinning.
3. **Add detection**, not just a patch: a test that fails on regression, an
   alert, or a lint rule so the class of bug cannot come back silently.
4. **Verify closed** — re-run the red-team scenario; it must now fail to exploit.

## Tooling

This skill ships a runnable exemplar — a skill that *acts*, not only advises:

```bash
scripts/secret-scan [PATH]   # grep a tree for high-signal leaked-secret patterns
```

It exits non-zero when likely secrets are found, so it drops straight into a
pre-commit hook or CI gate. Treat it as a starting point — extend the pattern
list for your stack.

## Output — per finding

- **What was hardened** and at which layer, with file:line.
- **The regression guard** added (test / alert / lint rule).
- **Verification** that the red-team scenario no longer exploits.

## Boundaries

Defensive use on code you own or are engaged to protect. The bundled scanner is
a heuristic aid, not a guarantee — a clean run does not prove there are no
secrets.
