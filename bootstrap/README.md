# Bootstrap

Before running `terraform init` for the first time, you must create
the S3 bucket and DynamoDB table that Terraform uses to store remote
state and prevent concurrent applies.

## Run the bootstrap script

```bash
chmod +x bootstrap/bootstrap.sh

# For dev environment
./bootstrap/bootstrap.sh dev eu-west-2

# For prod environment
./bootstrap/bootstrap.sh prod eu-west-2
```

## What gets created

| Resource | Name | Purpose |
|---|---|---|
| S3 Bucket | obs-platform-dev-terraform-state | Stores terraform.tfstate |
| S3 Versioning | Enabled | Allows state rollback |
| S3 Encryption | AES-256 | State encrypted at rest |
| S3 Public Access | Blocked | State never publicly accessible |
| DynamoDB Table | obs-platform-dev-terraform-locks | Prevents concurrent applies |

## Why this exists

Terraform remote state is a chicken-and-egg problem — you need AWS
resources to store state, but Terraform manages AWS resources. The
bootstrap script solves this by using the AWS CLI directly (not
Terraform) to create the prerequisite infrastructure.

This is standard practice in production Terraform setups.
