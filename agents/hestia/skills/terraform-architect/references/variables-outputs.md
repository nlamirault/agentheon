# Terraform Variables and Outputs Guide

Advanced patterns for variable declarations, complex types, validation, and output management in Terraform.

## Variable Declaration Patterns

### Basic Types

```hcl
# String
variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

# Number
variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 3
}

# Boolean
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}
```

### Collection Types

```hcl
# List
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Set (unique values)
variable "allowed_cidr_blocks" {
  description = "Set of allowed CIDR blocks"
  type        = set(string)
  default     = ["10.0.0.0/16", "172.16.0.0/12"]
}

# Map
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

### Complex Object Types

```hcl
# Object with specific structure
variable "database_config" {
  description = "Database configuration"
  type = object({
    engine                = string
    engine_version        = string
    instance_class        = string
    allocated_storage     = number
    multi_az              = bool
    backup_retention_days = number
    tags                  = map(string)
  })

  default = {
    engine                = "postgres"
    engine_version        = "15.3"
    instance_class        = "db.t3.micro"
    allocated_storage     = 20
    multi_az              = false
    backup_retention_days = 7
    tags = {
      Component = "Database"
    }
  }
}

# List of objects
variable "security_groups" {
  description = "Security group rules"
  type = list(object({
    name        = string
    description = string
    ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))

  default = []
}

# Map of objects
variable "applications" {
  description = "Application configurations"
  type = map(object({
    image_tag     = string
    cpu           = number
    memory        = number
    desired_count = number
    environment   = map(string)
  }))

  default = {}
}
```

### Optional Object Attributes (Terraform 1.3+)

```hcl
variable "instance_config" {
  description = "Instance configuration with optional fields"
  type = object({
    instance_type = string
    ami_id        = string
    key_name      = optional(string)
    monitoring    = optional(bool, true)  # Default value
    tags          = optional(map(string), {})
  })
}

# Usage
resource "aws_instance" "this" {
  instance_type = var.instance_config.instance_type
  ami           = var.instance_config.ami_id
  key_name      = var.instance_config.key_name  # May be null
  monitoring    = var.instance_config.monitoring  # Defaults to true

  tags = merge(
    var.instance_config.tags,
    { Name = "example" }
  )
}
```

## Variable Validation

### Basic Validation

```hcl
variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  description = "Number of instances"
  type        = number

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

### Advanced Validation

```hcl
variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = regex("^10\\.", var.cidr_block) != null
    error_message = "CIDR block must start with 10. (private network)."
  }
}

variable "email" {
  description = "Contact email address"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string

  validation {
    condition     = can(regex("^[tm][2-7]\\.", var.instance_type))
    error_message = "Instance type must be from t2-t7 or m2-m7 families."
  }
}
```

### Multiple Validations

```hcl
variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string

  validation {
    condition     = length(var.s3_bucket_name) >= 3 && length(var.s3_bucket_name) <= 63
    error_message = "Bucket name must be between 3 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.s3_bucket_name))
    error_message = "Bucket name must start and end with lowercase letter or number."
  }

  validation {
    condition     = !can(regex("\\.\\.|-\\.", var.s3_bucket_name))
    error_message = "Bucket name must not contain consecutive dots or hyphens."
  }
}
```

## Variable Files

### Environment-Specific Variables

```hcl
# variables.tf - Variable declarations
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

```hcl
# dev.tfvars
vpc_cidr    = "10.0.0.0/16"
environment = "dev"
```

```hcl
# prod.tfvars
vpc_cidr    = "10.10.0.0/16"
environment = "prod"
```

```bash
# Apply with specific tfvars
terraform apply -var-file="prod.tfvars"
```

### Auto-Loaded Variable Files

Terraform automatically loads:

- `terraform.tfvars`
- `terraform.tfvars.json`
- `*.auto.tfvars`
- `*.auto.tfvars.json`

```hcl
# terraform.tfvars (auto-loaded)
region      = "us-east-1"
project_name = "myapp"
```

```hcl
# common.auto.tfvars (auto-loaded)
tags = {
  ManagedBy = "Terraform"
  Team      = "Platform"
}
```

## Input Methods

### Priority Order (Highest to Lowest)

1. Command-line flags: `-var="key=value"`
2. Environment variables: `TF_VAR_key=value`
3. Variable files: `-var-file="file.tfvars"`
4. `*.auto.tfvars` files (alphabetical order)
5. `terraform.tfvars`
6. Default values in variable declarations

### Environment Variables

```bash
# Set via environment
export TF_VAR_region="us-west-2"
export TF_VAR_instance_count=5
export TF_VAR_enable_monitoring=true

# Complex types (JSON)
export TF_VAR_tags='{"Environment":"prod","Owner":"platform"}'
```

### Command-Line

```bash
# Simple values
terraform apply -var="region=us-east-1" -var="instance_count=3"

# Complex types
terraform apply -var='tags={"Environment":"prod"}'
```

## Sensitive Variables

### Marking Variables Sensitive

```hcl
variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true  # Prevents display in logs
}

variable "api_keys" {
  description = "API keys"
  type        = map(string)
  sensitive   = true
}
```

### Handling Sensitive Values

```hcl
# Reference sensitive variable
resource "aws_db_instance" "main" {
  password = var.database_password
  # ...
}

# Use with data sources
data "aws_secretsmanager_secret_version" "password" {
  secret_id = "db-password"
}

locals {
  db_password = sensitive(data.aws_secretsmanager_secret_version.password.secret_string)
}
```

## Outputs

### Basic Outputs

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "instance_ips" {
  description = "Private IP addresses of instances"
  value       = { for k, v in aws_instance.app : k => v.private_ip }
}
```

### Sensitive Outputs

```hcl
output "database_endpoint" {
  description = "Database connection endpoint"
  value       = aws_db_instance.main.endpoint
  # Not sensitive - connection info only
}

output "database_password" {
  description = "Database master password"
  value       = random_password.db_password.result
  sensitive   = true  # Prevents display
}

output "connection_string" {
  description = "Complete connection string"
  value       = "postgresql://${aws_db_instance.main.username}:${random_password.db_password.result}@${aws_db_instance.main.endpoint}"
  sensitive   = true
}
```

### Conditional Outputs

```hcl
output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.create_alb ? aws_lb.main[0].dns_name : null
}

output "nat_gateway_ips" {
  description = "NAT gateway IPs (if created)"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}
```

### Structured Outputs

```hcl
output "vpc_details" {
  description = "VPC configuration details"
  value = {
    id                = aws_vpc.main.id
    cidr_block        = aws_vpc.main.cidr_block
    public_subnet_ids = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
    nat_gateway_ips   = aws_eip.nat[*].public_ip
  }
}

output "applications" {
  description = "Application endpoints"
  value = {
    for name, app in module.applications : name => {
      url           = app.url
      health_check  = app.health_check_endpoint
      version       = app.version
    }
  }
}
```

## Module Outputs for Composition

### Resource Module Outputs

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of database subnets"
  value       = aws_subnet.database[*].id
}

output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_vpc.this.default_security_group_id
}
```

### Using Module Outputs

```hcl
# Root module
module "vpc" {
  source = "./modules/vpc"

  cidr_block = "10.0.0.0/16"
  # ...
}

module "application" {
  source = "./modules/application"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Pass outputs to other modules
}

module "database" {
  source = "./modules/database"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  # Depends on VPC creation
}
```

## Local Values

### Simple Locals

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  vpc_cidr = var.vpc_cidr != "" ? var.vpc_cidr : "10.0.0.0/16"
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  tags = merge(
    local.common_tags,
    { Name = "${local.name_prefix}-vpc" }
  )
}
```

### Complex Locals

```hcl
locals {
  # Flatten nested structures
  subnets = flatten([
    for az_index, az in var.availability_zones : [
      for subnet_type in ["public", "private", "database"] : {
        az          = az
        az_index    = az_index
        type        = subnet_type
        cidr_block  = cidrsubnet(var.vpc_cidr, 8, az_index * 10 + (subnet_type == "public" ? 0 : subnet_type == "private" ? 1 : 2))
      }
    ]
  ])

  # Group by type
  public_subnets   = [for s in local.subnets : s if s.type == "public"]
  private_subnets  = [for s in local.subnets : s if s.type == "private"]
  database_subnets = [for s in local.subnets : s if s.type == "database"]

  # Build security group rules
  security_group_rules = merge(
    # Default rules
    {
      allow_https = {
        type        = "ingress"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    },
    # Custom rules
    var.custom_security_rules
  )
}
```

## Conditional Logic

### Count-Based Conditionals

```hcl
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-${count.index + 1}"
  }
}
```

### For_each Conditionals

```hcl
resource "aws_subnet" "private" {
  for_each = var.create_private_subnets ? toset(var.availability_zones) : toset([])

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value) + 10)
  availability_zone = each.value

  tags = {
    Name = "${var.name}-private-${each.value}"
  }
}
```

### Ternary Expressions

```hcl
locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

  backup_retention = var.environment == "prod" ? 30 : var.environment == "staging" ? 7 : 1

  enable_monitoring = var.environment == "prod" || var.explicit_monitoring_enabled
}
```

## Dynamic Blocks

### Basic Dynamic Block

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
}
```

### Nested Dynamic Blocks

```hcl
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"

  dynamic "default_action" {
    for_each = var.default_actions
    content {
      type             = default_action.value.type
      target_group_arn = default_action.value.target_group_arn

      dynamic "forward" {
        for_each = default_action.value.type == "forward" ? [1] : []
        content {
          dynamic "target_group" {
            for_each = default_action.value.target_groups
            content {
              arn    = target_group.value.arn
              weight = target_group.value.weight
            }
          }
        }
      }
    }
  }
}
```

## Best Practices

✅ **DO:**

- Provide meaningful descriptions for all variables
- Define explicit types
- Use validation blocks for input constraints
- Mark sensitive variables appropriately
- Provide sensible defaults where appropriate
- Use local values for computed values
- Output all values needed by other modules
- Group related variables
- Use consistent naming conventions
- Document complex object structures

❌ **DON'T:**

- Skip variable descriptions
- Use implicit types
- Skip validation for critical inputs
- Expose sensitive values in outputs
- Use variables for constants
- Duplicate logic instead of using locals
- Output more than necessary
- Use abbreviations in names
- Mix naming conventions
- Over-complicate object structures

---

Proper variable and output management ensures maintainable, reusable, and self-documenting Terraform modules. Apply
these patterns consistently across your infrastructure code.
