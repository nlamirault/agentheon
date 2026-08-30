# Terraform / File Structure Guidelines

## Standard Project Layout

Enforce the following logical layout for Terraform configurations to ensure consistency and maintainability.

### Core Configuration Files

#### `main.tf`

- Contains `terraform` block with version constraints
- Defines backend configuration for remote state
- Includes top-level resource declarations or module usage
- Should be the entry point for understanding the infrastructure

**Example:**

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  environment = var.environment
}
```

#### `variables.tf`

- All input variable declarations with clear documentation
- Include `description`, `type`, and `default` where appropriate
- Use validation blocks for complex constraints
- Group related variables together with comments

**Example:**

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

#### `outputs.tf`

- All output definitions with descriptive documentation
- Include `description` for each output
- Group related outputs together
- Consider sensitive outputs and mark appropriately

**Example:**

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_endpoint" {
  description = "Endpoint for the database"
  value       = module.database.endpoint
  sensitive   = true
}
```

#### `locals.tf`

- Central place for `locals` used across the project
- Use for computed values and DRY principles
- Group related locals with comments
- Avoid complex logic; prefer simple transformations

**Example:**

```hcl
locals {
  # Common naming prefix
  name_prefix = "${var.project}-${var.environment}"

  # Standard tags applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project
    }
  )

  # Network configuration
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Computed CIDR blocks
  private_subnets = [
    for i in range(3) : cidrsubnet(var.vpc_cidr, 8, i)
  ]

  public_subnets = [
    for i in range(3) : cidrsubnet(var.vpc_cidr, 8, i + 100)
  ]
}
```

#### `data.tf`

- Data sources only
- Query existing infrastructure or external data
- Keep separate from resource definitions for clarity
- Document what external data is being queried

**Example:**

```hcl
# Fetch available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Fetch latest AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

#### `provider.tf` (Optional)

- Provider configurations if not in `main.tf`
- Multiple provider configurations (e.g., multi-region)
- Provider aliases and configurations

**Example:**

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"

  default_tags {
    tags = local.common_tags
  }
}
```

## Directory Structure

### Simple Project

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── data.tf
├── provider.tf
├── terraform.tfvars
├── .terraform.lock.hcl
└── README.md
```

### Complex Project with Modules

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── data.tf
├── provider.tf
├── terraform.tfvars
├── .terraform.lock.hcl
├── README.md
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── rds/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── environments/
    ├── dev/
    │   ├── terraform.tfvars
    │   └── backend.tf
    ├── staging/
    │   ├── terraform.tfvars
    │   └── backend.tf
    └── prod/
        ├── terraform.tfvars
        └── backend.tf
```

## File Organization Rules

### Warnings

You should warn if:

1. **Scattered Definitions**
   - Variables, outputs, or locals are spread across multiple files
   - Makes it harder to find and maintain configuration

2. **Misplaced Terraform Blocks**
   - Providers and terraform blocks declared in files other than `main.tf` or `provider.tf`
   - Reduces predictability and maintainability

3. **Mixed Concerns**
   - Data sources mixed with resource definitions in the same file
   - Resources that belong in modules are in root configuration

4. **Missing Documentation**
   - Files lack header comments explaining their purpose
   - Variables or outputs without descriptions

### Recommendations

1. **One Resource Type Per File** (for large projects)
   - Consider splitting by resource type when files exceed 300 lines
   - Example: `ec2.tf`, `security_groups.tf`, `iam.tf`

2. **Consistent Ordering**
   - Within files, order blocks alphabetically or logically
   - Use blank lines to separate logical groups

3. **Comments and Documentation**
   - Add file-level comments explaining the purpose
   - Document complex logic with inline comments
   - Maintain up-to-date README.md files

4. **Version Control**
   - Commit `.terraform.lock.hcl` to ensure consistent provider versions
   - Add `.terraform/` to `.gitignore`
   - Never commit `terraform.tfstate` files (use remote backend)

## Environment-Specific Configurations

### Using Workspaces

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars.d/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

### Using Separate Directories

```text
.
├── modules/
│   └── infrastructure/
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    ├── staging/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    └── prod/
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars
        └── backend.tf
```

## Naming Conventions

### File Names

- Use lowercase with underscores: `security_groups.tf`
- Be descriptive but concise: `alb_target_groups.tf`
- Avoid abbreviations unless widely understood

### Resource Names

```hcl
# Good
resource "aws_security_group" "web_server" {
  name = "${local.name_prefix}-web-server"
}

# Bad
resource "aws_security_group" "sg1" {
  name = "websg"
}
```

### Variable Names

```hcl
# Good
variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

# Bad
variable "cidr" {
  type = string
}
```

## Additional Files

### `.gitignore`

```gitignore
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files with secrets
*.tfvars
*.tfvars.json

# Ignore override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration files
.terraformrc
terraform.rc
```

### `README.md`

Every Terraform project should include a README with:

- Project description and purpose
- Prerequisites and requirements
- Usage instructions
- Variable documentation
- Output documentation
- Examples
- Contributing guidelines
