#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh
#
# Creates the S3 bucket and DynamoDB table required for Terraform remote state.
# Must be run ONCE before the first terraform init in any environment.
#
# Usage:
#   ./bootstrap.sh <environment> <region>
#   ./bootstrap.sh dev eu-west-2
#   ./bootstrap.sh prod eu-west-2
#
# What it creates:
#   - S3 bucket with versioning, encryption, and public access blocked
#   - DynamoDB table with PAY_PER_REQUEST billing for state locking
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
ENVIRONMENT="${1:?Usage: ./bootstrap.sh <environment> <region>}"
REGION="${2:?Usage: ./bootstrap.sh <environment> <region>}"
PROJECT_NAME="obs-platform"
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-terraform-state"
DYNAMODB_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-terraform-locks"

echo ""
echo "============================================="
echo "  Terraform Remote State Bootstrap"
echo "  Project:     ${PROJECT_NAME}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Region:      ${REGION}"
echo "  Bucket:      ${BUCKET_NAME}"
echo "  DynamoDB:    ${DYNAMODB_TABLE}"
echo "============================================="
echo ""

# ---------------------------------------------------------------------------
# S3 Bucket
# ---------------------------------------------------------------------------
echo "→ Creating S3 bucket: ${BUCKET_NAME}"

if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
  echo "  ✓ Bucket already exists — skipping creation"
else
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  echo "  ✓ Bucket created"
fi

echo "→ Enabling S3 versioning (allows state rollback)"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled
echo "  ✓ Versioning enabled"

echo "→ Enabling S3 server-side encryption (AES-256)"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
echo "  ✓ Encryption enabled"

echo "→ Blocking all public access to state bucket"
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,\
IgnorePublicAcls=true,\
BlockPublicPolicy=true,\
RestrictPublicBuckets=true"
echo "  ✓ Public access blocked"

echo "→ Enabling S3 bucket lifecycle (expire old state versions after 90 days)"
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET_NAME}" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-old-state-versions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    }]
  }'
echo "  ✓ Lifecycle policy applied"

# ---------------------------------------------------------------------------
# DynamoDB Table
# ---------------------------------------------------------------------------
echo ""
echo "→ Creating DynamoDB table: ${DYNAMODB_TABLE}"

if aws dynamodb describe-table \
     --table-name "${DYNAMODB_TABLE}" \
     --region "${REGION}" 2>/dev/null | grep -q "TableName"; then
  echo "  ✓ Table already exists — skipping creation"
else
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --tags \
      Key=Project,Value="${PROJECT_NAME}" \
      Key=Environment,Value="${ENVIRONMENT}" \
      Key=ManagedBy,Value=bootstrap-script
  echo "  ✓ DynamoDB table created"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  Bootstrap complete!"
echo ""
echo "  Next steps:"
echo "  1. cd environments/${ENVIRONMENT}"
echo "  2. terraform init"
echo "  3. terraform plan"
echo "============================================="
echo ""
