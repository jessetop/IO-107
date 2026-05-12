# Lab 3: Policy-as-Code Evaluation & Failure Remediation

**Duration:** 45 min
**Companion lecture:** Module 6 — Policy-as-Code with OPA

## Files to author

- `main.tf` — Terraform with **4 intentional OPA violations** the student remediates:
  1. Bad bucket name (doesn't match `<env>-<app>-<purpose>` regex)
  2. Missing `CostCenter` tag
  3. **No paired `aws_s3_bucket_server_side_encryption_configuration` resource** (the modern v4+ pattern)
  4. Lambda function with `timeout > 300` and no `kms_key_arn`
- `policies/naming.rego` — bucket-name regex check
- `policies/tagging.rego` — required-tags check
- `policies/encryption.rego` — paired-resource encryption check (modern Rego pattern; matches Module 6 slide)
- `policies/lambda.rego` — Lambda timeout + KMS key checks
- `conftest.toml` — `policy = "./policies"`
- `buildspec.yml` — `terraform init` + `plan` + `show -json` + `conftest test` (Validate stage); `terraform apply` only after manual approval
- `expected_output.txt` — example Conftest FAIL output students should match against
- `README.md` (this file)

## Lab guide reference

See `SYF-IO-107 - Lab 3 - Policy-as-Code Evaluation & Failure Remediation` in the deliverables Drive folder.

## Outstanding

- All code files. Rego policies are the trickiest part — match the slide-deck examples exactly. ~3 hr authoring.
- The paired-encryption Rego rule uses `input.configuration.root_module.resources[_]` with `expressions.bucket.references` — see Module 6 narrative + slide 12.
