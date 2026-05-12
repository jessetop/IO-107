# Module 1: Pipeline Architecture & Service Catalog — Teaching Narrative

**Duration:** 30 minutes

---

## Opening (2 minutes)

"Good morning, everyone, and welcome to Course 7: SDLC Pipeline and Deployment Guardrails. Today's focus is the *process* of shipping a change — what the pipeline does for you between `git push` and a deployed workload, and what it stops you from doing along the way.

If you took Course 6, you know *where* our resources live. Today we cover *how* they get there. The headline: infrastructure and application deployments don't happen from the console or a laptop. They flow through Service-Catalog-approved Terraform, committed to Git, executed by our CI/CD platform. That gives us consistency, an audit trail, and policy enforcement before anything reaches AWS."

[SLIDE: Module 1 - Pipeline Architecture & Service Catalog]

[SLIDE: Module Contents - "You Are Here"]

---

## Chapter Objectives (1 minute)

"By the end of this module, you'll be able to:"

[SLIDE: Chapter Objectives]
- Describe how a Terraform change flows from a Service Catalog product through the pipeline to AWS
- Name the orchestration tools in the pipeline — Jenkins, CloudBees, AWS CodePipeline, CodeDeploy — and what each one does
- Identify the standard pipeline stages and where validation happens
- List the primary deployment targets: EKS, Lambda, and Aurora

---

## Section 1: Why Pipeline-Driven (4 minutes)

"Let me set the philosophy up front so the rest of the day makes sense."

[SLIDE: Why Pipeline-Driven]
- Audit trail: every change ties back to a Git commit, PR review, and pipeline execution
- Consistency: the same approved Terraform produces the same infrastructure every time
- Approval gates: humans review production changes; the pipeline enforces the gate
- Compliance baked in: encryption, tagging, naming, network rules checked before deploy

"For a financial services organisation, this isn't bureaucracy — it's the audit story. When an auditor asks 'who changed this, when, and who approved it?' we point at the pipeline. When something breaks in production, we point at the same pipeline to roll back. Manual console clicks don't give us either of those.

One prerequisite I'll only mention once: everything downstream of `git push` is only as trustworthy as the commit landing on `main`. The standard pattern requires branch protection with required reviews on `main`, 2FA on every contributor account, and signed commits on production-targeted repos. These source-control controls are out of scope for this course, but every diagram and pipeline we cover today assumes they're in place — pipeline integrity collapses without them."

---

## Section 2: Service Catalog — the Source of Approved Terraform (5 minutes)

"Here's the piece that's specific to this environment: you don't write Terraform from scratch. You provision from an AWS Service Catalog product."

[SLIDE: AWS Service Catalog]
- Service Catalog products are pre-approved Terraform modules
- Cloud platform team authors and versions the products
- Developers consume products — they don't author raw Terraform
- Product version pins what AWS resources, settings, and tags are allowed

"Think of Service Catalog as the curated list of building blocks the platform team has vetted. There's a product for an S3 bucket with the organisation's encryption and BPA settings baked in. There's a product for an EKS application namespace with IRSA wired up. There's a product for an Aurora cluster with the right parameter groups, KMS keys, and tag defaults.

When you need infrastructure, you launch the product — typically from a self-service portal or via a Terraform module reference — and you supply the parameters: environment, application name, owner, cost centre. The product expands to the underlying Terraform, which is what flows through the pipeline.

Why this matters: by the time your change reaches the policy-validation stage, it's already structurally compliant. The Service Catalog product can't generate a bucket without encryption — that's not exposed as a parameter. OPA still validates everything downstream, but Service Catalog is the *first* guardrail, before the pipeline even runs."

[SLIDE: From Service Catalog to a Deployed Workload]
- Developer launches Service Catalog product → expanded Terraform
- Terraform committed to Git repo for the application
- Pipeline picks up the commit, runs plan, OPA validates, approval gates, apply
- Approved changes land in dev/stg/prd AWS accounts via cross-account role assumption

---

## Section 3: The Orchestration Tool Mix (5 minutes)

"Now the orchestration side. The enterprise CI/CD platform doesn't use one CI/CD tool — it uses a mix, and which tool drives a given pipeline depends on the workload's history and team. You don't need to administer any of these. You need to know which one you're looking at when something fails, and what each one does at the orchestration level."

[SLIDE: Pipeline Tool Mix]
- Jenkins: long-standing CI/CD engine for many workloads — builds, tests, triggers downstream
- CloudBees: enterprise Jenkins distribution — central pipelines, RBAC, audit, shared libraries
- AWS CodePipeline: AWS-native orchestrator for cloud-native and newer workloads
- AWS CodeDeploy: handles the deployment step itself — blue/green, in-place, traffic shifting

"Jenkins has been the workhorse for years. Many existing pipelines run on Jenkins jobs that build artifacts, run unit tests, and call out to AWS for the deploy.

CloudBees is the enterprise distribution of Jenkins that runs centrally — it adds RBAC, audit logging, shared libraries, and the central control plane that lets the platform team manage thousands of Jenkins pipelines.

AWS CodePipeline is the AWS-native orchestrator. Newer cloud-native workloads — especially EKS and Lambda — increasingly run on CodePipeline because it integrates directly with CodeBuild, CodeDeploy, EventBridge, and IAM.

AWS CodeDeploy is the deployment executor. Where CodePipeline says 'now deploy', CodeDeploy actually performs the deploy — handling alias-based traffic shifting for Lambda, rolling updates for EC2, and blue/green for ECS or Lambda. We focus on the AWS-native path in this course because that's where the modernisation work is happening, but you'll encounter Jenkins/CloudBees pipelines too."

[SLIDE: AWS CodePipeline — the AWS-Native Orchestrator]
- Event-driven: Amazon EventBridge triggers pipeline on a Git change
- Stages contain actions; actions produce artifacts consumed by later stages
- Built-in execution history and audit trail
- Calls CodeBuild for build/test, CodeDeploy for deploy, custom actions for OPA

"EventBridge — you may still see the older name 'CloudWatch Events' in legacy docs and API responses; it's the same service, rebranded in 2019 — detects a commit and kicks off the pipeline. The pipeline executes a series of stages, each containing one or more actions, and the output of one stage is passed to the next as an artifact in S3."

[SLIDE: AWS CodeBuild — Where Work Happens]
- Buildspec.yml defines build phases and commands
- Runs in a managed container; can join your VPC for private-resource access
- Logs sent to CloudWatch Logs
- Produces artifacts (Terraform plan, Docker image, Lambda zip) for downstream stages

---

## Section 4: Pipeline Stages at a Glance (4 minutes)

"Let me show you the canonical stage layout so you know where each kind of validation happens. Not every pipeline has every stage, but this is the typical flow."

[SLIDE: Pipeline Stages]
- Source → Build → Policy Validation (OPA) → Approval (stg/prd) → Deploy

"Source is triggered when code lands on the right branch. Build runs `terraform plan` for infrastructure changes, or compiles code and builds container images for application changes. Policy validation is where OPA evaluates the Terraform plan against the rules — naming, tagging, encryption, EKS pod security, Lambda config. We'll spend all of Module 6 on that stage.

Approval is the manual gate for staging and production deployments. CodePipeline supports manual approval actions natively; a human reviews what's about to deploy and clicks approve. Deploy is where it actually happens — `terraform apply` for infrastructure, Helm or kubectl for EKS, SAM deploy for Lambda, Aurora Blue/Green for database changes.

A failure at any stage stops the pipeline immediately. You don't waste approval-cycle time on a change that fails OPA, and you don't waste deploy windows on a change that fails the build."

---

## Section 5: Deployment Targets at a Glance (3 minutes)

"Three primary targets you'll see all day."

[SLIDE: Primary Deployment Targets]
- Amazon EKS — containerised applications (Module 3)
- AWS Lambda — serverless functions (Module 4)
- Aurora / RDS — schema migrations and Blue/Green (Module 5)

"EKS is our container platform. Module 3 covers Helm-based deployment, kubectl, and IRSA for pod-level IAM.

Lambda is the serverless target. Module 4 covers SAM, versioning, aliases, and CodeDeploy-driven traffic shifting.

Aurora and RDS are our relational databases. Module 5 covers schema migrations through the pipeline and Aurora Blue/Green deployment driven by Terraform — which Lab 4 exercises.

One acknowledgement: EC2 still exists for legacy workloads, and we are actively migrating those to EKS or Lambda. This course concentrates on the cloud-native targets because that's where new work is heading, but if you support a legacy EC2 workload, the same pipeline mechanics apply — CodeDeploy or Jenkins handles the EC2 deploy step instead of Helm or SAM."

---

## Summary and What's Next (1 minute)

[SLIDE: Chapter Summary]
- Described how Service Catalog → Terraform → Git → pipeline → AWS works
- Named the orchestration tools: Jenkins, CloudBees, AWS CodePipeline, AWS CodeDeploy
- Identified the standard pipeline stages and where OPA / approval / deploy sit
- Listed the primary deployment targets: EKS, Lambda, Aurora

"Up next: Module 2. We'll walk an end-to-end pipeline run using S3 as the example — because everyone already knows S3, it lets us focus on the *pipeline mechanics* rather than a new service. After that, we deep-dive on EKS, Lambda, and Aurora."

---

## Instructor Notes

**Key Points to Emphasize:**
- The "why" behind pipeline-driven operations (audit, compliance, consistency)
- Service Catalog is the first guardrail — vetted Terraform, not arbitrary HCL
- Tool mix exists because the enterprise is mid-modernisation; both Jenkins/CloudBees and AWS CodePipeline are in production
- Participants do not need to administer any of the orchestration tools

**Common Questions:**
- "Can I write my own Terraform outside Service Catalog?" — Only via exception request; default is no
- "Why both Jenkins and CodePipeline?" — Legacy + modernisation; new cloud-native work tends to land on CodePipeline
- "Can I deploy manually for emergencies?" — Break-glass procedures exist but are heavily audited; covered briefly in Module 8

**Timing Notes:**
- Opening: 2 min
- Objectives: 1 min
- Why Pipeline-Driven: 4 min
- Service Catalog: 5 min
- Orchestration Tool Mix: 5 min
- Pipeline Stages: 4 min
- Deployment Targets: 3 min
- Summary: 1 min
- Buffer: 5 min (Q&A and transitions)
