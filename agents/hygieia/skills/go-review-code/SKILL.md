---
name: go-review-code
allowed-tools: Bash(*), Glob(*), Grep(*), Read(*), Write(*)
argument-hint: [path] [--package package-path]
description: Review Go code for best practices, style, error handling, testing, dependencies, performance, and security
disable-model-invocation: true
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - go
  task: [review]
  persona: [developer]
  workload: [application]
---

# Go Code Review Command

This command performs a comprehensive review of Go code in a project or specific package, analyzing it against Go best
practices, project structure, error handling patterns, testing practices, dependencies, performance, and security.

## Usage

```bash
# Review entire project
/go:go-review-code .

# Review specific package
/go:go-review-code . --package ./internal/api

# Review from different path
/go:go-review-code /path/to/project --package ./pkg/utils
```

## Skills Reference

This command leverages the following Go development skills to guide its analysis:

- **@plugins/go/skills/go-best-practices/SKILL.md**: Project layout, error handling, testing practices, code formatting,
  module management, and concurrency patterns
- **@plugins/go/skills/go-errors-handling/SKILL.md**: Error wrapping, sentinel errors, custom error types, and error
  propagation
- **@plugins/go/skills/go-style-guide/SKILL.md**: Naming conventions, code formatting, comment styles, and anti-patterns

## What Gets Analyzed

### 1. Code Style and Best Practices

- Go formatting (gofmt, goimports)
- Naming conventions (MixedCaps, snake_case)
- Package organization (cmd/, internal/, pkg/)
- Code complexity and readability
- Idiomatic Go patterns

### 2. Error Handling

- Proper error propagation
- Error wrapping with `%w`
- Sentinel error usage
- Panic and recover patterns
- Error type definitions

### 3. Project Structure

- Standard project layout compliance
- Module organization (go.mod, go.sum)
- Package dependencies
- Import organization

### 4. Testing Practices

- Test coverage metrics (via `go test -cover`)
- Test file organization
- Table-driven tests
- Benchmark tests
- Example tests

### 5. Dependencies

- Module validation (go.mod, go.sum)
- Unused dependencies
- Vulnerability checks
- Dependency versions

### 6. Performance

- Memory allocations
- String concatenation patterns
- Buffer pooling
- Concurrent access patterns
- Premature optimization detection

### 7. Security

- SQL injection vulnerabilities
- Input sanitization
- Authentication/authorization patterns
- Cryptographic usage
- Panic conditions

### 8. Static Analysis

- `go vet` output
- `golangci-lint` results (if available)
- `staticcheck` findings (if available)

## Command Execution Flow

1. **Parse Arguments**
   - Extract project path (first argument)
   - Extract optional --package flag value
   - Validate paths exist

2. **Gather Context**
   - Find all Go files using Glob
   - Read go.mod and go.sum if present
   - Identify project structure (cmd/, internal/, pkg/)

3. **Run Static Analysis Tools**
   - Execute `go vet` on target path/package
   - Run `golangci-lint` if available
   - Run `staticcheck` if available
   - Check `go mod verify`
   - Run `go test -cover` for coverage metrics

4. **Analyze Code**
   - Review code style against Go best practices
   - Check error handling patterns
   - Validate naming conventions
   - Assess package organization
   - Identify security concerns
   - Evaluate performance patterns

5. **Generate Report**
   - Create markdown report with findings
   - Categorize issues by severity (Critical, Important, Suggestions)
   - Include file locations and line numbers
   - Provide code examples and recommended fixes
   - DO NOT automatically apply any changes

## Report Structure

The generated markdown report will include:

### Executive Summary

- Project type (library, service, CLI, etc.)
- Overall code quality assessment
- Number of critical issues found
- Number of recommendations

### Critical Issues 🔴

Issues that must be addressed:

- Security vulnerabilities
- Potential data loss
- Crash conditions
- Race conditions

### Important Concerns 🟡

Issues affecting maintainability or performance:

- Code smells
- Performance bottlenecks
- Testing gaps
- Unclear error handling

### Suggestions 🔵

Optimization opportunities and style improvements:

- Idiomatic Go patterns
- Documentation improvements
- Code organization
- Minor refactoring opportunities

### Best Practices Analysis

- ✅ Strengths: What the code does well
- ❌ Areas for Improvement: Where it deviates from best practices

### Project Structure Review

- Directory layout assessment
- Module organization
- Dependency analysis

### Testing Assessment

- Unit test coverage percentage
- Integration test presence
- Benchmark test presence
- Testing strategy evaluation

### Detailed Recommendations

Prioritized recommendations with:

- File location and line numbers
- Current code (problematic)
- Recommended code (improved)
- Explanation of why the change matters

### Static Analysis Results

- go vet findings
- golangci-lint results
- staticcheck warnings
- go mod verify status
- Test coverage summary

### Next Steps

1. **Immediate Actions**: Critical fixes required
2. **Short-term Improvements**: For next sprint/iteration
3. **Long-term Enhancements**: For future consideration

## Implementation Instructions

When this command is invoked:

1. **Parse command arguments**:

   ```text
   Arguments format: [path] [--package package-path]
   - path: Required, project root or directory to review
   - --package: Optional flag followed by package path relative to project root
   ```

2. **Validate inputs**:
   - Ensure path exists and is a directory
   - If --package specified, validate it exists within the path
   - Check if it's a Go project (contains .go files or go.mod)

3. **Discover Go files**:
   - If --package specified: Only analyze that package
   - Otherwise: Analyze entire project
   - Use Glob to find all \*.go files
   - Identify test files (\*\_test.go)

4. **Check for Go tools**:
   - Verify go is installed
   - Check for optional tools: golangci-lint, staticcheck
   - Note which tools are available for the report

5. **Run static analysis** (use Bash tool):

   ```bash
   # From the project root or package directory
   go vet ./...
   golangci-lint run --no-config --disable-all --enable=errcheck,gosimple,govet,ineffassign,staticcheck,typecheck,unused
   go mod verify
   go test -cover ./...
   ```

6. **Analyze code files**:
   - Read key Go files (prioritize main.go, important packages)
   - Apply guidance from Go skills (@plugins/go/skills/go-best-practices, @plugins/go/skills/go-errors-handling,
     @plugins/go/skills/go-style-guide)
   - Look for common issues:
     - Missing error checks
     - Improper error wrapping
     - Panic usage
     - Hardcoded values
     - Missing tests
     - Security vulnerabilities

7. **Generate markdown report**:
   - Write report to a file named: `go-review-report-{timestamp}.md`
   - Include all sections listed above
   - Use clear formatting with headers, lists, code blocks
   - Include file paths and line numbers for issues
   - Provide code examples showing current vs. recommended code

8. **Present results**:
   - Show the user the report file path
   - Summarize key findings (number of critical/important/suggestions)
   - DO NOT automatically apply any changes
   - Ask user if they want to address specific issues

## Important Constraints

- **Read-Only Analysis**: Do NOT modify any code files automatically
- **Report Only**: Generate a detailed report with recommendations
- **User Decision**: Let the user decide which changes to apply
- **Tool Availability**: Gracefully handle missing optional tools (golangci-lint, staticcheck)
- **Error Handling**: If a tool fails, note it in the report and continue with other checks
- **Scope**: Respect the --package flag to limit analysis scope

## Example Output Path

```text
go-review-report-2025-01-11-143022.md
```

## Notes

- The review focuses on providing actionable feedback
- All recommendations should include rationale and examples
- Security issues take highest priority
- Performance suggestions are lower priority unless critical
- Style issues are suggestions only
- The report should be educational, not just critical
