---
name: zig-review-code
allowed-tools: Bash(*), Glob(*), Grep(*), Read(*), Write(*)
argument-hint: [path] [--package package-path]
description: Review Zig code for best practices, memory safety, error handling, testing, and build system correctness
disable-model-invocation: true
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - zig
  task: [review]
  persona: [developer]
  workload: [systems, application]
---

# Zig Code Review Command

This command performs a comprehensive review of Zig code, analyzing it against Zig best practices, memory management
patterns, error handling, testing discipline, and build system correctness.

## Usage

```bash
# Review entire project
/zig:zig-review-code .

# Review specific source file or directory
/zig:zig-review-code . --package src/parser.zig

# Review from a different path
/zig:zig-review-code /path/to/project
```

## Skills Reference

This command leverages the following Zig skills:

- **@plugins/zig/skills/zig-best-practices/SKILL.md**: Code style, naming conventions, and formatting
- **@plugins/zig/skills/zig-error-handling/SKILL.md**: Error sets, error unions, and error propagation patterns
- **@plugins/zig/skills/zig-memory-management/SKILL.md**: Allocator patterns, defer/errdefer, and leak detection
- **@plugins/zig/skills/zig-build-system/SKILL.md**: build.zig correctness and cross-compilation
- **@plugins/zig/skills/zig-testing/SKILL.md**: Test coverage, inline tests, and leak detection in tests

## What Gets Analyzed

### 1. Code Style and Best Practices

- Naming conventions (camelCase functions, snake_case variables, PascalCase types)
- `zig fmt` compliance
- Struct initialization style (prefer `.{ .field = value }` with type annotation)
- File structure (module doc comment, import ordering, method ordering)

### 2. Memory Management

- All `alloc()` calls paired with `defer free()` or `errdefer free()`
- Correct allocator selection (no `page_allocator` for small frequent allocations)
- Arena allocator usage for grouped lifetime allocations
- No global allocator state

### 3. Error Handling

- Named error sets instead of anonymous `!T` everywhere
- No silently discarded errors (`_ = risky()`)
- No `catch unreachable` on fallible paths in production code
- Proper `errdefer` for cleanup on error paths

### 4. Testing

- Tests present for public API
- `std.testing.allocator` used (not `page_allocator`) in tests
- All modules registered in root test block
- Test names are descriptive

### 5. Build System

- `build.zig` uses modern API (`b.path()` not `.{ .path = }`)
- `build.zig.zon` present with correct name and version
- Test step and run step are configured
- No hardcoded absolute paths

### 6. Safety and Correctness

- Integer overflow handling (wrapping `+%=`, saturating `+|=` where appropriate)
- C interop null pointer checks (`[*c]T` → optional before deref)
- No `@setRuntimeSafety(false)` without documented profiling justification
- Comptime operations only on compile-time-known values

### 7. Static Analysis

- `zig fmt --check .` output
- `zig build` success
- `zig build test` results (if Zig is available)

## Command Execution Flow

1. **Parse Arguments**
   - Extract project path and optional `--package` filter
   - Validate path exists and contains `.zig` files

2. **Gather Context**
   - Find all `.zig` files using Glob
   - Read `build.zig` and `build.zig.zon` if present
   - Identify project type (executable vs library)

3. **Run Static Analysis** (if `zig` is available)

   ```bash
   zig fmt --check .
   zig build 2>&1
   zig build test 2>&1
   ```

4. **Analyze Code**
   - Review files against all Zig skills listed above
   - Check for common pitfalls documented in `zig-expert` agent
   - Identify deprecated APIs (`.{ .path = }`, async/await, `@Frame`)

5. **Generate Report**
   - Write report to `zig-review-report-{timestamp}.md`
   - Categorize by severity (Critical, Important, Suggestions)
   - Include file locations and line numbers
   - Provide before/after code examples
   - **Do NOT automatically apply any changes**

## Report Structure

### Executive Summary

- Project type (executable, library)
- Overall quality assessment
- Critical / Important / Suggestion counts

### Critical Issues 🔴

Issues that must be fixed:

- Memory leaks (missing `defer free()`)
- Deprecated APIs that do not compile on current Zig
- Silently discarded errors

### Important Concerns 🟡

Issues affecting correctness or maintainability:

- Anonymous error sets where named sets would improve clarity
- Missing tests for public API
- Wrong allocator for the context

### Suggestions 🔵

Style and optimization opportunities:

- Naming convention deviations
- Code organization improvements
- Documentation gaps

### Best Practices Analysis

- ✅ What the code does well
- ❌ Areas for improvement

### Build System Review

- `build.zig` API correctness
- `build.zig.zon` completeness
- CI/CD configuration presence

### Testing Assessment

- Test coverage of public API
- Use of `std.testing.allocator`
- Leak detection status

### Detailed Recommendations

For each issue:

- File path and line number
- Current code (problematic)
- Recommended code (improved)
- Rationale

### Static Analysis Results

- `zig fmt --check .` output
- `zig build` status
- `zig build test` results

### Next Steps

1. **Immediate**: Critical fixes (leaks, deprecated APIs)
2. **Short-term**: Error handling improvements
3. **Long-term**: Test coverage and documentation

## Implementation Instructions

1. Parse `[path]` and optional `--package` argument
2. Verify the path exists and contains `.zig` files
3. Check for `build.zig` to confirm it's a Zig project
4. Check if `zig` is installed: `zig version`
5. Run static analysis tools if available
6. Use Glob to find all `*.zig` files (or limit to `--package` if specified)
7. Read key files (prioritize `build.zig`, `build.zig.zon`, `src/main.zig`, `src/root.zig`)
8. Apply guidance from all referenced skills
9. Generate report at `zig-review-report-{YYYY-MM-DD-HHMMSS}.md`
10. Present summary and ask user which issues to address

## Important Constraints

- **Read-Only Analysis**: Do NOT modify any code files automatically
- **Report Only**: Generate a detailed report with recommendations
- **User Decision**: Let the user decide which changes to apply
- **Tool Availability**: Gracefully handle missing `zig` binary
- **Scope**: Respect `--package` to limit analysis scope

## Example Output Path

```text
zig-review-report-2025-06-15-143022.md
```
