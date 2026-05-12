# Course 7: SDLC Pipeline & Deployment Guardrails (v3)

**Duration:** 1 Day — **6.5 hr content** (8 hr classroom day minus 1 hr lunch + 2× 15 min breaks)
**Stream:** AWS Intermediate Operations & Environment Deep Dive
**Toolset:** AWS CodePipeline, CodeBuild, CodeDeploy, Service Catalog, Jenkins / CloudBees (discussion), Terraform, S3, IAM, OPA, AWS Config, SCPs, EKS, Lambda, Aurora, the enterprise CI/CD platform
**Version:** 3.0 — Scope-cut from v2 to fit 6.5 hr cap; refocused on process over tool internals; added Service Catalog + Jenkins/CloudBees framing per actual SYF workflow.

**Time budget:**

| Component | Time |
|---|---|
| 8 Modules (lecture) | 210 min |
| 4 Labs (hands-on) | 180 min |
| **Total content** | **390 min = 6.5 hr** |
| + 1 hr lunch + 2× 15 min breaks = 8 hr classroom day | |

Lab : lecture ratio ~ 46 : 54.

---

## Course Description

This one-day course gives engineers the working knowledge to ship code through an enterprise SDLC pipeline. The focus is on the **process of what the pipeline does for you when you commit Terraform from an approved Service Catalog product**, not on the internals of the underlying CI/CD tools. Participants learn how the platform validates, gates, and deploys their changes; what an OPA / SCP / tag-policy failure looks like at each stage; and how to remediate. The course covers deployment patterns for the primary compute platforms — Amazon EKS, AWS Lambda — and Aurora Blue/Green deployments triggered through Terraform. Coverage of Jenkins, CloudBees, AWS CodePipeline, CodeDeploy, and AWS Service Catalog is at the orchestration / process level; participants do not need to administer any of these tools.

---

## Learning Objectives

- Describe the pipeline architecture: how Terraform from an approved Service Catalog product flows through Jenkins / CloudBees / AWS CodePipeline / CodeDeploy to a deployed workload.
- Read a CodeBuild log and AWS CodePipeline console to determine which stage failed and why.
- Recognise OPA, SCP, tag-policy, and IAM denials by their error signatures.
- Deploy a containerised application to Amazon EKS via Helm + kubectl through the pipeline.
- Deploy a serverless application via AWS SAM with alias-based traffic shifting.
- Trigger an Aurora Blue/Green deployment by changing Terraform, and observe the pipeline-driven switchover.
- Navigate the exception request process when a guardrail blocks a legitimate change.

---

## Who Should Attend

Cloud / DevOps / application engineers and infrastructure operators. Assumed: basic Git + AWS console + Terraform comfort + familiarity with an enterprise AWS account structure (Course 6 or equivalent).

---

## Module 1: Pipeline Architecture & Service Catalog (30 min)

- The CI/CD model: Service Catalog product → Terraform → Git → pipeline → AWS
- Tool mix on the orchestration side: Jenkins, CloudBees, AWS CodePipeline, CodeDeploy — what each does in the end-to-end flow (no admin deep-dive)
- Why pipeline-driven: audit trail, consistency, approval gates, compliance
- Where validation happens (build, OPA, approval, deploy stages) at a glance
- Brief acknowledgement: EC2 still in use during migration, cloud-native (containers, serverless) is the modernisation target

## Module 2: Anatomy of a Pipeline Run — Using S3 (15 min)

A walk-through using S3 as the example, since everyone already knows S3. Goal: see the *pipeline mechanics* end-to-end before any deep-dive module.

- Commit → build → OPA validation → manual approval (for stg/prd) → deploy
- What CodeBuild does, what gets passed as an artifact, how to read logs
- Naming convention + mandatory tag enforcement (preview of Mod 6/7)
- Bucket policy patterns (standard: TLS-only, encryption-required)

## Module 3: EKS Deployment via Pipelines (40 min)

- Push-based deployment via Helm + `helm upgrade --install --atomic`
- `kubectl apply` and Kustomize as the alternative
- IRSA: pod-level IAM via service accounts (the standard pattern — no static keys)
- Fargate profiles vs. EC2-backed nodes — when each makes sense
- Reading deployment validation output and rollout status

## Module 4: Lambda Deployment via Pipelines (20 min)

- SAM template basics — what's pipeline-deployed vs. inline
- Lambda versioning + alias model + alias-based traffic shifting (canary/linear)
- CloudWatch alarms as the auto-rollback trigger
- Caveat: `:$LATEST` and unqualified ARNs bypass traffic shifting

## Module 5: Aurora Schema Migrations via Pipelines (20 min)

Process-focused. Tool internals (Flyway) deliberately light.

- The challenge: schema changes are stateful — rollbacks are hard
- How it's handled: Terraform changes drive RDS/Aurora pipelines; SQL migration files version-controlled and applied by the pipeline
- Aurora Blue/Green via Terraform (`blue_green_update`) — the pattern Lab 4 exercises
- Why developers can't connect direct to production DBs

## Module 6: Policy-as-Code with OPA (30 min)

- What OPA does in the pipeline (validates Terraform plan JSON)
- Reading Conftest evaluation output: PASS, FAIL, and the metadata
- The policy categories at a glance: naming, encryption, tagging, EKS pod-security, Lambda
- Writing a simple Rego rule — illustrative example

## Module 7: SCPs, Tagging, and AWS Config Rules (25 min)

- SCPs as the AWS Organizations layer — region/service/root denials
- The mandatory tags + tag policy enforcement at the org level
- AWS Config rules as the "deployed but non-compliant" detective layer
- How each layer's failure surfaces differently (build vs. deploy vs. post-deploy)

## Module 8: Troubleshooting + Course Wrap-up (30 min)

- Systematic diagnosis: which stage failed → which layer to inspect
- AWS CloudTrail and the AccessDenied / SCP-deny patterns
- OPA `FAIL` line anatomy and remediation flow
- Tag-policy + SCP-region error signatures
- Exception request workflow — when the guardrail is intentional but the use case is legitimate
- Course close: what you can now do; references to internal runbooks

---

## Lab 1: End-to-End EKS Deployment Pipeline (60 min)

Student clones an EKS app repo (Helm chart + buildspec), pushes a commit, watches the pipeline build, validate, and deploy to the training cluster. Verifies IRSA-injected env vars + LoadBalancer service.

## Lab 2: Lambda Deployment with SAM (45 min)

Student modifies a SAM template's `DeploymentPreference`, pushes a commit, watches alias-based canary traffic shifting in CloudWatch + the Lambda console.

## Lab 3: Policy-as-Code Evaluation & Failure Remediation (45 min)

Student pushes a Terraform plan with three deliberate OPA violations (bad name, missing tags, missing encryption resource), reads Conftest output, remediates each, and re-pushes.

## Lab 4: Aurora Blue/Green Deployment via Terraform + Pipeline (30 min) — NEW

Student modifies the `aws_rds_cluster` Terraform to opt the training Aurora cluster into a Blue/Green deployment (engine version bump or parameter-group change). Push → pipeline plan → OPA validation → approval → apply. Observes blue + green clusters in the RDS console and the switchover event in AWS CloudTrail.

---

## Changes from v2

| Change | Why |
|---|---|
| **Dropped Module 9** (Deployment Validation, Compliance Reporting) | Overlapping with Mod 8 — wrap-up folded into Mod 8 |
| **Dropped Lab 5** (Guardrail Troubleshooting capstone) | Labs 1-3 already exercise SCP/tag/OPA scenarios |
| **Renamed + reframed Mod 2** ("Anatomy of a Pipeline Run — Using S3") | Was an S3-features module; now a pipeline-mechanics walk-through using S3 as the example. Cut 30 → 15 min. |
| **Rewrote Module 5** as process-focused | Dropped Flyway/Liquibase tool deep-dive and Aurora Cloning; previews Lab 4 Blue/Green pattern. 45 → 20 min. |
| **Reworked Lab 4** as Aurora Blue/Green via Terraform | Old Lab 4 was Flyway-buildspec-focused; new Lab 4 hits the actual workflow (Terraform → pipeline → Aurora). 45 → 30 min. |
| **Added Service Catalog + Jenkins/CloudBees framing to Module 1** | Reflects actual SYF tech stack per customer-confirmed info 2026-05-12 |
| All module durations trimmed | Hit 6.5 hr content budget |

Old artifacts archived (no deletions):
- `content/narratives/_archive_v2_scope_cut/Module_9_narrative.md`
- `content/narratives/_archive_v2_scope_cut/Lab_4_narrative_Flyway_v1.md`
- `content/narratives/_archive_v2_scope_cut/Lab_5_narrative.md`
- `content/labs/_archive_v2_scope_cut/Lab_4_Guide_Flyway_v1.md`
- `content/labs/_archive_v2_scope_cut/Lab_5_Guide.md`
- `slide_json/_archive_v2_scope_cut/Module_9_slides.json`
