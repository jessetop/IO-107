# Module 2: Anatomy of a Pipeline Run — Using S3 — Teaching Narrative

**Duration:** 15 minutes

---

## Opening (1 minute)

"In Module 1 we talked about the pipeline architecture in the abstract — Service Catalog product, Terraform, orchestration tools, stages. Now I want you to *see* a pipeline run end-to-end before we deep-dive on any one target.

We'll use S3 as the example. Why S3? Because everyone in this room has used S3 before. You know what a bucket is. You know it holds objects. So when I walk you through the pipeline, your brain isn't busy learning a new AWS service — it's free to focus on the *pipeline mechanics*. The exact same flow you'll see here applies to EKS in Module 3, Lambda in Module 4, and Aurora in Module 5."

[SLIDE: Module 2 - Anatomy of a Pipeline Run — Using S3]

[SLIDE: Module Contents - "You Are Here"]

---

## Chapter Objectives (1 minute)

[SLIDE: Chapter Objectives]
- Trace a Terraform-to-S3 change through every stage of the pipeline
- Locate the artifacts (plan output, OPA result, build log) the pipeline produces at each stage
- Identify the organisation's standards that arrive in the Service Catalog S3 product by default
- Preview the failures you'll diagnose in Modules 6–8

"By the end you should be able to read a pipeline visualisation and know what each stage was doing, where its output lives, and what would cause it to fail."

---

## Section 1: The Walk-Through (6 minutes)

"Here's the canonical flow for an S3 change."

[SLIDE: Anatomy of a Pipeline Run — S3 Example]

"Stage 1: **Commit.** A developer launches the S3 Service Catalog product with parameters — environment, app name, owner, cost centre. The product expands to Terraform and commits to the application's repo on the right branch.

Stage 2: **Build.** EventBridge detects the commit and triggers the pipeline. CodeBuild runs `terraform plan` and saves the plan JSON as a pipeline artifact. The build log lands in CloudWatch Logs.

Stage 3: **OPA validation.** A custom action invokes Conftest against the plan JSON. The policies check naming (`client-{env}-{app}-{purpose}`), mandatory tags, encryption, BPA, and TLS-only bucket policy. If anything fails, the pipeline stops and OPA's failure output is the next thing you read.

Stage 4: **Approval (stg/prd only).** For dev, the pipeline proceeds automatically. For staging or production, the pipeline pauses at a manual approval action. A human reviews the plan and clicks approve in CodePipeline (or in the Jenkins/CloudBees UI, depending on the workload's history).

Stage 5: **Deploy.** The pipeline assumes a cross-account role into the target AWS account and runs `terraform apply`. The bucket is created with all the standard settings baked in.

The whole run takes a few minutes. Everything is logged, everything is reviewable in the pipeline console, everything ties back to the Git commit that started it."

[SLIDE: What the Terraform Change Looks Like]
```hcl
resource "aws_s3_bucket" "data_bucket" {
  bucket = "client-${var.environment}-${var.app_name}-data"

  tags = {
    Environment = var.environment
    Application = var.app_name
    Owner       = var.team_email
    CostCenter  = var.cost_center
    DataClass   = "confidential"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}
```

"Notice — and I want to stress this — the developer didn't *write* this Terraform from scratch. They launched the Service Catalog S3 product and supplied the variables. The product generated this HCL with the required settings already wired up. The OPA stage in the pipeline still validates this — the policy and the Service Catalog product are belt and braces, both enforcing the same standards from different angles."

---

## Section 2: Reading the Build Log (3 minutes)

"When you click into the build stage in the pipeline console, you land on the CodeBuild log. Here's what you're looking for."

[SLIDE: Reading the CodeBuild Log]
```
[Container] 2026/05/12 09:14:22 Running command terraform plan -out=tfplan
Terraform will perform the following actions:

  # aws_s3_bucket.data_bucket will be created
  + resource "aws_s3_bucket" "data_bucket" {
      + bucket = "client-dev-paymentsapi-data"
      + tags   = {
          + "Application" = "paymentsapi"
          + "CostCenter"  = "CC-4421"
          ...
      }
    }

Plan: 3 to add, 0 to change, 0 to destroy.

[Container] 2026/05/12 09:14:31 Running command conftest test tfplan.json
PASS - tfplan.json - main - bucket naming convention valid
PASS - tfplan.json - main - encryption configured
PASS - tfplan.json - main - mandatory tags present
```

"Two things are happening here in sequence. First, `terraform plan` produces the human-readable preview of what would change. Then `conftest test` runs the OPA policies against the plan and prints PASS or FAIL lines. When a stage fails, this is where you read the error — the FAIL line names the rule that fired and usually the resource that violated it. We'll go deep on diagnosing these failures in Module 8."

---

## Section 3: Standards Baked into the Product (3 minutes)

"The reason this all works so smoothly is that the Service Catalog S3 product ships the organisation's standards by default. You don't have to remember them. They show up in every bucket because they're not exposed as parameters you can override."

[SLIDE: Standards in the S3 Product]
- SSE-KMS encryption with a customer-managed CMK
- Block Public Access — all four settings enabled
- Bucket policy that denies any non-TLS request
- Mandatory tags: Environment, Application, Owner, CostCenter, DataClass

"Encryption is SSE-KMS with a customer-managed master key — the key policy controls who can decrypt, and CloudTrail logs every use. Block Public Access has all four settings on; even if a future bucket policy went wrong, BPA would still prevent public exposure. There's a default-deny bucket policy that rejects any request not on TLS — that's the `aws:SecureTransport` condition you'll see if you inspect a bucket. And the mandatory tags are populated from your Service Catalog parameters.

Everything in this list — naming, encryption, BPA, TLS, tagging — also has a corresponding OPA rule, so if someone tries to bypass the product and hand-write Terraform, the pipeline still catches it. Service Catalog is the first guardrail; OPA is the backstop."

---

## Section 4: What Comes Next (1 minute)

"This same pipeline pattern repeats for every target the rest of the day."

[SLIDE: Forward References]
- OPA failures (Module 6, Lab 3) — what FAIL output looks like and how to remediate
- Tag-policy enforcement (Module 7) — the org-level layer that catches missing tags
- Pipeline troubleshooting (Module 8) — systematic stage-by-stage diagnosis

"In Module 6 you'll dig into how OPA rules actually work and write a simple one yourself. Lab 3 has you fix three deliberate OPA failures against S3 Terraform — exactly the kind of failure you saw in this walk-through. Module 7 covers the tag-policy and SCP layers that sit above OPA. Module 8 covers systematic troubleshooting — which stage failed and which layer to inspect.

For now, the takeaway is: pipeline runs are *legible*. Every stage has an artifact, a log, and a clear success/fail signal. When something breaks, the pipeline tells you where."

---

## Summary (30 seconds)

[SLIDE: Chapter Summary]
- Traced an S3 change from commit through OPA, approval, and deploy
- Located the artifacts each stage produces (plan, OPA result, build log)
- Identified the standards the Service Catalog S3 product ships by default
- Previewed the failure scenarios deep-dived in Modules 6–8

"Up next: Module 3, Amazon EKS. The pipeline shape is the same — what changes is what `terraform apply` actually does at the end."

---

## Instructor Notes

**Key Points to Emphasize:**
- The point of this module is *pipeline mechanics*, not S3 features. If a participant asks about S3 storage classes, lifecycle, or replication — defer to AWS docs or to the troubleshooting module if relevant.
- The Service Catalog product is what makes the developer experience clean — the standards aren't a checklist they remember, they're parameters they fill in.
- Forward references matter: this is the cleanest, simplest walk-through; later modules deal with the messier deep-dives.

**Common Questions:**
- "What if I need a non-standard bucket?" — Exception process via Service Catalog product variant or platform team request
- "Why both Service Catalog AND OPA?" — Defence in depth; OPA catches the case where someone bypasses Service Catalog
- "Where's lifecycle / versioning?" — Configured in the Service Catalog product per data class; not in scope for this walk-through

**Timing Notes:**
- Opening: 1 min
- Objectives: 1 min
- Walk-through: 6 min
- Reading the Build Log: 3 min
- Standards in the Product: 3 min
- What Comes Next: 1 min
- Summary: 30 sec
- Buffer: ~30 sec
