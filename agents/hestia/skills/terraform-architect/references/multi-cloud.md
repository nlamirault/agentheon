# Multi-Cloud Terraform Patterns

Guide to managing infrastructure across multiple cloud providers (AWS, Azure, GCP) with Terraform, including abstraction
patterns and provider-specific considerations.

## Provider Configuration

### Multi-Provider Setup

```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
```

### Provider Aliases for Multi-Region

```hcl
# AWS multi-region
provider "aws" {
  region = "us-east-1"
  alias  = "us_east"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west"
}

# Azure multi-region (via location parameter)
provider "azurerm" {
  features {}
  alias = "primary"
}

provider "azurerm" {
  features {}
  alias = "secondary"
}

# GCP multi-region
provider "google" {
  project = var.project_id
  region  = "us-central1"
  alias   = "us"
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
  alias   = "eu"
}
```

## Abstraction Patterns

### Cloud-Agnostic Module Interface

```hcl
# modules/compute/variables.tf
variable "cloud_provider" {
  description = "Cloud provider (aws, azure, gcp)"
  type        = string

  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud_provider)
    error_message = "Cloud provider must be aws, azure, or gcp."
  }
}

variable "instance_config" {
  description = "Instance configuration"
  type = object({
    name          = string
    size          = string  # small, medium, large
    image         = string
    subnet_id     = string
    public_ip     = bool
  })
}
```

```hcl
# modules/compute/main.tf
locals {
  # Map generic sizes to cloud-specific instance types
  instance_types = {
    aws = {
      small  = "t3.micro"
      medium = "t3.medium"
      large  = "t3.large"
    }
    azure = {
      small  = "Standard_B1s"
      medium = "Standard_B2s"
      large  = "Standard_B4ms"
    }
    gcp = {
      small  = "e2-micro"
      medium = "e2-medium"
      large  = "e2-standard-4"
    }
  }

  instance_type = local.instance_types[var.cloud_provider][var.instance_config.size]
}

# AWS implementation
resource "aws_instance" "this" {
  count = var.cloud_provider == "aws" ? 1 : 0

  instance_type = local.instance_type
  ami           = var.instance_config.image
  subnet_id     = var.instance_config.subnet_id

  associate_public_ip_address = var.instance_config.public_ip

  tags = {
    Name = var.instance_config.name
  }
}

# Azure implementation
resource "azurerm_linux_virtual_machine" "this" {
  count = var.cloud_provider == "azure" ? 1 : 0

  name                = var.instance_config.name
  size                = local.instance_type
  resource_group_name = var.azure_resource_group
  location            = var.azure_location

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.instance_config.image
    version   = "latest"
  }

  # ...
}

# GCP implementation
resource "google_compute_instance" "this" {
  count = var.cloud_provider == "gcp" ? 1 : 0

  name         = var.instance_config.name
  machine_type = local.instance_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = var.instance_config.image
    }
  }

  network_interface {
    subnetwork = var.instance_config.subnet_id

    dynamic "access_config" {
      for_each = var.instance_config.public_ip ? [1] : []
      content {}
    }
  }
}
```

### Provider-Specific Submodules

```text
modules/
├── storage/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers/
│       ├── aws/
│       │   ├── main.tf       # S3 implementation
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── azure/
│       │   ├── main.tf       # Blob Storage implementation
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── gcp/
│           ├── main.tf       # Cloud Storage implementation
│           ├── variables.tf
│           └── outputs.tf
```

```hcl
# modules/storage/main.tf
module "aws_storage" {
  source = "./providers/aws"
  count  = var.provider == "aws" ? 1 : 0

  bucket_name = var.name
  versioning  = var.versioning
  encryption  = var.encryption
}

module "azure_storage" {
  source = "./providers/azure"
  count  = var.provider == "azure" ? 1 : 0

  storage_account_name = var.name
  resource_group       = var.azure_resource_group
  versioning           = var.versioning
  encryption           = var.encryption
}

module "gcp_storage" {
  source = "./providers/gcp"
  count  = var.provider == "gcp" ? 1 : 0

  bucket_name = var.name
  project_id  = var.gcp_project_id
  versioning  = var.versioning
  encryption  = var.encryption
}

# Unified outputs
output "id" {
  value = coalesce(
    try(module.aws_storage[0].id, null),
    try(module.azure_storage[0].id, null),
    try(module.gcp_storage[0].id, null)
  )
}
```

## Cloud Service Mapping

### Compute

| Generic             | AWS          | Azure           | GCP             |
| ------------------- | ------------ | --------------- | --------------- |
| Virtual Machine     | EC2          | Virtual Machine | Compute Engine  |
| Container Service   | ECS/EKS      | AKS             | GKE             |
| Serverless Function | Lambda       | Functions       | Cloud Functions |
| Auto Scaling        | Auto Scaling | VM Scale Sets   | Instance Groups |

### Storage

| Generic        | AWS     | Azure           | GCP              |
| -------------- | ------- | --------------- | ---------------- |
| Object Storage | S3      | Blob Storage    | Cloud Storage    |
| Block Storage  | EBS     | Managed Disks   | Persistent Disks |
| File Storage   | EFS     | Files           | Filestore        |
| Archive        | Glacier | Archive Storage | Coldline/Archive |

### Database

| Generic         | AWS         | Azure           | GCP         |
| --------------- | ----------- | --------------- | ----------- |
| Relational      | RDS         | SQL Database    | Cloud SQL   |
| NoSQL Document  | DynamoDB    | Cosmos DB       | Firestore   |
| NoSQL Key-Value | DynamoDB    | Cosmos DB       | Bigtable    |
| Cache           | ElastiCache | Cache for Redis | Memorystore |
| Data Warehouse  | Redshift    | Synapse         | BigQuery    |

### Networking

| Generic         | AWS         | Azure           | GCP                  |
| --------------- | ----------- | --------------- | -------------------- |
| Virtual Network | VPC         | Virtual Network | VPC                  |
| Load Balancer   | ELB/ALB/NLB | Load Balancer   | Cloud Load Balancing |
| DNS             | Route 53    | DNS Zone        | Cloud DNS            |
| CDN             | CloudFront  | CDN             | Cloud CDN            |
| VPN             | VPN Gateway | VPN Gateway     | Cloud VPN            |

## Common Patterns

### Multi-Cloud Networking

```hcl
# AWS VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "main-vpc"
    Environment = var.environment
  }
}

# Azure Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.azure_location
  resource_group_name = var.resource_group_name

  tags = {
    environment = var.environment
  }
}

# GCP VPC
resource "google_compute_network" "main" {
  name                    = "main-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Cloud Interconnects (if needed)
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "main-vpn-gateway"
  location            = var.azure_location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  # ...
}
```

### Cross-Cloud Storage Replication

```hcl
# Primary storage in AWS
resource "aws_s3_bucket" "primary" {
  bucket = "company-data-primary"
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Replica in GCP
resource "google_storage_bucket" "replica" {
  name     = "company-data-replica"
  location = "US"

  versioning {
    enabled = true
  }
}

# Replication configuration (requires external tooling)
resource "null_resource" "setup_replication" {
  provisioner "local-exec" {
    command = "aws s3 sync s3://${aws_s3_bucket.primary.id} gs://${google_storage_bucket.replica.name}"
  }

  triggers = {
    primary_bucket = aws_s3_bucket.primary.id
    replica_bucket = google_storage_bucket.replica.name
  }
}
```

### Multi-Cloud Database

```hcl
# Variable to select cloud
variable "database_provider" {
  description = "Cloud provider for database"
  type        = string
  default     = "aws"
}

# AWS RDS
resource "aws_db_instance" "main" {
  count = var.database_provider == "aws" ? 1 : 0

  identifier     = "main-db"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"

  # ...
}

# Azure SQL Database
resource "azurerm_mssql_server" "main" {
  count = var.database_provider == "azure" ? 1 : 0

  name                         = "main-sqlserver"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.admin_password
}

# GCP Cloud SQL
resource "google_sql_database_instance" "main" {
  count = var.database_provider == "gcp" ? 1 : 0

  name             = "main-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"
  }
}

# Unified output
output "database_endpoint" {
  value = coalesce(
    try(aws_db_instance.main[0].endpoint, ""),
    try("${azurerm_mssql_server.main[0].fully_qualified_domain_name}:1433", ""),
    try(google_sql_database_instance.main[0].connection_name, "")
  )
}
```

## Provider-Specific Considerations

### AWS

**Authentication:**

```hcl
provider "aws" {
  region = var.region

  # Prefer IAM roles over access keys
  assume_role {
    role_arn = var.role_arn
  }

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
```

**Regional Services:**

- Most services are regional
- Some are global (IAM, CloudFront, Route 53)
- Use provider aliases for multi-region

### Azure

**Authentication:**

```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }

  # Prefer Managed Identity over Service Principal
  use_msi = true
}
```

**Resource Groups:**

- All resources must belong to a resource group
- Resource groups are regional
- Use for logical organization

### GCP

**Authentication:**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region

  # Prefer Workload Identity over service account keys
  # Credentials loaded from GOOGLE_APPLICATION_CREDENTIALS
}
```

**Projects:**

- Resources belong to projects
- Projects can be organized in folders and organizations
- Use for billing and access control

## Tagging/Labeling Strategy

### Unified Tagging

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

# AWS (tags)
resource "aws_instance" "this" {
  # ...

  tags = merge(
    local.common_tags,
    { Name = "app-server" }
  )
}

# Azure (tags)
resource "azurerm_virtual_machine" "this" {
  # ...

  tags = merge(
    local.common_tags,
    { name = "app-server" }
  )
}

# GCP (labels)
resource "google_compute_instance" "this" {
  # ...

  labels = merge(
    { for k, v in local.common_tags : lower(k) => lower(v) },
    { name = "app-server" }
  )
}
```

## Cost Optimization

### Cross-Cloud Cost Comparison

```hcl
variable "evaluate_costs" {
  description = "Evaluate costs across clouds"
  type        = bool
  default     = false
}

data "external" "aws_cost" {
  count = var.evaluate_costs ? 1 : 0

  program = ["python", "${path.module}/scripts/estimate-aws-cost.py"]
  query = {
    instance_type = var.instance_config.size
    region        = var.aws_region
  }
}

data "external" "azure_cost" {
  count = var.evaluate_costs ? 1 : 0

  program = ["python", "${path.module}/scripts/estimate-azure-cost.py"]
  query = {
    instance_type = var.instance_config.size
    region        = var.azure_region
  }
}

output "cost_comparison" {
  value = var.evaluate_costs ? {
    aws   = data.external.aws_cost[0].result
    azure = data.external.azure_cost[0].result
  } : null
}
```

## Best Practices

✅ **DO:**

- Use consistent naming across clouds
- Implement cloud-agnostic interfaces where possible
- Separate provider-specific logic into submodules
- Use provider aliases for multi-region deployments
- Implement unified tagging/labeling strategy
- Document cloud-specific requirements
- Use data sources to reference cross-cloud resources
- Implement proper authentication for each provider
- Test modules against all supported clouds
- Use cost estimation tools

❌ **DON'T:**

- Mix cloud-specific logic in generic modules
- Hardcode cloud-specific values
- Assume identical feature parity across clouds
- Use different naming conventions per cloud
- Skip provider version pinning
- Ignore cloud-specific best practices
- Assume resources map 1:1 across clouds
- Over-abstract and lose cloud-specific features
- Skip cost analysis
- Use same credentials across environments

---

Multi-cloud infrastructure requires careful planning and abstraction. Use these patterns to build portable, maintainable
infrastructure across AWS, Azure, and GCP.
