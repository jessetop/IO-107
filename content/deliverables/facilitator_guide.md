# Facilitator Guide: IO-107 SDLC Pipeline & Deployment Guardrails

**Course Duration:** 1 day, **6.5 hr of content** (8 hr classroom day minus 1 hr lunch + 2 × 15 min breaks)
**Stream:** Stream 2 — AWS Intermediate Operations & Environment Deep Dive
**Audience:** Cloud / DevOps / application engineers and infrastructure operators
**Version:** 3.0 — matches `course_outline_v3.md` (8 modules + 4 labs; replaces v2 9-module / 5-lab build)

---

## Table of Contents

1. [Course Overview](#course-overview)
2. [Delivery Format and Pacing](#delivery-format-and-pacing)
3. [Pre-Course Preparation Checklist](#pre-course-preparation-checklist)
4. [Module-by-Module Delivery Notes](#module-by-module-delivery-notes)
5. [Lab Facilitation Guide](#lab-facilitation-guide)
6. [Time-Management Contingencies](#time-management-contingencies)
7. [Common Cross-Course Questions](#common-cross-course-questions)
8. [Post-Class Follow-Up](#post-class-follow-up)

---

## Course Overview

This is the deployment-and-guardrails day. Students arrive having completed IO-106 (AWS account structure, networking, Service Catalog basics) and leave knowing how the pipelines move a Terraform change from a Git commit to a deployed workload — and equally important, how to read the failures that the guardrails produce.

v3 of the course is deliberately **process-focused, not tool-internals-focused**. Students do not learn to administer Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy, or AWS Service Catalog. They learn what each of those things does in the end-to-end flow, what artifacts arrive at each pipeline stage, and what the failure signatures look like at the OPA / SCP / tag-policy / IAM layers.

The dominant teaching theme is **"Terraform from a Service Catalog product, committed to Git, executed by the pipeline."** Module 1 frames it. Module 2 walks the entire flow end-to-end using S3 as the example so the mechanics are visible before any deep-dive. Modules 3-5 then layer on the three deployment targets that matter: Amazon EKS (Module 3 + Lab 1), AWS Lambda (Module 4 + Lab 2), and Aurora Blue/Green via Terraform (Module 5 + Lab 4). Modules 6-8 cover the guardrail layers — OPA, SCPs, tag policies, AWS Config — and the troubleshooting flow that ties them together.

### What the day buys the student

- Confidence reading a pipeline failure and deciding whether it is OPA, SCP, tag policy, or IAM before paging anyone.
- Working knowledge of the three deployment primitives: Helm `--atomic`, SAM `AutoPublishAlias` with canary, and Aurora `blue_green_update` via Terraform.
- An understanding of IRSA that goes deeper than "annotate a service account" — they should be able to read the trust policy and find the namespace/SA condition.
- The exception-request workflow, in their hands and rehearsed in Module 8.

---

## Delivery Format and Pacing

The outline allocates **210 min of module content + 180 min of labs = 390 min = 6.5 hr** against an 8 hr classroom day with lunch and two breaks. This fits.

### Suggested 1-day schedule

| Time | Block | Duration |
|------|-------|----------|
| 09:00 – 09:30 | Module 1 — Pipeline Architecture & Service Catalog | 30 min |
| 09:30 – 09:45 | Module 2 — Anatomy of a Pipeline Run (Using S3) | 15 min |
| 09:45 – 10:25 | Module 3 — EKS Deployment via Pipelines | 40 min |
| 10:25 – 10:40 | Break | 15 min |
| 10:40 – 11:40 | Lab 1 — End-to-End EKS Deployment Pipeline | 60 min |
| 11:40 – 12:00 | Module 4 — Lambda Deployment via Pipelines | 20 min |
| 12:00 – 13:00 | Lunch | 60 min |
| 13:00 – 13:45 | Lab 2 — Lambda Deployment with SAM | 45 min |
| 13:45 – 14:05 | Module 5 — Aurora Schema Migrations via Pipelines | 20 min |
| 14:05 – 14:35 | Module 6 — Policy-as-Code with OPA | 30 min |
| 14:35 – 15:20 | Lab 3 — Policy-as-Code Evaluation & Failure Remediation | 45 min |
| 15:20 – 15:35 | Break | 15 min |
| 15:35 – 16:00 | Module 7 — SCPs, Tagging, and AWS Config Rules | 25 min |
| 16:00 – 16:30 | Lab 4 — Aurora Blue/Green Deployment via Terraform + Pipeline | 30 min |
| 16:30 – 17:00 | Module 8 — Troubleshooting + Course Wrap-up | 30 min |

Total: 390 min content + 60 min lunch + 30 min breaks = 480 min (8 hr).

If a single block overruns, the timing reserve lives in the breaks and in Module 8 (the wrap-up will compress to ~20 min if necessary — the systematic-diagnosis framework is the load-bearing content; the exception-request walkthrough can be deferred to a Q&A handout).

---

## Pre-Course Preparation Checklist

Run this checklist 48 hours before delivery, then again the morning of class.

### AWS environment (per student)

- [ ] Training AWS account assigned to each student with the standard sandbox SCPs attached (region restrictions on; us-east-1 only).
- [ ] AWS Console SSO link confirmed working from the student's laptop or Citrix VDI.
- [ ] AWS CloudShell or Cloud9 session reachable — students should not be relying on a local CLI alone.
- [ ] The shared AWS CodePipeline + AWS CodeBuild project for IO-107 labs is healthy in the shared tools account, source actions wired to the four lab repos.
- [ ] Shared training Amazon EKS cluster reachable; `kubectl` config can be regenerated with `aws eks update-kubeconfig --name <cluster> --region us-east-1`.
- [ ] AWS Load Balancer Controller installed on the training cluster and service-subnet tagging confirmed (Lab 1 fails silently without it).
- [ ] Shared training Aurora cluster (`training-aurora`) provisioned and `available`, on the engine version Lab 4's starting state expects (default Lab 4 starting state is Aurora PostgreSQL 15.4 → bump to 15.5). Confirm with platform team whether the approved-version pin in the OPA policy has moved before class.
- [ ] Secrets Manager secrets `training-aurora/host`, `training-aurora/username`, `training-aurora/password` exist and the CodeBuild role can read all three (Module 5 references the pattern; the pipeline that triggers Lab 4's `terraform apply` needs to authenticate against the RDS API via its execution role — secret reads happen if the lab repo includes a post-deploy validation step).
- [ ] Amazon ECR registry hostname for the training environment confirmed — write the exact `{accountID}.dkr.ecr.us-east-1.amazonaws.com/` prefix on the whiteboard before Lab 1.
- [ ] AWS Organizations SCPs include a region-restriction SCP (denies non-us-east-1) and a tag policy enforcing `Environment` allowed values `dev | stg | prd`. Module 7 references both; Lab 3 exercises the tag policy via OPA.

### Repos and code

- [ ] All four lab repos cloned somewhere reachable; URLs written on the whiteboard at start of class (every lab guide says "instructor will provide on the whiteboard").
- [ ] Each repo's `buildspec.yml` opened and skimmed end-to-end — you will be asked to explain each phase.
- [ ] OPA / Conftest policies installed in the Validate stage and tested against the Lab 3 violation set — the lab expects the Conftest output to enumerate the planted failures with FAIL lines.
- [ ] At least one **successful** pipeline run captured in your browser history so you can show it side-by-side with a failure (Module 1 demo).

### Instructor demo materials

- [ ] Demo pipeline ready for Module 1 — a recent successful execution that shows all standard stages green, plus one recent failure showing red. Both should be reachable from the demo account.
- [ ] S3-via-pipeline demo open for Module 2 — pull up a recent S3 pipeline run that shows commit → build (`terraform plan`) → OPA validate → approval → apply, so the slide-deck flow has a concrete on-screen anchor.
- [ ] Sample Helm chart pre-deployed and `helm history myapp` showing at least 3 revisions for Module 3's rollback discussion.
- [ ] SAM application with `AutoPublishAlias` and `Canary10Percent5Minutes` configured and ready to deploy live (Module 4 demo) — students need to see alias weights actually moving in the console.
- [ ] An Aurora Blue/Green deployment record visible in the RDS console (recent or archived) so Module 5 can show what students will see in Lab 4.
- [ ] OPA policy file open in a second tab — when a student asks "what does the policy actually look like?" you need to show it within 10 seconds.

### Slides and PDFs

- [ ] All 8 module slide decks loaded in browser tabs (Google Slides, IO-107 folder `1RHTmkxdyWQMi3WVp8bJGKmmuFkv0mciy`).
- [ ] All 4 Lab Guide PDFs printed or shared link sent to students at start of day.
- [ ] Student reference sheet PDF and pre-course assessment PDF distributed at start of class (the reference sheet is the thing students will actually look at during labs).

---

## Module-by-Module Delivery Notes

### Module 1 — Pipeline Architecture & Service Catalog (30 min)

**Goal:** Frame the CI/CD model. Tool mix on the orchestration side: **Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy** — what each does. No deep-dive on any of them.

**Headline message:** *"You don't deploy from a console. A Terraform change from an approved Service Catalog product is committed to Git, the pipeline picks it up, and AWS sees the change. Service Catalog is what makes the Terraform you commit pre-approved."*

**Pacing:**
- 4 min — Why pipeline-driven (audit trail, consistency, approval gates, compliance)
- 6 min — The Service Catalog → Terraform → Git → pipeline → AWS flow
- 8 min — Tool mix: Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy — one slide each, role in the flow, *not* an admin tutorial
- 6 min — Pipeline stages at a glance (build, OPA, approval, deploy)
- 4 min — Deployment targets: EKS, Lambda, Aurora — and the EC2-during-migration acknowledgement
- 2 min — Wrap and bridge to Module 2

**Likely questions:**
- *"Do we use Jenkins or CodePipeline?"* — Both, depending on the team and the workload. The pipeline pattern is the same regardless. Don't pick a winner in class.
- *"Can I write Terraform that isn't from a Service Catalog product?"* — Not for the core deployment path. The Service Catalog product *is* what makes the Terraform pre-approved. If a team needs a resource type that isn't covered, the path is "ask platform to add it to the catalog" — not "write your own Terraform around the catalog".
- *"What about EC2?"* — Acknowledge once: EC2 is still in use during migration. Cloud-native (containers, serverless) is the target. Don't dwell.

### Module 2 — Anatomy of a Pipeline Run, Using S3 (15 min)

**Goal:** Walk one end-to-end pipeline run so the mechanics are visible *before* any deep-dive module. S3 is the example because everyone already knows S3 — their brain isn't busy learning an AWS service while they're learning pipeline mechanics.

**This is not an S3-features module.** It is a pipeline-mechanics module that uses S3 as the resource. Resist student requests to deep-dive S3 here; defer to "the S3 Service Catalog product gives you the defaults — TLS-only, encryption-required — by default."

**Pacing:**
- 1 min — Opening (why we use S3 as the example)
- 6 min — The walk-through: commit → build → OPA → approval → deploy, what gets produced at each stage
- 3 min — What CodeBuild does, what gets passed as an artifact, how to read the log
- 3 min — Naming convention + mandatory tag enforcement (preview of Modules 6/7)
- 2 min — Bridge to Module 3 (now we do the same flow with EKS as the target)

### Module 3 — EKS Deployment via Pipelines (40 min)

**Goal:** Helm `upgrade --install --atomic`, `kubectl apply` and Kustomize as the alternative, **IRSA** as the pod-to-AWS auth pattern, Fargate vs EC2-backed node trade-offs, reading rollout status from the pipeline log.

**Pacing:**
- 2 min — Module open, bridge from Module 2's pipeline flow
- 10 min — Helm in CodeBuild: `helm upgrade --install --atomic`, `values-{env}.yaml`, what `--atomic` does on failure
- 8 min — `kubectl apply` + Kustomize as the alternative; when teams choose it
- 12 min — IRSA: the problem (no static keys), how it works (OIDC + trust policy condition on `system:serviceaccount:<ns>:<sa>`), what the `eks.amazonaws.com/role-arn` annotation does
- 5 min — Fargate vs EC2-backed nodes
- 3 min — Reading deployment validation and rollout status from CodeBuild logs

**Likely questions:**
- *"Why not use an EC2 instance profile?"* — Pod-level scope vs node-level scope. One instance profile = every pod on the node gets the same role. Lab 1's KC question 2 covers this.
- *"Does IRSA work on Fargate?"* — Yes. Fargate pods are launched into the cluster with the same OIDC provider integration.

### Module 4 — Lambda Deployment via Pipelines (20 min)

**Goal:** SAM template basics, Lambda versioning + alias model, **alias-based traffic shifting** (canary / linear), CloudWatch alarms as the auto-rollback trigger, and the **caveats** that bypass traffic shifting (`:$LATEST`, unqualified ARNs).

**Pacing:**
- 1 min — Open, bridge from Module 3
- 5 min — SAM template basics, what's pipeline-deployed
- 5 min — Versions and aliases (`$LATEST` mutable, `:N` immutable, aliases are stable pointers)
- 6 min — Traffic shifting: `Canary10Percent5Minutes`, `Linear10PercentEvery1Minute`, alarms as the rollback signal
- 3 min — Caveats: `:$LATEST` and unqualified ARNs bypass shifting; event sources must point at the alias

**Likely question:**
- *"Why standardise on `Canary10Percent5Minutes`?"* — Real-traffic observation window before full cutover. Lab 2 KC2 answer is the long form.

### Module 5 — Aurora Schema Migrations via Pipelines (20 min)

**Goal:** Pipeline-driven database changes; the **Aurora Blue/Green via Terraform** pattern Lab 4 exercises. Process-focused — tool internals are deliberately light. **Do not turn this into a Flyway tutorial.** Flyway is mentioned (it is what runs in the CodeBuild step for non-schema-bump SQL migrations), but the slide deck spends most of its time on the Blue/Green Terraform pattern.

**Pacing:**
- 2 min — Open, bridge from Module 4 (Lambda was stateless; data tier is stateful)
- 4 min — Why schema changes are different (stateful; rollbacks are hard; pipeline-driven not console-driven)
- 4 min — How it's handled: Terraform changes drive the pipeline; SQL migrations applied by CodeBuild; secrets via Secrets Manager
- 7 min — **Aurora Blue/Green via Terraform** — what `blue_green_update { enabled = true }` does, what triggers a Blue/Green path (`engine_version`, parameter group, instance class), what doesn't (tag edits, backup window), why this is Lab 4's target pattern
- 2 min — No direct database access policy + bridge to Module 6

**v3 reframing note for instructors who taught v2:** v2 spent ~20 min on Flyway commands, undo migrations, `flyway_schema_history`, and Aurora Cloning. v3 cut all of that. If a student asks about Flyway internals, the right answer is "we use Flyway as the SQL applier in CodeBuild; the lab pattern is Terraform-driven, not Flyway-command-driven." Aurora Cloning is **not** in v3 — do not bring it up.

### Module 6 — Policy-as-Code with OPA (30 min)

**Goal:** What OPA does in the pipeline (validates `tfplan.json`), reading Conftest output, the policy categories (naming, encryption, tagging, EKS pod-security, Lambda), writing a simple Rego rule.

**Pacing:**
- 2 min — Open
- 6 min — What OPA does, Terraform plan evaluation flow (`terraform plan -out=tfplan` → `terraform show -json` → `conftest test`)
- 8 min — Policy categories at a glance, with one Rego example
- 8 min — Reading Conftest output: PASS, FAIL, and the metadata; what each FAIL line tells you
- 6 min — Policy lifecycle (policies live in their own repo, reviewed by platform/security; do not work around)

Lab 3 immediately exercises this — don't over-rehearse the FAIL-reading skill in the module; let the lab do it.

### Module 7 — SCPs, Tagging, and AWS Config Rules (25 min)

**Goal:** SCPs as the AWS Organizations layer (region/service/root denials); the mandatory tags + tag policy enforcement; AWS Config rules as the *deployed-but-non-compliant* detective layer. How each layer's failure surfaces differently — **build** (OPA), **deploy** (SCP, IAM), or **post-deploy** (Config).

**Pacing:**
- 2 min — Open, bridge from Module 6 (OPA prevents; SCP denies; Config detects)
- 8 min — SCPs: region restrictions, service denials, the `explicit deny in a service control policy` error signature
- 8 min — Tagging: mandatory tags, AWS Organizations tag policies, allowed-values enforcement
- 7 min — AWS Config rules: continuous compliance, drift detection, remediation actions

### Module 8 — Troubleshooting + Course Wrap-up (30 min)

**Goal:** Systematic diagnosis (which stage failed → which layer); CloudTrail and the AccessDenied / SCP-deny patterns; OPA `FAIL` line anatomy; tag-policy + SCP-region signatures; **exception request workflow**; course close.

This module **absorbs the wrap-up content that used to live in v2 Module 9** (deployment validation, compliance reporting). Keep the wrap-up tight; the load-bearing content is the systematic-diagnosis framework.

**Pacing:**
- 2 min — Open
- 6 min — Systematic diagnosis framework: stage → layer → log to read first
- 6 min — CloudTrail walk: AccessDenied patterns, SCP vs IAM distinguishing language
- 6 min — OPA FAIL anatomy + tag-policy / SCP-region signatures
- 6 min — Exception request workflow: when, what to include, what is *not* an exception (e.g. "raise the OPA policy limit")
- 4 min — Course close: what students can now do, references to internal runbooks, thank-you

---

## Lab Facilitation Guide

### Lab 1 — End-to-End EKS Deployment Pipeline (60 min)

**Where it lands:** Right after Module 3.

**What students do:** Clone an EKS app repo, modify `values-dev.yaml` or push a no-op commit, watch AWS CodePipeline build the image, push to Amazon ECR, run OPA validate, deploy via Helm, and verify pods + LoadBalancer + IRSA-injected env vars.

**Common stumbling points:**
- `kubectl exec ... aws s3 ls` returns "Unable to locate credentials" → the pod was started before the IRSA annotation was applied. `kubectl delete pod $POD_NAME` so the Deployment recreates it with env vars injected.
- LoadBalancer service stuck on `<pending>` for >2 min → the AWS Load Balancer Controller subnet-tag prereq is missing. Check pre-class setup.
- `helm upgrade` fails and Helm rolls back automatically (this is `--atomic` working). Talk through the rollback in real time — it's a teaching moment.

**Time check:** If the room is consistently >70 min in, abandon the IRSA `aws s3 ls` verification step and defer to lab guide self-reading. The Knowledge Check is the assessable part.

### Lab 2 — Lambda Deployment with SAM (45 min)

**Where it lands:** Right after Module 4 (with lunch between them in the suggested schedule).

**What students do:** Modify `DeploymentPreference` in a SAM template, push, watch the pipeline build with SAM, deploy with alias-based traffic shifting, and observe the alias weights move in the Lambda console.

**Common stumbling points:**
- Students try to invoke `$LATEST` directly and don't see canary behaviour → the lab uses the alias-backed API Gateway endpoint. Reinforce that aliases are the stable indirection point.
- CloudWatch alarm doesn't fire fast enough to demonstrate rollback live → that's expected; the alarm is the *safety net*, not the primary feedback. Show a recent rollback from your demo history instead.

### Lab 3 — Policy-as-Code Evaluation & Failure Remediation (45 min)

**Where it lands:** Right after Module 6.

**What students do:** Push a Terraform plan that has been seeded with deliberate OPA violations (bad name, missing tags, missing encryption resource, Lambda timeout over the cap, EKS container missing resource limits, disallowed image registry). Read Conftest output, remediate each, push again, watch the pipeline go green.

**Common stumbling points:**
- Students try to "fix" the Lambda timeout violation by editing the OPA policy file in the lab repo → that file is not the policy source of truth in the pipeline. The right answer is to lower the timeout to within the policy cap. KC3 covers this.
- Tag key case-sensitivity (`environment` vs `Environment`) — students miss it on first read.

### Lab 4 — Aurora Blue/Green Deployment via Terraform + Pipeline (30 min) — **NEW in v3**

**Where it lands:** Right after Module 7, before Module 8.

**What students do:** Edit `terraform/aurora_cluster.tf` in the lab repo to (a) bump `engine_version` (default: 15.4 → 15.5; confirm with platform-team approved-version pin), (b) add `blue_green_update { enabled = true }`. Push. Pipeline runs `terraform plan`, OPA validates (may flag the version if the OPA approved-version list hasn't been updated — talk students through that as Lab-3-style remediation), approval gate triggers because Aurora is prod-tier. Approve. `terraform apply` runs; AWS RDS provisions the green cluster, replicates, and switches over. Students see blue + green in the RDS console and `CreateBlueGreenDeployment` / `ModifyDBCluster` / `SwitchoverBlueGreenDeployment` events in AWS CloudTrail.

**Common stumbling points:**
- Real Aurora Blue/Green takes 5-15 min end-to-end. The lab guide flags this. If class time is tight, demonstrate the switchover event separately rather than waiting for every student's apply to finish — the plan + approval portion is the assessable part.
- Students edit attributes that force-replace the cluster (e.g. `cluster_identifier`, `engine`) by accident → the plan will say `forces replacement`. Catch this in their `terraform plan` output and have them reset from `origin/main`.
- OPA may deny the target engine version if the approved-version list pins to a different patch. Treat as a Lab-3-style remediation: ask platform team / instructor what the current approved version is, use that.
- Do **not** allow students to remove the `blue_green_update` block to "just upgrade in place". That defeats the entire point of the lab and is what Module 5 + Lab 4 Knowledge Check 4 explicitly warn against.

**Why this lab matters more than its 30 min suggests:** It is the only place in IO-107 where students see the AWS data-tier deployment pattern. EKS (Lab 1) and Lambda (Lab 2) are stateless. Aurora Blue/Green is the pattern that enables zero-downtime engine upgrades on persistent data — and the pipeline + approval gate is what makes it auditable.

---

## Time-Management Contingencies

| Scenario | Mitigation |
|----------|-----------|
| Lab 1 runs 15 min long | Cut Module 4's serverless framing from 5 → 2 min; the SAM template walkthrough still lands. |
| OPA isn't installed correctly on the Validate stage and Lab 3 can't run live | Walk Lab 3 as a demo using your pre-captured CodeBuild logs; assign the remediation steps as post-class homework. |
| Aurora Blue/Green switchover takes longer than 15 min | Move to Module 8 wrap-up while applies finish; revisit RDS console + CloudTrail at the end of class to close the loop. |
| Module 8 is at risk of being skipped | Compress to the systematic-diagnosis framework + exception-request workflow (12-15 min minimum); defer CloudTrail walk to a handout. |
| Multiple students lock out of training account at start of day | Move Module 1 + 2 lecture forward; reset accounts during the break before Lab 1. |

---

## Common Cross-Course Questions

- *"Why aren't we covering DynamoDB?"* — Approved-services list. Aurora and RDS are the data-tier defaults.
- *"Why aren't we covering ECS?"* — The standard is EKS. ECS is out of scope across the entire stream.
- *"What about Function URLs?"* — Not in scope for this course. Lambda deployments are exercised via SAM + alias + API Gateway as the public entrypoint.
- *"What about Lambda Layers?"* — Briefly: layers are a packaging tool, mentioned in passing in Module 4 if a student raises it; not a teaching focus.
- *"Can I just use Aurora Cloning to test my migration?"* — Aurora Cloning is not in v3 of this course. The pattern Lab 4 exercises is Blue/Green via Terraform — the standard for production engine bumps.
- *"Where does AWS CodeDeploy fit?"* — CodeDeploy is the engine that performs Lambda alias traffic shifting under the SAM `DeploymentPreference`. Students don't administer it. Module 4 mentions it; the rest is invisible plumbing.

---

## Post-Class Follow-Up

- Send the **Student Reference Sheet PDF** + the **Knowledge Check Bank PDF** to all attendees within 24 hr.
- Share the **Google Slides links** (read-only) for the 8 module decks.
- Send the **Lab 4 instructor demo recording** (if captured) — the Blue/Green switchover is rarely fast enough to fully observe live, and the recording is the artefact students will reference if they have to do this for real.
- Offer a 30-min Q&A office hour 1-2 weeks post-class — by then, students will have tried to push a real change through the pipeline and the SCP / OPA questions will be sharper.
- Capture every "this OPA policy denied my legitimate use case" report and route it to the platform / policy team. The pipeline is only as useful as the policy library is current.

---

*Facilitator Guide v3.0 — IO-107 SDLC Pipeline & Deployment Guardrails. Matches `course_outline_v3.md` (8 modules + 4 labs; 6.5 hr content). Last updated 2026-05-11.*
