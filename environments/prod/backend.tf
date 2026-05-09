# =============================================================================
# environments/prod/backend.tf
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "obs-platform-prod-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "obs-platform-prod-terraform-locks"
  }
}
