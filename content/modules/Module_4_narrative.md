# Chapter 4: Lambda Deployment Pipelines — Teaching Narrative

**Duration:** 20 minutes

---

## Opening (1 minute)

"We've covered containerised deployments with EKS. Now serverless. Lambda is the platform for event-driven, serverless workloads — and just like everything else, Lambda deployments go through CI/CD pipelines.

Lambda is fundamentally different from EKS. No cluster, no nodes. You write code, package it, and AWS handles the rest. But that simplicity has its own deployment considerations: SAM templates, versions and aliases, and traffic shifting for safe rollout. Twenty minutes — let's go."

[SLIDE: Chapter 4 Title]

[SLIDE: Chapter Objectives]
- Deploy serverless applications using AWS SAM through CodeBuild pipelines
- Implement Lambda versioning and alias strategies for safe deployments
- Configure traffic shifting for canary and linear deployments
- Recognise the caveats that silently bypass traffic shifting

---

## Chapter Concepts — You Are Here (30 seconds)

[SLIDE: Chapter Concepts — highlight row 0]

"Four concepts: SAM, versioning + aliases, traffic shifting, then the caveats that bite teams in production."

---

## Section 1: AWS SAM Deployments (5 minutes)

[SLIDE: Serverless — Deployed via SAM]
- Event-driven workloads: S3, SQS, Kinesis, EventBridge, API Gateway
- Not for long-running processes (15-minute limit) — use EKS instead
- Standard: AWS SAM templates deployed by CodeBuild
- SAM extends CloudFormation with serverless-specific shorthand
- Same pipeline shape as everything else: build, OPA, approval, deploy

"Lambda is for event-driven workloads — something happens and Lambda runs code in response. If your process runs more than 15 minutes or needs persistent connections, use EKS instead.

For deployment, the standard is AWS SAM. SAM extends CloudFormation with simplified syntax for serverless resources — one resource type expands into the Lambda function, IAM role, and event sources. SAM also gives you `sam local` for laptop-side testing before pushing. The pipeline shape is the same as everything else we've covered: source, build, OPA validation, approval, deploy."

[SLIDE: SAM Template — Function with Traffic Shifting]
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Timeout: 30
    Runtime: python3.11
    MemorySize: 256

Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: app.handler
      AutoPublishAlias: prod
      DeploymentPreference:
        Type: Canary10Percent5Minutes
```

"This is the smallest SAM template that does something interesting. The `Transform` line tells CloudFormation to process this as a SAM template. `Globals` sets defaults — 30-second timeout, Python 3.11, 256 MB memory — that any function inherits. The function itself uses `Type: AWS::Serverless::Function`, which expands into a Lambda function plus IAM role plus event sources, about 50 lines of raw CloudFormation under the hood.

The two lines that matter for safe deployment are `AutoPublishAlias` and `DeploymentPreference`. `AutoPublishAlias` creates the `prod` alias and updates it on every deploy. `DeploymentPreference` controls how traffic shifts to the new version — we'll cover the shifting types in two slides."

[SLIDE: Build and Deploy in CodeBuild]
```yaml
# buildspec.yml
phases:
  install:
    commands: [ pip install aws-sam-cli ]
  build:
    commands:
      - sam build
      - sam package \
          --output-template-file packaged.yaml \
          --s3-bucket $ARTIFACT_BUCKET
  post_build:
    commands:
      - sam deploy \
          --template-file packaged.yaml \
          --stack-name $STACK_NAME \
          --capabilities CAPABILITY_IAM \
          --no-fail-on-empty-changeset
```

"Install phase: installs the SAM CLI (pin a specific runtime version in real CodeBuild images). Build phase: `sam build` (compile + dependencies) and `sam package` (upload code to S3, produce a packaged template). Post-build: `sam deploy` against the packaged template.

Two callouts. First: `CAPABILITY_IAM` only *acknowledges* that the template creates IAM resources — it does NOT grant permissions. The pipeline role's own IAM policy (which itself is reviewed) constrains what those resources can do, and SCPs apply on top. `CAPABILITY_IAM` is an acknowledgement, not a grant.

Second: `--no-fail-on-empty-changeset` prevents the build from failing on re-runs when nothing changed. In real templates, `--parameter-overrides Environment=$ENVIRONMENT` passes per-environment values into template parameters — log level, VPC settings, memory."

---

## Section 2: Lambda Versioning and Aliases (4 minutes)

[SLIDE: Chapter Concepts — highlight row 1]

[SLIDE: Lambda Versions and Aliases]
- `$LATEST` is mutable — changes every deploy
- Published versions are immutable snapshots (1, 2, 3, ...)
- Alias = named pointer to a version (e.g., `prod` → version 5)
- Deploy new code → publish version N → update alias to N
- Rollback = update alias back to version N-1

"By default, when you update a Lambda function you update `$LATEST`, which is mutable. But you can publish a version, which creates an immutable snapshot. Once version 1 exists, its code never changes.

Aliases are named pointers to a specific version. The `prod` alias might point to version 5. When you deploy version 6 and verify it works, you update `prod` to point to version 6. If something goes wrong, you flip `prod` back to version 5. That alias flip *is* your rollback — no redeploy needed.

This is why event sources — API Gateway, SQS triggers, S3 triggers — should always reference the alias ARN, not the function ARN or `$LATEST`. The alias is the stable contract."

---

## Section 3: Traffic Shifting and Auto-Rollback (4 minutes)

[SLIDE: Chapter Concepts — highlight row 2]

[SLIDE: Traffic Shifting Types]

| Type | Behaviour |
|------|-----------|
| Canary10Percent5Minutes | 10% for 5 min, then 100% |
| Canary10Percent30Minutes | 10% for 30 min, then 100% |
| Linear10PercentEvery1Minute | 10% increase every minute |
| AllAtOnce | Immediate 100% shift (dev only) |

"Canary shifts a small percentage of traffic to the new version, waits, then completes. Linear gradually increases traffic over time. AllAtOnce is immediate and is only appropriate for dev environments.

Production deployments typically use `Canary10Percent5Minutes` or slower — we want time to detect issues. The slower the shift, the more invocations you get to observe new-version error rates and latency before all traffic moves over.

Pair this with CloudWatch alarms on the alias: if the canary alarm fires during the shift window, CodeDeploy automatically rolls the alias back to the previous version. That auto-rollback is the whole reason canary shifting exists — catch a bad deploy with 10% blast radius, not 100%."

---

## Section 4: Deployment Caveats (4 minutes)

[SLIDE: Chapter Concepts — highlight row 3]

[SLIDE: Deployment Caveats — What Bypasses Shifting]
- **Bypass risks:** unqualified function ARN invokes skip alias weights; explicit `:$LATEST` invokes go straight to newest code; `AuthType: NONE` on Function URLs blocked by OPA
- **Other limits:** ZIP + layers must stay under 250 MB total; need bigger? container image packaging (up to 10 GB); `CAPABILITY_IAM` acknowledges, does not grant

"These are the gotchas that bite teams in production.

First and most important: traffic shifting only applies to invokes that hit the alias ARN. If a caller hits the unqualified function ARN or explicitly invokes `:$LATEST`, the shifting weights are bypassed entirely — that caller goes straight to `$LATEST`, silently making your canary an all-at-once deploy for them. That's why we enforce 'always reference the alias' as a deployment rule.

Second: OPA policy blocks `AuthType: NONE` on Function URLs for any non-public namespace. Either use `AWS_IAM` or front the URL with an authoriser. `NONE` is for intentionally-public webhooks only.

Third: the ZIP + Layers limit is 250 MB unzipped. If your function genuinely needs more — large ML models, bundled binaries — switch to Lambda container-image packaging instead. Container images support up to 10 GB; layers are not the right escape hatch.

Fourth, repeating from the buildspec slide: `CAPABILITY_IAM` is an acknowledgement that the template creates IAM, not a grant of permission to do anything."

---

## Summary and What's Next (1 minute)

[SLIDE: Chapter Summary]
- Deployed serverless applications using AWS SAM through CodeBuild pipelines
- Implemented Lambda versioning and alias strategies for safe deployments
- Configured canary and linear traffic shifting with auto-rollback
- Identified the caveats that silently bypass traffic shifting

"That's Lambda deployment. SAM as the standard template. Versions are immutable, aliases are mutable pointers — that's how safe rollouts work. Traffic shifting plus a CloudWatch alarm gives you auto-rollback. And the caveats — `$LATEST`, unqualified ARNs, AuthType NONE, the 250 MB limit — are the ones to remember.

Lab 2 walks you through a SAM deployment with canary shifting end to end. Next up is Chapter 5: schema migrations for Aurora — different problem class, same pipeline-driven philosophy."

---

## Instructor Notes

**Key Points to Emphasise:**
- Always reference the alias ARN — `$LATEST` and unqualified ARNs bypass traffic shifting silently
- `CAPABILITY_IAM` is acknowledgement, not authorisation
- 250 MB limit on ZIP + layers — past that, use container images
- Canary + CloudWatch alarm = auto-rollback

**Common Questions:**
- "Can I update a published version?" — No, versions are immutable; publish a new one
- "How do I roll back?" — Update the alias to point to the previous version
- "What if traffic shifting fails?" — CloudWatch alarms trigger CodeDeploy auto-rollback

**Timing Notes (20 minutes):**
- Opening + objectives: 2 min
- SAM: 5 min
- Versioning + aliases: 4 min
- Traffic shifting: 4 min
- Caveats: 4 min
- Summary: 1 min
