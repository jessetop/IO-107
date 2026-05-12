# IO-107 Knowledge Check Bank

## SDLC Pipeline & Deployment Guardrails

This bank consolidates every knowledge check question used in IO-107 v3. The course has **8 modules and 4 labs**; lab KCs are the only assessable knowledge checks in the current decks. Each question lists the prompt as it appears in the source lab, the expected answer, an explanation grounded in the relevant module narrative or slide content, and a difficulty marker.

Questions extracted from:
- `content/labs/Lab_1_Guide.md` (EKS Deployment Pipeline)
- `content/labs/Lab_2_Guide.md` (Lambda Deployment with SAM)
- `content/labs/Lab_3_Guide.md` (Policy-as-Code Evaluation & Failure Remediation)
- `content/labs/Lab_4_Guide.md` (Aurora Blue/Green Deployment via Terraform + Pipeline)

All lab questions are **short-answer / discussion-style** (the source labs were authored that way). Answer keys below are derived from the module narratives and slide decks explicitly cited in each question's `<!-- source: -->` comment.

> **Instructor note — coverage gap:** None of the 8 lecture decks (Modules 1-8) currently contain `knowledge_check` slides. The only knowledge checks in IO-107 are the post-lab ones below. If you want in-lecture comprehension checks (recommended for a one-day course of this density), see "Recommended Additions" at the end of this document.

---

## Module 1: Pipeline Architecture & Service Catalog

*(no knowledge check questions in the current Module 1 slide deck — see "Recommended Additions" at the end of this document)*

---

## Module 2: Anatomy of a Pipeline Run — Using S3

*(no knowledge check questions in the current Module 2 slide deck — see "Recommended Additions" at the end of this document)*

---

## Module 3: EKS Deployment via Pipelines

*(no in-lecture knowledge check questions — covered by Lab 1 KC below)*

---

## Module 4: Lambda Deployment via Pipelines

*(no in-lecture knowledge check questions — covered by Lab 2 KC below)*

---

## Module 5: Aurora Schema Migrations via Pipelines

*(no in-lecture knowledge check questions — covered by Lab 4 KC below)*

---

## Module 6: Policy-as-Code with OPA

*(no in-lecture knowledge check questions — covered by Lab 3 KC below)*

---

## Module 7: SCPs, Tagging, and AWS Config Rules

*(no in-lecture knowledge check questions — see "Recommended Additions" at the end of this document)*

---

## Module 8: Troubleshooting + Course Wrap-up

*(no in-lecture knowledge check questions — see "Recommended Additions" at the end of this document)*

---

# Lab Knowledge Checks

The four lab knowledge checks are short-answer / discussion questions. They are intentionally open-ended so the instructor can use them either as written exercises ("write your answer, then compare") or as group discussion prompts after each lab.

---

## Lab 1: End-to-End EKS Deployment Pipeline

**Format:** Short answer / discussion
**Source:** `content/labs/Lab_1_Guide.md` §Knowledge Check

### LQ1.1
**Question:** Why does the `buildspec.yml` pass the `--atomic` flag to `helm upgrade --install`, and what does Helm do when a deployment under `--atomic` fails to become healthy before `--timeout`?

**Answer:**
- `--atomic` guarantees the release is treated as all-or-nothing. If any resource in the chart fails to become healthy within `--timeout`, Helm automatically rolls the release back to its previous revision rather than leaving the cluster in a half-deployed state.
- This is mandatory in production pipelines because a failed deployment should automatically revert, not leave the cluster in a broken state requiring manual intervention.

**Source:** Module 3 narrative, §"Rollback Strategies" (`--atomic` is required in all production pipelines so failures revert automatically).
**Difficulty:** Intermediate

---

### LQ1.2
**Question:** A teammate proposes putting AWS access keys into a Kubernetes Secret and mounting it as environment variables on the pod, so the application can call S3. Citing what you saw in Task 7, give two specific reasons IRSA is preferred over that approach.

**Answer:** Any two of the following:
1. **No long-lived credentials on the pod.** IRSA uses a projected OIDC token that the AWS SDK exchanges for short-lived STS credentials at runtime — there are no static access keys to leak, commit to Git, or rotate.
2. **Pod-level scope, not node-level.** Each pod gets exactly the IAM role it needs. The old EC2-instance-profile approach gave every pod on the node the same broad permissions; static keys in a Secret would do the same if the Secret is shared.
3. **Tight conditional trust.** The IRSA trust policy ties the role to a specific OIDC provider, namespace, and ServiceAccount via `StringEquals` conditions, so a compromised pod elsewhere in the cluster cannot assume it. Static keys mounted as env vars have no such conditional binding.
4. **Auditable, automatically rotated.** STS issues fresh credentials on a short cadence; CloudTrail records each `AssumeRoleWithWebIdentity` call. Long-lived keys in Secrets have no equivalent rotation or audit signal.

**Source:** Module 3 narrative, §"The IRSA Problem" + §"How IRSA Works".
**Difficulty:** Intermediate

---

### LQ1.3
**Question:** In the IRSA trust policy that backs `myapp-dev-role`, what string under the `Condition` block ties the role to a specific namespace and ServiceAccount, and what would happen if that string were left as `*`?

**Answer:**
- The binding string is the `sub` claim in the OIDC condition:
  `"oidc.eks.<region>.amazonaws.com/id/<oidc-id>:sub": "system:serviceaccount:<namespace>:<service-account-name>"`
  (in the module example: `system:serviceaccount:myteam:myapp-sa`).
- Replacing the value with `*` (a wildcard) would mean *any* ServiceAccount in *any* namespace in the cluster could assume the role. That breaks the IRSA security model — a compromised pod in any other namespace, or any newly created ServiceAccount, would gain the role's permissions. The whole point of IRSA is that the trust policy is narrowly scoped to one namespace + one ServiceAccount.

**Source:** Module 3 narrative, §"IRSA in Pipelines" ("This is tight scoping. Even if someone compromises a different pod, they cannot assume this role because their token will not match the conditions.")
**Difficulty:** Advanced

---

### LQ1.4
**Question:** Walking from your `git push` to pods running in Amazon EKS, name the four AWS services that participated in the deployment, in order of involvement.

**Answer:**
1. **AWS CodePipeline** — picks up the commit from the source repo, orchestrates the stages (Source → Build → Validate → Approval (for stg/prd) → Deploy), and enforces the approval gate.
2. **AWS CodeBuild** — executes `buildspec.yml`: builds the Docker image, runs `helm upgrade --install`, and runs `kubectl rollout status` against the cluster.
3. **Amazon ECR** — receives the `docker push` for the new image and is then pulled from when the pods start.
4. **Amazon EKS** — the target cluster. The CodeBuild step authenticates via `aws eks update-kubeconfig`, the Helm release lands as Deployments / Services / ServiceAccount, and the pods pull the image from ECR using the IRSA-issued credentials.

**Source:** Module 1 narrative §"The Standard Pipeline Stages" + Module 3 narrative §"EKS Deployment Pipeline".
**Difficulty:** Basic

---

## Lab 2: Lambda Deployment with SAM

**Format:** Short answer / discussion
**Source:** `content/labs/Lab_2_Guide.md` §Knowledge Check

### LQ2.1
**Question:** In the SAM template you reviewed, the `AutoPublishAlias: live` property triggers two automatic behaviours on each deploy. What are they?

**Answer:**
1. **Publishing a new immutable version of the function.** Whenever the function code or configuration changes, SAM calls `PublishVersion`, producing a numbered, immutable snapshot (`:1`, `:2`, `:3`, …) — `$LATEST` is no longer relied on for production traffic.
2. **Updating the named alias (`live`) to point at the new version** in line with the `DeploymentPreference` (e.g. `Canary10Percent5Minutes`). Event sources (API Gateway, SQS, EventBridge) that target `<function>:live` therefore see the alias shift traffic gradually to the new version rather than instantly cutting over.

**Source:** Module 4 narrative, §"Traffic Shifting Configuration" ("`AutoPublishAlias` creates an alias and automatically updates it on deploy. The `DeploymentPreference` controls how traffic shifts to the new version.")
**Difficulty:** Intermediate

---

### LQ2.2
**Question:** Production Lambda deployments standardise on `Canary10Percent5Minutes`. Why is this preferred over `AllAtOnce`?

**Answer:**
- `Canary10Percent5Minutes` sends 10% of invocations to the new version for 5 minutes, then shifts 100%. During the 5-minute window, CloudWatch alarms (e.g. error rate, latency) can observe real production traffic on the new code while 90% of users are still served by the previous, known-good version.
- If the canary alarm breaches, AWS CodeDeploy (the engine SAM uses behind the scenes for traffic shifting) automatically rolls the alias back to the previous version — the bad code never sees more than 10% of traffic.
- `AllAtOnce` cuts 100% of traffic to the new version immediately; there is no observation window and no automatic rollback signal. A regression hits every user before any alarm can fire. `AllAtOnce` is reserved for dev environments or low-risk changes where the deployer is confident.

**Source:** Module 4 narrative, §"Traffic Shifting Types" ("Production deployments typically use Canary10Percent5Minutes or slower. We want time to detect issues.")
**Difficulty:** Intermediate

---

### LQ2.3
**Question:** What is the difference between `$LATEST` and a published Lambda version, and why should event sources reference an alias rather than `$LATEST`?

**Answer:**
- **`$LATEST`** is mutable. It always points at the most recently deployed function code/configuration and changes with every deployment. It has no version number of its own.
- **A published version** (e.g. `:5`) is an immutable snapshot of the function at publish time. Once `:5` exists, its code and configuration cannot be modified. Qualified ARNs (`…:function:MyFunc:5`) target that exact snapshot.
- **Event sources should target an alias** (e.g. `:live`), not `$LATEST`, because:
  - The alias gives you a stable indirection point. You can deploy and test new code (a new version) without changing what the alias resolves to.
  - The alias enables weighted traffic shifting — `$LATEST` cannot be split across versions.
  - Rollback is a single `update-alias` call to repoint at the previous version; there is no equivalent rollback for `$LATEST`.
  - Pointing event sources at `$LATEST` means every deployment immediately and atomically becomes production for every consumer, which is exactly the failure mode versioning is designed to avoid.

**Source:** Module 4 narrative, §"Lambda Versions and Aliases" + §"Deployment Caveats — What Bypasses Shifting" ("Event sources — API Gateway, SQS triggers, S3 triggers — should reference the alias, not $LATEST. That way, they're isolated from deployments until you explicitly update the alias.")
**Difficulty:** Intermediate

---

### LQ2.4
**Question:** During the canary window, the `ApiErrorAlarm` defined in the template breaches its threshold. What happens to the traffic weights on the `live` alias, and who performs the rollback?

**Answer:**
- The breach is detected by CloudWatch and surfaced to AWS CodeDeploy (the deployment engine SAM uses behind the scenes for traffic shifting).
- AWS CodeDeploy automatically reverts the alias: the `live` alias is repointed at the **previous** version and the new version's weight is set back to 0%. The canary is aborted; no further traffic shifts to the new version.
- **No human performs the rollback** — it is automated. The deployer's role is post-incident: investigate the alarm cause, fix the code, and redeploy. The alarm-driven rollback is the safety net, not the primary feedback channel.

**Source:** Module 4 narrative, §"Traffic Shifting Types" + Lab 2 narrative §"Section 2: Review the SAM Template" (CloudWatch alarms in the SAM template trigger automatic rollback during traffic shifting).
**Difficulty:** Advanced

---

### LQ2.5
**Question:** The standard is to use AWS SAM rather than raw CloudFormation for Lambda deployments. Name two SAM features that justify this choice.

**Answer:** Any two of the following:
1. **Simplified resource types for serverless.** `AWS::Serverless::Function`, `AWS::Serverless::Api`, and `AWS::Serverless::HttpApi` collapse what would otherwise be many CloudFormation resources (function + role + permissions + event source mappings + log groups) into a single, terser declaration.
2. **Built-in traffic shifting / safe-deploy primitives.** `AutoPublishAlias` and `DeploymentPreference` (with values like `Canary10Percent5Minutes`, `Linear10PercentEvery1Minute`) deliver canary and linear deployments declaratively. Doing this in raw CloudFormation requires hand-rolling AWS CodeDeploy resources.
3. **Local testing via `sam local`** — invoke functions, run APIs, and run the build container on a developer laptop before pushing to the pipeline. CloudFormation has no equivalent.
4. **`sam build` packaging.** SAM builds Python/Node/Java functions into deployment artifacts (including dependency installation in a Lambda-compatible container) with one command; raw CloudFormation requires you to produce the zip yourself.
5. **Transparent expansion to CloudFormation.** SAM templates are a superset — they expand to standard CloudFormation, so existing CloudFormation tooling, change sets, and stack drift detection still apply.

**Source:** Module 4 narrative, §"Serverless — Deployed via SAM".
**Difficulty:** Intermediate

---

## Lab 3: Policy-as-Code Evaluation & Failure Remediation

**Format:** Short answer / discussion
**Source:** `content/labs/Lab_3_Guide.md` §Knowledge Check

### LQ3.1
**Question:** The pipeline runs OPA against `tfplan.json`, not against `main.tf`. Why does the validation stage evaluate the Terraform *plan* in JSON form rather than the source `.tf` file directly?

**Answer:**
- `main.tf` is *source*, not the *intended outcome*. The same `.tf` file can produce different planned resources depending on variables, `tfvars`, workspace, module inputs, and state. OPA against `.tf` would have to re-implement Terraform's interpolation, variable resolution, and module expansion — and would still miss values that come from data sources or remote state.
- `terraform plan -out=tfplan` followed by `terraform show -json tfplan > tfplan.json` produces the *fully resolved* set of resource changes Terraform is about to apply — every attribute, every interpolated value, every computed default — in a stable JSON schema documented by HashiCorp.
- Evaluating the plan JSON means the policy sees exactly what AWS will see. Conftest/OPA can write rules like "every `aws_s3_bucket` in `resource_changes` must have encryption configured" against the actual planned state, without having to predict it.

**Source:** Module 6 narrative, §"Terraform Plan Evaluation" (`terraform plan -out=tfplan` → `terraform show -json` → `conftest test tfplan.json`).
**Difficulty:** Advanced

---

### LQ3.2
**Question:** Look at the Rego encryption rule shown in Module 6 (`deny[msg]` when an `aws_s3_bucket` resource has no `server_side_encryption_configuration`). Why does that rule still fire when the resource definition itself looks "fine" but encryption is configured via a separate `aws_s3_bucket_server_side_encryption_configuration` resource? How is the remediated lab code structured to make the policy pass?

**Answer:**
- The policy as written checks the `aws_s3_bucket` resource for an inline `server_side_encryption_configuration` block. The current AWS Terraform provider (v4+) deprecated the inline block and moved encryption to a **separate** resource type (`aws_s3_bucket_server_side_encryption_configuration`) referencing the bucket by ID. The bucket resource itself therefore no longer contains encryption configuration — the OPA rule, evaluated against just the `aws_s3_bucket` row in `tfplan.json`, sees no encryption and denies.
- In Lab 3 the remediation does not put encryption back inline. Instead:
  1. Keep encryption in its own resource: `aws_s3_bucket_server_side_encryption_configuration "this" { bucket = aws_s3_bucket.this.id; rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } } }`.
  2. Either (a) update the OPA rule to look across `resource_changes` for a matching `aws_s3_bucket_server_side_encryption_configuration` whose `bucket` attribute references the offending bucket's ID, or (b) (the standard convention) rely on the policy library's already-updated rule that does exactly that lookup. The Lab 3 remediated code adds the separate encryption resource and the bucket then passes the library's lookup-based rule.

**Source:** Module 6 narrative, §"Encryption Policies" + the Terraform AWS provider's `aws_s3_bucket_server_side_encryption_configuration` resource documentation.
**Difficulty:** Advanced

---

### LQ3.3
**Question:** A teammate is in a hurry and proposes "fixing" the Lambda timeout violation by editing the OPA policy to raise the maximum from 300 to 900 seconds, then committing both the timeout change and the policy change together. Based on what Module 6 taught about policy lifecycle, why is this not an acceptable remediation, and what is the correct path?

**Answer:**
- **Why it is wrong:**
  - Policies are owned by the platform / policy team, not by application teams. They live in a separate Git repository with their own pull-request review process.
  - The 300-second cap exists for a reason (organisational standard for Lambda timeout; longer-running workloads belong on a different compute platform). Raising the cap unilaterally bypasses that decision without engaging the people who set it.
  - Combining an application change with a policy change in the same commit defeats the entire shift-left model: policies are meant to *gate* application changes, not move in lockstep with whatever the application happens to need.
  - It also defeats audit. The compliance dashboard relies on policies being a stable, reviewed baseline; an inline policy edit makes "what was enforced when" unanswerable.
- **Correct path:**
  - If 300 seconds is genuinely the wrong number, open a pull request against the policy repository proposing the change with business justification. The policy team reviews and, if approved, the new value rolls out as a warning first, then enforced.
  - If the team has a *one-off* legitimate need for a longer timeout that does not justify changing the global policy, file an exception request through the exception workflow (covered in Module 8). Approved exceptions are time-boxed, scoped to one deployment, and audited.
  - Either way, the application PR stays focused on the application; policy changes go through the policy team.

**Source:** Module 6 narrative, §"Policy Versioning and Lifecycle" ("Policies are version-controlled just like code. Changes go through pull requests and review… Do not try to work around policies — that defeats the purpose.")
**Difficulty:** Intermediate

---

### LQ3.4
**Question:** Naming the three EKS-specific violations you remediated in Task 7, identify for each one which class of failure it would have caused in production if it had reached Amazon EKS without the OPA stage (for example: cost / blast-radius / supply-chain / operational).

**Answer:** The three EKS-specific violations from Lab 3 Task 7, classified per Module 6 §"EKS-Specific Policies":

1. **Missing `resources.limits` on the container (memory + CPU).**
   - **Class:** Cost + blast-radius + operational.
   - A pod with no limits can consume an entire node's memory/CPU, evict other pods (blast-radius), drive node autoscaling (cost), and trigger node-level OOM kills (operational instability).

2. **Disallowed container image registry (`docker.io/library/nginx:latest`).**
   - **Class:** Supply-chain (primary) + operational.
   - Public Docker Hub is outside the approved image supply chain — there is no vulnerability scan, no provenance, and the `latest` tag is mutable so two deployments can produce two different images with no audit trail. The standard requires images pinned by version and pulled from the approved Amazon ECR registry.

3. **Container running with no `runAsNonRoot` / privileged-style security context, or pod missing required `environment` / `owner` labels (the lab uses both, depending on which subset of the policy library is in scope).**
   - **Class:** Blast-radius (for the security-context case) or operational/compliance (for the labels case).
   - A pod running as root in a shared cluster magnifies the consequences of any container escape; missing ownership labels mean an incident responder cannot identify the owning team during a 2 AM page.

**Source:** Module 6 narrative, §"EKS-Specific Policies" (resource limits required; images must come from approved registries; security contexts and labels enforced).
**Difficulty:** Advanced

---

## Lab 4: Aurora Blue/Green Deployment via Terraform + Pipeline

**Format:** Short answer / discussion
**Source:** `content/labs/Lab_4_Guide.md` §Knowledge Check

### LQ4.1
**Question:** Why does the pipeline require a manual approval gate before `terraform apply` runs against the training Aurora cluster, when Lab 1's EKS pipeline targeting `dev` did not? Refer to what Module 5 said about the difference between application deployments and database changes.

**Answer:**
- **Statefulness.** Module 5 framed schema and engine-version changes as *stateful* — once data has moved through a new version, you cannot simply redeploy the previous version to undo it. Application deployments to `dev` (Lab 1) are stateless and reversible by re-running the pipeline; a database change is not.
- **Blast radius.** Aurora is a *shared* persistent data store. A botched application deploy affects one workload; a botched engine-version bump can affect every consumer of the cluster.
- **Approval gate is the standard for prod-tier resources.** Aurora is treated as prod-tier even in the training environment because it is shared and persistent. The approval gate adds a human review on top of the OPA validation — OPA enforces *compliance* (is this change well-formed and policy-compliant?); the approver provides *judgement* (is this the right time, on the right cluster, with the right risk acceptance?).
- The `dev` EKS pipeline in Lab 1 deliberately omits approval so students can iterate quickly. Module 1 and Lab 1 both flag that *staging and production EKS pipelines do require approval* — only `dev` does not.

**Source:** Module 5 narrative, §"Why Schema Changes Are Different" + Module 1 narrative §"The Approval Stage".
**Difficulty:** Intermediate

---

### LQ4.2
**Question:** You bump `engine_version` on an `aws_rds_cluster` resource and push, but you forget to add the `blue_green_update { enabled = true }` block. The apply still succeeds — what is the operational impact on the application connecting to the cluster, and why is the Blue/Green opt-in the standard for this kind of change?

**Answer:**
- **Operational impact without Blue/Green opt-in:** Terraform issues a `ModifyDBCluster` call that performs the engine upgrade *in place* on the existing cluster. Aurora's in-place engine upgrade requires the cluster to be temporarily unavailable while the engine binaries are swapped and the data files are migrated. For an Aurora PostgreSQL minor version bump that is typically a multi-minute downtime window; for a major bump it can be considerably longer. Every application connection drops; reads and writes both fail until the upgrade completes.
- **Why Blue/Green is the standard:** With `blue_green_update { enabled = true }`, Aurora provisions a *new* (green) cluster on the target engine version, replicates from blue, waits for replication lag to reach zero, and then atomically swaps the cluster endpoint. The application connecting to `training-aurora.cluster-xxxxx.us-east-1.rds.amazonaws.com` sees an essentially instantaneous cutover — no multi-minute downtime, no failed transactions. The cost is one extra cluster running for the duration of the deployment window (covered in Lab 4 §Cost Considerations); the benefit is zero-downtime upgrades on a shared persistent data store.
- This is the headline reason Module 5 named Aurora Blue/Green via Terraform as the standard pattern.

**Source:** Module 5 narrative, §"Aurora Blue/Green via Terraform — Lab 4 Preview" + AWS RDS Blue/Green Deployments documentation.
**Difficulty:** Intermediate

---

### LQ4.3
**Question:** Naming the three RDS API events you saw in CloudTrail (Task 8), which of them is the **auditable** record that the cluster's serving endpoint actually moved to the new engine version? Why is observing the other two not sufficient for compliance evidence?

**Answer:**
- **The auditable event is `SwitchoverBlueGreenDeployment`.** Its event record contains the source ARN (the blue cluster, on the old engine version) and the target ARN (the green cluster, now serving on the new engine version), along with the timestamp of the cluster-endpoint cut-over. This is the single point at which application traffic moved from the old engine to the new engine.
- **`CreateBlueGreenDeployment`** only records that the deployment record was *opened* — the green cluster is being provisioned. It does not establish that the switchover happened, or that the application is now running on the new version. A `CreateBlueGreenDeployment` event with no follow-up `SwitchoverBlueGreenDeployment` indicates the deployment was opened and then either timed out, was cancelled, or has not yet completed.
- **`ModifyDBCluster`** records the intent (the engine-version change) but is also emitted by *in-place* (non-Blue/Green) modifications. Reading only this event cannot tell an auditor whether the change went through the Blue/Green path or the in-place path, and cannot establish when (or if) the new engine actually became active.
- The compliance signal to rely on is therefore the `SwitchoverBlueGreenDeployment` event paired with the calling identity (matching the AWS CodeBuild execution role from the pipeline) and the timestamp — that triplet is what evidences "this engine bump was pipeline-driven and the cutover happened at this time".

**Source:** Module 5 narrative, §"Aurora Blue/Green via Terraform — Lab 4 Preview" + AWS CloudTrail Logging Amazon RDS API calls documentation.
**Difficulty:** Advanced

---

### LQ4.4
**Question:** A teammate proposes "speeding up the Lab 4 pattern in production" by removing the `blue_green_update` block and just letting Terraform do an in-place engine upgrade. Citing Module 5 directly, give two reasons that is unacceptable for a prod-tier Aurora cluster.

**Answer:** Any two of the following (Module 5 §"Aurora Blue/Green via Terraform"):
1. **Downtime.** An in-place engine upgrade takes the cluster offline for the duration of the binary swap and data migration — a multi-minute (minor) to multi-tens-of-minutes (major) outage window. For a shared, persistent data store backing application workloads, that is unacceptable; the Blue/Green pattern is the standard precisely *because* it eliminates this downtime.
2. **Reversibility.** During an in-place upgrade there is no green cluster to fall back to. If the new engine version introduces a regression that only surfaces under production load, the only path back is a restore-from-snapshot, which is hours not seconds. With Blue/Green, if the new version is wrong, you can detect it before switchover (the green cluster is observable while blue is still serving) — and the switchover itself is atomic, so traffic only moves once.
3. **Compliance/audit trail.** The `SwitchoverBlueGreenDeployment` CloudTrail event is the auditable record that the cutover happened at a specific time, driven by the pipeline. An in-place `ModifyDBCluster` does not produce that distinct event; the audit trail collapses to "Terraform did a thing".
4. **Replication-lag preconditions.** Aurora will not switch over until replication lag from blue to green has reached zero. That is a built-in safety check that an in-place upgrade does not have — the in-place path proceeds whether or not the application is in a state that can tolerate the swap.

**Source:** Module 5 narrative, §"Aurora Blue/Green via Terraform — Lab 4 Preview" + AWS RDS Blue/Green Deployments documentation.
**Difficulty:** Advanced

---

# Summary by Source

| Source | KC Question Count |
|---|---|
| Module 1 (slides) | 0 |
| Module 2 (slides) | 0 |
| Module 3 (slides) | 0 |
| Module 4 (slides) | 0 |
| Module 5 (slides) | 0 |
| Module 6 (slides) | 0 |
| Module 7 (slides) | 0 |
| Module 8 (slides) | 0 |
| Lab 1 — EKS Deployment | 4 |
| Lab 2 — Lambda SAM | 5 |
| Lab 3 — OPA Policy-as-Code | 4 |
| Lab 4 — Aurora Blue/Green via Terraform | 4 |
| **Total** | **17** |

---

# Recommended Additions (Instructor Action)

The current IO-107 v3 lecture decks contain no in-slide knowledge checks. For a one-day course of this density, the instructor (and any future slide-deck author) should consider adding one knowledge-check pair per module — at minimum on the modules that are *not* directly exercised in a lab:

- **Module 1 (Pipeline Architecture & Service Catalog):** suggested KC — "Name the orchestration tools in the pipeline and what each one does."
- **Module 2 (Anatomy of a Pipeline Run, Using S3):** suggested KC — "Trace a Terraform-to-S3 change through the standard stages and identify where the OPA validation happens."
- **Module 7 (SCPs, Tagging, and AWS Config Rules):** suggested KC — "Distinguish the error signatures of an SCP denial, an IAM denial, and a tag-policy violation."
- **Module 8 (Troubleshooting + Course Wrap-up):** suggested KC — "Given a pipeline failure at the Deploy stage with `explicit deny in a service control policy` in the log, name the next two artefacts to inspect and the appropriate remediation path."

Adding these would bring lecture coverage to parity with the lab coverage and give the instructor mid-module comprehension checkpoints. Do **not** invent these and slot them into the existing decks without instructor review — flag them on the pipeline checklist for the next deck-revision pass.

---

*Knowledge Check Bank v3.0 — IO-107 SDLC Pipeline & Deployment Guardrails. Matches `course_outline_v3.md` (8 modules + 4 labs). Last updated 2026-05-12.*
