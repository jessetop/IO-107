# IO-107 SDLC Pipeline & Deployment Guardrails — Claude Instructions

**Course ID:** IO-107
**Stream:** Stream 2 - AWS Intermediate Operations
**Duration:** 1 Day
**Created:** 2026-04-07
**Last Updated:** 2026-04-07

---

## Approved Repositories

Lab code is staged in the IO-107 umbrella testing repo:

- https://github.com/jessetop/IO-107

The four lab subtrees live at:
- `labs/io107-lab1-eks-app/` (Lab 1 — EKS Deployment)
- `labs/io107-lab2-sam-app/` (Lab 2 — Lambda SAM)
- `labs/io107-lab3-policy-violations/` (Lab 3 — OPA)
- `labs/io107-lab4-aurora-bluegreen/` (Lab 4 — Aurora Blue/Green)

At classroom delivery time these will be split into per-lab repos under the [Client]'s GitHub/CodeCommit org and the `[client-org]/[repo-name]` placeholder in each lab guide will be replaced with the real per-lab URL.

For LabForge validation runs (`verify_repo_code.py`), the source of truth is the local `labforge_iterations/repo_additions/io107-lab*-*/` staging directories, which mirror the GitHub repo subfolders one-to-one.

---

## CRITICAL: Read This File First

This file is the **single source of truth** for course-specific information. Claude MUST read this file at the start of every session before working on this course.

---

## Client Context: Synchrony Financial (SYF)

### Approved AWS Services (Use These in Content)
- **Compute:** EKS (Fargate/EC2), Lambda
- **Storage:** S3
- **Database:** RDS, Aurora
- **CI/CD:** CodePipeline, CodeBuild
- **Policy:** AWS Config, SCPs, OPA

### Services NOT Used (Avoid in Content)
- DynamoDB — Use Aurora/RDS instead
- ECS — Use EKS instead for all container examples

---

## Reference Documentation (Single Source of Truth)

**AWS CI/CD:**
- [CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/) - Pipeline architecture
- [CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/) - Build configuration
- [AWS Config Developer Guide](https://docs.aws.amazon.com/config/latest/developerguide/) - Compliance rules

**AWS Governance:**
- [Organizations SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) - Service control policies
- [Tag Policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html) - Tagging enforcement

**Policy-as-Code:**
- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/) - OPA and Rego
- [Conftest](https://www.conftest.dev/) - Policy testing

**EKS Deployment (NEW - Addresses Gap):**
- [EKS Deployment Guide](https://docs.aws.amazon.com/eks/latest/userguide/deployments.html) - EKS deployments
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) - IAM Roles for Service Accounts
- [Helm Charts](https://docs.aws.amazon.com/eks/latest/userguide/helm.html) - Helm on EKS

**Lambda Deployment (NEW - Addresses Gap):**
- [Lambda Deployment](https://docs.aws.amazon.com/lambda/latest/dg/deploying-lambda-apps.html) - Lambda deployment
- [SAM Developer Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/) - SAM framework
- [Lambda Versioning](https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html) - Versions and aliases

**Database Migration (NEW - Addresses Gap):**
- [RDS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html) - Database deployments
- [Aurora Cloning](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Clone.html) - Aurora for testing

**Version/Date Verified:** 2026-04-07

---

## Course-Specific Instructions

### Content Gaps to Address (from stream_2_3_4_review.md)

**HIGH PRIORITY:**
1. **Add EKS Deployment Pipeline Coverage**
   - Helm chart deployments via CodeBuild
   - kubectl apply via CodeBuild
   - EKS service account IAM roles (IRSA)
   - Fargate profile deployments

2. **Add Lambda Deployment Patterns**
   - SAM/Serverless Framework integration
   - Lambda versioning and aliases
   - Lambda function URLs vs API Gateway

**MEDIUM PRIORITY:**
3. **Add RDS/Aurora Schema Migration**
   - Flyway/Liquibase integration in pipelines
   - Blue/green database deployments
   - Aurora cloning for testing environments

**LOW PRIORITY:**
4. **Update Generic IaC Examples**
   - Replace EC2-centric examples with EKS/Lambda/RDS

---

## Content Restrictions

- ONLY use the documentation listed above for technical content
- DO NOT use web searches for AWS features, APIs, or capabilities
- If information is not in the official docs, ASK the user
- All deployment examples must use EKS/Lambda/Aurora (not EC2/ECS/DynamoDB)

---

## Pipeline Status

See `pipeline_checklist.md` in this folder for current progress.

### Quick Links
- Pipeline Checklist: `./pipeline_checklist.md`
- Facts Extracted: `./facts_extracted_v2.md` (to be created)
- Course Outline v1: `./course_outline.md`
- Course Outline v2: `./course_outline_v2.md` (to be created)
- Slide JSON: `./slide_json/`

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-04-07 | Initial creation with SYF context | Claude |
| 2026-04-07 | Added EKS/Lambda/Aurora deployment gap requirements | Claude |

