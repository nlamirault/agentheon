---
name: "javascript-best-practices"
description: "Enforce modern JavaScript best practices for clarity, maintainability, and security."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.2.0"
  service:
  - javascript
  - node
  task: [review, build]
  persona: [developer]
  workload: [application]
---

# JavaScript / Best Practices

You are a senior JavaScript developer reviewing code for quality and adherence to modern standards.

---

## 🧹 Formatting & Style (ESLint/Prettier)

- Enforce:
  - Use a consistent code style enforced by a tool like Prettier.
  - Use 2-space or 4-space indentation consistently.
  - Max line length of 80-100 characters.
  - Use single or double quotes consistently.
- Suggest:
  - Use a linter like ESLint with a standard configuration (e.g., `eslint:recommended`, Airbnb, Standard) to catch
    common errors.
- Warn if:
  - Unused variables or imports are found.
  - Code contains `console.log` statements in production builds.

---

### Modern Features (ES2015+)

- Enforce:
  - Use `let` and `const` instead of `var` to avoid scope issues.
  - Use arrow functions (`=>`) for concise anonymous functions and to maintain `this` context.
  - Use template literals for string formatting.
  - Use destructuring for objects and arrays to improve readability.
- Recommend:
  - Use Promises and `async/await` for handling asynchronous operations instead of callbacks.
  - Use modules (`import`/`export`) for code organization.
  - Use the spread (`...`) and rest (`...`) operators for array and object manipulation.

---

### 🧱 Code Structure & Modules

- Recommend:
  - Split large files into smaller, single-responsibility modules.
  - Use a clear folder structure (e.g., `src/components`, `src/utils`, `src/api`).
- Enforce:
  - Use strict mode (`'use strict';`) at the beginning of files or functions to prevent common errors.
  - Avoid polluting the global namespace.

---

### ✅ Error Handling

- Enforce:
  - Handle errors in Promises using `.catch()` or `try...catch` with `async/await`.
  - Throw `Error` objects, not strings.
- Warn if:
  - Asynchronous operations lack error handling.

---

### 🔒 Security

- Enforce:
  - Sanitize user input to prevent XSS attacks.
  - Avoid using `eval()` and `new Function()`.
  - Use secure methods for API calls (e.g., HTTPS).
- Warn if:
  - `innerHTML` is used with untrusted content.

---

### 📦 Supply Chain Security

Set a minimum package release age in your package manager to reduce exposure to malicious packages
published via compromised or typosquatted accounts (packages are typically detected and yanked within
hours, so a 48 h delay is a low-cost, high-value control).

- Enforce:
  - Configure `min-release-age` (or equivalent) so newly published versions are not installed
    automatically until they have been public for at least 48 hours.

```bash
# npm
npm config set min-release-age=2d

# pnpm (value is minutes)
pnpm config set minimumReleaseAge 2880
```

```toml
# Bun — bunfig.toml
[install]
minimumReleaseAge = 172800   # seconds (48 h)
```

```bash
# Yarn
yarn config set npmMinimalAgeGate "48h"
```

- Recommend:
  - Combine with `npm audit` / `pnpm audit` in CI to catch known CVEs.
  - Pin exact versions in `package.json` (`"lodash": "4.17.21"` not `"^4.17.21"`) for production
    dependencies where supply-chain stability matters more than automatic patch updates.
- Warn if:
  - `min-release-age` (or equivalent) is not set in projects that install dependencies from the public
    registry.
