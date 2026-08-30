# Lint Configuration Files

This directory contains example `.lint` configuration files for the Grafana Dashboard Linter.

## Available Templates

### 1. `.lint` - Complete Reference

**Purpose**: Comprehensive example showing ALL 17 linter rules with detailed documentation.

**Use this when**:

- Learning about all available rules
- Understanding what each rule validates
- Creating a fully documented configuration
- Need detailed examples of granular exclusions

**Content**:

- All 17 rules documented in exclusions section
- Detailed explanations for each rule
- Examples of panel-specific exclusions
- Best practices and usage notes
- Complete reference documentation

**Usage**:

```bash
# Copy to your dashboard directory
cp examples/.lint ./dashboards/.lint

# Remove exclusions for rules you want to enforce
# Update reasons to match your use case
# Use with linter
dashboard-linter lint --config ./dashboards/.lint ./dashboards/*.json
```

---

### 2. `.lint.minimal` - Quick Start Template

**Purpose**: Minimal template with most common exclusions (commented out).

**Use this when**:

- Starting a new project
- Only need a few specific exclusions
- Want a clean, focused configuration
- Prefer to enable exclusions as needed

**Content**:

- Common exclusion patterns (commented)
- Simple structure
- Quick to customize
- Easy to maintain

**Usage**:

```bash
# Copy to your dashboard directory as .lint
cp examples/.lint.minimal ./dashboards/.lint

# Uncomment and customize the exclusions you need
# Use with linter
dashboard-linter lint --config ./dashboards/.lint ./dashboards/*.json
```

---

## Quick Start

### Option 1: No Exclusions (Strict Validation)

Don't create a `.lint` file - enforce all rules:

```bash
# All rules enforced
dashboard-linter lint --strict ./dashboards/*.json
```

### Option 2: Start with Minimal Template

```bash
# Copy minimal template
cp examples/.lint.minimal ./dashboards/.lint

# Edit to uncomment needed exclusions
nano ./dashboards/.lint

# Validate
dashboard-linter lint --config ./dashboards/.lint ./dashboards/*.json
```

### Option 3: Start with Complete Reference

```bash
# Copy complete reference
cp examples/.lint ./dashboards/.lint

# Remove exclusions for rules you want to enforce
nano ./dashboards/.lint

# Validate
dashboard-linter lint --config ./dashboards/.lint ./dashboards/*.json
```

---

## Rule Categories

### Template Configuration Rules (5 rules)

- `template-datasource-rule` - Templated datasource variable
- `template-job-rule` - Templated job variable
- `template-instance-rule` - Templated instance variable
- `template-label-promql-rule` - Valid PromQL in variables
- `template-on-time-change-reload-rule` - Variable refresh behavior

### Panel Rules (4 rules)

- `panel-datasource-rule` - Use $datasource not hardcoded
- `panel-title-description-rule` - Titles and descriptions required
- `panel-units-rule` - Proper unit configuration
- `panel-no-targets-rule` - Every panel needs queries

### Query Validation Rules (7 rules)

- `target-logql-rule` - Valid LogQL syntax
- `target-logql-auto-rule` - Use $\_\_auto for ranges
- `target-promql-rule` - Valid PromQL syntax
- `target-rate-interval-rule` - Use $\_\_rate_interval
- `target-job-rule` - Include job matchers
- `target-instance-rule` - Include instance matchers
- `target-counter-agg-rule` - Counters need rate/irate/increase

### Dashboard Configuration (1 rule)

- `uneditable-dashboard` - Protect production dashboards

---

## Common Exclusion Patterns

### Pattern 1: Cluster-Wide Aggregations

```yaml
exclusions:
  target-instance-rule:
    reason: "Totals across all instances"
    entries:
      - panel: "Total Request Rate"
        targetIdx: 0

  target-job-rule:
    reason: "Cluster-wide metrics"
    entries:
      - panel: "Cluster CPU"
        targetIdx: 0
```

**Use when**: Dashboard shows cluster/service totals, not per-instance metrics.

---

### Pattern 2: SLO/Compliance Dashboards

```yaml
exclusions:
  target-rate-interval-rule:
    reason: "Exact time windows required for SLO calculations"
    entries:
      - panel: "Daily Error Budget"
        targetIdx: 0
      - panel: "Monthly Availability"
        targetIdx: 0
```

**Use when**: Need fixed time windows (24h, 30d) for SLA/SLO compliance.

---

### Pattern 3: Multi-Datasource Dashboards

```yaml
exclusions:
  template-datasource-rule:
    reason: "Dashboard uses Prometheus for metrics and Loki for logs"

  panel-datasource-rule:
    reason: "Different panels require different datasources"
```

**Use when**: Dashboard combines multiple datasource types (Prometheus + Loki).

---

### Pattern 4: Development/Staging Environment

```yaml
exclusions:
  uneditable-dashboard:
    reason: "Development environment - editing required for rapid iteration"

warnings:
  panel-title-description-rule:
  panel-units-rule:
```

**Use when**: Dashboard is under active development or in staging environment.

---

### Pattern 5: Status/Health Dashboards

```yaml
exclusions:
  panel-title-description-rule:
    reason: "Simple status indicators are self-explanatory"
    entries:
      - panel: "Status"
      - panel: "Health"

  panel-units-rule:
    reason: "Status panels use value mappings (OK/WARNING/CRITICAL)"
    entries:
      - panel: "Service Health"
```

**Use when**: Dashboard has simple status panels with value mappings.

---

## Best Practices

### 1. Always Document Why

❌ **Bad**:

```yaml
exclusions:
  target-instance-rule:
```

✅ **Good**:

```yaml
exclusions:
  target-instance-rule:
    reason: "Cluster-wide totals don't filter by instance"
```

### 2. Be Specific with Granular Exclusions

❌ **Bad**: Exclude entire rule for all panels

```yaml
exclusions:
  target-instance-rule:
    reason: "Some panels don't need instance"
```

✅ **Good**: Exclude only specific panels

```yaml
exclusions:
  target-instance-rule:
    reason: "Totals panels aggregate across all instances"
    entries:
      - panel: "Total Request Rate"
        targetIdx: 0
```

### 3. Use Warnings for Gradual Adoption

```yaml
# Start with warnings during migration
warnings:
  panel-title-description-rule:
  panel-units-rule:
# After dashboards are updated, move to exclusions or remove
```

### 4. Review and Clean Up Regularly

```yaml
# Mark temporary exclusions
exclusions:
  template-job-rule:
    reason: "TODO: Add job variable after Q1 migration"
```

### 5. Keep in Version Control

```bash
# Commit .lint file with dashboards
git add dashboards/.lint dashboards/*.json
git commit -m "feat: add SLO dashboard with documented exclusions"
```

---

## Testing Your Configuration

### 1. Validate Configuration Syntax

```bash
# Lint will validate .lint file syntax
dashboard-linter lint --config .lint dashboard.json
```

### 2. Test Strict Mode

```bash
# Ensure warnings don't hide issues
dashboard-linter lint --strict --config .lint dashboard.json
```

### 3. Test Without Config

```bash
# See what rules are excluded
dashboard-linter lint dashboard.json
# vs
dashboard-linter lint --config .lint dashboard.json
```

### 4. Use Verbose Mode

```bash
# See detailed validation output
dashboard-linter lint --verbose --config .lint dashboard.json
```

---

## Environment-Specific Configurations

### Development

```yaml
# .lint.dev
exclusions:
  uneditable-dashboard:
    reason: "Development environment"

warnings:
  panel-title-description-rule:
  panel-units-rule:
```

### Staging

```yaml
# .lint.staging
exclusions:
  uneditable-dashboard:
    reason: "Staging environment - testing allowed"
# Enforce most rules
```

### Production

```yaml
# .lint.prod
# Minimal exclusions
exclusions:
  target-instance-rule:
    reason: "Documented cluster-wide aggregations"
    entries:
      - panel: "Total Request Rate"
        targetIdx: 0
# No warnings - all rules enforced
```

**Usage**:

```bash
# Development
dashboard-linter lint --config .lint.dev dashboards/*.json

# Production
dashboard-linter lint --strict --config .lint.prod dashboards/*.json
```

---

## Troubleshooting

### Issue: Rule not excluded

**Problem**: Rule still fails even with exclusion

```yaml
exclusions:
  panel-title-description-rule:
```

**Solution**: Check spelling and indentation (YAML is whitespace-sensitive)

---

### Issue: Granular exclusion not working

**Problem**: Panel-specific exclusion ignored

```yaml
entries:
  - panel: "Request Rate"
    targetIdx: 0
```

**Solution**: Ensure panel name matches exactly (case-sensitive)

```bash
# Find exact panel name
jq '.dashboard.panels[].title' dashboard.json
```

---

### Issue: Config file not found

**Problem**: `--config .lint` file not found

**Solution**: Use full path or ensure file is in correct directory

```bash
dashboard-linter lint --config ./dashboards/.lint ./dashboards/api.json
```

---

## References

- **Best Practices**: `../references/best-practices.md`
- **Dashboard Linter**: <https://github.com/grafana/dashboard-linter>
- **Rule Documentation**: <https://github.com/grafana/dashboard-linter/tree/main/docs/rules>
- **Validation Script**: `../scripts/validate-dashboards.sh`
