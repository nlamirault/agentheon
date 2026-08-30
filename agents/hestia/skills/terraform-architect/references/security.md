# Terraform / Security Best Practices

## Core Security Principles

Security should be integrated into every aspect of your Terraform infrastructure code. Follow these principles to ensure
secure infrastructure deployment.

## Secrets Management

### Never Hardcode Secrets

**Avoid:**

```hcl
# ❌ BAD: Hardcoded credentials
resource "aws_db_instance" "database" {
  username = "admin"
  password = "SuperSecret123!"  # Never do this!
}

provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"  # Never do this!
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # Never do this!
}
```

**Instead:**

```hcl
# ✅ GOOD: Use external secret management
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "database" {
  username = var.db_username
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}

# Or use environment variables
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
provider "aws" {
  region = var.aws_region
}
```

### Secret Storage Options

#### AWS Secrets Manager

```hcl
# Store secret
resource "aws_secretsmanager_secret" "api_key" {
  name        = "${var.environment}/api/key"
  description = "API key for external service"

  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key  # Passed via environment variable
}

# Retrieve secret
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
}

locals {
  api_key = jsondecode(data.aws_secretsmanager_secret_version.api_key.secret_string)["key"]
}
```

#### HashiCorp Vault

```hcl
provider "vault" {
  address = var.vault_addr
  # Token passed via VAULT_TOKEN environment variable
}

data "vault_generic_secret" "database" {
  path = "secret/database/credentials"
}

resource "aws_db_instance" "database" {
  username = data.vault_generic_secret.database.data["username"]
  password = data.vault_generic_secret.database.data["password"]
}
```

#### Environment Variables

```hcl
# variables.tf
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# main.tf
resource "aws_db_instance" "database" {
  username = var.db_username
  password = var.db_password
}

# Set via environment variable:
# export TF_VAR_db_password="your-secure-password"
```

### Sensitive Output Protection

```hcl
output "database_password" {
  description = "Database password"
  value       = aws_db_instance.database.password
  sensitive   = true  # Prevents output in logs
}
```

## Encryption

### Encryption at Rest

#### S3 Bucket Encryption

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project}-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

#### EBS Volume Encryption

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = 100

  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn

  tags = local.common_tags
}
```

#### RDS Encryption

```hcl
resource "aws_db_instance" "database" {
  allocated_storage    = 100
  engine              = "postgres"
  instance_class      = "db.t3.medium"

  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn

  # Enable backup encryption
  backup_retention_period = 7

  tags = local.common_tags
}
```

### Encryption in Transit

#### Load Balancer with TLS

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

#### RDS with SSL/TLS

```hcl
resource "aws_db_instance" "database" {
  # ... other configuration ...

  # Create parameter group to enforce SSL
  parameter_group_name = aws_db_parameter_group.ssl_required.name
}

resource "aws_db_parameter_group" "ssl_required" {
  name   = "${var.project}-ssl-required"
  family = "postgres14"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
```

## Access Controls

### IAM Policies - Least Privilege

```hcl
# ❌ BAD: Overly permissive
resource "aws_iam_policy" "bad_example" {
  name = "too-permissive"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"  # Never use wildcard for actions
        Resource = "*"  # Never use wildcard for resources
      }
    ]
  })
}

# ✅ GOOD: Specific permissions
resource "aws_iam_policy" "s3_read_only" {
  name        = "${var.project}-s3-read-only"
  description = "Read-only access to specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
      }
    ]
  })
}
```

### Security Groups - Principle of Least Privilege

```hcl
# ❌ BAD: Open to the world
resource "aws_security_group" "bad_example" {
  name = "too-open"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Never do this!
  }
}

# ✅ GOOD: Specific and restricted
resource "aws_security_group" "web" {
  name        = "${var.project}-web"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # Only allow HTTPS from specific IP ranges
  ingress {
    description = "HTTPS from office"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.office_ip_ranges
  }

  # Allow outbound to specific services only
  egress {
    description     = "HTTPS to internet"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
```

### VPC Security

```hcl
# Private subnets for databases
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  # Disable public IP assignment
  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-private-${local.azs[count.index]}"
      Tier = "private"
    }
  )
}

# Network ACLs for additional protection
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Deny all by default, only allow specific rules
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-private-nacl"
    }
  )
}
```

## Compliance and Auditing

### CloudTrail Logging

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data.arn}/"]
    }
  }

  tags = local.common_tags
}
```

### Config Rules

```hcl
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "${var.project}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name = "${var.project}-s3-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
```

### Resource Tagging for Compliance

```hcl
locals {
  common_tags = {
    Environment  = var.environment
    Project      = var.project
    ManagedBy    = "Terraform"
    CostCenter   = var.cost_center
    Compliance   = var.compliance_level  # e.g., "PCI-DSS", "HIPAA"
    DataClass    = var.data_classification  # e.g., "Public", "Internal", "Confidential"
  }
}
```

## Vulnerability Management

### Regular Updates

```hcl
# Pin provider versions but update regularly
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow minor updates
    }
  }
}

# Use data sources for latest AMIs
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### Dependency Scanning

Use tools like:

- `tfsec` for static analysis
- `checkov` for policy-as-code scanning
- `terrascan` for compliance checks
- Snyk for vulnerability scanning

## State File Security

### Remote Backend with Encryption

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-locks"

    # Enable versioning for state recovery
    versioning = true
  }
}
```

### State Locking

```hcl
# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}
```

### State File Access Control

```hcl
# S3 bucket for state files
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-terraform-state"

  tags = local.common_tags
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy for least privilege access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireEncryptedTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

## Security Scanning in CI/CD

### Example GitHub Actions Workflow

```yaml
name: Terraform Security Scan

on:
  pull_request:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: false

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          soft_fail: false

      - name: Run Terrascan
        uses: tenable/terrascan-action@main
        with:
          iac_type: 'terraform'
          policy_type: 'aws'
```

## Security Checklist

- [ ] No hardcoded secrets in code
- [ ] Sensitive outputs marked as sensitive
- [ ] Encryption at rest enabled for all storage
- [ ] Encryption in transit configured
- [ ] IAM policies follow least privilege
- [ ] Security groups are restrictive
- [ ] CloudTrail logging enabled
- [ ] State file encrypted and access-controlled
- [ ] Regular security scans in CI/CD
- [ ] Compliance tagging applied
- [ ] VPC flow logs enabled
- [ ] WAF rules configured for public endpoints
- [ ] Backup and disaster recovery configured
