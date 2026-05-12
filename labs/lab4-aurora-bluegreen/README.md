# Lab 4: Aurora Blue/Green Deployment via Terraform + Pipeline

**Duration:** 30 min
**Companion lecture:** Module 5 — Aurora Schema Migrations via Pipelines

## Files to author

- `terraform/aurora_cluster.tf` — `aws_rds_cluster` resource for Aurora PostgreSQL:
  - Initial state: `engine = "aurora-postgresql"`, `engine_version = "15.4"`, default parameter group, **NO `blue_green_update` block** (students add it)
  - Encrypted at rest (KMS), Multi-AZ, mandatory tags
- `terraform/variables.tf` — `environment`, `application`, `owner`, `cost_center`, `kms_key_arn`
- `terraform/outputs.tf` — cluster endpoint, reader endpoint, port
- `terraform/terraform.tfvars.example`
- `policies/engine_version_pin.rego` — OPA policy that pins engine version to an approved list (e.g. `15.5`, `15.6`)
- `buildspec.yml` — `terraform init` + `terraform plan` + `conftest test` (Validate); manual approval; `terraform apply` (Deploy)
- `expected_cloudtrail_events.txt` — example CloudTrail events students look for:
  - `CreateBlueGreenDeployment`
  - `ModifyDBCluster`
  - `SwitchoverBlueGreenDeployment`
- `README.md` (this file)

## Student-modification path (matches lab guide)

1. Open `terraform/aurora_cluster.tf`
2. Add the `blue_green_update { enabled = true }` block to the `aws_rds_cluster` resource
3. Bump `engine_version` from `15.4` to `15.5`
4. Commit and push
5. Watch pipeline: plan → OPA validate → manual approval → apply
6. Observe blue + green clusters in the RDS console + the three CloudTrail events

## Lab guide reference

See `SYF-IO-107 - Lab 4 - Aurora Blue/Green Deployment via Terraform + Pipeline` in the deliverables Drive folder.

## Outstanding

- All code files. ~1.5 hr authoring.
- Confirm the training Aurora cluster ID with platform team before the engine-version pin policy is finalised.
- Real Aurora Blue/Green switchover takes 5-15 min — instructor may demonstrate separately.
