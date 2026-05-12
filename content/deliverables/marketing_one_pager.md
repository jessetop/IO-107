# IO-107: SDLC Pipeline & Deployment Guardrails

## Ship to EKS, Lambda, and Aurora through your enterprise pipelines — without fighting the guardrails.

---

## Course Overview

This one-day, instructor-led course walks engineers through the process of shipping code through an enterprise SDLC pipeline. The focus is the **process of what the pipeline does for you when you commit Terraform from an approved Service Catalog product**, not the internals of the underlying CI/CD tools. Participants learn how the platform validates, gates, and deploys their changes; what an OPA / SCP / tag-policy failure looks like at each stage; and how to remediate. The course covers deployment patterns for the primary compute platforms — Amazon EKS and AWS Lambda — and Aurora Blue/Green deployments triggered through Terraform. Coverage of Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy, and AWS Service Catalog is at the orchestration / process level; participants do not need to administer any of these tools.

---

## Who Should Attend

Cloud engineers, DevOps engineers, application developers, and infrastructure operators who deploy workloads into an enterprise AWS environment.

**Prerequisites:**
- Basic CI/CD and Git familiarity
- Foundational AWS knowledge (IAM, S3, CloudWatch, CloudTrail)
- Basic Terraform comfort (reading and editing resources, reading a `terraform plan`)
- Familiarity with an enterprise AWS account structure (IO-106 or equivalent)
- Basic container and Kubernetes concepts (helpful, not required)

---

## What You Will Learn

By the end of this course, participants will be able to:

- **Describe the pipeline architecture** — how Terraform from an approved Service Catalog product flows through Jenkins / CloudBees / AWS CodePipeline / AWS CodeDeploy to a deployed workload.
- **Read a CodeBuild log and AWS CodePipeline console** to determine which stage failed and why.
- **Recognise OPA, SCP, tag-policy, and IAM denials** by their distinct error signatures.
- **Deploy a containerised application to Amazon EKS** via Helm + kubectl through the pipeline, including IRSA configuration.
- **Deploy a serverless application via AWS SAM** with alias-based traffic shifting (canary / linear).
- **Trigger an Aurora Blue/Green deployment by changing Terraform**, and observe the pipeline-driven switchover in the RDS console and AWS CloudTrail.
- **Navigate the exception request process** when a guardrail blocks a legitimate change.

---

## Format

- **Duration:** 1 day — **6.5 hr of content** (8 hr classroom day minus 1 hr lunch + 2 × 15 min breaks)
- **Delivery:** Instructor-led, in-person or virtual
- **Content split:** 210 min lecture (8 modules) + 180 min hands-on (4 labs) — approximately 46% hands-on
- **Materials:** pipeline architecture diagrams, OPA policy library reference, tagging schema spec, exception request templates, EKS / SAM / Terraform-Aurora reference guides

---

## Hands-On Labs

| Lab | Duration | What You Build |
|-----|----------|----------------|
| **Lab 1: End-to-End EKS Deployment Pipeline** | 60 min | Push a Helm chart change through the pipeline; verify pods, LoadBalancer service, and IRSA-injected credentials in the training EKS cluster. |
| **Lab 2: Lambda Deployment with SAM** | 45 min | Modify a SAM template's `DeploymentPreference`, deploy through the pipeline, and observe alias-based canary traffic shifting in CloudWatch and the Lambda console. |
| **Lab 3: Policy-as-Code Evaluation & Remediation** | 45 min | Push a Terraform plan with deliberate OPA violations (naming, tags, encryption, EKS pod-security, Lambda timeout). Read Conftest output, remediate, and re-run to a green pipeline. |
| **Lab 4: Aurora Blue/Green Deployment via Terraform + Pipeline** | 30 min | Edit `aws_rds_cluster` Terraform to opt the training Aurora cluster into a Blue/Green deployment. Watch the pipeline plan, OPA validate, approve, and apply; observe blue + green clusters in the RDS console and `SwitchoverBlueGreenDeployment` in CloudTrail. |

---

## Why This Matters

Enterprise AWS environments are typically governed by multiple layers of policy — SCPs, OPA rules, tag policies, AWS Config rules, and pipeline-level approval gates. Engineers who understand only the application side of a deployment end up blocked at unfamiliar policy boundaries, escalating issues that they could resolve themselves. This course closes that gap by walking through the actual control plane: what gets evaluated where, why a deployment was denied, and what the supported remediation path looks like.

The course is scoped exclusively to a defined set of approved AWS services — EKS, Lambda, Aurora / RDS, and S3 — and to the CI/CD toolchain typical of regulated enterprises. There are no examples involving services outside the approved portfolio.

---

## What Participants Need

- Laptop with a modern browser
- Access to the CI/CD platform and the training AWS accounts (provided at course start)
- Lab credentials and repository access (provided at course start)
- Git, AWS CLI, `kubectl`, and Terraform installed locally — or willingness to use AWS CloudShell (pre-installed with all four)

---

*Course materials prepared by ROI Training. Content grounded in official AWS documentation and the approved service portfolio. Version 3.0, 2026-05-12.*
