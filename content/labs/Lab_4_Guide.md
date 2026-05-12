# Lab 4: Aurora Blue/Green Deployment via Terraform + Pipeline

| | |
|---|---|
| **Course** | IO-107 SDLC Pipeline & Deployment Guardrails |
| **Module** | Module 5 — Database Schema Migrations |
| **Duration** | 30 minutes |
| **Difficulty** | Intermediate |
| **Prerequisites** | Modules 1–5 completed; Labs 1–3 completed (familiarity with AWS CodePipeline, AWS CodeBuild, OPA validation stage, and reading CodeBuild logs); access to the training AWS account, Terraform CLI, and the training Amazon Aurora cluster; `git` and AWS CLI configured locally |
| **Builds On** | Lab 1 (shared AWS CodePipeline, AWS CodeBuild project, IAM execution roles, S3 artifact bucket); Lab 3 (OPA validation stage and Terraform-plan evaluation pattern). The Amazon Aurora training cluster (`training-aurora`) is pre-provisioned by the platform team — you modify it via Terraform; you do **not** create it. |

---

## Learning Objectives

By the end of this lab, you will:

- Modify the `aws_rds_cluster` Terraform for the training Amazon Aurora cluster to opt the change into an Aurora Blue/Green deployment via the `blue_green_update` block. <!-- source: course_outline_v3.md Lab 4 + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->
- Push the change and observe AWS CodePipeline run `terraform plan`, OPA policy validation, the manual approval gate (because the change targets a prod-tier resource), and `terraform apply`. <!-- source: course_outline_v3.md Lab 4 + Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" -->
- Locate the blue (current) and green (new) clusters in the Amazon RDS console during the deployment window, and read the `ModifyDBCluster` / `SwitchoverBlueGreenDeployment` events in AWS CloudTrail. <!-- source: course_outline_v3.md Lab 4 + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->
- Recognise which Terraform parameter changes trigger a Blue/Green path (engine version, parameter group, instance class) versus which do not (small attribute changes), and identify the replication-lag preconditions that gate switchover. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

> **Note:** A real Aurora Blue/Green switchover typically takes 5–15 minutes end-to-end (green provisioning + replication catch-up + switchover window). If class time is tight, your instructor may demonstrate the switchover event separately rather than waiting for every student's apply to finish — the Terraform plan + approval portion of the lab is the assessable part. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

---

## Task 1: Pre-flight Checks

1. **Open** your terminal (or the lab environment's Cloud9 / CloudShell session, whichever your environment provides).

2. **Confirm** AWS CLI access to the training account and confirm the training Aurora cluster exists:

    ```bash
    aws sts get-caller-identity
    aws rds describe-db-clusters \
        --db-cluster-identifier training-aurora \
        --query 'DBClusters[0].[DBClusterIdentifier,Status,Engine,EngineVersion]' \
        --output table
    ```
    <!-- source: https://docs.aws.amazon.com/cli/latest/reference/rds/describe-db-clusters.html -->

    **Expected Result:** `aws sts get-caller-identity` returns the lab IAM identity, and `describe-db-clusters` returns one row showing `training-aurora`, `available`, an Aurora engine name (e.g. `aurora-postgresql`), and the current engine version. If `describe-db-clusters` returns an empty list or a `DBClusterNotFoundFault`, **stop** — confirm with your instructor that the training cluster is provisioned in the account/region you are signed in to.

3. **Confirm** the AWS CodePipeline + AWS CodeBuild execution role used in Labs 1–3 is still attached to the pipeline. From the previous labs you already know the pipeline exists; this step just verifies it is in a state where it can run a Terraform plan and apply against the RDS account:

    ```bash
    aws codepipeline list-pipelines --output table
    ```
    <!-- source: https://docs.aws.amazon.com/cli/latest/reference/codepipeline/list-pipelines.html -->

    **Expected Result:** The pipeline you used in Labs 1–3 appears in the list. Your instructor will confirm the exact pipeline name on the lab whiteboard — it is the same pipeline; only the source repo and target resource change for this lab.

> **Note:** The training Aurora cluster, its DB subnet group, its parameter group, and its KMS key are all owned by the platform team and are pre-provisioned. You modify the cluster via Terraform in this lab — you do not create or destroy it. This is the same pattern Lab 1 used for the EKS cluster and Lab 3 used for the CodePipeline / CodeBuild project. <!-- source: Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" -->

---

## Task 2: Clone the Aurora Terraform Repository

4. **Clone** the lab repository. Your instructor will provide the actual URL on the lab whiteboard — paste it into the command below:

    ```bash
    git clone https://github.com/[client-org]/[repo-name].git io107-lab4-aurora-bluegreen
    ```
    <!-- TODO: replace with real repo URL before delivery -->
    <!-- source: course_outline_v3.md Lab 4 -->

5. **Change directory** into the repo and list the top level:

    ```bash
    cd io107-lab4-aurora-bluegreen
    ls -la
    ```
    <!-- source: course_outline_v3.md Lab 4 -->

    Expected structure:

    ```
    io107-lab4-aurora-bluegreen/
    ├── terraform/
    │   ├── aurora_cluster.tf   # aws_rds_cluster + instances for training-aurora
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── providers.tf
    ├── buildspec.yml           # plan / validate / apply phases
    └── README.md
    ```
    <!-- source: course_outline_v3.md Lab 4 -->

6. **Open** `terraform/aurora_cluster.tf` and `buildspec.yml` in your editor. You will edit `aurora_cluster.tf` in Task 3 and only read `buildspec.yml`.

---

## Task 3: Inspect the Existing `aws_rds_cluster` Definition

7. **Read** the `aws_rds_cluster` block in `terraform/aurora_cluster.tf`. The starting state describes the training cluster as it exists today — Aurora PostgreSQL on a specific engine version, with the standard tags, encryption, and backup settings:

    ```hcl
    resource "aws_rds_cluster" "training" {
      cluster_identifier      = "training-aurora"
      engine                  = "aurora-postgresql"
      engine_version          = "15.4"
      database_name           = "training"
      master_username         = "training_admin"
      manage_master_user_password = true

      db_subnet_group_name    = data.aws_db_subnet_group.training.name
      vpc_security_group_ids  = [data.aws_security_group.training_db.id]

      db_cluster_parameter_group_name = "training-aurora-pg15-default"

      storage_encrypted       = true
      kms_key_id              = data.aws_kms_key.training_rds.arn

      backup_retention_period = 7
      preferred_backup_window = "03:00-04:00"

      skip_final_snapshot     = false
      final_snapshot_identifier = "training-aurora-final"

      tags = {
        Environment = "training"
        Application = "io107-lab"
        Owner       = "platform-team@client.com"
        CostCenter  = "CC-TRAINING"
        DataClass   = "internal"
      }
    }
    ```
    <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster -->

8. **Identify** which kinds of changes to this resource would trigger an Aurora Blue/Green path versus which would not. Module 5 named the Blue/Green-relevant change classes; the Terraform provider exposes them as the same attributes:

    - **Triggers Blue/Green** (when `blue_green_update.enabled = true` is set): `engine_version` bump (minor or major), `db_cluster_parameter_group_name` change, instance class change on the cluster instances. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->
    - **Does NOT trigger Blue/Green:** tag-only edits, `backup_retention_period`, `preferred_backup_window`, `deletion_protection` — these are applied in place against the existing cluster. <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster -->

> **Note:** Changing `engine_version` against an `aws_rds_cluster` **without** opting into `blue_green_update` is the path that historically caused multi-minute downtime windows. The Blue/Green opt-in is what makes the upgrade zero-downtime for the application connecting to the cluster endpoint — Module 5 made this the headline reason for adopting Aurora Blue/Green. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" -->

---

## Task 4: Add the `blue_green_update` Block and Bump the Engine Version

9. **Edit** `terraform/aurora_cluster.tf`. Make two changes to the `aws_rds_cluster.training` resource:

    1. Bump `engine_version` from `"15.4"` to `"15.5"` (your instructor will confirm the exact target version on the whiteboard if a different patch level is current at delivery time).
    2. Add a `blue_green_update` block with `enabled = true`.

    The relevant lines after your edit should look like this:

    ```hcl
    resource "aws_rds_cluster" "training" {
      cluster_identifier      = "training-aurora"
      engine                  = "aurora-postgresql"
      engine_version          = "15.5"          # was "15.4"
      # ... (rest unchanged) ...

      blue_green_update {
        enabled = true
      }
    }
    ```
    <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

10. **Save** the file. Do not edit anything else — keep the change set minimal so the `terraform plan` output is easy to read in the pipeline log.

> **What Just Happened?** You have declared, in code, that the next apply against this cluster must go through a Blue/Green path: Aurora will provision a green cluster at engine version 15.5, replicate from blue, and only switch the cluster endpoint over once replication lag has reached zero. The application connecting to `training-aurora.cluster-xxxxx.us-east-1.rds.amazonaws.com` does not need to know any of that happened. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

---

## Task 5: Push and Watch the Pipeline Plan + OPA Validate

11. **Stage, commit, and push** your change to trigger AWS CodePipeline:

    ```bash
    git add terraform/aurora_cluster.tf
    git commit -m "Lab 4: opt training-aurora into blue/green for 15.5 upgrade"
    git push origin main
    ```
    <!-- source: course_outline_v3.md Lab 4 -->

12. **Switch** to the AWS Management Console and navigate to **CodePipeline > Pipelines**. Find the pipeline your instructor named on the lab whiteboard and click it. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-view-console.html -->

13. **Watch** the stages execute. Source should turn green within seconds; Build (which runs `terraform plan -out=tfplan` and `terraform show -json tfplan > tfplan.json`) follows; Validate (the OPA / Conftest stage from Lab 3) evaluates the planned change. <!-- source: Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" + Module_6_narrative.md §"Terraform Plan Evaluation" -->

14. **Click** into the Build stage > **Details** to open the AWS CodeBuild execution and locate the `terraform plan` output in the log. You should see a one-resource change block similar to:

    ```
    Terraform will perform the following actions:

      # aws_rds_cluster.training will be updated in-place
      ~ resource "aws_rds_cluster" "training" {
            cluster_identifier      = "training-aurora"
          ~ engine_version          = "15.4" -> "15.5"
            # (all other attributes unchanged)

          + blue_green_update {
              + enabled = true
            }
        }

    Plan: 0 to add, 1 to change, 0 to destroy.
    ```
    <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster + https://developer.hashicorp.com/terraform/cli/commands/plan -->

    **Expected Result:** AWS CodeBuild's log shows exactly one resource changing (`aws_rds_cluster.training`), the `engine_version` diff `"15.4" -> "15.5"`, and the new `blue_green_update { enabled = true }` block in the plan. If the plan shows additional changes (other resources being destroyed or recreated), **stop** — you have edited more than intended. Reset the file from `origin/main` and reapply only the two edits from Task 4.

15. **Return** to the AWS CodePipeline view and watch the Validate stage. The OPA policies from Lab 3 (naming, encryption, tagging, Lambda timeout, EKS image registry, container resource limits) do not specifically target Aurora Blue/Green; the engine-version policy used on supported-version pins **may** flag a bump if `15.5` is outside the approved-version list. If Validate goes red, read the Conftest output as you did in Lab 3 and confirm with your instructor whether to choose a different target version. <!-- source: Module_6_narrative.md §"Section 4: Reading OPA Evaluation Results" + Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" -->

    **Expected Result:** The Validate stage is **Succeeded** (green) with the instructor-confirmed target version, and the pipeline proceeds to the **Approval** stage. If Validate is red for any reason other than version pin, treat it as a Lab 3-style remediation — fix the policy violation, push again, do **not** weaken the policy.

---

## Task 6: Approve and Apply

16. **Wait** for the pipeline to reach the **Approval** stage. The standard pattern from Module 1 and Lab 1 **requires** a manual approval gate on any pipeline targeting a prod-tier resource — Aurora training is treated as prod-tier because it is a shared, persistent data store. The Validate stage from Lab 3 enforces compliance; the approval gate adds a human review for irreversible changes. <!-- source: Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" + facts_extracted_v2.md §"AWS CodePipeline" -->

17. **Click** the **Review** button on the approval action. Read the planned change one more time. When ready, enter an approval comment (`Lab 4: approve engine bump 15.4 → 15.5 via blue/green`) and click **Approve**. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals-action-add.html -->

18. **Watch** the Deploy stage execute. Inside Deploy, `terraform apply tfplan` runs in AWS CodeBuild. AWS RDS receives the `ModifyDBCluster` API call with the Blue/Green opt-in, provisions the green cluster, replicates from blue, and — once replication lag is zero — performs the switchover. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html + https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_ModifyDBCluster.html -->

> **Note:** Real Aurora Blue/Green typically takes 5–15 minutes end-to-end for the training cluster size. The pipeline's apply step will sit on `Still modifying...` output from Terraform while RDS does the green provisioning and switchover behind the scenes. The CodeBuild log streams progress; you do not need to refresh anything. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

---

## Task 7: Observe Blue and Green in the RDS Console

19. **Open** a second browser tab and navigate to the AWS Management Console > **RDS > Databases**. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ViewInstance.html -->

20. **Find** the row for `training-aurora`. While the deployment is in progress, you will see **two** related clusters:

    - The original (blue) cluster: `training-aurora` — status `available`, still serving traffic on the cluster endpoint.
    - The green cluster: `training-aurora-green-<random-suffix>` — status will transition from `creating` to `available` and finally disappear after switchover.
    <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-viewing.html -->

    **Expected Result:** Both blue and green clusters are visible in the **Databases** list during the deployment window. Click **training-aurora** > **Configuration** tab to see the active engine version transition from `15.4` to `15.5` at the moment of switchover. After switchover completes, only the (now-upgraded) `training-aurora` cluster remains visible — the green identifier and the Blue/Green deployment record are torn down by Aurora.

21. **Click** the **Blue/Green Deployments** sub-section of the RDS console (left navigation) to see the deployment record itself: its status (`AVAILABLE` → `SWITCHOVER_IN_PROGRESS` → `SWITCHOVER_COMPLETED`), the source ARN, and the target ARN. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-viewing.html -->

---

## Task 8: Find the Switchover Event in CloudTrail

22. **Navigate** to the AWS Management Console > **CloudTrail > Event history**. <!-- source: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html -->

23. **Filter** the event history. Set **Lookup attributes** to **Event source** and enter `rds.amazonaws.com`. Set the time window to the last 30 minutes. <!-- source: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events-console.html -->

24. **Locate** the events that correspond to your Blue/Green run. You should see these names, in roughly this order:

    - `CreateBlueGreenDeployment` — emitted when Terraform's apply triggered the Blue/Green opt-in path.
    - `ModifyDBCluster` — on the blue cluster, recording the engine-version change as the intent.
    - `SwitchoverBlueGreenDeployment` — the moment of the cluster endpoint cut-over. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/logging-using-cloudtrail.html -->

    **Expected Result:** All three event names appear in CloudTrail within the last 30 minutes, sourced from `rds.amazonaws.com`, with the calling identity matching the AWS CodeBuild execution role used by the pipeline (the same role identity Lab 1 and Lab 3 observed in their CodeBuild log lines). Clicking **SwitchoverBlueGreenDeployment** > **Event record** shows the source and target cluster ARNs and the timestamp — this is the auditable record the compliance team relies on to evidence that the schema/version change was pipeline-driven and not a manual console action.

> **What Just Happened?** A `git push` against a Terraform file made AWS RDS provision an entirely new Aurora cluster, replicate to it, and atomically swap the cluster endpoint — with CloudTrail recording every step and AWS CodePipeline gating the apply behind your explicit approval. Module 5 promised this as the workflow that enables zero-downtime engine upgrades; you just executed it end-to-end. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

---

## Troubleshooting

### `terraform plan` shows a `forces replacement` warning on the cluster

**Check:** Read the plan output carefully. `cluster_identifier`, `master_username`, `database_name`, and `engine` (not `engine_version`) all force replacement when changed. <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster -->

**Fix:** You have edited one of those immutable attributes by mistake. Reset `terraform/aurora_cluster.tf` from `origin/main` (`git checkout origin/main -- terraform/aurora_cluster.tf`) and reapply **only** the two edits from Task 4 — the `engine_version` bump and the new `blue_green_update` block. The plan should then show `1 to change, 0 to destroy`. <!-- source: https://developer.hashicorp.com/terraform/cli/commands/plan -->

### Validate stage fails with an engine-version policy denial

**Check:** Open the CodeBuild log for the Validate stage and read the Conftest `FAIL` line. If it names the engine version (e.g. `Aurora engine version '15.5' not in approved list`), this is the same kind of policy failure you handled in Lab 3 — a real denial from a real Rego rule. <!-- source: Module_6_narrative.md §"Section 4: Reading OPA Evaluation Results" -->

**Fix:** Confirm with your instructor which Aurora engine version is currently on the approved list and use that one in your edit. Do **not** edit the OPA policy to add `15.5` — that is the anti-pattern Module 6 called out and Lab 3 covered in Knowledge Check question 3. <!-- source: Module_6_narrative.md §"Section 6: Policy Versioning and Lifecycle" -->

### Apply sits on `Still modifying...` for longer than 15 minutes

**Check:** Open the **Blue/Green Deployments** page in the RDS console (Task 7, step 21) and read the deployment record's status. If it is stuck in `SWITCHOVER_IN_PROGRESS` for an unusually long time, the most likely cause is replication lag that has not yet hit zero — Aurora will not switch over until lag is zero. <!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

**Fix:** Replication lag is a function of the write activity on the blue cluster. If a classmate is running heavy writes against `training-aurora` in parallel, lag will stay non-zero. Wait for write traffic to subside; Aurora will complete the switchover automatically once lag reaches zero. If lag stays high for more than 15 minutes, raise it to your instructor — do **not** force-switchover from the console as a workaround. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

### CloudTrail does not show `SwitchoverBlueGreenDeployment`

**Check:** Confirm the event filter is set to **Event source = `rds.amazonaws.com`** and the time window covers your apply. CloudTrail event history can lag the actual API call by a few minutes — the event may not be searchable for up to 15 minutes after the call. <!-- source: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events-console.html -->

**Fix:** Widen the time window to the last hour and refresh. If the event is still missing after 30 minutes, confirm the apply actually reached the switchover phase by re-reading the CodeBuild log for the Deploy stage — if the apply errored out before switchover, CloudTrail will only have `CreateBlueGreenDeployment` and `ModifyDBCluster`, not the switchover event. <!-- source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/logging-using-cloudtrail.html -->

---

## Knowledge Check

**Question 1:** Why does the pipeline require a manual approval gate before `terraform apply` runs against the training Aurora cluster, when Lab 1's EKS pipeline targeting `dev` did not? Refer to what Module 5 said about the difference between application deployments and database changes.
<!-- source: Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" -->

**Question 2:** You bump `engine_version` on an `aws_rds_cluster` resource and push, but you forget to add the `blue_green_update { enabled = true }` block. The apply still succeeds — what is the operational impact on the application connecting to the cluster, and why is the Blue/Green opt-in the standard for this kind of change?
<!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" -->

**Question 3:** Naming the three RDS API events you saw in CloudTrail (Task 8), which of them is the **auditable** record that the cluster's serving endpoint actually moved to the new engine version? Why is observing the other two not sufficient for compliance evidence?
<!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/logging-using-cloudtrail.html -->

**Question 4:** A teammate proposes "speeding up the Lab 4 pattern in production" by removing the `blue_green_update` block and just letting Terraform do an in-place engine upgrade. Citing Module 5 directly, give two reasons that is unacceptable for a prod-tier Aurora cluster.
<!-- source: Module_5_narrative.md §"Section 4: Aurora Blue/Green Deployments" -->

*Answers are in the Knowledge Check Bank.*

---

## Completion Checklist

- [ ] `aws sts get-caller-identity` and `aws rds describe-db-clusters` against `training-aurora` both succeeded before any edits
- [ ] Lab 4 repo cloned and `terraform/aurora_cluster.tf` + `buildspec.yml` opened
- [ ] `engine_version` edited from the starting value to the instructor-confirmed target version
- [ ] `blue_green_update { enabled = true }` block added to the `aws_rds_cluster.training` resource
- [ ] Change committed and pushed; AWS CodePipeline triggered automatically
- [ ] Build stage's CodeBuild log shows exactly one resource changing in the Terraform plan (`aws_rds_cluster.training`)
- [ ] Validate stage (OPA / Conftest) shows **Succeeded** (or version-pin denial was resolved with instructor)
- [ ] Approval action was reviewed and approved with a comment
- [ ] Deploy stage's `terraform apply` ran without error
- [ ] Blue and green clusters were both visible in the **RDS > Databases** view during the deployment window
- [ ] **Blue/Green Deployments** RDS console page showed the deployment transition through `AVAILABLE` → `SWITCHOVER_IN_PROGRESS` → `SWITCHOVER_COMPLETED`
- [ ] AWS CloudTrail event history shows `CreateBlueGreenDeployment`, `ModifyDBCluster`, and `SwitchoverBlueGreenDeployment` for `rds.amazonaws.com` in your apply window

---

## Cost Considerations

Aurora Blue/Green provisions a full second cluster (the green) for the duration of the deployment, which is the dominant cost driver for this lab. The deployment window is short, but the green cluster is billed at full Aurora rates while it exists.

| Component | Type | Hourly Cost (us-east-1, on-demand) |
|-----------|------|------------------------------------|
| Amazon Aurora (blue cluster, training-tier instance) | Shared training cluster | ~$0.08/hour share <!-- source: https://aws.amazon.com/rds/aurora/pricing/ verified 2026-04-07 --> |
| Amazon Aurora (green cluster, same instance class, ~15 min of life) | Full-rate during deployment | ~$0.08/hour for ~0.25 hour ≈ $0.02 <!-- source: https://aws.amazon.com/rds/aurora/pricing/ verified 2026-04-07 --> |
| Aurora storage (copy-on-write green, only changed pages) | Per GB-month | <$0.01 share <!-- source: https://aws.amazon.com/rds/aurora/pricing/ verified 2026-04-07 --> |
| AWS CodePipeline (one active pipeline) | Per active pipeline-month | <$0.02/hour share <!-- source: https://aws.amazon.com/codepipeline/pricing/ verified 2026-04-07 --> |
| AWS CodeBuild (plan + validate + apply build minutes) | `general1.small` build-minute | ~$0.005/build-minute <!-- source: https://aws.amazon.com/codebuild/pricing/ verified 2026-04-07 --> |
| AWS CloudTrail (Event history, free tier) | Management events | $0 <!-- source: https://aws.amazon.com/cloudtrail/pricing/ verified 2026-04-07 --> |
| **Total (this lab, ~30 min)** | | **~$0.05–$0.10 (single run)** |

**Cleanup:** The training Aurora cluster, the AWS CodePipeline, and the AWS CodeBuild project all persist between cohorts and are owned by the platform team — do **not** delete them and do **not** run `terraform destroy` against the shared training account. The green cluster tears itself down automatically when the Blue/Green deployment completes its switchover; you do not need to do anything to remove it. Your local clone of `io107-lab4-aurora-bluegreen/` can be removed with the standard `rm -rf io107-lab4-aurora-bluegreen` once the lab is complete. <!-- source: Module_5_narrative.md §"Section 1: Why Pipeline-Driven Database Changes" + https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html -->

---

## Next Steps

This is the final hands-on lab in IO-107. In **Module 6 (Policy-as-Code with OPA)** through **Module 8 (Troubleshooting Pipeline & Policy Failures)** you have already seen the policy and guardrail layers that wrap every pipeline you used in Labs 1–4. The course wrap-up will tie the four labs back to the end-to-end SDLC model: container deployments (Lab 1), serverless deployments (Lab 2), policy enforcement (Lab 3), and data-tier changes (Lab 4) — all driven by the same pipeline pattern with the same guardrails. <!-- source: course_outline_v3.md Lab 4 -->

---

## Resources

- [Amazon RDS User Guide — Blue/Green Deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html)
- [Amazon RDS User Guide — Viewing a Blue/Green Deployment](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-viewing.html)
- [Amazon RDS API Reference — ModifyDBCluster](https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_ModifyDBCluster.html)
- [Terraform AWS provider — `aws_rds_cluster`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster)
- [AWS CloudTrail User Guide — Logging Amazon RDS API calls](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/logging-using-cloudtrail.html)
- [AWS CodePipeline User Guide — Manage Approval Actions](https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals-action-add.html)
- [Terraform CLI — `terraform plan`](https://developer.hashicorp.com/terraform/cli/commands/plan)
