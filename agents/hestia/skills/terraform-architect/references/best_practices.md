# Terraform / Best Practices

## Core Principles

You are an expert Terraform reviewer following HashiCorp and community standards.

### Version Management

- Enforce:
  - `terraform` block with `required_version` and `required_providers`
  - Explicit provider version pinning using `~>` or `>=`
  - Use versioned modules with semantic versioning

### Configuration Standards

- Enforce:
  - Usage of `locals` instead of duplicating literals or logic
  - Avoid hardcoded values in favor of variables and locals
  - Use `for_each` or `count` for dynamic resource creation
  - Use remote backends (e.g., S3, Azure Blob, GCS) for state management
  - Organize resources by service or application domain (e.g., networking, compute)

### Code Quality

- Recommend:
  - `terraform fmt` and `terraform validate` as part of CI
  - Tag all resources with `Name`, `Environment`, `Owner` using standard tags map
  - Use validation rules for variables to prevent incorrect input values

- Warn if:
  - Resources do not use `lifecycle { prevent_destroy = true }` for critical infrastructure
  - Inline policies are used instead of separate `aws_iam_policy_document`
  - AWS credentials are hardcoded

## Module Guidelines

### Design Principles

- Split code into reusable modules to avoid duplication
- Use outputs from modules to pass information between configurations
- Version control modules and follow semantic versioning for stability
- Document module usage with examples and clearly define inputs/outputs

### Module Structure

```text
modules/
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── README.md
│   └── examples/
│       └── basic/
```

### Module Best Practices

- Keep modules focused on a single responsibility
- Use sensible defaults in variables
- Provide comprehensive examples
- Include validation for input variables
- Document all outputs with descriptions

### Single Responsibility

Each module should have one clear purpose:

**Good - Focused module:**

```text
vpc-module/
├── main.tf          # VPC and subnet resources only
├── variables.tf
└── outputs.tf
```

**Bad - Too many responsibilities:**

```text
infrastructure-module/
├── main.tf          # VPC, EC2, RDS, S3, CloudFront...
```

### Composition Over Monoliths

Build complex infrastructure by composing smaller modules:

```hcl
# Root module composing smaller modules
module "vpc" {
  source = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
}

module "eks" {
  source = "./modules/eks"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}

module "rds" {
  source = "./modules/rds"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids
}
```

## Variable Design Patterns

### Required vs Optional Variables

```hcl
# Required - no default
variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

# Optional with default
variable "enable_deletion_protection" {
  description = "Enable deletion protection for the database"
  type        = bool
  default     = true
}

# Optional with null default (use provider default)
variable "instance_type" {
  description = "Instance type for EC2 instances. If not specified, uses provider default"
  type        = string
  default     = null
}
```

### Complex Type Variables

```hcl
# Object type for structured data
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

# Map of objects for multiple instances
variable "applications" {
  description = "Map of applications to deploy"
  type = map(object({
    image_tag    = string
    cpu          = number
    memory       = number
    desired_count = number
    environment_variables = map(string)
  }))

  default = {}
}
```

### Variable Validation

```hcl
variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

## Output Design

### Output Categorization

Organize outputs by purpose:

```hcl
# Identity outputs
output "id" {
  description = "ID of the created resource"
  value       = aws_instance.this.id
}

output "arn" {
  description = "ARN of the created resource"
  value       = aws_instance.this.arn
}

# Network outputs
output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address (if assigned)"
  value       = aws_instance.this.public_ip
}

# Connection outputs
output "connection_string" {
  description = "Connection string for the resource"
  value       = "https://${aws_instance.this.public_dns}:8080"
  sensitive   = true
}

# Resource outputs for module composition
output "security_group_id" {
  description = "Security group ID for allowing access"
  value       = aws_security_group.this.id
}
```

### Sensitive Outputs

```hcl
output "database_password" {
  description = "Database master password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "api_key" {
  description = "API key for service access"
  value       = aws_api_gateway_api_key.this.value
  sensitive   = true
}
```

## Dynamic Blocks

Use dynamic blocks for repeating configuration:

```hcl
resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}
```

## Conditional Resources

### Count for Conditional Creation

```hcl
resource "aws_eip" "this" {
  count = var.create_eip ? 1 : 0

  instance = aws_instance.this.id
  domain   = "vpc"
}

# Reference conditional resource
output "eip_address" {
  value = var.create_eip ? aws_eip.this[0].public_ip : null
}
```

### For_each for Multiple Instances

```hcl
resource "aws_subnet" "private" {
  for_each = var.availability_zones

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.key + 10)
  availability_zone = each.value

  tags = {
    Name = "${var.name}-private-${each.value}"
    Type = "private"
  }
}

# Reference for_each resources
output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}
```

## Module Sources

### Local Modules

```hcl
module "vpc" {
  source = "./modules/vpc"
  # or
  source = "../../../modules/vpc"
}
```

### Git Sources

```hcl
# Git HTTPS
module "vpc" {
  source = "git::https://github.com/company/terraform-modules.git//modules/vpc?ref=v1.2.0"
}

# Git SSH
module "vpc" {
  source = "git::ssh://git@github.com/company/terraform-modules.git//modules/vpc?ref=v1.2.0"
}

# Specific branch
module "vpc" {
  source = "git::https://github.com/company/terraform-modules.git//modules/vpc?ref=main"
}
```

### Registry Sources

```hcl
# Public registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"
}

# Private registry
module "vpc" {
  source  = "app.terraform.io/company/vpc/aws"
  version = "1.0.0"
}
```

## Module Versioning

### Semantic Versioning

Follow semver principles:

- MAJOR version: Breaking changes
- MINOR version: New features, backward compatible
- PATCH version: Bug fixes

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"  # Allow 5.1.x, but not 5.2.0
}
```

## Performance Optimization

### Execution Speed

- Cache Terraform provider plugins locally to reduce download time during plan and apply operations
- Limit the use of `count` or `for_each` when not necessary to avoid unnecessary duplication of resources

### State Management

- Use remote state locking to prevent concurrent modifications
- Split large state files into smaller, manageable pieces using workspaces or separate configurations
- Regularly backup state files
- Use state file encryption for sensitive data

## Key Conventions

### Tagging Strategy

1. Use tagging for all resources to ensure proper tracking and cost management
2. Standard tags should include:
   - `Name`: Resource identifier
   - `Environment`: dev, staging, production
   - `Owner`: Team or individual responsible
   - `Project`: Project or application name
   - `ManagedBy`: Terraform
   - `CostCenter`: For cost allocation

### Resource Organization

1. Ensure that resources are defined in a modular, reusable way for easier scaling
2. Group related resources together logically
3. Use consistent naming conventions across all resources
4. Document your code and configurations with `README.md` files, explaining the purpose of each module

## Anti-Patterns to Avoid

### Don't Use Hardcoded Values

```hcl
# ❌ BAD
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"  # Hardcoded AMI
  instance_type = "t3.micro"
  subnet_id     = "subnet-12345"           # Hardcoded subnet
}

# ✅ GOOD
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
}
```

### Don't Create God Modules

```hcl
# ❌ BAD - Monolithic module doing everything
module "everything" {
  source = "./modules/complete-infrastructure"

  # 50+ variables for VPC, EC2, RDS, S3, CloudFront...
}

# ✅ GOOD - Composed from focused modules
module "vpc" {
  source = "./modules/vpc"
  # 5-10 variables
}

module "application" {
  source = "./modules/application"
  vpc_id = module.vpc.id
  # 5-10 variables
}
```

### Don't Skip Validation

```hcl
# ❌ BAD - No validation
variable "environment" {
  type = string
}

# ✅ GOOD - With validation
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

## Advanced Patterns

### Provider Passing

```hcl
# Root module
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "secondary"
}

module "primary_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.primary
  }
}

module "secondary_vpc" {
  source = "./modules/vpc"

  providers = {
    aws = aws.secondary
  }
}
```

### Module Dependencies

```hcl
# Explicit dependency
module "database" {
  source = "./modules/rds"

  # Implicit dependency via output
  subnet_ids = module.vpc.database_subnet_ids

  # Explicit dependency
  depends_on = [module.vpc]
}
```

### Feature Flags

```hcl
variable "features" {
  description = "Feature flags"
  type = object({
    enable_monitoring = bool
    enable_backup     = bool
    enable_encryption = bool
  })

  default = {
    enable_monitoring = true
    enable_backup     = true
    enable_encryption = true
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  count = var.features.enable_monitoring ? 1 : 0
  # ...
}
```

## Refactoring Modules

### Moved Blocks (Terraform 1.5+)

```hcl
# Rename resource without recreating
moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}

# Move resource to module
moved {
  from = aws_security_group.app
  to   = module.application.aws_security_group.app
}
```

### Import Blocks (Terraform 1.5+)

```hcl
import {
  to = aws_instance.example
  id = "i-1234567890abcdef"
}
```

## Documentation and Learning Resources

### Official Documentation

- [Terraform Registry](https://registry.terraform.io/) - Official modules and providers
- [HashiCorp Learn](https://learn.hashicorp.com/terraform) - Tutorials and guides
- [Terraform Best Practices](https://www.terraform-best-practices.com/) - Community best practices

### Cloud Provider Resources

- AWS: [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Azure: [AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- GCP: [Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Example Configuration

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
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.project
  cidr = "10.0.0.0/16"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project}-vpc"
    }
  )
}
```

---

Apply these module design patterns to create maintainable, reusable, and well-structured Terraform modules that scale
across teams and environments.
