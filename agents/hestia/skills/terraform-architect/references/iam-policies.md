# IAM Policy Best Practices

**CRITICAL RULE**: Always use `data "aws_iam_policy_document"` instead of inline `jsonencode()` for IAM policies.

## Why Use aws_iam_policy_document?

The `aws_iam_policy_document` data source provides significant advantages over `jsonencode()`:

### Benefits

| Feature             | aws_iam_policy_document     | jsonencode()                   |
| ------------------- | --------------------------- | ------------------------------ |
| **Type Safety**     | ✅ Validates structure      | ❌ No validation               |
| **Interpolation**   | ✅ Safe variable handling   | ❌ Manual escaping required    |
| **Plan Visibility** | ✅ Shows policy changes     | ❌ Shows JSON blob             |
| **Readability**     | ✅ HCL syntax, easy to read | ❌ JSON in HCL, harder to read |
| **Maintainability** | ✅ Easy to modify           | ❌ Error-prone to edit         |
| **Escaping**        | ✅ Automatic                | ❌ Manual                      |

### Terraform Plan Comparison

**With `jsonencode()` (BAD)**:

```text
# aws_iam_policy.example will be updated in-place
~ resource "aws_iam_policy" "example" {
    ~ policy = jsonencode(
        ~ {
            ~ Statement = [...]  # Unreadable diff
          }
      )
  }
```

**With `aws_iam_policy_document` (GOOD)**:

```text
# data.aws_iam_policy_document.example will be read
# Shows clear, structured policy changes

# aws_iam_policy.example will be updated in-place
~ resource "aws_iam_policy" "example" {
    ~ policy = (known after apply)  # Clear diff in policy document
  }
```

## Basic Pattern

### ❌ BAD: Using jsonencode()

**Avoid this pattern:**

```hcl
resource "aws_iam_policy" "bad_example" {
  name = "example-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::${var.bucket_name}/*"
    }]
  })
}
```

**Problems**:

- No validation of policy structure
- Variable interpolation can break JSON
- Changes show as opaque JSON diff
- Error-prone to edit manually
- No type checking for fields

### ✅ GOOD: Using aws_iam_policy_document

**Prefer this pattern:**

```hcl
data "aws_iam_policy_document" "good_example" {
  statement {
    sid    = "AllowS3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "good_example" {
  name   = "example-policy"
  policy = data.aws_iam_policy_document.good_example.json
}
```

**Advantages**:

- Terraform validates structure
- Safe variable interpolation
- Clear diffs in terraform plan
- Easy to read and maintain
- Type-safe fields

## Common Patterns

### S3 Bucket Access Policy

```hcl
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
    ]
  }

  statement {
    sid    = "AllowObjectOperations"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.environment}-s3-access"
  description = "S3 access policy for ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.s3_access.json
}
```

### Trust Policy (Assume Role Policy)

**For EKS Service Accounts:**

```hcl
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_service_account" {
  name               = "${var.environment}-${var.service_name}-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}
```

**For ECS Tasks:**

```hcl
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}
```

**For Lambda Functions:**

```hcl
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}
```

### Secrets Manager Access

```hcl
data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "AllowSecretsRead"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/*",
    ]
  }
}

resource "aws_iam_policy" "secrets_access" {
  name   = "${var.environment}-secrets-access"
  policy = data.aws_iam_policy_document.secrets_access.json
}
```

### CloudWatch Logs Policy

```hcl
data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid    = "AllowLogOperations"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/${var.service_name}/*",
    ]
  }
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name   = "${var.environment}-cloudwatch-logs"
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}
```

## Advanced Patterns

### Combining Multiple Policy Documents

Use `source_policy_documents` to merge multiple policies:

```hcl
# Base policy - logging
data "aws_iam_policy_document" "base_logging" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

# Additional policy - S3 access
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "S3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

# Combined policy
data "aws_iam_policy_document" "combined" {
  source_policy_documents = [
    data.aws_iam_policy_document.base_logging.json,
    data.aws_iam_policy_document.s3_access.json,
  ]
}

resource "aws_iam_policy" "combined" {
  name   = "${var.environment}-combined-policy"
  policy = data.aws_iam_policy_document.combined.json
}
```

### Conditional Statements

```hcl
data "aws_iam_policy_document" "conditional_access" {
  statement {
    sid    = "AllowFromVPCOnly"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [var.vpc_endpoint_id]
    }
  }

  statement {
    sid    = "DenyUnencryptedUploads"
    effect = "Deny"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }
}

resource "aws_iam_policy" "conditional_access" {
  name   = "${var.environment}-conditional-access"
  policy = data.aws_iam_policy_document.conditional_access.json
}
```

### Principal-Based Policies

```hcl
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "AllowRootAccountManagement"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "AllowServiceUsage"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.service_role.arn,
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_kms_key" "service_key" {
  description = "${var.environment} service encryption key"
  policy      = data.aws_iam_policy_document.kms_key_policy.json
}
```

### Override and Extension

Use `override_policy_documents` to override specific statements:

```hcl
# Base policy
data "aws_iam_policy_document" "base" {
  statement {
    sid    = "BaseS3Access"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

# Override for production - add write access
data "aws_iam_policy_document" "production_override" {
  override_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]

  statement {
    sid    = "BaseS3Access"  # Same SID to override
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",  # Additional action
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "${var.environment}-s3-access"
  policy = var.environment == "prod" ? data.aws_iam_policy_document.production_override.json : data.aws_iam_policy_document.base.json
}
```

## Least Privilege Principle

### ❌ BAD: Overly Permissive

```hcl
data "aws_iam_policy_document" "too_permissive" {
  statement {
    effect    = "Allow"
    actions   = ["*"]              # TOO BROAD
    resources = ["*"]              # TOO BROAD
  }
}
```

### ✅ GOOD: Specific Permissions

```hcl
data "aws_iam_policy_document" "specific_permissions" {
  statement {
    sid    = "SpecificS3Actions"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/uploads/*",  # Specific path
    ]
  }
}
```

## Testing Policy Documents

### Validate Policy Syntax

```bash
# Terraform will validate policy structure
terraform validate

# Check plan output for policy changes
terraform plan | grep -A 20 "aws_iam_policy_document"
```

### Use AWS IAM Policy Simulator

```bash
# Export policy to JSON
terraform state pull | jq '.resources[] | select(.type=="aws_iam_policy_document") | .instances[0].attributes.json' > policy.json

# Test policy with AWS CLI
aws iam simulate-custom-policy \
  --policy-input-list file://policy.json \
  --action-names s3:GetObject \
  --resource-arns "arn:aws:s3:::my-bucket/*"
```

## Common Mistakes to Avoid

### 1. Using jsonencode() for Policies

❌ **Don't**:

```hcl
policy = jsonencode({...})
```

✅ **Do**:

```hcl
data "aws_iam_policy_document" "example" {...}
policy = data.aws_iam_policy_document.example.json
```

### 2. Overly Broad Permissions

❌ **Don't**:

```hcl
actions = ["*"]
resources = ["*"]
```

✅ **Do**:

```hcl
actions = ["s3:GetObject", "s3:PutObject"]
resources = ["arn:aws:s3:::specific-bucket/*"]
```

### 3. Missing SID (Statement ID)

❌ **Don't**:

```hcl
statement {
  effect = "Allow"
  # No sid
}
```

✅ **Do**:

```hcl
statement {
  sid    = "DescriptiveName"
  effect = "Allow"
}
```

### 4. Forgetting Conditions for Sensitive Operations

❌ **Don't**:

```hcl
statement {
  actions = ["iam:PassRole"]
  resources = ["*"]
}
```

✅ **Do**:

```hcl
statement {
  actions = ["iam:PassRole"]
  resources = ["arn:aws:iam::${var.account_id}:role/specific-role"]

  condition {
    test     = "StringEquals"
    variable = "iam:PassedToService"
    values   = ["ecs-tasks.amazonaws.com"]
  }
}
```

### 5. Not Using Data Sources for Dynamic Values

❌ **Don't**:

```hcl
resources = ["arn:aws:logs:us-east-1:123456789012:*"]
```

✅ **Do**:

```hcl
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resources = [
  "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
]
```

## Migration Guide

### Converting Existing jsonencode() Policies

1. **Identify policies using jsonencode():**

```bash
grep -r "jsonencode" *.tf
```

2. **Extract the policy JSON:**

```hcl
# Before
resource "aws_iam_policy" "example" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "arn:aws:s3:::bucket/*"
    }]
  })
}
```

3. **Convert to aws_iam_policy_document:**

```hcl
# After
data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::bucket/*",
    ]
  }
}

resource "aws_iam_policy" "example" {
  policy = data.aws_iam_policy_document.example.json
}
```

4. **Validate the change:**

```bash
terraform plan

# Should show no changes if conversion is correct
```

## Checklist

Before committing IAM policies:

- [ ] Using `aws_iam_policy_document` (not `jsonencode()`)
- [ ] All statements have descriptive `sid` values
- [ ] Permissions follow least privilege principle
- [ ] Resources are specific (not `"*"` unless necessary)
- [ ] Conditions applied for sensitive operations
- [ ] Dynamic values use data sources
- [ ] Policy validated with `terraform validate`
- [ ] Plan output reviewed and understood
- [ ] No overly permissive wildcards

## Resources

- [AWS IAM Policy Document Data Source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)
- [AWS IAM Policy Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Policy Simulator](https://policysim.aws.amazon.com/)
- [IAM Policy Examples](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_examples.html)
