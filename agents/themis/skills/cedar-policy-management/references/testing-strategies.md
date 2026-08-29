# Cedar Policy Testing Strategies

Comprehensive guide to testing Cedar authorization policies and schemas.

## Testing Fundamentals

### Why Test Policies?

Policy testing ensures:

- **Correctness**: Policies grant intended access
- **Security**: No unintended permission grants
- **Completeness**: All scenarios are covered
- **Regression prevention**: Changes don't break existing functionality
- **Compliance**: Policies meet regulatory requirements

### Test Levels

**Unit Tests**: Test individual policies in isolation
**Integration Tests**: Test policy sets with realistic entity data
**Regression Tests**: Verify fixes remain fixed
**Performance Tests**: Measure policy evaluation time
**Security Tests**: Verify no unauthorized access paths

## Unit Testing

### Testing Individual Policies

Test each policy with specific scenarios:

**Policy:**

```cedar
permit(
  principal in Group::"editors",
  action == Action::"write",
  resource is Document
) when {
  resource.department == principal.department
};
```

**Test cases:**

```bash
# Test 1: Editor in same department - ALLOW
cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"write"' \
  --resource 'Document::"doc1"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json

# Expected: ALLOW

# Test 2: Editor in different department - DENY
cedar authorize \
  --principal 'User::"bob"' \
  --action 'Action::"write"' \
  --resource 'Document::"doc1"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json

# Expected: DENY

# Test 3: Non-editor - DENY
cedar authorize \
  --principal 'User::"charlie"' \
  --action 'Action::"write"' \
  --resource 'Document::"doc1"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json

# Expected: DENY
```

### Test Case Structure

Organize test cases systematically:

```text
tests/
├── policies/
│   ├── test-editor-write.sh
│   ├── test-viewer-read.sh
│   └── test-admin-all.sh
├── entities/
│   ├── test-users.json
│   ├── test-documents.json
│   └── test-groups.json
└── expected/
    ├── allow-cases.txt
    └── deny-cases.txt
```

**Test script template:**

```bash
#!/bin/bash
# Test: Editor write access in same department

# Setup
PRINCIPAL='User::"alice"'
ACTION='Action::"write"'
RESOURCE='Document::"doc1"'
EXPECTED="ALLOW"

# Execute
RESULT=$(cedar authorize \
  --principal "$PRINCIPAL" \
  --action "$ACTION" \
  --resource "$RESOURCE" \
  --entities tests/entities/test-users.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json \
  | grep "Decision:" | awk '{print $2}')

# Assert
if [ "$RESULT" == "$EXPECTED" ]; then
  echo "✓ Test passed: $RESULT == $EXPECTED"
  exit 0
else
  echo "✗ Test failed: $RESULT != $EXPECTED"
  exit 1
fi
```

### Boundary Testing

Test edge cases and boundaries:

```bash
# Test boundary: Exactly at approval limit
cedar authorize \
  --principal 'User::"manager"' \
  --action 'Action::"approve"' \
  --resource 'Expense::"10000"' \
  --context '{"amount": 10000}' \
  --policy-set policies/ \
  --schema schema.cedarschema.json

# Test boundary: Just over approval limit
cedar authorize \
  --principal 'User::"manager"' \
  --action 'Action::"approve"' \
  --resource 'Expense::"10001"' \
  --context '{"amount": 10001}' \
  --policy-set policies/ \
  --schema schema.cedarschema.json
```

## Integration Testing

### Testing Policy Sets

Test complete policy sets with realistic data:

**Test scenario: Document access control**

```json
// entities.json
[
  {
    "uid": { "type": "User", "id": "alice" },
    "attrs": {
      "department": "engineering",
      "role": "editor"
    },
    "parents": [
      { "type": "Group", "id": "editors" },
      { "type": "Group", "id": "engineering-team" }
    ]
  },
  {
    "uid": { "type": "Document", "id": "doc1" },
    "attrs": {
      "department": "engineering",
      "classification": "internal",
      "owner": { "type": "User", "id": "alice" }
    },
    "parents": [
      { "type": "Folder", "id": "engineering-docs" }
    ]
  }
]
```

**Test script:**

```bash
#!/bin/bash
# Integration test: Document access scenarios

declare -A tests=(
  ["alice can read own doc"]="User::alice Action::read Document::doc1 ALLOW"
  ["alice can write own doc"]="User::alice Action::write Document::doc1 ALLOW"
  ["bob cannot write alice doc"]="User::bob Action::write Document::doc1 DENY"
  ["admin can delete any doc"]="User::admin Action::delete Document::doc1 ALLOW"
)

for test_name in "${!tests[@]}"; do
  IFS=' ' read -r principal action resource expected <<< "${tests[$test_name]}"

  result=$(cedar authorize \
    --principal "$principal" \
    --action "$action" \
    --resource "$resource" \
    --entities entities.json \
    --policy-set policies/ \
    --schema schema.cedarschema.json \
    | grep "Decision:" | awk '{print $2}')

  if [ "$result" == "$expected" ]; then
    echo "✓ $test_name"
  else
    echo "✗ $test_name: expected $expected, got $result"
  fi
done
```

### Context-Based Testing

Test policies with context variations:

```bash
# Test: Business hours access
cedar authorize \
  --principal 'User::"contractor"' \
  --action 'Action::"access"' \
  --resource 'System::"production"' \
  --context '{"time": {"hour": 10, "dayOfWeek": "Monday"}}' \
  --policy-set policies/ \
  --schema schema.cedarschema.json
# Expected: ALLOW (during business hours)

cedar authorize \
  --principal 'User::"contractor"' \
  --action 'Action::"access"' \
  --resource 'System::"production"' \
  --context '{"time": {"hour": 22, "dayOfWeek": "Monday"}}' \
  --policy-set policies/ \
  --schema schema.cedarschema.json
# Expected: DENY (outside business hours)
```

## Automated Testing

### CI/CD Integration

Integrate policy tests into CI/CD pipeline:

```yaml
# .github/workflows/test-policies.yml
name: Test Cedar Policies

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Cedar CLI
        run: cargo install cedar-policy-cli

      - name: Validate schema
        run: cedar validate-schema --schema schema.cedarschema.json

      - name: Validate policies
        run: cedar validate --schema schema.cedarschema.json --policy-set policies/

      - name: Run unit tests
        run: ./tests/run-unit-tests.sh

      - name: Run integration tests
        run: ./tests/run-integration-tests.sh

      - name: Generate coverage report
        run: ./tests/generate-coverage.sh
```

### Test Automation Script

Automate test execution:

```bash
#!/bin/bash
# tests/run-all-tests.sh

set -e

echo "=== Cedar Policy Test Suite ==="

# 1. Schema validation
echo "Validating schema..."
cedar validate-schema --schema schema.cedarschema.json
echo "✓ Schema valid"

# 2. Policy validation
echo "Validating policies..."
cedar validate --schema schema.cedarschema.json --policy-set policies/
echo "✓ Policies valid"

# 3. Unit tests
echo "Running unit tests..."
passed=0
failed=0

for test in tests/unit/*.sh; do
  if bash "$test"; then
    ((passed++))
  else
    ((failed++))
  fi
done

echo "Unit tests: $passed passed, $failed failed"

# 4. Integration tests
echo "Running integration tests..."
int_passed=0
int_failed=0

for test in tests/integration/*.sh; do
  if bash "$test"; then
    ((int_passed++))
  else
    ((int_failed++))
  fi
done

echo "Integration tests: $int_passed passed, $int_failed failed"

# 5. Summary
total_passed=$((passed + int_passed))
total_failed=$((failed + int_failed))
total=$((total_passed + total_failed))

echo "=== Summary ==="
echo "Total: $total tests"
echo "Passed: $total_passed"
echo "Failed: $total_failed"

if [ $total_failed -eq 0 ]; then
  echo "✓ All tests passed"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
```

## Test Coverage

### Measuring Coverage

Track which policies are tested:

```bash
#!/bin/bash
# tests/generate-coverage.sh

# Extract all policy IDs from policy files
policy_ids=$(grep -r '@id' policies/ | sed 's/.*@id("\(.*\)").*/\1/' | sort -u)

# Extract tested policy IDs from test files
tested_ids=$(grep -r 'policy-set' tests/ | grep -o 'policy-id=[^ ]*' | cut -d= -f2 | sort -u)

# Calculate coverage
total=$(echo "$policy_ids" | wc -l)
tested=$(echo "$tested_ids" | wc -l)
coverage=$(echo "scale=2; $tested * 100 / $total" | bc)

echo "Policy Coverage: $tested/$total ($coverage%)"

# Find untested policies
echo "Untested policies:"
comm -23 <(echo "$policy_ids") <(echo "$tested_ids")
```

### Coverage Goals

**Enforce:**

- Critical policies: 100% coverage
- Standard policies: 80%+ coverage
- All policies: At least one test case

**Test types to include:**

- Happy path (expected allow)
- Negative cases (expected deny)
- Boundary conditions
- Edge cases
- Error conditions

## Regression Testing

### Preventing Regressions

Capture bug scenarios as tests:

```bash
#!/bin/bash
# tests/regression/bug-123-department-check.sh
# Regression test for bug #123: Department check was case-sensitive

# This bug allowed cross-department access when department names
# had different cases (e.g., "Engineering" vs "engineering")

# Test case that exposed the bug
cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"write"' \
  --resource 'Document::"doc1"' \
  --entities tests/entities/bug-123.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json

# Expected: DENY (different departments)
# Bug behavior: ALLOW (case-insensitive comparison)
```

### Regression Test Organization

```text
tests/regression/
├── bug-123-department-check.sh
├── bug-145-approval-limit.sh
├── bug-156-temporal-access.sh
└── README.md  # Document each regression test
```

**README.md format:**

```markdown
# Regression Tests

## bug-123-department-check.sh

**Issue**: #123
**Fixed**: 2024-01-15
**Description**: Department comparison was case-insensitive, allowing cross-department access
**Test**: Verifies case-sensitive department matching

## bug-145-approval-limit.sh

**Issue**: #145
**Fixed**: 2024-01-20
**Description**: Approval limits were inclusive on both ends
**Test**: Verifies exclusive upper bound for approval limits
```

## Performance Testing

### Measuring Evaluation Time

Test policy evaluation performance:

```bash
#!/bin/bash
# tests/performance/evaluate-time.sh

iterations=1000
policy_set="policies/"
entities="tests/entities/large-dataset.json"

echo "Running $iterations authorization requests..."

start=$(date +%s%N)

for i in $(seq 1 $iterations); do
  cedar authorize \
    --principal "User::user$i" \
    --action "Action::read" \
    --resource "Document::doc$i" \
    --entities "$entities" \
    --policy-set "$policy_set" \
    --schema schema.cedarschema.json \
    > /dev/null
done

end=$(date +%s%N)

elapsed_ns=$((end - start))
elapsed_ms=$((elapsed_ns / 1000000))
avg_ms=$((elapsed_ms / iterations))

echo "Total time: ${elapsed_ms}ms"
echo "Average per request: ${avg_ms}ms"

# Performance thresholds
if [ $avg_ms -lt 10 ]; then
  echo "✓ Performance: Excellent (<10ms)"
elif [ $avg_ms -lt 50 ]; then
  echo "⚠ Performance: Acceptable (10-50ms)"
else
  echo "✗ Performance: Poor (>50ms)"
  exit 1
fi
```

### Load Testing

Test under high load:

```bash
#!/bin/bash
# tests/performance/load-test.sh

concurrent_users=100
requests_per_user=10

echo "Load test: $concurrent_users users, $requests_per_user requests each"

# Generate requests
for user in $(seq 1 $concurrent_users); do
  {
    for req in $(seq 1 $requests_per_user); do
      cedar authorize \
        --principal "User::user$user" \
        --action "Action::read" \
        --resource "Document::doc$req" \
        --entities entities.json \
        --policy-set policies/ \
        --schema schema.cedarschema.json \
        > /dev/null
    done
  } &
done

wait
echo "✓ Load test completed"
```

## Security Testing

### Negative Security Testing

Test that unauthorized access is denied:

```bash
#!/bin/bash
# tests/security/unauthorized-access.sh

# Test 1: User cannot access other user's private documents
result=$(cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"read"' \
  --resource 'Document::"bobs-private-doc"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json \
  | grep "Decision:" | awk '{print $2}')

if [ "$result" == "DENY" ]; then
  echo "✓ Private document access denied"
else
  echo "✗ SECURITY ISSUE: Private document accessible"
  exit 1
fi

# Test 2: Non-admin cannot delete documents
result=$(cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"delete"' \
  --resource 'Document::"any-doc"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json \
  | grep "Decision:" | awk '{print $2}')

if [ "$result" == "DENY" ]; then
  echo "✓ Delete action denied for non-admin"
else
  echo "✗ SECURITY ISSUE: Non-admin can delete"
  exit 1
fi
```

### Privilege Escalation Testing

Test for privilege escalation paths:

```bash
#!/bin/bash
# tests/security/privilege-escalation.sh

# Test: Regular user cannot grant permissions
result=$(cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"grantPermission"' \
  --resource 'User::"bob"' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json \
  | grep "Decision:" | awk '{print $2}')

if [ "$result" == "DENY" ]; then
  echo "✓ Permission grant denied for regular user"
else
  echo "✗ SECURITY ISSUE: Regular user can grant permissions"
  exit 1
fi

# Test: User cannot elevate their own role
result=$(cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"addToGroup"' \
  --resource 'Group::"admins"' \
  --context '{"target": {"type": "User", "id": "alice"}}' \
  --entities entities.json \
  --policy-set policies/ \
  --schema schema.cedarschema.json \
  | grep "Decision:" | awk '{print $2}')

if [ "$result" == "DENY" ]; then
  echo "✓ Self-elevation denied"
else
  echo "✗ SECURITY ISSUE: User can elevate themselves"
  exit 1
fi
```

## Test Data Management

### Test Entity Sets

Create focused entity sets for testing:

```json
// tests/entities/minimal-rbac.json
[
  {
    "uid": { "type": "User", "id": "admin" },
    "parents": [{ "type": "Role", "id": "admin" }]
  },
  {
    "uid": { "type": "User", "id": "editor" },
    "parents": [{ "type": "Role", "id": "editor" }]
  },
  {
    "uid": { "type": "User", "id": "viewer" },
    "parents": [{ "type": "Role", "id": "viewer" }]
  },
  {
    "uid": { "type": "Document", "id": "test-doc" },
    "attrs": {
      "owner": { "type": "User", "id": "editor" }
    }
  }
]
```

### Fixture Management

Organize test fixtures:

```text
tests/fixtures/
├── users/
│   ├── admin-user.json
│   ├── regular-user.json
│   └── contractor-user.json
├── documents/
│   ├── public-doc.json
│   ├── internal-doc.json
│   └── confidential-doc.json
└── combined/
    ├── small-dataset.json
    └── large-dataset.json
```

## Best Practices

### Write Tests First (TDD)

1. Write test case for expected behavior
2. Write policy to pass test
3. Verify test passes
4. Refactor if needed

### Test Naming

Use descriptive test names:

```bash
# Good: Descriptive
tests/unit/editor-can-write-own-department-docs.sh

# Avoid: Vague
tests/unit/test1.sh
```

### Test Documentation

Document test purpose and expected behavior:

```bash
#!/bin/bash
# Test: Editor write access in same department
#
# Policy: permit editors to write documents in their department
# Expected: ALLOW when principal.department == resource.department
# Expected: DENY when departments differ
#
# Test scenarios:
# 1. Alice (engineering editor) writes engineering doc → ALLOW
# 2. Alice (engineering editor) writes sales doc → DENY
# 3. Bob (sales editor) writes sales doc → ALLOW
```

### Continuous Testing

Run tests:

- Before committing changes
- In pull requests
- Before deployment
- On schedule (daily/weekly)
- After incidents

---

Comprehensive testing ensures Cedar policies work correctly, securely, and efficiently. Combine multiple testing
strategies for robust authorization systems.
