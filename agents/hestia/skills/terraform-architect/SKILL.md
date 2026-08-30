---
name: "terraform-architect"
description: "Comprehensive Terraform architecture and best practices skill for designing, organizing, and maintaining production-grade infrastructure as code. Includes HashiCorp standards, module design patterns, security practices, testing strategies, and multi-cloud guidance for AWS, Azure, and GCP"
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - terraform
  task: [configure, review, build]
  persona: [platform-engineer, devops]
  workload: [infrastructure]
---

# Terraform Architect

This skill provides comprehensive guidance for architecting, developing, organizing, and maintaining high-quality
Terraform infrastructure code. Apply these practices to create maintainable, secure, and scalable infrastructure as code
across AWS, Azure, GCP, and other cloud providers.

## Overview

This skill provides comprehensive guidance for:

- ✅ Writing clean, maintainable Terraform code
- 🏗️ Designing modular, reusable infrastructure components
- 🔒 Implementing security best practices
- 📁 Organizing files and project structure
- 🧪 Testing infrastructure code at multiple levels
- ☁️ Cloud-specific configurations (AWS, Azure, GCP)
- 🛠️ Tooling and automation
- 📊 Version management and state handling

## Core Principles

Follow these fundamental architectural principles when working with Terraform:

### 1. Infrastructure as Code Standards

- Treat infrastructure code with the same rigor as application code
- Use version control for all Terraform configurations
- Implement code reviews for infrastructure changes
- Maintain clear documentation and meaningful commit messages

### 2. Version Management

- Always specify provider and Terraform versions explicitly
- Pin versions to ensure reproducible builds across environments
- Use pessimistic constraints (`~>`) for providers to allow safe updates
- Test version upgrades in non-production environments first

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
```

### 3. State Management

- Always use remote state backends (S3, Azure Blob, GCS, Terraform Cloud)
- Enable state locking to prevent concurrent modifications
- Never commit state files to version control
- Implement state file encryption at rest
- Use separate state files per environment (dev, staging, prod)

**Example AWS S3 Backend:**

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "project/environment/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 4. Security First

- Never hardcode secrets in code or configuration files
- Store sensitive values in secret management systems (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)
- Use least-privilege IAM policies
- Enable encryption at rest and in transit for all resources
- Scan code with tools like Checkov, tfsec, or Terrascan

**Example Secrets Management:**

```hcl
# ❌ BAD - Never hardcode secrets
resource "aws_db_instance" "main" {
  password = "hardcoded-password-123"
}

# ✅ GOOD - Use data sources to retrieve secrets
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

### 5. Modularity and Reusability

- Design modules with single responsibility principle
- Create generic, composable modules
- Avoid hardcoding values; use variables for flexibility
- Keep modules small and focused (typically 200-500 lines per module)

### 6. Testing

- Implement comprehensive testing at multiple levels
- Use static analysis (terraform validate, tflint, tfsec)
- Perform unit testing with Terratest or kitchen-terraform
- Test in isolated environments before production deployment

### 7. Documentation

- Keep README and inline documentation current
- Use terraform-docs for automatic documentation generation
- Include usage examples with every module
- Document breaking changes in CHANGELOG.md

For detailed implementation guidance, see:

- Version management and configuration standards: **@references/best_practices.md**
- Security patterns and secrets management: **@references/security.md**
- Testing strategies and workflows: **@references/testing.md**

## Module Structure and Design

Organize Terraform modules using this standard structure for consistency and maintainability:

```text
module-name/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Terraform and provider version constraints
├── README.md         # Module documentation
├── examples/         # Usage examples
│   └── complete/
│       ├── main.tf
│       ├── variables.tf
│       └── README.md
└── tests/            # Automated tests (optional)
    └── module_test.go
```

**File Organization Best Practices:**

- `main.tf` - Core resource definitions grouped logically
- `variables.tf` - All input variables with descriptions, types, and defaults
- `outputs.tf` - All outputs with descriptions
- `versions.tf` - Terraform version and required providers with version constraints
- Additional `.tf` files for complex modules (e.g., `iam.tf`, `networking.tf`)

**Module Design Principles:**

- Keep modules focused on a single responsibility
- Use sensible defaults in variables
- Provide comprehensive examples in `examples/` directory
- Include validation for input variables
- Document all outputs with descriptions

For advanced module design patterns, composition strategies, and complex architectures, see
**@references/best_practices.md**.

## Documentation Structure

This skill is organized into focused reference documents and configuration templates:

### 📚 Reference Documentation

#### Core Practices

**@references/best_practices.md**

- Version management and pinning strategies
- Configuration standards and conventions
- Code quality guidelines
- Module design principles and patterns
- Performance optimization techniques
- Key conventions and common patterns
- Example configurations and usage patterns
- Troubleshooting common issues

**@references/file_structure.md**

- Standard project layouts for different project sizes
- File organization rules and conventions
- Naming conventions for resources and files
- Directory structures for monorepos vs. separate repos
- Environment-specific configurations
- `.gitignore` setup for Terraform projects

**@references/iam-policies.md**

- Always use `aws_iam_policy_document` over `jsonencode()`
- Type safety and validation benefits
- Trust policies and assume role patterns
- Least privilege principle implementation
- Combining multiple policy documents
- Conditional statements and principal-based policies
- Common patterns for S3, Secrets Manager, CloudWatch
- Migration guide from jsonencode()

**@references/security.md**

- Secrets management strategies and tools
- Encryption at rest and in transit
- IAM and access control best practices
- VPC and network security patterns
- Compliance and auditing requirements
- State file security and access control
- Security scanning in CI/CD pipelines
- SAST tool integration (tfsec, Checkov, Terrascan)

**@references/testing.md**

- Testing strategies and testing pyramid
- Static analysis and linting tools
- Unit testing with Terratest
- Integration testing approaches
- End-to-end testing strategies
- CI/CD integration patterns
- Cost estimation with Infracost
- Test fixture management

#### Cloud Provider Guidance

**@references/aws.md**

- AWS-specific best practices and recommendations
- Resource configuration patterns for common services
- IAM policies and security configurations
- VPC networking patterns and best practices
- Common AWS resource examples
- AWS-specific gotchas and troubleshooting

**@references/azure.md**

- Azure-specific best practices and recommendations
- Resource configuration patterns for common services
- Azure AD and RBAC configurations
- Virtual network patterns and best practices
- Common Azure resource examples
- Azure-specific considerations

**@references/gcp.md**

- GCP-specific best practices and recommendations
- Resource configuration patterns for common services
- IAM and service account configurations
- VPC networking patterns and best practices
- Common GCP resource examples
- GCP-specific considerations

### 🛠️ Configuration Templates

**@assets/.tflint.hcl**

- TFLint configuration with AWS/Azure/GCP plugins
- Rule enablement and customization
- Naming conventions enforcement
- Plugin configuration for different cloud providers

**@assets/.pre-commit-config.yaml**

- Pre-commit hooks for Terraform
- Format checking and validation
- Security scanning (tfsec, Checkov)
- Documentation generation with terraform-docs
- Custom validation rules

## Naming Conventions

Apply consistent naming throughout Terraform code for better maintainability:

**Resource Names (in code):**

```hcl
# Pattern: <resource-type>_<descriptive-name>
resource "aws_instance" "web_server" {}
resource "azurerm_virtual_network" "main_vnet" {}
resource "google_compute_instance" "app_instance" {}
```

**Variable Names:**

```hcl
# Use snake_case, descriptive names
variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}
```

**Tag/Label Naming:**

```hcl
# Use consistent tagging across all resources
tags = {
  Environment = var.environment
  ManagedBy   = "Terraform"
  Project     = var.project_name
  Owner       = var.owner
  CostCenter  = var.cost_center
}
```

**Naming Guidelines:**

- Use lowercase with underscores (snake_case)
- Be descriptive but concise
- Avoid abbreviations unless universally understood
- Include context (environment, purpose, region when relevant)
- Keep names consistent across similar resources

For complete naming conventions and examples, see **@references/best_practices.md**.

## Variable and Output Management

**Variable Declarations with Validation:**

```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Instance type must be from t3 family."
  }
}

variable "availability_zones" {
  description = "List of availability zones for resource deployment"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability."
  }
}

variable "database_config" {
  description = "Database configuration settings"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
    multi_az       = bool
    backup_retention_period = number
  })

  default = {
    engine         = "postgres"
    engine_version = "15.3"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    multi_az       = false
    backup_retention_period = 7
  }
}
```

**Variable Best Practices:**

- Always include meaningful descriptions
- Define explicit types (string, number, bool, list, map, object)
- Provide sensible defaults where appropriate
- Use validation blocks for input constraints
- Mark sensitive variables with `sensitive = true`

**Output Values:**

```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${aws_db_instance.main.endpoint}"
  sensitive   = true
}
```

For advanced variable patterns, complex type definitions, and output strategies, see **@references/best_practices.md**
and **@references/variables-outputs.md**.

## Quick Start

For complete examples and implementation patterns, see:

- Project initialization and backend configuration: **@references/best_practices.md**
- Module structure and organization: **@references/file_structure.md**
- AWS-specific resource patterns: **@references/aws.md**
- Azure-specific resource patterns: **@references/azure.md**
- GCP-specific resource patterns: **@references/gcp.md**

## Testing and Validation

Implement testing at multiple levels for reliable infrastructure:

**Static Analysis and Validation:**

```bash
# Format check
terraform fmt -check -recursive

# Syntax validation
terraform validate

# Static security analysis
tfsec .
checkov -d .

# Linting
tflint --recursive
```

**Plan Review:**

```bash
# Generate and review execution plan
terraform plan -out=tfplan

# Analyze plan output in JSON format
terraform show -json tfplan | jq
```

**Automated Testing:**

- Use Terratest for Go-based testing
- Implement kitchen-terraform for Ruby-based tests
- Create test fixtures in `examples/` directories
- Test in isolated environments with temporary resources
- Clean up resources after test completion

**Testing Strategies:**

- **Unit Tests**: Test individual modules in isolation
- **Integration Tests**: Test module interactions
- **End-to-End Tests**: Test complete infrastructure deployments
- **Policy Tests**: Validate security and compliance policies
- **Cost Tests**: Estimate and validate infrastructure costs

See **@references/testing.md** for complete testing strategies, tool configurations, and working examples.

## CI/CD Integration

Integrate Terraform into automated pipelines with these stages:

**Pipeline Stages:**

1. **Validate** - Format check, syntax validation, and static analysis
2. **Plan** - Generate execution plan and cost estimate
3. **Review** - Manual approval gate for changes
4. **Apply** - Execute infrastructure changes
5. **Test** - Verify deployment with automated tests

**CI/CD Best Practices:**

- Use separate service accounts with limited permissions
- Store state in shared remote backend
- Implement plan artifacts for approval workflows
- Enable plan destruction on PR closure
- Use automated drift detection
- Implement automated rollback on failures
- Include security scanning in pipeline
- Generate and archive plan outputs

For complete CI/CD pipeline configurations, including GitHub Actions workflows, GitLab CI, Azure DevOps, and Jenkins
examples, see **@references/testing.md**.

## Scripted Plan Analysis

Before running `terraform apply`, use the bundled script to identify risky operations:

```bash
terraform plan -out=tfplan
terraform show -json tfplan | python3 ${CLAUDE_SKILL_ROOT}/scripts/analyze_plan.py
```

The script flags: deletions, replacements (destroy+create), high-risk resource types (RDS, S3, VPCs, IAM roles), and
produces a risk level (LOW / MEDIUM / HIGH). Treat a HIGH rating as a blocker — review with the team before proceeding.

## Safety Protocol for Destructive Operations

When this skill is active, apply these guardrails:

**Always run plan analysis before apply:**

- Run `analyze_plan.py` on the plan output and surface the risk report to the user
- For MEDIUM or HIGH risk: explicitly list what will be deleted or replaced and ask for confirmation
- Never run `terraform apply` directly — always `plan` first

**Require explicit confirmation for:**

- `terraform destroy` on any workspace — state the exact resources that will be destroyed
- `terraform apply` when the plan contains deletions of stateful resources (databases, storage buckets, VPCs)
- `terraform state rm` — removing state doesn't destroy the resource but orphans it; confirm the user knows this

**Refuse and explain if:**

- `terraform apply -auto-approve` is requested without first reviewing the plan output
- `terraform state push` is attempted — overwriting remote state can cause irreversible corruption
- The workspace name is `prod` or `production` and the plan contains any delete or replace actions

**Before any apply:**

1. Run `analyze_plan.py` and show the risk level
2. Read back the list of changes (create/update/delete/replace counts)
3. Ask "Does this match your intent?" before proceeding

## Best Practices Checklist

### Before Commit

- [ ] Code formatted with `terraform fmt`
- [ ] Validation passed with `terraform validate`
- [ ] TFLint checks passed without errors
- [ ] Security scans completed (tfsec, Checkov)
- [ ] Documentation updated (README, inline comments)
- [ ] Variables have descriptions and types
- [ ] Outputs have descriptions
- [ ] No hardcoded secrets or sensitive data
- [ ] Pre-commit hooks executed successfully

### Before Pull Request

- [ ] Plan reviewed and understood
- [ ] All tests passing (unit, integration)
- [ ] Security review completed
- [ ] Cost implications reviewed with Infracost
- [ ] Breaking changes documented
- [ ] Migration path documented (if needed)
- [ ] Examples updated if needed
- [ ] Peer review completed

### Before Deploy

- [ ] Backup current state file
- [ ] Review changes in staging environment
- [ ] Communication plan ready for stakeholders
- [ ] Rollback plan documented and tested
- [ ] Monitoring and alerting configured
- [ ] On-call engineer available
- [ ] Change window scheduled (for production)
- [ ] Post-deployment verification plan ready

## Multi-Cloud Considerations

When working across multiple cloud providers:

**Provider Configuration with Aliases:**

```hcl
# Use provider aliases for multi-region or multi-account
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "secondary"
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
```

**Multi-Cloud Abstraction Patterns:**

- Create cloud-agnostic module interfaces where possible
- Use consistent variable naming across providers
- Implement cloud-specific submodules for provider-specific features
- Document provider-specific requirements and limitations
- Consider using Terragrunt for DRY multi-environment configurations

For detailed multi-cloud patterns and abstraction strategies, see **@references/multi-cloud.md**.

## Common Patterns

For common Terraform patterns including:

- Remote state configuration examples
- Standard tagging conventions
- Module source patterns
- Workspace management strategies
- State file organization
- Provider configuration patterns

See **@references/best_practices.md**.

## Troubleshooting

For troubleshooting common Terraform issues including:

- State lock resolution
- Provider plugin errors
- State drift detection and remediation
- Resource import procedures
- Version upgrade issues
- Backend migration procedures

See **@references/best_practices.md**.

## Essential Commands Quick Reference

**Basic Workflow:**

```bash
terraform init          # Initialize working directory
terraform validate      # Validate configuration syntax
terraform plan          # Preview infrastructure changes
terraform apply         # Apply infrastructure changes
terraform destroy       # Destroy infrastructure
```

**State Management:**

```bash
terraform state list                    # List resources in state
terraform state show <resource>         # Show resource details
terraform state mv <source> <dest>      # Move resource in state
terraform state rm <resource>           # Remove resource from state
terraform state pull                    # Download and output state file
```

**Workspace Management:**

```bash
terraform workspace list                # List workspaces
terraform workspace new <name>          # Create workspace
terraform workspace select <name>       # Switch workspace
terraform workspace delete <name>       # Delete workspace
```

**Code Quality:**

```bash
terraform fmt -recursive               # Format code recursively
terraform fmt -check                   # Check formatting without changes
tflint                                 # Run linter
tfsec .                                # Security scan
checkov -d .                          # Policy as code scan
```

## Recommended Tools

- **terraform-docs** - Automatic documentation generation from code
- **tflint** - Linting for Terraform with pluggable rules
- **tfsec** - Static analysis security scanner
- **checkov** - Policy-as-code and security scanning
- **terrascan** - Compliance and security scanning
- **infracost** - Cloud cost estimates for infrastructure changes
- **terratest** - Go-based automated testing framework
- **pre-commit** - Git pre-commit hooks for code quality
- **terraform-compliance** - BDD-style compliance testing
- **tfswitch** - Terraform version switcher

## Learning Resources

### Official Documentation

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Registry](https://registry.terraform.io/)
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- [Terraform Best Practices Guide](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

### Community Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform AWS Modules](https://github.com/terraform-aws-modules)
- [Terraform Azure Modules](https://github.com/Azure/terraform-azurerm-modules)
- [Terraform GCP Modules](https://github.com/terraform-google-modules)
- [Awesome Terraform](https://github.com/shuaibiyy/awesome-terraform)

### Tool Documentation

- [TFLint](https://github.com/terraform-linters/tflint)
- [tfsec](https://github.com/aquasecurity/tfsec)
- [Checkov](https://www.checkov.io/)
- [terraform-docs](https://github.com/terraform-docs/terraform-docs)
- [Terratest](https://terratest.gruntwork.io/)
- [Infracost](https://www.infracost.io/)

## Contributing

When contributing to Terraform projects:

1. Follow the file structure guidelines outlined in this skill
2. Run all linters and tests locally before submitting
3. Update documentation for any changes (README, inline comments)
4. Include working examples for new modules
5. Add tests for new functionality
6. Follow semantic versioning for module releases
7. Write clear, descriptive commit messages
8. Participate in code reviews constructively

## Support and Feedback

For questions or improvements to this skill:

- Review the reference documentation for detailed guidance
- Check configuration templates in `assets/` directory
- Consult cloud-specific guides for provider-specific patterns
- Follow security best practices rigorously
- Report issues or suggest improvements through your team's feedback channels

---

## Additional Resources

### Reference Files

| Reference                         | Content                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `references/best_practices.md`    | Version management, configuration standards, code quality guidelines, and module design principles           |
| `references/file_structure.md`    | Standard project layouts, file organization rules, naming conventions, and directory structures              |
| `references/security.md`          | Secrets management, encryption at rest and in transit, IAM controls, compliance, and state file security     |
| `references/testing.md`           | Testing strategies, static analysis, unit testing with Terratest, integration testing, and CI/CD integration |
| `references/aws.md`               | AWS-specific best practices, resource configuration patterns, IAM and security, and VPC networking           |
| `references/azure.md`             | Azure-specific best practices, resource configuration patterns, Azure AD and RBAC, and virtual networks      |
| `references/gcp.md`               | GCP-specific best practices, resource configuration patterns, IAM and service accounts, and VPC networking   |
| `references/variables-outputs.md` | Complex variable patterns, type definitions, and output strategies                                           |
| `references/multi-cloud.md`       | Cloud abstraction patterns, multi-provider strategies, and cross-cloud considerations                        |

### Asset Templates

| Asset                            | Description                                                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `assets/.tflint.hcl`             | TFLint configuration with AWS/Azure/GCP plugins, rule enablement, and naming conventions enforcement                         |
| `assets/.pre-commit-config.yaml` | Pre-commit hooks for Terraform format checking, validation, security scanning (tfsec, Checkov), and documentation generation |

### Example Projects

Working examples demonstrating best practices:

- **`examples/complete-module/`** - Fully structured Terraform module with all recommended files and patterns
- **`examples/terratest/`** - Automated testing setup with Terratest, including unit and integration tests
- **`examples/github-actions/`** - Complete GitHub Actions workflow for Terraform CI/CD
- **`examples/multi-cloud/`** - Multi-provider infrastructure demonstrating abstraction patterns

---

**Version**: 2.0.0
**Last Updated**: 2026-01-09
**Maintained By**: Infrastructure Team

Apply these practices consistently to create maintainable, secure, and scalable infrastructure as code. For specific
implementation details and advanced patterns, consult the reference files and working examples provided in this skill.
