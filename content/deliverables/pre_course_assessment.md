# Pre-Course Self-Assessment: IO-107 SDLC Pipeline & Deployment Guardrails

**Course:** IO-107 — SDLC Pipeline & Deployment Guardrails (1 Day, 6.5 hr content)
**Stream:** AWS Intermediate Operations & Environment Deep Dive

---

## Purpose

This self-assessment helps you decide whether you are ready for IO-107. The course assumes you already have working familiarity with AWS fundamentals, CI/CD concepts, version control, Terraform, and basic container vocabulary — it does **not** re-teach them. Spend 10-15 minutes rating yourself honestly. If you mark "I have never heard of this" or "I have read about it" on more than four questions, complete the suggested catch-up before the class so you can keep pace with the labs.

**How to use this:**

For each topic, pick the level that best describes you:

- **L1:** I have never heard of this
- **L2:** I have read about it but not used it
- **L3:** I have used it a few times under guidance
- **L4:** I use it regularly on my own

Anything **L2 or below** flags a gap. Suggested catch-up resources are listed under each question.

---

## Section A: AWS Fundamentals

Most of these were covered in **IO-106 AWS Network Architecture** (the prior course in this stream) or in foundational AWS training. If you completed IO-106, you should be at L3 or higher on every question in this section.

### Q1. Navigating the AWS Console — IAM, S3, and CloudWatch

Can you sign in to the AWS Console, find the **IAM**, **Amazon S3**, and **Amazon CloudWatch** services from the search bar, and open a role, a bucket, or a log group?

> If L2 or below: Review [AWS Management Console basics](https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/getting-started.html). You will navigate these services constantly during the labs.

### Q2. IAM Roles vs. IAM Users

Can you explain the difference between an IAM **user** and an IAM **role**, and why pipelines use roles (not users) to authenticate?

> If L2 or below: Read [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html). Module 1 and Lab 1 assume you understand that AWS CodeBuild assumes a service role to deploy on your behalf.

### Q3. Amazon S3 Concepts

Can you describe what a **bucket**, **object**, **prefix**, and **bucket policy** are? Do you know that S3 supports server-side encryption (SSE-S3, SSE-KMS)?

> If L2 or below: Read the [S3 User Guide — Getting started](https://docs.aws.amazon.com/AmazonS3/latest/userguide/GetStartedWithS3.html). Module 2 uses S3 as the walk-through example for pipeline mechanics, so the bucket / encryption / TLS-only patterns should already be familiar.

### Q4. AWS CLI

Can you run `aws s3 ls`, `aws sts get-caller-identity`, `aws eks update-kubeconfig`, or `aws rds describe-db-clusters` from a terminal once your credentials are configured?

> If L2 or below: Work through [Configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html). Lab 1, Lab 2, and Lab 4 all expect the AWS CLI to be installed and configured on your laptop or in the training CloudShell.

### Q5. CloudWatch Logs

Can you open a **CloudWatch Logs** log group, find a log stream, and read entries from it?

> If L2 or below: Read [What is Amazon CloudWatch Logs?](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html). AWS CodeBuild writes every pipeline build's output to CloudWatch Logs — reading them is how you diagnose failures in Module 8 and Lab 3.

### Q6. AWS Shared Responsibility & Approved Services

Are you aware that this environment operates with a **defined list of approved AWS services** (EKS, Lambda, S3, RDS, Aurora) and that some popular AWS services (e.g. DynamoDB, ECS) are **not** in scope?

> If L2 or below: Review IO-106 Module 1 (or your onboarding deck) on the approved-service policy. The whole course assumes you will deploy only to EKS, Lambda, and Aurora.

### Q7. AWS CloudTrail

Can you find a specific API event in **CloudTrail Event history** by event source and time window, and read its event record?

> If L2 or below: Read [Viewing CloudTrail events](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html). Lab 4 ends with you locating `CreateBlueGreenDeployment`, `ModifyDBCluster`, and `SwitchoverBlueGreenDeployment` events in CloudTrail; Module 8 uses CloudTrail to identify SCP denials.

---

## Section B: Version Control & CI/CD Concepts

### Q8. Git Basics

Can you `git clone` a repository, create a branch, make a commit, and push it to a remote?

> If L2 or below: Work through [the Git handbook](https://docs.github.com/en/get-started/using-git/about-git). Every lab in this course starts with `git clone` and ends with `git push`.

### Q9. Pull Requests / Merge Reviews

Do you understand what a **pull request** (or merge request) is, and why pipelines often run validation checks against PRs before code is merged?

> If L2 or below: Read [About pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests). Modules 1 and 6 both assume the PR-driven workflow.

### Q10. CI/CD Pipelines — Stages and Artifacts

Can you describe what a **pipeline stage** is, what an **artifact** is, and the typical flow from `source → build → validate → approval → deploy`?

> If L2 or below: Read [What is AWS CodePipeline?](https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html). Module 1 walks through the pipeline at the orchestration level — Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy — and assumes you grasp the concept of stages and artifacts.

### Q11. Build Specifications (`buildspec.yml`)

Have you seen — or written — a CI/CD build configuration file (CodeBuild's `buildspec.yml`, GitHub Actions `workflow.yml`, GitLab `.gitlab-ci.yml`, or similar)?

> If L2 or below: Skim the [AWS CodeBuild buildspec reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html). Every lab in this course inspects or modifies a `buildspec.yml`.

---

## Section C: Terraform & Infrastructure as Code

### Q12. Terraform Basics

Have you read or written a **Terraform configuration**? Do you understand resources, providers, `terraform plan`, and `terraform apply`?

> If L2 or below: Work through [the Terraform tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started). Module 1's central message is *"Terraform from an approved Service Catalog product, committed to Git, executed by the pipeline."* Labs 3 and 4 both edit Terraform files directly.

### Q13. AWS Service Catalog (Awareness)

Are you aware that the standard deployment path is **Terraform from an approved AWS Service Catalog product** — i.e. you do not author Terraform from scratch for the core deployment path; you launch a Service Catalog product that emits the Terraform for you?

> If L2 or below: Skim the [AWS Service Catalog overview](https://docs.aws.amazon.com/servicecatalog/latest/adminguide/introduction.html). Module 1 frames this as the headline workflow; you do not need to be able to author products, only to recognise the pattern.

### Q14. Reading a `terraform plan` Output

Can you read a `terraform plan` output and identify which resources will be created, changed, destroyed, or replaced (`forces replacement`)?

> If L2 or below: Read [`terraform plan` documentation](https://developer.hashicorp.com/terraform/cli/commands/plan). Lab 4's `terraform plan` output is the central artefact you read; misreading it can lead to accidentally proposing a cluster destruction.

---

## Section D: Containers & Kubernetes (Helpful, Not Required)

The course description states basic Kubernetes knowledge is **helpful but not required**. If you are at L1 on the questions below, you can still attend — but plan to spend extra time on Module 3 and Lab 1.

### Q15. Containers and Docker

Can you explain what a **container image** is and what a `Dockerfile` does? Have you run `docker build` or `docker run`?

> If L2 or below: Work through [Docker's "Get Started" tutorial](https://docs.docker.com/get-started/). Module 3 builds a container image as part of the EKS pipeline.

### Q16. Kubernetes Vocabulary

Can you define **pod**, **deployment**, **service**, and **namespace** at a conversational level?

> If L2 or below: Read [Kubernetes Concepts](https://kubernetes.io/docs/concepts/) — focus on Workloads and Services. Module 3, Module 6 (EKS policies), and Lab 1 all use these terms without re-defining them.

### Q17. Helm

Have you heard of **Helm** as the Kubernetes package manager, and do you know what a `values.yaml` file controls?

> If L2 or below: Skim [the Helm Quickstart](https://helm.sh/docs/intro/quickstart/). Lab 1 modifies a `values-{env}.yaml` and runs `helm upgrade --install`.

---

## Section E: AWS Compute & Database — Foundational Awareness

You do not need deep expertise here — Modules 3, 4, and 5 will go deeper. You **do** need to know each service exists and what it broadly does.

### Q18. Amazon EKS

Do you know that **Amazon EKS** is AWS's managed Kubernetes service, and that workloads can run on either **EC2 worker nodes** or **AWS Fargate**?

> If L2 or below: Read [What is Amazon EKS?](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html). Module 3 and Lab 1 assume this baseline.

### Q19. AWS Lambda

Do you know that **AWS Lambda** runs code without managing servers, and that you can package functions and deploy them through automated tooling? Are you aware of the **versions and aliases** model — `$LATEST` vs. a published version like `:5`?

> If L2 or below: Read [What is AWS Lambda?](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html). Module 4 and Lab 2 build on this; the alias-as-stable-pointer pattern is central to the lab.

### Q20. Amazon Aurora and the Blue/Green Pattern

Do you know that **Amazon Aurora** is a managed relational database service, and are you aware that **engine version upgrades and parameter-group changes can be performed via an Aurora Blue/Green deployment** — provisioning a new (green) cluster, replicating from the old (blue), and switching over once replication catches up?

> If L2 or below: Read [Amazon RDS Blue/Green Deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html). Module 5 frames the pattern; Lab 4 exercises it via Terraform's `blue_green_update` block. You do **not** need to have used Blue/Green yourself — you need to know it exists.

---

## Section F: Lab Environment Readiness

Confirm each of the following **before** class. These are not knowledge questions — they are practical setup items the labs require.

- [ ] I can sign in to the training AWS account through the SSO portal.
- [ ] I have access to the CI/CD platform (the orchestrator dashboard your training coordinator names — Jenkins / CloudBees / the AWS CodePipeline console, depending on which is in scope for your cohort).
- [ ] I have `git` installed locally — or I know I will use the in-browser AWS CloudShell during labs.
- [ ] I have the **AWS CLI** configured, or I am comfortable configuring it on day-one of the course.
- [ ] I have `kubectl` installed locally — or I will use CloudShell (CloudShell has it pre-installed).
- [ ] I have `terraform` installed locally — or I will rely on the pipeline's `terraform plan / apply` and not run plans on my laptop.
- [ ] My laptop can reach `git.[client-domain]` and the AWS Console without VPN issues. (If unsure, ask your training coordinator before class.)

If any box is unchecked, contact your training coordinator at least one business day before the course.

---

## Scoring Yourself

Count the questions where you marked **L1 (never heard of)** or **L2 (read about, never used)**:

| Gaps Counted (Q1-Q20) | Recommendation |
|------------------------|----------------|
| **0-2** | You are ready. Skim the linked resources for the few items you flagged. |
| **3-4** | You can attend, but allocate **2-3 hours** before class to work through the linked resources, especially anything in Section A, B, or C. |
| **5-7** | You will struggle to keep pace. We strongly recommend completing IO-106 first (or its equivalent) and revisiting AWS Cloud Practitioner-level training and a Terraform getting-started tutorial before booking IO-107. |
| **8+** | Prerequisites are not yet met. Do not attend until you have foundational AWS, Git, Terraform, and CI/CD experience. The labs are hands-on and time-boxed — you will fall behind. |

---

## Priority Catch-Up Topics (If You Only Have Time for Three)

If you have limited prep time, focus here — these are the topics the course **most** depends on:

1. **Terraform basics + reading a plan** ([Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)) — every lab edits a Terraform file and reads the resulting plan in a pipeline log.
2. **IAM roles and trust policies** ([IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)) — Module 3 (IRSA), Module 6 (OPA evaluation), Module 7 (SCPs), and Lab 1 all assume you understand role assumption and trust policy conditions.
3. **Git fundamentals** ([Git handbook](https://docs.github.com/en/get-started/using-git/about-git)) — every lab starts with `git clone` and ends with `git push`.

---

## Notes

- This assessment is for self-evaluation only. You do not submit it.
- The service-portfolio rules (EKS over ECS, Aurora / RDS over DynamoDB) are reinforced throughout the course — if you are unfamiliar with that policy, that is normal and the course will cover it.
- If you have specific questions about whether your background fits, contact your training coordinator before booking.

---

*Assessment prepared for: IO-107 SDLC Pipeline & Deployment Guardrails (1 Day, 6.5 hr content)*
*Version: 3.0 (matches `course_outline_v3.md`) | Last Updated: 2026-05-12*
