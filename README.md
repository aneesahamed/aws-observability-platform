# AWS Observability Platform — OTel Demo on ECS Fargate

> **Production-grade AWS infrastructure** for deploying the [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/) microservices application on Amazon ECS Fargate — built with Terraform, secured with least-privilege IAM + OIDC, and delivered through a GitHub Actions CI/CD pipeline with zero stored AWS credentials.

---

## Architecture

```
                          ┌─────────────────────────────────────────────────────┐
                          │                  AWS eu-west-2                       │
                          │                                                      │
  Internet ──────────────►│  ┌──────────────────────────────────────────────┐   │
                          │  │              VPC  10.0.0.0/16                 │   │
                          │  │                                               │   │
                          │  │  ┌─────────────────────────────────────────┐ │   │
                          │  │  │   Public Subnets (eu-west-2a / 2b)      │ │   │
                          │  │  │   ┌──────────────┐  ┌───────────────┐   │ │   │
                          │  │  │   │     ALB       │  │  NAT Gateway  │   │ │   │
                          │  │  │   │  (port 80/443)│  │  + Elastic IP │   │ │   │
                          │  │  │   └──────┬───────┘  └───────────────┘   │ │   │
                          │  │  └──────────┼──────────────────────────────┘ │   │
                          │  │             │                                 │   │
                          │  │  ┌──────────▼──────────────────────────────┐ │   │
                          │  │  │   Private App Subnets (2a / 2b)         │ │   │
                          │  │  │                                          │ │   │
                          │  │  │  ┌──────────────────────────────────┐   │ │   │
                          │  │  │  │         ECS Fargate Cluster       │   │ │   │
                          │  │  │  │  frontend  │ cart  │  checkout   │   │ │   │
                          │  │  │  │  payment   │shipping│  email     │   │ │   │
                          │  │  │  │  recommend │  ad   │  currency   │   │ │   │
                          │  │  │  │  quote  │product-catalog│reviews │   │ │   │
                          │  │  │  │  accounting│fraud │image-provider│  │ │   │
                          │  │  │  │  load-gen  │  otel-collector     │   │ │   │
                          │  │  │  └──────────────────────────────────┘   │ │   │
                          │  │  └────────────────────────────────────────-┘ │   │
                          │  │                                               │   │
                          │  │  ┌──────────────────────────────────────────┐ │   │
                          │  │  │   Private Data Subnets (2a / 2b)         │ │   │
                          │  │  │                                           │ │   │
                          │  │  │  ┌────────────────┐  ┌─────────────────┐ │ │   │
                          │  │  │  │ Aurora PG 16   │  │  ElastiCache    │ │ │   │
                          │  │  │  │ Serverless v2  │  │  Serverless     │ │ │   │
                          │  │  │  │ (Multi-AZ)     │  │  Redis          │ │ │   │
                          │  │  │  └────────────────┘  └─────────────────┘ │ │   │
                          │  │  └──────────────────────────────────────────┘ │   │
                          │  └─────────────────────────────────────────────--┘   │
                          │                                                       │
                          │  ┌───────────────┐  ┌───────────────────────────┐   │
                          │  │  ECR (17 repos)│  │  Secrets Manager / SSM    │   │
                          │  └───────────────┘  └───────────────────────────┘   │
                          │  ┌───────────────┐  ┌───────────────────────────┐   │
                          │  │  CloudWatch   │  │  IAM (OIDC + Task Roles)   │   │
                          │  │  Dashboard +  │  │                            │   │
                          │  │  5 Alarms     │  └───────────────────────────┘   │
                          │  └───────────────┘                                   │
                          └─────────────────────────────────────────────────────┘
```

**CI/CD Flow:**
```
  Developer PR
       │
       ▼
  GitHub Actions (terraform-ci.yml)
  ├── fmt -check -recursive
  ├── validate
  ├── plan (dev)
  └── Post plan as PR comment
       │
       ▼ (merge to main)
  GitHub Actions (terraform-apply.yml)
  ├── apply → dev  (automatic)
  └── apply → prod (requires manual approval via GitHub Environment)
```

---

## Prerequisites

| Tool | Minimum Version | Notes |
|------|----------------|-------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | 1.13.0 | `terraform -version` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | 2.x | For bootstrapping only |
| [Git](https://git-scm.com/) | Any recent | |
| AWS Account | — | IAM permissions to create all resources |

### Required AWS Resources (Bootstrap — one-time)

Before running `terraform init`, create the remote state backend for each environment:

```bash
# Dev
aws s3api create-bucket \
  --bucket obs-platform-dev-terraform-state \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

aws s3api put-bucket-versioning \
  --bucket obs-platform-dev-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket obs-platform-dev-terraform-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name obs-platform-dev-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-2

# Repeat above for prod (replace 'dev' with 'prod')
```

### GitHub OIDC Setup

Create an IAM OIDC Identity Provider and a role that GitHub Actions can assume:

```bash
# 1. Create the OIDC provider (one-time per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create the role with the trust policy below and attach AdministratorAccess
#    (scope down to specific actions for production hardening)
```

Trust policy for the IAM role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:aneesahamed/aws-observability-platform:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Add these secrets to your GitHub repository (**Settings → Secrets → Actions**):

| Secret | Example Value |
|--------|--------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/github-actions-terraform` |
| `AWS_REGION` | `eu-west-2` |

Configure a **GitHub Environment** named `prod` (**Settings → Environments**) with required reviewers to enforce the manual approval gate before prod apply.

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/aneesahamed/aws-observability-platform.git
cd aws-observability-platform

# 2. Copy and configure variables
cp terraform.tfvars.example environments/dev/terraform.tfvars
# Edit environments/dev/terraform.tfvars with your values

# 3. Initialise Terraform for dev
cd environments/dev
terraform init

# 4. Preview changes
terraform plan

# 5. Apply (or let the CI/CD pipeline do it on merge to main)
terraform apply
```

---

## Module Descriptions

| Module | Path | What It Provisions |
|--------|------|--------------------|
| **vpc** | `modules/vpc` | VPC, 6 subnets (public/app/data × 2 AZs), IGW, NAT GW, route tables, VPC Flow Logs |
| **security-groups** | `modules/security-groups` | ALB, ECS, RDS, and ElastiCache security groups with least-privilege rules |
| **iam** | `modules/iam` | Shared ECS task execution role + 17 per-service task roles with scoped permissions |
| **ecr** | `modules/ecr` | 17 ECR repositories (one per OTel service) with scan-on-push and lifecycle policies |
| **rds** | `modules/rds` | Aurora PostgreSQL 16 Serverless v2, 2 instances (Multi-AZ), Secrets Manager credentials |
| **elasticache** | `modules/elasticache` | ElastiCache Serverless Redis with auth token in Secrets Manager |
| **alb** | `modules/alb` | Internet-facing ALB, target group, HTTP/HTTPS listeners, S3 access logs |
| **ecs** | `modules/ecs` | ECS Fargate cluster, task definitions + services for all 17 OTel services, auto-scaling |
| **cloudwatch** | `modules/cloudwatch` | Dashboard, 5 metric alarms, SNS topic for notifications |
| **ssm** | `modules/ssm` | SSM Parameter Store entries for non-sensitive app configuration |

---

## AWS Services — Rationale

| Service | Why It Was Chosen |
|---------|------------------|
| **ECS Fargate** | Serverless containers — no EC2 nodes to patch. Right-sized per service, pay-per-use. |
| **Aurora PostgreSQL Serverless v2** | Auto-scales from 0.5 ACU, Multi-AZ HA, compatible with standard PostgreSQL drivers. |
| **ElastiCache Serverless Redis** | Zero-config scaling for the cart service cache; no cluster sizing decisions needed. |
| **ALB** | Layer-7 load balancing, path-based routing, native target group health checks for Fargate. |
| **ECR** | Private container registry co-located with ECS; scan-on-push catches vulnerabilities before deploy. |
| **Secrets Manager** | Automatic rotation support, native ECS integration for injecting credentials at task start. |
| **SSM Parameter Store** | Free tier for non-secret config; IAM-scoped read access per service. |
| **CloudWatch** | Native AWS observability — no extra agent for basic metrics; Container Insights for ECS. |
| **IAM OIDC** | Eliminates long-lived AWS credentials in CI/CD; short-lived tokens scoped per workflow run. |
| **S3 + DynamoDB** | Industry-standard Terraform remote state with encryption, versioning, and state locking. |

---

## Cost Estimation (dev environment — eu-west-2)

> Estimates based on light usage (~8 h/day workday usage). Actual costs will vary.

| Service | Estimated Monthly Cost |
|---------|----------------------|
| ECS Fargate (17 services × 0.25 vCPU / 0.5 GB, ~8 h/day) | ~$18 |
| Aurora Serverless v2 (0.5 ACU min, occasional queries) | ~$12 |
| ElastiCache Serverless (minimal traffic) | ~$6 |
| ALB (1 LCU baseline) | ~$18 |
| NAT Gateway (1×, light egress) | ~$5 |
| ECR (17 repos, <1 GB each) | ~$2 |
| CloudWatch (logs + metrics + dashboard) | ~$5 |
| Secrets Manager (3 secrets) | ~$1 |
| S3 + DynamoDB (state files) | ~$1 |
| **Total** | **~$68 / month** |

💡 **Cost tip:** Stop ECS services and scale Aurora to 0 ACU outside business hours using AWS EventBridge Scheduler to cut dev costs by ~60%.

---

## Security Considerations

1. **No stored credentials** — GitHub Actions authenticates via OIDC; short-lived tokens are scoped to the specific repository and workflow.
2. **Least-privilege IAM** — each ECS service gets its own task role restricted to its own secrets, log group, and SSM path.
3. **Private subnets** — ECS tasks, RDS, and ElastiCache are never placed in public subnets; all internet egress goes through the NAT Gateway.
4. **Secrets Manager** — database passwords and Redis auth tokens are auto-generated by Terraform, stored encrypted, and injected into containers at startup. They are never in plaintext config or environment variables checked into source control.
5. **VPC Flow Logs** — all accepted and rejected traffic is logged to CloudWatch for audit and incident response.
6. **ALB access logs** — stored in S3 with a lifecycle policy; the bucket blocks all public access and enforces SSL-only requests.
7. **Deletion protection** — Aurora and the ALB have `deletion_protection = true` in prod, preventing accidental teardown.
8. **Encryption at rest** — Aurora storage and ECR images are AES-256 encrypted; Secrets Manager uses AWS-managed KMS keys.
9. **Image scanning** — ECR scan-on-push detects known CVEs in every image before it can be deployed.
10. **State file security** — Terraform state (which may contain sensitive outputs) is stored in an encrypted, versioned S3 bucket with DynamoDB locking to prevent concurrent modifications.

---

## CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│  terraform-ci.yml  (every push + PR to main)                        │
│                                                                     │
│  lint ──► validate ──► plan (dev)                                   │
│                             └─► Post plan as PR comment             │
│                             └─► Upload plan artifact (7 days)       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  terraform-apply.yml  (push to main only)                           │
│                                                                     │
│  apply-dev (automatic) ──► apply-prod (manual approval required)    │
│       └─► Write job summary         └─► Write job summary           │
│       └─► Upload plan artifact           └─► Upload plan artifact   │
│           (30 days)                          (90 days)              │
└─────────────────────────────────────────────────────────────────────┘
```

- **OIDC authentication** — no `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` stored anywhere
- **Concurrency groups** — outdated CI runs are cancelled automatically; apply runs are never cancelled mid-flight
- **Provider caching** — Terraform providers are cached between runs to speed up init
- **Plan-as-comment** — every PR gets an up-to-date plan diff posted and updated automatically
- **Manual approval gate** — prod apply waits for a required reviewer via GitHub Environment protection rules
- **Pinned action SHAs** — all `uses:` references pin the full commit SHA, preventing supply-chain attacks from mutable tags

---

## Author

**Anees Ahamed**
Cloud Engineer · AWS Solutions Architect
[github.com/aneesahamed](https://github.com/aneesahamed)

Production-grade AWS microservices platform — ECS Fargate, Aurora PostgreSQL,  ElastiCache, Terraform IaC, GitHub Actions CI/CD, distributed tracing with  OpenTelemetry and X-Ray
