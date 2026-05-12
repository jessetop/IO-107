# Lab 3: Policy-as-Code Evaluation & Failure Remediation

| | |
|---|---|
| **Course** | IO-107 SDLC Pipeline & Deployment Guardrails |
| **Module** | Module 6 — Policy-as-Code with OPA |
| **Duration** | 45 minutes |
| **Difficulty** | Intermediate |
| **Prerequisites** | Module 6 completed; Labs 1–2 completed (familiarity with AWS CodePipeline, AWS CodeBuild, and reading CodeBuild logs); access to the training AWS account and CI/CD platform; `git` configured locally |

---

## Learning Objectives

By the end of this lab, you will:

- Deploy a Terraform + Kubernetes template that intentionally violates the OPA policies (naming, encryption, tagging, Lambda timeout, container image registry, container resource limits). <!-- source: course_outline_v2.md Lab 3 + Lab_3_narrative.md §"Section 2: Review the Intentional Violations" -->
- Observe AWS CodePipeline halt at the OPA policy-validation stage and locate the Conftest output in the AWS CodeBuild logs. <!-- source: course_outline_v2.md Lab 3 + Module_6_narrative.md §"Section 2: OPA Integration in the Pipeline" -->
- Read and interpret the Conftest `FAIL` lines and map each one back to the resource in the source files. <!-- source: Module_6_narrative.md §"Section 4: Reading OPA Evaluation Results" + Lab_3_narrative.md §"Section 3: Trigger the Pipeline and Observe Failure" -->
- Identify the EKS-specific policy violations (disallowed image registry, missing container resource limits, missing required labels) and the Lambda-specific violation (timeout above the maximum). <!-- source: course_outline_v2.md Lab 3 + Module_6_narrative.md §"EKS-Specific Policies" + Module_6_narrative.md §"Lambda-Specific Policies" -->
- Remediate every violation in line with the standards and confirm the pipeline completes successfully on re-run. <!-- source: course_outline_v2.md Lab 3 + Lab_3_narrative.md §"Section 6: Re-run the Pipeline" -->

---

## Task 1: Clone the Violations Repository

1. **Open** your terminal (or the lab environment's Cloud9 / CloudShell session, whichever your environment provides).

2. **Clone** the lab repository. Your instructor will provide the actual URL on the lab whiteboard — paste it into the command below:

    ```bash
    git clone https://github.com/[client-org]/[repo-name].git io107-lab3-policy-violations
    ```
    <!-- TODO: replace with real repo URL before delivery -->
    <!-- source: Lab_3_narrative.md §"Section 1: Clone the Repository with Violations" -->

3. **Change directory** into the repo and list the top level:

    ```bash
    cd io107-lab3-policy-violations
    ls -la
    ```
    <!-- source: Lab_3_narrative.md §"Section 1: Clone the Repository with Violations" -->

    Expected structure:

    ```
    io107-lab3-policy-violations/
    ├── terraform/
    │   ├── main.tf          # Infrastructure with violations
    │   ├── variables.tf
    │   └── outputs.tf
    ├── kubernetes/
    │   └── deployment.yaml  # K8s manifest with violations
    ├── buildspec.yml
    └── README.md
    ```
    <!-- source: Lab_3_narrative.md §"Section 1: Clone the Repository with Violations" -->

4. **Open** `terraform/main.tf`, `kubernetes/deployment.yaml`, and `buildspec.yml` in your editor of choice. You will refer to all three in the next tasks.

> **Note:** This repository is deliberately broken. The infrastructure described inside will never reach AWS in this state — the OPA policy stage is designed to stop it. Your goal for the lab is to make the policies pass without weakening them.

---

## Task 2: Identify the Terraform Violations

5. **Open** `terraform/main.tf`. You will see two resources — an S3 bucket and a Lambda function — both written to deliberately fail the OPA policies:

    ```hcl
    # VIOLATION 1: S3 bucket with wrong naming convention
    resource "aws_s3_bucket" "data_bucket" {
      bucket = "my-bucket"  # Should be client-{env}-{app}-{purpose}

      # VIOLATION 2: Missing encryption configuration
      # (no server_side_encryption_configuration block)

      # VIOLATION 3: Missing required tags
      tags = {
        Name = "My Bucket"
        # Missing: Environment, Application, Owner, CostCenter, DataClass
      }
    }

    # VIOLATION 4: Lambda with excessive timeout
    resource "aws_lambda_function" "processor" {
      function_name = "data-processor"
      runtime       = "python3.11"
      handler       = "app.handler"
      timeout       = 600  # Exceeds maximum allowed (300)
      memory_size   = 512
      filename      = "lambda.zip"

      tags = {
        Name = "Processor"
        # Missing required tags
      }
    }
    ```
    <!-- source: Lab_3_narrative.md §"Section 2: Review the Intentional Violations" -->

6. **List** the violations on paper or in a scratch file before you run the pipeline. You should be able to find at least these five from the Terraform file alone, all of which were covered in Module 6:

    - S3 bucket name `my-bucket` does not match `client-{env}-{app}-{purpose}`. <!-- source: Module_6_narrative.md §"Resource Naming Policies" -->
    - S3 bucket has no `aws_s3_bucket_server_side_encryption_configuration` block. <!-- source: Module_6_narrative.md §"Encryption Policies" + facts_extracted_v2.md §"S3 Bucket Provisioning" -->
    - S3 bucket is missing the required tags `Environment`, `Application`, `Owner`, `CostCenter`, `DataClass`. <!-- source: Module_6_narrative.md §"Tagging Policies" -->
    - Lambda function `data-processor` has `timeout = 600`, exceeding the 300-second maximum the policy enforces. <!-- source: Module_6_narrative.md §"Lambda-Specific Policies" -->
    - Lambda function is missing the same required tags. <!-- source: Module_6_narrative.md §"Tagging Policies" -->

> **Note:** The required-tags list in the OPA library is `Environment`, `Application`, `Owner`, `CostCenter`. `DataClass` is additionally required for resources that store or process data (S3 buckets, RDS instances, Lambda functions tagged for confidential workloads). Both lists were defined in Module 6. <!-- source: Module_6_narrative.md §"Tagging Policies" + Module_6_narrative.md §"Lambda-Specific Policies" -->

---

## Task 3: Identify the Kubernetes Violations

7. **Open** `kubernetes/deployment.yaml`. The manifest deploys a single-replica web app to the training Amazon EKS cluster — and breaks three EKS-specific policies in the process:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp
      namespace: default
      # VIOLATION: Missing required labels
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: myapp
      template:
        metadata:
          labels:
            app: myapp
        spec:
          containers:
            - name: myapp
              # VIOLATION: Image from unapproved registry
              image: docker.io/library/nginx:latest
              # VIOLATION: Missing resource limits
              ports:
                - containerPort: 80
    ```
    <!-- source: Lab_3_narrative.md §"Section 2: Review the Intentional Violations" -->

8. **Add** the following Kubernetes-side violations to your list:

    - Deployment metadata is missing the required labels `environment` and `owner`. <!-- source: Lab_3_narrative.md §"Section 2: Review the Intentional Violations" + Module_6_narrative.md §"Tagging Policies" -->
    - Container `myapp` pulls from `docker.io/library/nginx:latest`. Only images from the approved Amazon ECR registry are permitted. <!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->
    - Container `myapp` has no `resources.limits` block — neither memory nor CPU. The EKS policy requires both. <!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->

> **What Just Happened?** You have just done what Module 6 said is the entire point of policy-as-code: you read the rules off the resource definitions, before deployment, with no console or wiki lookup. Every item on your list maps directly to a Rego rule shown in Module 6. <!-- source: Module_6_narrative.md §"Opening" + Module_6_narrative.md §"Section 4: Reading OPA Evaluation Results" -->

---

## Task 4: Trigger the Pipeline and Watch It Fail

9. **Make** a trivial change in the repo to force a new commit (Conftest evaluates on every pipeline run, so any push works):

    ```bash
    echo "# Lab 3 test run" >> terraform/main.tf
    ```
    <!-- source: Lab_3_narrative.md §"Section 3: Trigger the Pipeline and Observe Failure" -->

10. **Stage, commit, and push** to trigger AWS CodePipeline:

    ```bash
    git add terraform/main.tf
    git commit -m "Lab 3: trigger OPA validation run"
    git push origin main
    ```
    <!-- source: Lab_3_narrative.md §"Section 3: Trigger the Pipeline and Observe Failure" -->

11. **Switch** to the AWS Management Console and navigate to **CodePipeline > Pipelines**. Find the pipeline named after your repo (your instructor will confirm the exact name) and click it. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-view-console.html -->

12. **Watch** the stages execute. The **Source** stage should turn green within seconds of the push, then **Build** should run to completion. The **Validate** stage (where Conftest runs the OPA policies) will turn **red** and the pipeline will halt before any deployment happens. <!-- source: Module_6_narrative.md §"Section 2: OPA Integration in the Pipeline" + facts_extracted_v2.md §"AWS CodePipeline" -->

    **Expected Result:** AWS CodePipeline shows **Source** and **Build** as **Succeeded** (green) and **Validate** as **Failed** (red). The pipeline overall status is **Failed**, and no **Deploy** stage runs. If **Build** itself fails red, fix that first — Conftest only runs once Build succeeds.

> **Note:** The pipeline runs OPA *after* `terraform plan -out=tfplan` and `terraform show -json tfplan > tfplan.json`, so the policy stage evaluates the planned changes — not the raw `.tf` source. That is why the validation stage runs in CodeBuild against `tfplan.json` rather than against `main.tf` directly. <!-- source: Module_6_narrative.md §"Terraform Plan Evaluation" -->

---

## Task 5: Read the Conftest Output

13. **Click** into the failed **Validate** stage and follow the **Details** link to open the AWS CodeBuild execution that ran Conftest. <!-- source: https://docs.aws.amazon.com/codebuild/latest/userguide/view-build-details.html -->

14. **Scroll** the CodeBuild log to the Conftest output section. You will see a list of `FAIL` lines and a summary, matching the structure Module 6 introduced:

    ```
    Running policy validation...

    FAIL - terraform/main.tf - main - S3 bucket 'my-bucket' does not match naming pattern 'client-{env}-{app}-{purpose}'
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' must have server-side encryption enabled
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Environment
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Application
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Owner
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: CostCenter
    FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: DataClass
    FAIL - terraform/main.tf - main - Lambda 'data-processor' timeout 600 exceeds maximum of 300 seconds
    FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Environment
    FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Application
    FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Owner
    FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: CostCenter
    FAIL - kubernetes/deployment.yaml - main - Container 'myapp' must have memory limit defined
    FAIL - kubernetes/deployment.yaml - main - Container 'myapp' must have CPU limit defined
    FAIL - kubernetes/deployment.yaml - main - Container 'myapp' uses image from unapproved registry 'docker.io'
    FAIL - kubernetes/deployment.yaml - main - Deployment 'myapp' missing required label: environment
    FAIL - kubernetes/deployment.yaml - main - Deployment 'myapp' missing required label: owner

    17 tests, 0 passed, 0 warnings, 17 failures

    Policy validation failed. Fix violations before deployment.
    ```
    <!-- source: Lab_3_narrative.md §"Section 3: Trigger the Pipeline and Observe Failure" -->

15. **Read** each line carefully and map it to your list from Tasks 2–3. Each `FAIL` line follows the same shape Module 6 described — the source file, the policy package (`main`), and a human-readable message: <!-- source: Module_6_narrative.md §"Section 4: Reading OPA Evaluation Results" -->

    1. Read the message — what is wrong?
    2. Identify the resource named in the message.
    3. Find that resource in `terraform/main.tf` or `kubernetes/deployment.yaml`.
    4. Confirm what the policy requires (Module 6 has the Rego source for each).
    5. Plan the smallest change that satisfies the policy.

16. **Confirm** the total: 17 failures. 12 in the Terraform plan, 5 in the Kubernetes manifest. If your line count differs from 17, refresh the CodeBuild log — the build may still be writing.

> **What Just Happened?** The Validate stage exited with a non-zero status because Conftest produced at least one denial. Per Module 6, that non-zero exit code is what causes AWS CodePipeline to fail the stage and stop progression — no human-in-the-loop blocked anything. The policy engine did. <!-- source: Module_6_narrative.md §"Section 2: OPA Integration in the Pipeline" -->

---

## Task 6: Remediate the Terraform File

17. **Open** `terraform/main.tf` and replace its contents with the remediated version below. Every change directly addresses one or more `FAIL` lines from the Conftest output:

    ```hcl
    # FIXED: Bucket name matches client-{env}-{app}-{purpose}
    resource "aws_s3_bucket" "data_bucket" {
      bucket = "client-dev-lab3-data"

      tags = {
        Environment = "dev"
        Application = "lab3"
        Owner       = "training@client.com"
        CostCenter  = "CC-TRAINING"
        DataClass   = "internal"
      }
    }

    # FIXED: Encryption configuration added (SSE-S3 / AES256)
    resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
      bucket = aws_s3_bucket.data_bucket.id

      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }

    # FIXED: Timeout within limit + all required tags
    resource "aws_lambda_function" "processor" {
      function_name = "client-dev-lab3-processor"
      runtime       = "python3.11"
      handler       = "app.handler"
      timeout       = 30
      memory_size   = 512
      filename      = "lambda.zip"

      tags = {
        Environment = "dev"
        Application = "lab3"
        Owner       = "training@client.com"
        CostCenter  = "CC-TRAINING"
      }
    }
    ```
    <!-- source: Lab_3_narrative.md §"Section 4: Remediate Terraform Violations" -->

18. **Verify** each fix lines up with the original `FAIL` lines:

    - Bucket name now matches the `client-{env}-{app}-{purpose}` regex from Module 6's naming policy. <!-- source: Module_6_narrative.md §"Resource Naming Policies" -->
    - A standalone `aws_s3_bucket_server_side_encryption_configuration` resource is the current pattern Terraform uses for S3 default encryption — the legacy inline `server_side_encryption_configuration` block was **removed from the schema in AWS provider v4.0 (Feb 2022)**, so it produces an "Unsupported argument" error at `terraform plan` time, not a deprecation warning. <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration -->
    - All four required tags (`Environment`, `Application`, `Owner`, `CostCenter`) are present on both resources, plus `DataClass` on the S3 bucket because it stores data. <!-- source: Module_6_narrative.md §"Tagging Policies" -->
    - Lambda timeout reduced from `600` to `30` — well below the 300-second cap. <!-- source: Module_6_narrative.md §"Lambda-Specific Policies" -->

> **Note:** Do not "fix" a tagging policy by removing the resource, and do not "fix" the timeout policy by raising the cap. Both work-arounds defeat the point of the guardrail — and per Module 6, policy changes go through pull-request review on the policy repo, not local edits. <!-- source: Module_6_narrative.md §"Section 6: Policy Versioning and Lifecycle" -->

---

## Task 7: Remediate the Kubernetes Manifest

19. **Open** `kubernetes/deployment.yaml` and replace its contents with the remediated version below:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp
      namespace: lab3
      labels:
        app: myapp
        environment: dev
        owner: training-at-client-com
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: myapp
      template:
        metadata:
          labels:
            app: myapp
            environment: dev
            owner: training-at-client-com
        spec:
          containers:
            - name: myapp
              # FIXED: Image from approved Amazon ECR registry
              image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/nginx:1.21
              ports:
                - containerPort: 80
              # FIXED: Memory and CPU limits + requests
              resources:
                limits:
                  memory: "256Mi"
                  cpu: "500m"
                requests:
                  memory: "128Mi"
                  cpu: "100m"
    ```
    <!-- source: Lab_3_narrative.md §"Section 5: Remediate Kubernetes Violations" -->

20. **Confirm** the EKS-specific policies are satisfied:

    - `metadata.labels` and the pod template's `metadata.labels` both carry the required `environment` and `owner` labels. <!-- source: Lab_3_narrative.md §"Section 5: Remediate Kubernetes Violations" -->
    - `image:` now points at `123456789012.dkr.ecr.us-east-1.amazonaws.com/nginx:1.21` — the approved Amazon ECR registry pattern Module 6 used in the EKS policy's `startswith` check. <!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->
    - `resources.limits.memory` and `resources.limits.cpu` are both set, so both Conftest denials about missing limits go away. <!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->
    - Tag the image to a specific version (`1.21`) rather than `latest` — pinning is the standard for reproducible deploys. <!-- source: Lab_3_narrative.md §"Section 5: Remediate Kubernetes Violations" -->

> **Note:** The remediated manifest also moves the workload out of the `default` namespace and into `lab3`. This is not enforced by a Module 6 OPA policy — it is a best practice carried over from Lab 1's `lab1` namespace pattern, so each lab's resources stay isolated and easy to clean up. <!-- source: Lab_3_narrative.md §"Section 5: Remediate Kubernetes Violations" -->

---

## Task 8: Re-run the Pipeline and Confirm All Policies Pass

21. **Stage, commit, and push** both files:

    ```bash
    git add terraform/main.tf kubernetes/deployment.yaml
    git commit -m "Lab 3: remediate all OPA policy violations"
    git push origin main
    ```
    <!-- source: Lab_3_narrative.md §"Section 6: Re-run the Pipeline" -->

22. **Return** to the AWS CodePipeline console and watch the new execution. The **Source** stage should turn green, then **Build**, and this time the **Validate** stage should also turn green.

    **Expected Result:** AWS CodePipeline shows **Source**, **Build**, and **Validate** all as **Succeeded** (green) for the new execution. The **Validate** stage that turned red on the previous run is now green, indicating Conftest exited with status 0 against the updated `tfplan.json` and `deployment.yaml`.

23. **Click** into the **Validate** stage's CodeBuild execution and confirm the Conftest summary now reports zero failures:

    ```
    Running policy validation...

    17 tests, 17 passed, 0 warnings, 0 failures

    Policy validation passed. Proceeding to deployment.
    ```
    <!-- source: Lab_3_narrative.md §"Section 6: Re-run the Pipeline" -->

24. **Confirm** the pipeline proceeds past the **Validate** stage into the standard downstream stages (pipelines run **Approval** before **Deploy** for non-dev targets, as introduced in Module 1 and used in Labs 1–2). For this lab the deployment target is `dev`, so no manual approval is required and the pipeline will run to overall **Succeeded**. <!-- source: facts_extracted_v2.md §"AWS CodePipeline" + Module_6_narrative.md §"Pipeline Integration Point" -->

    **Expected Result:** The overall pipeline status reads **Succeeded** in the AWS CodePipeline console, every stage tile is green, and the **Deploy** stage's CodeBuild log shows the `terraform apply` and `kubectl apply -f kubernetes/deployment.yaml` commands ran without error. The `client-dev-lab3-data` S3 bucket and the `myapp` Deployment in namespace `lab3` now exist in the training account.

> **What Just Happened?** You took a deployment that was blocked by 17 separate policy denials and made it deployable by changing only the resource definitions — never the policies themselves. That is the workflow Module 6 promised: the policies are the contract, the pipeline enforces them, and the human work is bringing the configuration into compliance. <!-- source: Module_6_narrative.md §"Section 6: Policy Versioning and Lifecycle" + Module_6_narrative.md §"Summary and What's Next" -->

---

## Troubleshooting

### Pipeline does not trigger after `git push`

**Check:** In the AWS CodePipeline console, open the pipeline > **Source** stage. Confirm the source action shows the latest commit SHA.

**Fix:** If the commit is not visible, the source webhook may be disconnected. Re-run the pipeline manually by clicking **Release change** at the top of the pipeline page. If that succeeds, raise a ticket to have the webhook reconnected — do not work around the issue permanently. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-rerun-manually.html -->

### Conftest output is empty or missing from the CodeBuild log

**Check:** Scroll the CodeBuild log up to the install phase and confirm Conftest itself ran. The log should contain a line that looks like `conftest test tfplan.json -p /policies/terraform --output ...` matching the Module 6 buildspec pattern. <!-- source: Module_6_narrative.md §"Conftest for Configuration Testing" -->

**Fix:** If Conftest never ran, the Validate stage's buildspec was not invoked — usually because the **Build** stage failed earlier and Validate was skipped. Fix the build error first; Conftest will run on the next push. <!-- source: facts_extracted_v2.md §"AWS CodeBuild" -->

### Re-run still shows S3 encryption failure after you added the encryption block

**Check:** Confirm you added a **separate** `aws_s3_bucket_server_side_encryption_configuration` resource that references `aws_s3_bucket.data_bucket.id`, not an inline `server_side_encryption_configuration {}` block inside the `aws_s3_bucket` resource.

**Fix:** The AWS Terraform provider moved S3 default-encryption settings into a dedicated resource type. Inline blocks on `aws_s3_bucket` were **removed from the schema in AWS provider v4.0 (Feb 2022)** — they no longer parse, regardless of how Module 6's encryption policy is written. Use the standalone resource shown in Task 6. <!-- source: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration -->

### Lambda still flagged for a missing tag after you added the tags block

**Check:** Tag keys are case-sensitive. Conftest is comparing the literal strings `Environment`, `Application`, `Owner`, `CostCenter`. Re-open `terraform/main.tf` and confirm exact spelling and case.

**Fix:** Rename mis-cased keys (for example, `environment` → `Environment`), push again, and re-check the Conftest output. <!-- source: Module_6_narrative.md §"Tagging Policies" + Lab_3_narrative.md §"Instructor Notes" -->

### Container image policy still fails after you switched away from Docker Hub

**Check:** Print the new image line and confirm the prefix exactly matches the Amazon ECR registry hostname the policy looks for. The Module 6 EKS policy uses `startswith(container.image, "123456789012.dkr.ecr.us-east-1.amazonaws.com/")`. <!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->

**Fix:** Make sure there is no `docker.io/` or other prefix in front of the ECR hostname. The image must start with the account ID, then `.dkr.ecr.<region>.amazonaws.com/`. For the training environment, your instructor will confirm the exact account ID and region.

---

## Knowledge Check

**Question 1:** The pipeline runs OPA against `tfplan.json`, not against `main.tf`. Why does the validation stage evaluate the Terraform *plan* in JSON form rather than the source `.tf` file directly?
<!-- source: Module_6_narrative.md §"Terraform Plan Evaluation" -->

**Question 2:** Look at the Rego encryption rule shown in Module 6 (`deny[msg]` when an `aws_s3_bucket` resource has no `server_side_encryption_configuration`). Why does that rule still fire when the resource definition itself looks "fine" but encryption is configured via a separate `aws_s3_bucket_server_side_encryption_configuration` resource? How is the remediated lab code structured to make the policy pass?
<!-- source: Module_6_narrative.md §"Encryption Policies" + https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration -->

**Question 3:** A teammate is in a hurry and proposes "fixing" the Lambda timeout violation by editing the OPA policy to raise the maximum from 300 to 900 seconds, then committing both the timeout change and the policy change together. Based on what Module 6 taught about policy lifecycle, why is this not an acceptable remediation, and what is the correct path?
<!-- source: Module_6_narrative.md §"Section 6: Policy Versioning and Lifecycle" -->

**Question 4:** Naming the three EKS-specific violations you remediated in Task 7, identify for each one which class of failure it would have caused in production if it had reached Amazon EKS without the OPA stage (for example: cost / blast-radius / supply-chain / operational).
<!-- source: Module_6_narrative.md §"EKS-Specific Policies" -->

*Answers are in the Knowledge Check Bank.*

---

## Completion Checklist

- [ ] Repository cloned and `terraform/main.tf`, `kubernetes/deployment.yaml`, `buildspec.yml` opened
- [ ] Terraform violations enumerated on paper before running the pipeline
- [ ] Kubernetes violations enumerated on paper before running the pipeline
- [ ] First pipeline run reached the **Validate** stage and failed
- [ ] Conftest output located in the AWS CodeBuild log for the Validate stage
- [ ] Total of 17 `FAIL` lines confirmed in the Conftest output
- [ ] S3 bucket renamed to match the `client-{env}-{app}-{purpose}` pattern
- [ ] Separate `aws_s3_bucket_server_side_encryption_configuration` resource added
- [ ] All required tags (`Environment`, `Application`, `Owner`, `CostCenter`, plus `DataClass` on S3) added to both Terraform resources
- [ ] Lambda `timeout` reduced to a value `<= 300`
- [ ] Container image swapped from `docker.io/library/nginx:latest` to the approved Amazon ECR registry, pinned to a version (not `latest`)
- [ ] Container `resources.limits` block added with both `memory` and `cpu` set
- [ ] `environment` and `owner` labels added at both the Deployment and pod-template level
- [ ] Re-run pipeline shows `17 tests, 17 passed, 0 warnings, 0 failures` in Conftest output
- [ ] Pipeline reaches overall status **Succeeded**

---

## Cost Considerations

Lab 3 is almost entirely a *policy evaluation* exercise — the Validate stage stops the pipeline before any chargeable AWS resources are created on the first run, and the remediated re-run deploys only the small training-scale resources defined in the templates.

| Component | Type | Hourly Cost (us-east-1, on-demand) |
|-----------|------|------------------------------------|
| AWS CodePipeline (one active pipeline) | Per active pipeline-month | <$0.02/hour share <!-- source: https://aws.amazon.com/codepipeline/pricing/ verified 2026-04-07 --> |
| AWS CodeBuild (build + validate minutes) | `general1.small` build-minute | ~$0.005/build-minute <!-- source: https://aws.amazon.com/codebuild/pricing/ verified 2026-04-07 --> |
| Amazon S3 bucket (`client-dev-lab3-data`, empty) | Standard storage | <$0.01/hour share <!-- source: https://aws.amazon.com/s3/pricing/ verified 2026-04-07 --> |
| AWS Lambda function (`client-dev-lab3-processor`, idle) | Per-request + GB-second | $0/hour at zero invocations <!-- source: https://aws.amazon.com/lambda/pricing/ verified 2026-04-07 --> |
| Amazon EKS workload (1 pod, fraction of shared worker) | Shared training cluster | ~$0.01/hour share <!-- source: https://aws.amazon.com/eks/pricing/ verified 2026-04-07 --> |
| **Total (this lab, ~1 hour)** | | **~$0.05/hour** |

**Cleanup:** The training EKS cluster, CodePipeline, and CodeBuild project persist between cohorts — do **not** delete them. To release the small set of resources your remediated push created:

```bash
# Kubernetes side
kubectl delete -f kubernetes/deployment.yaml
kubectl delete namespace lab3
```
<!-- source: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete -->

The Terraform-created S3 bucket and Lambda function are torn down by your instructor's lab-reset job between cohorts; do not run `terraform destroy` directly against the shared training account unless your instructor asks you to.

---

## Next Steps

In **Lab 4: Database Migration Pipeline**, you'll execute a Flyway-based schema migration through the pipeline against Amazon Aurora, add a new migration file, validate the schema change, and walk a simulated failed migration through the rollback procedure. The pipeline-driven model is the same; the workload changes from compute (EKS, Lambda) to data. <!-- source: course_outline_v2.md Lab 4 -->

---

## Resources

- [Open Policy Agent — Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Conftest — Documentation](https://www.conftest.dev/)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/)
- [Terraform AWS provider — `aws_s3_bucket_server_side_encryption_configuration`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)
- [AWS Lambda — Configure function timeout](https://docs.aws.amazon.com/lambda/latest/dg/configuration-function-common.html)
- [Amazon ECR — Private repository concepts](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Repositories.html)
- [Kubernetes — Resource limits on Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
