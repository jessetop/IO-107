# Module 7: SCPs, Tagging Guardrails & AWS Config Rules — Teaching Narrative

**Duration:** 25 minutes (trimmed from 45 min per v3 outline)

---

## Opening (2 minutes)

"In Chapter 6, we covered OPA — policy-as-code that validates your deployments *before* they happen. But OPA isn't the only guardrail. We have multiple layers of protection, each operating at a different level.

This chapter covers three additional guardrails: Service Control Policies that restrict what's even *possible* in your AWS account, tag policies that enforce consistent tagging, and AWS Config rules that continuously monitor compliance.

Think of it as defense in depth. OPA catches issues in the pipeline. SCPs prevent unauthorized actions at the API level. Tag policies enforce metadata standards. Config rules detect drift after deployment."

[SLIDE: Chapter 7 - SCPs, Tagging Guardrails and AWS Config Rules]

---

## Module Objectives (2 minutes)

[SLIDE: Chapter Objectives]
- Explain how SCPs restrict actions within AWS accounts
- Recognise the three main SCP categories
- Identify the mandatory tags and tag policy enforcement
- Understand AWS Config rules as the detective compliance layer

---

## Section 1: Service Control Policies (10 minutes)

[SLIDE: Chapter Concepts — Service Control Policies (SCPs)]

[SLIDE: Service Control Policies in AWS Organizations]
- JSON in AWS Organizations — attached to OUs or accounts
- Set maximum permissions — define the ceiling, cannot grant, only restrict
- Apply to all principals including root, admins, and pipeline roles
- Intersection logic: Effective perms = IAM Allow INTERSECT SCP Allow

"SCPs are attached to organizational units or individual accounts in AWS Organizations. They define the maximum permissions any principal in that account can have. Even with Administrator access, if an SCP denies an action, you cannot perform it.

The key distinction: SCPs don't grant permissions — IAM policies do that. SCPs restrict what permissions are *effective*. Think of it as a ceiling — your IAM permissions can go up to that ceiling but never through it.

Effective permissions are the intersection of IAM Allow and SCP Allow. If IAM grants but SCP denies, the result is deny. If SCP allows but IAM doesn't grant, the result is also deny. Both must allow.

This applies to pipeline execution roles too — your CodeBuild service role is subject to SCPs just like a human user. SCP-blocked deployments fail at the *deploy* stage, not at OPA, because SCPs evaluate when the actual API call is made."

[SLIDE: Region Restriction SCP]
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyOutsideApprovedRegions",
    "Effect": "Deny",
    "NotAction": [
      "iam:*", "cloudfront:*", "route53:*",
      "support:*", "organizations:*",
      "sts:GetCallerIdentity"
    ],
    "Resource": "*",
    "Condition": {
      "StringNotEquals": {
        "aws:RequestedRegion": ["us-east-1", "us-west-2"]
      }
    }
  }]
}
```

"This SCP restricts actions to approved regions — us-east-1 and us-west-2. Any attempt to create resources in other regions will be denied. This addresses data residency requirements and simplifies our operational footprint.

**Critical detail:** `aws:RequestedRegion` does NOT evaluate for global services — IAM, CloudFront, Route 53, Organizations, STS in non-regional mode, AWS Support. Without the `NotAction` carve-out shown here, this SCP locks the account out of IAM itself and breaks everything. A real region-restriction SCP must include this `NotAction` list. Don't deploy a region SCP without that carve-out."

[SLIDE: Service Restriction SCP]
- Effect: Deny on Action list (e.g. `braket:*`, `gamelift:*`, `groundstation:*`)
- Even with IAM permission, the API call is rejected
- Reduces attack surface and prevents shadow IT
- The real list covers every service outside the approved portfolio
- Need a blocked service? Request via platform team, not bypass

"This SCP denies specific AWS services that aren't in the approved portfolio. The structure is simple: `Effect: Deny` on an Action list, `Resource: \"*\"`. Even if someone has IAM permissions for GameLift, the SCP blocks the API call before it gets evaluated.

A real service-restriction SCP is longer — it lists every service outside the approved portfolio (which you saw in Chapter 1: EKS, Lambda, S3, RDS, Aurora, plus a handful of supporting services like KMS, CloudWatch, IAM, Secrets Manager). If you need a service that's currently blocked, work with the platform team rather than try to bypass it."

[SLIDE: Root Account Protection SCP]
```json
{
  "Sid": "ProtectRootAccount",
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringLike": {
      "aws:PrincipalArn": "arn:aws:iam::*:root"
    }
  },
  "NotAction": [
    "iam:CreateVirtualMFADevice",
    "iam:EnableMFADevice",
    "sts:GetSessionToken"
  ]
}
```

"The root account is too powerful to use for regular operations. This SCP denies almost all actions for the root user, except setting up MFA. Root should only be used for the handful of account-recovery scenarios that genuinely require it — closing the account, changing root email, certain billing operations.

Day-to-day work happens through federated roles with appropriate scope. If you see root used in CloudTrail, that's an incident signal."

---

## Section 2: Tagging Guardrails (6 minutes)

[SLIDE: Chapter Concepts — Mandatory Tags and Tag Policies]

[SLIDE: Mandatory Tags and Tag Policy Enforcement]

| Tag | Purpose | Example Values |
|-----|---------|----------------|
| Environment | Lifecycle stage | dev, stg, prd |
| Application | Application name | payment-api |
| Owner | Responsible team email | platform-team@client.com |
| CostCenter | Financial code | CC-12345 |
| DataClass | Data sensitivity | public, internal, confidential |

"These five tags are required on all taggable resources. Missing any of them will fail the OPA policy check from Chapter 6 — that's the build-stage enforcement.

There's also a second enforcement layer: tag policies in AWS Organizations. Tag policies define the canonical tag keys and the allowed values. Unlike OPA which runs before deployment, tag policies apply continuously. If someone manages to bypass the pipeline (which they shouldn't) and creates a resource with `Environment=test` instead of `dev/stg/prd`, tag policies flag it in the Organizations console.

So you get pre-deploy enforcement from OPA and post-deploy enforcement from tag policies — defence in depth on the same requirement.

Why mandatory tags? Cost allocation: when the bill comes, CostCenter says which team is responsible. Ownership: when something breaks at 2 AM, Owner is who we page. Environment: tells you whether a resource is safe to modify. DataClass: drives Lambda VPC policy, S3 bucket policy, and retention rules."

---

## Section 3: AWS Config and Failure-Stage Signatures (5 minutes)

[SLIDE: Chapter Concepts — AWS Config as Detective Control]

[SLIDE: AWS Config — The Detective Layer]
- Continuously records resource configurations
- Evaluates each resource against Config rules
- Marks resources COMPLIANT or NON_COMPLIANT in real time
- Catches drift: manual changes, role assumption, console edits
- Key rules: encryption, public access, required tags

"AWS Config is the post-deployment compliance layer — the detective control after OPA's preventive layer and tag policies' organizational layer.

Config continuously records the configuration of every resource in scope. Config rules evaluate those configurations against desired states — `s3-bucket-server-side-encryption-enabled`, `rds-storage-encrypted`, `eks-cluster-log-enabled`, `required-tags`, and others. Each resource is marked COMPLIANT or NON_COMPLIANT.

This catches drift — if someone bypasses the pipeline and makes a manual change, or a role gets assumed and a setting flipped, Config detects it.

AWS provides managed rules for common checks; the platform team also maintains custom rules backed by Lambda for organisation-specific requirements. Remediation can be manual or automated via Systems Manager documents — auto-remediation is used carefully because changing resources automatically can have unintended consequences in production."

[SLIDE: Chapter Concepts — Failure-Stage Signatures]

[SLIDE: Failure-Stage Signatures]

**Build Stage**
- OPA: Conftest FAIL — missing tags, naming, encryption
- Fix in Terraform, push, re-run pipeline

**Deploy Stage**
- AccessDenied + 'service control policy' = SCP
- AccessDenied + 'not authorized' = IAM
- Tag-policy violation: invalid value (not just missing)

"This is the punchline of the whole guardrails picture — where each layer surfaces a failure.

Build stage failures are OPA: the Conftest FAIL output you saw in Chapter 6 — missing tags, naming violations, encryption resources absent. Fix the Terraform, push, re-run.

Deploy stage failures look different. SCP denials show `AccessDenied` plus 'explicit deny in a service control policy' — the SCP blocked the API call. IAM denials show `AccessDenied` plus 'not authorized' — the pipeline role lacks the permission. Tag-policy violations at deploy time show 'tags did not match required values' — this is the canonical-case/allowed-value check from the tag policy, not OPA.

And then post-deploy, AWS Config will mark resources NON_COMPLIANT if something drifts.

Recognising which layer fired tells you immediately where to look in Chapter 8."

---

## Summary and What's Next (2 minutes)

[SLIDE: Chapter Summary]
- Explained how SCPs create hard limits on account capabilities
- Recognised the three main SCP categories (region, service, root)
- Identified the mandatory tags and tag policy enforcement
- Understood AWS Config as the detective compliance layer

"You now understand the full guardrail picture. OPA for pre-deployment validation. SCPs for organizational boundaries. Tag policies for consistent metadata. Config rules for continuous monitoring.

Next up is Chapter 8 — troubleshooting. You'll learn how to diagnose whether a failure is an OPA violation, an SCP denial, a tagging issue, or something else."

---

## Instructor Notes

**Key Points to Emphasize:**
- SCPs are hard limits — no way to exceed them from within the account
- The region SCP needs `NotAction` for global services or it bricks the account
- Tag policies complement OPA — both enforce, at different times
- Config is continuous; catches drift after deployment

**Common Questions:**
- "How do I know what SCPs apply to my account?" — Platform team can show; also viewable in Organizations console
- "Can I request an SCP exception?" — Yes, exception process covered in Chapter 8
- "What if Config says non-compliant but I can't find the issue?" — Check the Config resource timeline for what changed and when

**Timing Notes:**
- Opening: 2 min
- Objectives: 2 min
- SCPs: 10 min
- Tagging: 6 min
- Config + Failure Signatures: 5 min
- Summary: 2 min — **Total: ~27 min** (target 25 with 2 min absorbed in Q&A)
