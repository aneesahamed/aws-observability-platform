# =============================================================================
# environments/dev/backend.tf
#
# Remote state configuration for the dev environment.
#
# BOOTSTRAP REQUIRED BEFORE FIRST terraform init:
# The S3 bucket and DynamoDB table below must exist before Terraform can
# initialise. Run the bootstrap script first:
#   cd bootstrap && ./bootstrap.sh dev eu-west-2
#
# The bootstrap script creates:
#   - S3 bucket:        obs-platform-dev-terraform-state
#   - DynamoDB table:   obs-platform-dev-terraform-locks
#   - S3 versioning:    enabled (allows state rollback)
#   - S3 encryption:    AES-256 server-side encryption
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "obs-platform-dev-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "obs-platform-dev-terraform-locks"

    # State file versioning allows rollback if a bad apply corrupts state.
    # Versioning is enabled on the bucket by the bootstrap script.
  }
}
