# TFLint Configuration File
# https://github.com/terraform-linters/tflint

# Configure TFLint behavior
config {
  # Enable all plugin rules
  plugin_dir = "~/.tflint.d/plugins"

  # Disable specific rules module-wide
  disabled_by_default = false

  # Force TFLint to return non-zero exit code on warnings
  force = false

  # Module inspection enables deeper analysis
  module = true

  # Disable color output (useful for CI/CD)
  # color = false

  # Set format for output (default, json, checkstyle, junit, compact, sarif)
  format = "default"
}

# AWS Plugin Configuration
plugin "aws" {
  enabled = true
  version = "0.47.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # Deep check enables more thorough validation using AWS APIs
  # Requires AWS credentials to be configured
  deep_check = false
}

# Azure Plugin Configuration (uncomment if using Azure)
# plugin "azurerm" {
#   enabled = true
#   version = "0.25.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
# }

# GCP Plugin Configuration (uncomment if using GCP)
# plugin "google" {
#   enabled = true
#   version = "0.27.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-google"
# }

# Terraform Core Rules
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"

  # Custom naming rules for different block types
  custom = [
    {
      type   = "resource"
      format = "snake_case"
    },
    {
      type   = "data"
      format = "snake_case"
    },
    {
      type   = "variable"
      format = "snake_case"
    },
    {
      type   = "output"
      format = "snake_case"
    },
    {
      type   = "module"
      format = "snake_case"
    },
    {
      type   = "locals"
      format = "snake_case"
    }
  ]
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "flexible" # Options: "flexible", "semver"
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

# AWS-specific rules (examples)
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_instance_previous_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_previous_type" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_previous_type" {
  enabled = true
}

# S3 Rules
rule "aws_s3_bucket_invalid_acl" {
  enabled = true
}

rule "aws_s3_bucket_invalid_region" {
  enabled = true
}

# IAM Rules
rule "aws_iam_policy_invalid_policy" {
  enabled = true
}

rule "aws_iam_role_invalid_assume_role_policy" {
  enabled = true
}

# Security Group Rules
rule "aws_security_group_invalid_protocol" {
  enabled = true
}

# RDS Rules
rule "aws_db_instance_invalid_engine" {
  enabled = true
}

rule "aws_db_instance_default_parameter_group" {
  enabled = true
}

# Route53 Rules
rule "aws_route53_record_invalid_type" {
  enabled = true
}

# Lambda Rules
rule "aws_lambda_function_invalid_runtime" {
  enabled = true
}

# ALB/ELB Rules
rule "aws_alb_invalid_security_group" {
  enabled = true
}

rule "aws_alb_invalid_subnet" {
  enabled = true
}

rule "aws_elb_invalid_security_group" {
  enabled = true
}

rule "aws_elb_invalid_subnet" {
  enabled = true
}

# Custom Rules (examples)
# You can define custom rules by creating rule files in .tflint.d/rules/

# Example: Disable specific rules for certain directories
# rule "aws_instance_invalid_type" {
#   enabled = false
#   exclude = ["modules/legacy/**"]
# }

# Example: Configure rule severity
# Some rules can have their severity adjusted:
# - "error" - Fail TFLint (exit code 2)
# - "warning" - Show warning but don't fail (exit code 0)
# - "notice" - Informational message

# Documentation and Best Practices
# 1. Run 'tflint --init' to download plugins before first use
# 2. Use 'tflint --recursive' to lint all subdirectories
# 3. Enable deep_check carefully as it makes API calls to AWS
# 4. Add .tflint.hcl to version control
# 5. Update plugin versions regularly
# 6. Use '--format json' for CI/CD integration
# 7. Consider using '--minimum-failure-severity' in CI/CD

# Example CI/CD Usage:
# tflint --init
# tflint --recursive --minimum-failure-severity=error

# Example with specific format:
# tflint --format json > tflint-results.json
# tflint --format checkstyle > tflint-checkstyle.xml

# Ignore specific issues inline in Terraform files:
# resource "aws_instance" "example" {
#   #tflint-ignore: aws_instance_previous_type
#   instance_type = "t2.micro"
# }

# Or ignore for the entire file:
# #tflint-ignore-file: terraform_documented_variables
