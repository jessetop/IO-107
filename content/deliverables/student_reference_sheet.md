# IO-107: SDLC Pipeline & Deployment Guardrails
## Student Reference Sheet

A scannable quick-reference for the commands, patterns, and terminology used across the four labs. Keep this open during class and after.

---

## Quick Commands

### Git (every lab)

```bash
# Clone a training repo
git clone https://github.com/[client-org]/[repo-name].git

# Create a feature branch
git checkout -b lab2-add-post-endpoint

# Stage, commit, push to trigger the pipeline
git add <files>
git commit -m "Lab N: <what changed>"
git push origin main
```

The merge into `main` is what triggers the pipeline. Pushing only to a feature branch does **not** trigger it.

---

### kubectl (Lab 1)

```bash
# Point kubectl at the training cluster
aws eks update-kubeconfig --name training-eks-cluster --region us-east-1

# List pods and watch a rollout
kubectl get pods -n lab1 -l app=myapp
kubectl rollout status deployment/myapp -n lab1 --timeout=5m

# Inspect a ServiceAccount (verify IRSA annotation)
kubectl get sa myapp-sa -n lab1 -o yaml

# Exec into a pod to test IRSA
POD_NAME=$(kubectl get pods -n lab1 -l app=myapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lab1 $POD_NAME -- env | grep AWS
kubectl exec -n lab1 $POD_NAME -- aws s3 ls

# Delete a pod (Deployment will recreate with fresh IRSA injection)
kubectl delete pod $POD_NAME -n lab1
```

---

### Helm (Lab 1)

```bash
# The exact upgrade command the buildspec runs
helm upgrade --install $APP_NAME charts/myapp \
  --namespace $NAMESPACE \
  --create-namespace \
  --values charts/myapp/values-$ENVIRONMENT.yaml \
  --set image.tag=$IMAGE_TAG \
  --atomic \
  --timeout 10m

# Remove a release (cleanup)
helm uninstall myapp -n lab1
```

`--atomic` is required in production pipelines: if any resource fails to become ready within `--timeout`, Helm rolls the release back automatically.

---

### AWS CLI (Lab 1, Lab 2, Lab 4)

```bash
# Identity check
aws sts get-caller-identity

# ECR login for docker push (CodeBuild does this for you)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Retrieve the API Gateway endpoint from CloudFormation outputs (Lab 2)
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name io107-lab2-sam-app \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

# Inspect a Lambda alias (reference only — never update manually)
aws lambda get-alias --function-name lab2-api-ApiFunction-xxx --name live

# Describe the training Aurora cluster (Lab 4 pre-flight)
aws rds describe-db-clusters \
  --db-cluster-identifier training-aurora \
  --query 'DBClusters[0].[DBClusterIdentifier,Status,Engine,EngineVersion]' \
  --output table
```

---

### SAM CLI (Lab 2)

```bash
# Inside CodeBuild — install, build, package, deploy
pip install aws-sam-cli
sam build
sam package --output-template-file packaged.yaml --s3-bucket $ARTIFACT_BUCKET
sam deploy \
  --template-file packaged.yaml \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides Environment=$ENVIRONMENT \
  --no-fail-on-empty-changeset
```

`--capabilities CAPABILITY_IAM` is required because SAM creates the Lambda execution role. `--no-fail-on-empty-changeset` prevents the pipeline from failing when a re-run produces no infrastructure changes.

---

### Conftest / OPA (Lab 3)

```bash
# How CodeBuild runs OPA against a Terraform plan
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json -p /policies/terraform --output json

# Test policies locally before opening a PR on the policy repo
conftest test test.json -p policies/
```

A non-zero exit code from `conftest` fails the **Validate** stage and stops the pipeline.

---

### Terraform — Aurora Blue/Green (Lab 4)

```hcl
# The two edits Lab 4 makes to terraform/aurora_cluster.tf
resource "aws_rds_cluster" "training" {
  cluster_identifier  = "training-aurora"
  engine              = "aurora-postgresql"
  engine_version      = "15.5"          # was "15.4"
  # ... (rest of the resource unchanged) ...

  blue_green_update {
    enabled = true
  }
}
```

**Triggers a Blue/Green path** (when `blue_green_update.enabled = true`): `engine_version` bump, `db_cluster_parameter_group_name` change, instance class change.

**Does NOT trigger Blue/Green** (applied in place): tag-only edits, `backup_retention_period`, `preferred_backup_window`, `deletion_protection`.

```bash
# Verify the cluster + describe the Blue/Green deployment record
aws rds describe-db-clusters --db-cluster-identifier training-aurora

# Filter CloudTrail for the three Blue/Green RDS API events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=rds.amazonaws.com \
  --start-time $(date -u -d '30 minutes ago' +%FT%TZ)
# Expected events: CreateBlueGreenDeployment, ModifyDBCluster, SwitchoverBlueGreenDeployment
```

`SwitchoverBlueGreenDeployment` is the auditable event proving the cluster endpoint cut over to the new engine version.

---

## Common Patterns

### `buildspec.yml` skeleton (standard pipelines)

```yaml
version: 0.2

env:
  variables:
    CLUSTER_NAME: "training-eks-cluster"
  secrets-manager:                     # Secrets pulled at build time, never in Git
    DB_PASSWORD: "training-aurora/password"

phases:
  install:      # Install tools (helm, sam, terraform, conftest)
  pre_build:    # ECR login, terraform plan, set IMAGE_TAG
  build:        # docker build/push, sam build, terraform plan -out=tfplan
  post_build:   # helm upgrade --install, sam deploy, terraform apply tfplan
```

---

### Helm `values-{env}.yaml` (IRSA wiring)

```yaml
replicaCount: 1
resources:
  limits:
    cpu: 250m
    memory: 256Mi
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/myapp-dev-role
environment: dev
```

The `eks.amazonaws.com/role-arn` annotation is what EKS reads to bind the ServiceAccount to an IAM role via the cluster's OIDC provider.

---

### SAM canary deployment

```yaml
ApiFunction:
  Type: AWS::Serverless::Function
  Properties:
    AutoPublishAlias: live
    DeploymentPreference:
      Type: Canary10Percent5Minutes
      Alarms:
        - !Ref ApiErrorAlarm
```

Three pieces working together: an **alias** (`live`) callers reference instead of `$LATEST`, a **deployment preference** that shifts traffic gradually, and a **CloudWatch alarm** that triggers automatic rollback during the canary window.

---

### Compliant resource tags (mandatory schema)

```hcl
tags = {
  Environment = "dev"              # Allowed: dev | stg | prd
  Application = "lab3"
  Owner       = "training@client.com"
  CostCenter  = "CC-TRAINING"
  DataClass   = "internal"         # Required for S3, RDS, data-handling Lambdas
}
```

Tag keys and values are **case-sensitive** — `environment` ≠ `Environment`.

---

### Compliant EKS pod `securityContext`

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: app
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/app:1.21
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          resources:
            limits:
              memory: "256Mi"
              cpu: "500m"
```

Image **must** come from the approved Amazon ECR registry, pinned to a version (not `:latest`).

---

### Basic Rego deny rule (read these in pipeline failures)

```rego
package main

deny[msg] {
  input.resource_type == "aws_s3_bucket"
  not input.encryption_configured
  msg := sprintf("S3 bucket '%s' must have server-side encryption enabled", [input.name])
}
```

All conditions inside a rule body use AND logic — every line must be true for the rule to fire.

---

## Failure Categorisation (Troubleshooting Framework)

| Stage that failed | Error wording | Category | Where to fix |
|---|---|---|---|
| **Validate** | `FAIL - <file> - main - ...` | **OPA policy violation** | Edit the Terraform / Kubernetes file |
| **Deploy** | `with an explicit deny in a service control policy` | **SCP denial** | Exception request — *do not* edit code |
| **Deploy** | `Tag value '...' does not meet tag policy requirements` | **AWS Organizations tag policy** | Correct the tag value (`dev`/`stg`/`prd`) |
| **Deploy** | `is not authorized to perform` (no SCP wording) | **IAM permission gap** | Platform team updates the pipeline role |
| **Approval** | gate not advancing | Manual review pending | Page the approver named on the lab whiteboard |

---

## Troubleshooting Quick-Ref (top issues from the labs)

| Symptom | One-line fix |
|---|---|
| Pipeline did not trigger after `git push` | Confirm you merged to `main`; if commit still missing in **Source**, click **Release change** and raise a ticket for the webhook |
| `kubectl exec ... aws s3 ls` returns "Unable to locate credentials" | IRSA annotation missing or pod predates it — `kubectl delete pod $POD_NAME` so the Deployment recreates it with env vars injected |
| Helm rolled back during deploy | `--atomic` already reverted; run `kubectl describe pod <pod>` to find the failing readiness/image-pull error, fix, re-push |
| Conftest still flags missing tag after you added it | Tag keys are case-sensitive — must be `Environment`, not `environment` |
| `terraform plan` for Lab 4 shows `forces replacement` on the cluster | You edited an immutable attribute (`cluster_identifier`, `engine`, `master_username`). Reset from `origin/main` and reapply only the `engine_version` + `blue_green_update` edits |
| Lab 4 Validate stage fails on engine version | The OPA approved-version pin may not yet include your target version. Confirm the current approved version with your instructor and use that; do **not** edit the OPA policy |
| Lab 4 apply sits on `Still modifying...` for >15 min | Replication lag has not reached zero. Wait for blue-cluster write traffic to subside; do not force-switchover from the console |
| CloudTrail event for failed `CreateBucket` not visible | CloudTrail is region-scoped — switch the console region selector to the region the call targeted |
| CloudTrail event for `SwitchoverBlueGreenDeployment` not visible after Lab 4 apply | CloudTrail can lag by up to 15 min; widen the time window and refresh |

---

## Glossary

| Term | Definition |
|---|---|
| **Service Catalog product** | An AWS Service Catalog item that emits pre-approved Terraform for standard resources (S3 bucket, EKS app, Lambda function, Aurora cluster). The Terraform you commit to Git in the standard flow comes from launching one of these. |
| **AWS CodePipeline** | The AWS-native pipeline orchestrator. One of the orchestrators in the enterprise mix (alongside Jenkins / CloudBees). |
| **AWS CodeBuild** | The build executor — runs `terraform plan / apply`, `helm upgrade`, `sam build / deploy`, `conftest test`, etc., per `buildspec.yml`. Output streams to CloudWatch Logs. |
| **AWS CodeDeploy** | The deployment engine that performs Lambda alias traffic shifting under SAM's `DeploymentPreference`. You do not configure it directly; SAM generates the CodeDeploy resources. |
| **IRSA** | IAM Roles for Service Accounts. Binds a Kubernetes ServiceAccount to an IAM role via the EKS cluster's OIDC provider so pods get short-lived AWS credentials without baked-in keys. |
| **Atomic rollback** | `helm upgrade --atomic` automatically reverts the release if any resource fails to become ready before `--timeout`. Required in production pipelines. |
| **Canary deployment** | Gradual traffic shift to a new version. `Canary10Percent5Minutes` sends 10% of traffic to the new Lambda version for 5 minutes, then 100% if the alarm stays clear. |
| **Blue/Green (Aurora)** | Aurora provisions a *green* cluster on the new engine / parameter group, replicates from *blue*, and atomically switches the cluster endpoint once replication lag hits zero. Lab 4 exercises this via Terraform's `blue_green_update { enabled = true }`. |
| **`blue_green_update`** | The Terraform `aws_rds_cluster` block that opts a change into Aurora's Blue/Green path. With `enabled = true`, attribute changes that would otherwise be in-place (engine version, parameter group, instance class) go through the Blue/Green workflow. |
| **`SwitchoverBlueGreenDeployment`** | The CloudTrail event recording the moment the cluster endpoint moves from blue to green. The auditable record that the engine-version change actually took effect. |
| **GitOps** | Git is the source of truth for deployments. Every change to infrastructure or application config goes through a commit, PR, and pipeline — never through a console. |
| **OPA / Rego** | Open Policy Agent is a policy engine; Rego is its declarative policy language. Evaluates JSON input (a Terraform plan, a Kubernetes manifest) against deny rules. |
| **Conftest** | An OPA wrapper for testing configuration files. Returns non-zero exit code on any denial, which fails the pipeline's Validate stage. |
| **SCP** | Service Control Policy. AWS Organizations–level guardrail that applies to **every** principal in the account, including pipeline execution roles. SCP denials say "explicit deny in a service control policy". |
| **Tag policy** | AWS Organizations policy that enforces allowed tag keys and values across accounts. The `Environment` tag must be one of `dev`, `stg`, `prd`. |
| **AWS Config** | Continuous compliance evaluation against deployed resources. Catches drift after deployment (e.g. someone `kubectl edit`s a running pod). |
| **`$LATEST`** | Lambda's mutable pointer to the most recent function code. Event sources should reference an **alias** (e.g. `live`) instead, so traffic shifts are controlled by deployment preferences. |
| **Exception request** | Formal process to bypass a guardrail for a legitimate use case. Requires business justification, narrowest scope, risk mitigation, and approval chain. Never used to skip security controls. |

---

## Useful URLs

**AWS CI/CD**
- AWS CodePipeline User Guide — https://docs.aws.amazon.com/codepipeline/latest/userguide/
- AWS CodeBuild buildspec reference — https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
- AWS CodeDeploy User Guide — https://docs.aws.amazon.com/codedeploy/latest/userguide/
- AWS Service Catalog Administrator Guide — https://docs.aws.amazon.com/servicecatalog/latest/adminguide/

**EKS & Helm**
- IAM Roles for Service Accounts — https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- `aws eks update-kubeconfig` — https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html
- `helm upgrade` reference — https://helm.sh/docs/helm/helm_upgrade/

**Lambda & SAM**
- AWS SAM Developer Guide — https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/
- Lambda Versioning and Aliases — https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html

**Database**
- Amazon Aurora User Guide — https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/
- Amazon RDS Blue/Green Deployments — https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html
- Terraform AWS provider — `aws_rds_cluster` — https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster

**Policy & Governance**
- Open Policy Agent — https://www.openpolicyagent.org/docs/latest/
- Conftest — https://www.conftest.dev/
- AWS Organizations SCPs — https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html
- AWS Organizations Tag Policies — https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html
- AWS Config Developer Guide — https://docs.aws.amazon.com/config/latest/developerguide/
- AWS CloudTrail Event History — https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html

---

*Course: IO-107 SDLC Pipeline & Deployment Guardrails — 1 day, 6.5 hr content, 4 labs. Version 3.0, last updated 2026-05-12.*
