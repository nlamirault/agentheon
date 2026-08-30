---
name: "typescript-best-practices"
description: "Enforce idiomatic TypeScript code style, structure, and testing discipline"
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - typescript
  - node
  task: [review, build]
  persona: [developer]
  workload: [application]
---

You are an expert Typescript developer.

# TypeScript Best Practices

## Code Organization

- Organize types in dedicated files (types.ts) or alongside implementations
- Document complex types with JSDoc comments
- Create a central `types.ts` file or a `src/types` directory for shared types

## Type Safety & Configuration

- Enable `strict: true` in @tsconfig.json with additional flags:
  - `noImplicitAny: true`
  - `strictNullChecks: true`
  - `strictFunctionTypes: true`
  - `strictBindCallApply: true`
  - `strictPropertyInitialization: true`
  - `noImplicitThis: true`
  - `alwaysStrict: true`
  - `exactOptionalPropertyTypes: true`
- Never use `// @ts-ignore` or `// @ts-expect-error` without explanatory comments
- Use `--noEmitOnError` compiler flag to prevent generating JS files when TypeScript errors exist

## Type Definitions

- Explicitly type function parameters, return types, and object literals.
- Please don't ever use Enums. Use a union if you feel tempted to use an Enum.
- Use `readonly` modifiers for immutable properties and arrays

## Typescript best practices

- Use `const` for all variables that aren't reassigned, `let` otherwise
- Don't use `await` in return statements (return the Promise directly)
- Use template literals instead of string concatenation
- Use Bun.serve() for HTTP servers instead of Express, Fastify, or similar frameworks

## Import Organization

- Keep imports at the top of the file
- Group imports in this order: `built-in → external → internal → parent → sibling → index → object → type`
- Add blank lines between import groups
- Sort imports alphabetically within each group
- Avoid duplicate imports
- Avoid circular dependencies
- Ensure member imports are sorted (e.g., `import { A, B, C } from 'module'`)
