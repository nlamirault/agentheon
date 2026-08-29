# Terraform / Testing and CI/CD Integration

## Testing Strategy

A comprehensive testing strategy for Terraform includes multiple layers of validation, from syntax checking to
end-to-end infrastructure testing.

### Testing Pyramid

```text
                 ▲
               /   \
             /       \
           /  E2E     \
         /   Testing    \
       /                 \
     /  Integration Tests  \
   /                         \
 /      Unit Tests (Modules)   \
/________________________________\
     Static Analysis & Linting
```

## Static Analysis and Linting

### Terraform Format and Validation

```bash
# Format check (in CI)
terraform fmt -check -recursive

# Format fix (locally)
terraform fmt -recursive

# Validate syntax and configuration
terraform validate

# Validate with variables
terraform validate -var-file=terraform.tfvars
```

### TFLint

TFLint is a pluggable Terraform linter that checks for errors, warnings, and best practices.

**Installation:**

```bash
# macOS
brew install tflint

# Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Windows
choco install tflint
```

**Configuration:** See `assets/.tflint.hcl`

**Usage:**

```bash
# Initialize TFLint plugins
tflint --init

# Run TFLint
tflint

# Run recursively
tflint --recursive

# Output in JSON
tflint --format json
```

### tfsec

Security scanner for Terraform code.

```bash
# Install
brew install tfsec

# Run scan
tfsec .

# Exclude specific checks
tfsec . --exclude-rule aws-s3-enable-bucket-logging

# Output formats
tfsec . --format json
tfsec . --format sarif > tfsec-results.sarif
```

**Example inline ignore:**

```hcl
resource "aws_s3_bucket" "example" {
  #tfsec:ignore:aws-s3-enable-bucket-logging
  bucket = "my-bucket"

  # Logging not required for this use case
}
```

### Checkov

Policy-as-code scanner supporting multiple IaC frameworks.

```bash
# Install
pip install checkov

# Run scan
checkov -d .

# Scan specific file
checkov -f main.tf

# Skip specific checks
checkov -d . --skip-check CKV_AWS_18

# Output formats
checkov -d . -o json
checkov -d . -o sarif
```

**Example inline skip:**

```hcl
resource "aws_s3_bucket" "example" {
  #checkov:skip=CKV_AWS_18:Logging not required for this bucket
  bucket = "my-bucket"
}
```

### Terrascan

Static code analyzer for detecting compliance and security violations.

```bash
# Install
brew install terrascan

# Scan
terrascan scan -t aws

# Scan with specific policies
terrascan scan -t aws -p aws -i terraform

# Output formats
terrascan scan -o json
terrascan scan -o sarif
```

## Unit Testing (Modules)

### Terratest

Go-based framework for testing Terraform modules.

**Example test structure:**

```text
tests/
├── go.mod
├── go.sum
└── terraform_test.go
```

**Example test (`terraform_test.go`):**

```go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformVPCModule(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        // Path to Terraform code
        TerraformDir: "../examples/complete",

        // Variables to pass
        Vars: map[string]interface{}{
            "vpc_cidr":     "10.0.0.0/16",
            "environment":  "test",
        },

        // Disable colors in output
        NoColor: true,
    }

    // Clean up resources after test
    defer terraform.Destroy(t, terraformOptions)

    // Deploy infrastructure
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    vpcID := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcID)

    privateSubnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
    assert.Equal(t, 3, len(privateSubnets))
}
```

**Run tests:**

```bash
cd tests
go test -v -timeout 30m
```

### Kitchen-Terraform

Ruby-based testing framework using Test Kitchen.

**Installation:**

```bash
gem install kitchen-terraform
```

**Configuration (`.kitchen.yml`):**

```yaml
---
driver:
  name: terraform
  root_module_directory: test/fixtures/wrapper

provisioner:
  name: terraform

verifier:
  name: terraform
  systems:
    - name: basic
      backend: local
      controls:
        - operating_system

platforms:
  - name: terraform

suites:
  - name: default
    driver:
      variables:
        environment: test
```

**InSpec test (`test/integration/default/controls/vpc_spec.rb`):**

```ruby
control 'vpc' do
  describe aws_vpc(attribute('vpc_id')) do
    it { should exist }
    its('cidr_block') { should eq '10.0.0.0/16' }
    its('state') { should eq 'available' }
  end
end
```

## Integration Testing

### Terraform Test (Native)

Terraform 1.6+ includes native testing capabilities.

**Test file structure:**

```text
tests/
├── main.tftest.hcl
├── vpc.tftest.hcl
└── security_groups.tftest.hcl
```

**Example test (`vpc.tftest.hcl`):**

```hcl
run "valid_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr    = "10.0.0.0/16"
    environment = "test"
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets"
  }
}

run "vpc_creation" {
  command = apply

  variables {
    vpc_cidr    = "10.0.0.0/16"
    environment = "test"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block mismatch"
  }
}
```

**Run tests:**

```bash
# Run all tests
terraform test

# Run specific test file
terraform test tests/vpc.tftest.hcl

# Verbose output
terraform test -verbose
```

## End-to-End Testing

### Infrastructure Validation

After deployment, validate the infrastructure is working as expected:

**Example validation script:**

```bash
#!/bin/bash

set -e

# Get outputs from Terraform
VPC_ID=$(terraform output -raw vpc_id)
LB_DNS=$(terraform output -raw load_balancer_dns)

# Validate VPC exists
aws ec2 describe-vpcs --vpc-ids $VPC_ID

# Validate load balancer is healthy
curl -f https://$LB_DNS/health

# Validate database connectivity
psql "postgresql://user@$(terraform output -raw db_endpoint)/dbname" -c "SELECT 1"

echo "All validation checks passed!"
```

### Automated Testing with InSpec

```ruby
# test/integration/default/controls/infrastructure_spec.rb

control 'vpc' do
  impact 1.0
  title 'VPC Configuration'
  desc 'Ensure VPC is properly configured'

  describe aws_vpc(attribute('vpc_id')) do
    it { should exist }
    its('state') { should eq 'available' }
    its('cidr_block') { should eq '10.0.0.0/16' }
    it { should_not be_default }
  end
end

control 'subnets' do
  impact 1.0
  title 'Subnet Configuration'

  attribute('private_subnet_ids').each do |subnet_id|
    describe aws_subnet(subnet_id) do
      it { should exist }
      it { should_not be_mapping_public_ip_on_launch }
    end
  end
end

control 'security_groups' do
  impact 1.0
  title 'Security Group Rules'

  describe aws_security_group(attribute('web_sg_id')) do
    it { should exist }
    it { should_not allow_in(port: 22, ipv4_range: '0.0.0.0/0') }
    it { should allow_in(port: 443, ipv4_range: '0.0.0.0/0') }
  end
end
```

## CI/CD Integration

### GitHub Actions

**Complete workflow (`.github/workflows/terraform.yml`):**

```yaml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]
    paths:
      - '**.tf'
      - '**.tfvars'
      - '.github/workflows/terraform.yml'
  push:
    branches: [main]

env:
  TF_VERSION: '1.6.0'
  AWS_REGION: 'us-east-1'

jobs:
  lint:
    name: Lint and Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4

      - name: TFLint Init
        run: tflint --init

      - name: Run TFLint
        run: tflint --recursive

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: false

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          soft_fail: false
          output_format: sarif
          output_file_path: results.sarif

      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif

  validate:
    name: Validate
    runs-on: ubuntu-latest
    needs: [lint]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

  plan:
    name: Plan
    runs-on: ubuntu-latest
    needs: [validate, security]
    if: github.event_name == 'pull_request'
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -no-color -out=tfplan
          terraform show -no-color tfplan > plan.txt

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('plan.txt', 'utf8');
            const output = `#### Terraform Plan 📖
            <details><summary>Show Plan</summary>

            \`\`\`terraform
            ${plan}
            \`\`\`

            </details>`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

  test:
    name: Test
    runs-on: ubuntu-latest
    needs: [validate]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Run Terraform Tests
        run: terraform test

  apply:
    name: Apply
    runs-on: ubuntu-latest
    needs: [plan, test]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        run: terraform apply -auto-approve
```

### GitLab CI

```yaml
# .gitlab-ci.yml
image:
  name: hashicorp/terraform:1.6
  entrypoint: [""]

variables:
  TF_ROOT: ${CI_PROJECT_DIR}
  TF_ADDRESS: ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${CI_COMMIT_REF_NAME}

cache:
  paths:
    - ${TF_ROOT}/.terraform

before_script:
  - cd ${TF_ROOT}
  - terraform --version
  - terraform init

stages:
  - validate
  - test
  - plan
  - apply

format:
  stage: validate
  script:
    - terraform fmt -check -recursive

validate:
  stage: validate
  script:
    - terraform validate

tfsec:
  stage: test
  image: aquasec/tfsec:latest
  script:
    - tfsec .

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/tfplan
    reports:
      terraform: ${TF_ROOT}/tfplan.json

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan
  only:
    - main
  when: manual
```

## Testing Best Practices

### 1. Test Isolation

- Use separate AWS accounts or projects for testing
- Clean up resources after tests
- Use unique naming to avoid conflicts

### 2. Mock External Dependencies

```hcl
# Use data sources that can be mocked
data "aws_ami" "test" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

# For testing, you can override with a variable
variable "ami_id_override" {
  type    = string
  default = null
}

locals {
  ami_id = var.ami_id_override != null ? var.ami_id_override : data.aws_ami.test.id
}
```

### 3. Use Test Fixtures

```text
tests/
├── fixtures/
│   ├── minimal/
│   │   ├── main.tf
│   │   └── variables.tf
│   └── complete/
│       ├── main.tf
│       └── variables.tf
└── terraform_test.go
```

### 4. Implement Timeouts

```go
terraformOptions := &terraform.Options{
    TerraformDir: "../examples/complete",
    MaxRetries:   3,
    TimeBetweenRetries: 5 * time.Second,
}
```

### 5. Run Tests in Parallel

```go
func TestTerraformModules(t *testing.T) {
    tests := []struct {
        name string
        dir  string
    }{
        {"VPC", "../modules/vpc"},
        {"EC2", "../modules/ec2"},
        {"RDS", "../modules/rds"},
    }

    for _, tc := range tests {
        tc := tc // capture range variable
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            // Test implementation
        })
    }
}
```

## Cost Estimation in CI/CD

### Infracost

```yaml
- name: Setup Infracost
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Run Infracost
  run: |
    infracost breakdown --path .
    infracost diff --path . --compare-to infracost-base.json
```

## Documentation Testing

Ensure documentation stays up-to-date:

```bash
# Validate README examples
terraform-docs markdown table . --output-check

# Generate documentation
terraform-docs markdown table . > README.md
```

## Continuous Monitoring

After deployment, implement continuous validation:

- CloudWatch Alarms for resource health
- AWS Config for compliance
- Cost anomaly detection
- Regular security scans

## Testing Checklist

- [ ] Terraform format check passes
- [ ] Terraform validate succeeds
- [ ] TFLint runs without errors
- [ ] tfsec scan passes
- [ ] Checkov scan passes
- [ ] Unit tests pass (Terratest)
- [ ] Integration tests pass
- [ ] Plan generated successfully
- [ ] Documentation up-to-date
- [ ] Cost estimation reviewed
- [ ] Security scan results reviewed
