# Module 6: Policy-as-Code with OPA — Teaching Narrative

**Duration:** 30 minutes (trimmed from 45 min per v3 outline)

---

## Opening (2 minutes)

"Throughout the day, I've mentioned policy validation as a pipeline stage. You deploy S3 buckets, EKS workloads, Lambda functions — and somewhere in there, OPA checks that your configuration meets the organisation's standards. Now it's time to understand exactly what that means.

Open Policy Agent — OPA — is the engine behind the policy-as-code approach. Instead of having a list of requirements in a wiki that people might or might not follow, we encode those requirements as policies that are automatically evaluated. Your deployment either passes the policies or it doesn't.

This module covers how OPA fits into the pipeline, how to read a Conftest FAIL line, and the modern Rego pattern for AWS provider v4+."

[SLIDE: Chapter 6 - Policy-as-Code with OPA]

---

## Module Objectives (2 minutes)

[SLIDE: Chapter Objectives]
- Explain how OPA integrates into the deployment pipeline
- Read and interpret OPA policy evaluation results
- Identify the policy categories at a high level
- Recognise the modern Rego pattern for paired Terraform resources

[SLIDE: Chapter Concepts — Introduction to OPA and Rego]

---

## Section 1: What OPA Does + Rego Basics (8 minutes)

"Let's start with the fundamentals."

[SLIDE: What is Open Policy Agent?]
- General-purpose policy engine decoupled from applications
- Input: JSON data to evaluate (e.g. a Terraform plan)
- Policy: rules written in Rego
- Output: allow/deny decisions with human-readable reasons
- Primary use here: validates Terraform plans before deployment

"OPA is a policy engine. You give it some data — a Terraform plan, a Kubernetes manifest, any JSON — and you give it policies written in a language called Rego. OPA evaluates the data against the policies and tells you if it passes or fails.

The key insight is that policies are *data*, not code baked into an application. You can update policies independently of applications. You can test them. You can version them.

Here, OPA's primary job is infrastructure-as-code validation — evaluating Terraform plans before deployment. It's also used in industry for Kubernetes admission control and API authorization, but plan validation is where you'll encounter it."

[SLIDE: Rego Language Basics]
```rego
package main

SSE := "aws_s3_bucket_server_side_encryption_configuration"

deny[msg] {
    bucket := input.resource_changes[_]
    bucket.type == "aws_s3_bucket"
    not has_encryption(bucket)
    msg := sprintf("Bucket %v missing encryption",
                   [bucket.address])
}

# AWS provider v4+: encryption is a separate resource.
has_encryption(bucket) {
    enc := input.resource_changes[_]
    enc.type == SSE
}
```

"Rego is OPA's policy language. It's declarative — you describe what should be true, not how to check it. This example walks every resource change in the Terraform plan, finds the S3 buckets, and denies any bucket that doesn't have a paired `aws_s3_bucket_server_side_encryption_configuration` resource in the same plan.

That separate-resource pattern is the **modern** Terraform AWS provider v4+ shape — inline `server_side_encryption_configuration` blocks on `aws_s3_bucket` were removed from the schema in v4.0 (Feb 2022) and now produce an Unsupported-argument error at `terraform plan` long before OPA sees them. So our policies look at the paired resource type, not an inline attribute.

The `deny[msg]` syntax creates a rule that collects denial messages. If any deny rule matches, the policy fails. If no deny rules match, the policy passes.

**Caveat for instructors:** this simplified version only checks that AT LEAST ONE encryption resource exists in the plan, not that each specific bucket has its OWN paired encryption resource. For multi-bucket plans you need the pair-by-reference pattern we'll see in the encryption deep-dive — it looks up `enc.expressions.bucket.references` via `input.configuration` to match each bucket to its specific encryption partner."

---

## Section 2: Pipeline Integration (8 minutes)

[SLIDE: Chapter Concepts — OPA Integration in the Pipeline]

"Now let's see how OPA fits into the pipeline."

[SLIDE: Pipeline Integration Point]
- OPA runs after build, before the approval gate
- Evaluates the Terraform plan JSON
- Conftest is the wrapper that runs OPA in CI/CD
- Fails the pipeline immediately if violations found
- Detailed output names each violation and resource

"OPA validation happens after the build stage produces a Terraform plan. Before anyone approves the deployment, OPA evaluates the planned changes against the policies. If there are violations, the pipeline stops — no deployment happens.

We use Conftest to run OPA policies. Conftest is an OPA wrapper designed specifically for testing configuration files. It handles the input parsing and output formatting. You point it at your plan and your policy directory, and it returns pass/fail results."

[SLIDE: Build and Validate Phases]
- **Build phase:** `terraform init`, `terraform plan -out=tfplan`, `terraform show -json > tfplan.json`
- **Validate phase:** `conftest test tfplan.json -p /policies/terraform`
- Non-zero exit fails the pipeline

"Here's the buildspec flow split across two phases. The build phase runs `terraform plan` and converts the resulting binary plan file to JSON — that JSON is what OPA can read. The validate phase runs Conftest against that JSON, pointing at the policy directory mounted into the container. If any deny rules match, Conftest exits with a non-zero code and the pipeline fails. No human intervention — it's fully automated.

The policies directory is typically synced from the central policy Git repo before this phase runs, so policy updates roll out to every pipeline automatically."

[SLIDE: Reading Conftest FAIL Output]
```
FAIL - tfplan.json - main -
  Bucket 'myapp-data' missing encryption resource
FAIL - tfplan.json - main -
  Resource 'aws_s3_bucket.myapp_data'
  missing required tag: CostCenter

2 tests, 0 passed, 0 warnings, 2 failures
```

"When policies fail, Conftest outputs one line per failure. The format is: FAIL, filename, policy package, then the human-readable message. At the bottom is a summary — total tests, passed, warnings, failures. You need to fix all failures before the pipeline will pass.

Warnings appear but don't block — these are typically new policies still in their grace period. The structured `--output json` format is also available if you want the same information for dashboards or automation. This is the output students will see most often in Lab 3 and in real failures, so get comfortable reading it."

---

## Section 3: The Policy Library (8 minutes)

[SLIDE: Chapter Concepts — The OPA Policy Library]

[SLIDE: Policy Categories]
- Naming: resource names match `client-{env}-{app}-{purpose}`
- Encryption: S3, RDS, EBS, Aurora must encrypt at rest
- Tagging: 5 mandatory tags on every resource
- EKS: memory limits + approved ECR registry
- Lambda: timeout cap + VPC for confidential data

"The policy library covers these five categories. Some apply to all resources — naming, tagging. Others apply to specific resource types — encryption for S3, network policies for EKS. We'll deep-dive the encryption category on the next slide because it shows the modern Rego pattern. The other categories follow the same shape. Tagging is covered in detail in Chapter 7, so we won't duplicate it here."

[SLIDE: Encryption Policy (Paired-Resource Pattern)]
```rego
SSE := "aws_s3_bucket_server_side_encryption_configuration"

deny[msg] {
    bucket := input.resource_changes[_]
    bucket.type == "aws_s3_bucket"
    not has_paired_encryption(bucket.address)
    msg := sprintf("Bucket '%v' missing paired
      encryption resource", [bucket.address])
}

# Resolve pairing via configuration (preserves refs)
has_paired_encryption(addr) {
    enc := input.configuration.root_module.resources[_]
    enc.type == SSE
    ref := enc.expressions.bucket.references[_]
    startswith(ref, addr)
}
```

"Encryption at rest is mandatory. This is the stronger, multi-bucket-safe version of the policy we saw earlier. Two things are happening.

First, the `deny` rule walks every S3 bucket in the plan.

Second, the helper rule `has_paired_encryption` cross-references each bucket against the plan's `configuration` section to confirm a paired encryption resource references it by Terraform address.

Why look at `configuration` instead of `resource_changes`? Because at plan time, the encryption resource's `bucket` attribute resolves to `(known after apply)` — Terraform hasn't created the bucket yet, so it can't fill in the bucket ID. The `configuration` section preserves the *reference expression* (`aws_s3_bucket.example.id`), which is what we actually want to match.

Similar policies exist for RDS instances, EBS volumes, and any other resource that stores data."

[SLIDE: Other Policy Categories at a Glance]

**EKS Policies**
- Containers must declare memory limits
- Images must come from approved ECR registry
- Required Kubernetes labels enforced

**Lambda Policies**
- Timeout capped at 300 seconds
- DataClass=confidential requires VPC
- Reserved concurrency for critical paths

"Two more categories worth knowing about, but we won't deep-dive the Rego today.

EKS policies enforce that containers declare memory limits (so a runaway pod can't starve other workloads), that images come from the approved ECR registry (no Docker Hub pulls), and that required labels are present.

Lambda policies enforce a 300-second timeout cap, require VPC configuration when a function is tagged `DataClass=confidential`, and require reserved concurrency on the critical path.

The shape of these rules is the same as the encryption rule — walk `input.resource_changes`, check the attribute, emit a denial. If you want to read them, the policy repo is linked from the internal wiki."

---

## Section 4: Writing a Simple Rego Rule (4 minutes)

[SLIDE: Chapter Concepts — Writing a Simple Rego Rule]

[SLIDE: Writing a Simple Rego Rule]
- Same shape as encryption rule: package, `deny[msg]`, conditions, message
- All conditions must be true (AND logic) for deny to fire
- `sprintf` builds the human-readable failure message
- Test locally first: `conftest test test.json -p policies/`
- Submit new rules as PRs to the central policy repository

"Sometimes you need policies specific to your team or application — minimum replica counts for production, naming patterns particular to your app, custom tag values. The structure is identical to the encryption rule: package declaration, `deny` rule, conditions that must ALL be true (AND logic), and a `sprintf` message that names the violating resource.

Example use case: 'Production Kubernetes Deployments must have at least 3 replicas' — you'd check `input.kind == \"Deployment\"`, `input.metadata.labels.environment == \"production\"`, `input.spec.replicas < 3`, then sprintf the failure.

Your team can add rules like this — submit them as PRs to the central policy repository. Always test locally with `conftest test` before committing: create a sample input JSON, run the policy, verify both pass and fail scenarios. That's how you develop and debug policies before they hit the pipeline and block someone else."

---

## Summary and What's Next (2 minutes)

[SLIDE: Chapter Summary]
- Explained how OPA integrates into the pipeline as a pre-deployment gate
- Read Conftest FAIL output and identified the violation
- Identified the policy categories: naming, encryption, tagging, EKS, Lambda
- Recognised the modern paired-resource Rego pattern for AWS provider v4+

"You now understand how policy-as-code works in this environment. OPA evaluates your deployments against automated policies. When policies fail, the output tells you exactly what to fix. You can even write your own policies for team-specific requirements.

Next up is Chapter 7, where we cover the other guardrails: SCPs, tag policies, and AWS Config rules. These work alongside OPA but operate at different levels."

---

## Instructor Notes

**Key Points to Emphasize:**
- Policies are data, not code — they can be updated independently
- OPA runs pre-deployment, catching issues before resources are created
- All conditions in a rule use AND logic
- The modern paired-resource pattern matters because v4+ removed inline encryption
- Test policies locally before committing

**Common Questions:**
- "Can I bypass a policy?" — Emergency bypass exists but requires justification (covered in Chapter 8)
- "How do I request a new policy?" — Submit a PR to the policy repo, platform team reviews
- "What if a policy is wrong?" — Same path: PR with proposed fix

**Timing Notes:**
- Opening: 2 min
- Objectives: 2 min
- OPA + Rego: 8 min
- Pipeline Integration: 8 min
- Policy Library: 8 min
- Custom Rules: 4 min
- Summary + Q&A: 2 min — **Total: ~34 min** (target 30, with 4 min buffer absorbed in Q&A)
