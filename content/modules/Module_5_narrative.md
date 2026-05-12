# Chapter 5: Aurora Schema Migrations via Pipelines — Teaching Narrative

**Duration:** 20 minutes

---

## Opening (1 minute)

"We've covered deploying applications to EKS and Lambda. Applications don't exist in isolation — they have data, and that data lives in databases. The relational data here lives in Aurora and RDS.

Here's the challenge: database changes are fundamentally different from application deployments. If you deploy a bad Lambda, you flip the alias and you're back where you started. If you deploy a bad schema migration, you've altered the structure of your production data. Much harder to undo. This chapter is process-focused: how schema changes flow through pipelines, the Secrets Manager + Flyway pattern, and a preview of the Aurora Blue/Green workflow you'll exercise in Lab 4. Twenty minutes."

[SLIDE: Chapter 5 Title]

[SLIDE: Chapter Objectives]
- Explain why schema changes are stateful and require pipeline-driven control
- Describe how SQL migrations apply through CodeBuild
- Use the `env.secrets-manager` pattern for Flyway credentials
- Preview the Aurora Blue/Green Terraform workflow for Lab 4

---

## Chapter Concepts — You Are Here (30 seconds)

[SLIDE: Chapter Concepts — highlight row 0]

"Four concepts: why schema changes are different; the migration pattern end to end; Secrets Manager + Flyway; and a Lab 4 preview of Aurora Blue/Green via Terraform."

---

## Section 1: Why Schema Changes Are Different (3 minutes)

[SLIDE: Schema Changes Are Stateful — Rollbacks Are Hard]
- Deploy a bad Lambda? Roll back in seconds — stateless
- Run an `ALTER TABLE` that drops a column? That data is gone
- Add a NOT NULL column without a default? All inserts start failing
- Manual SQL via a client = no audit trail, no reproducibility
- Financial data demands the strictest change control

"Open with the framing: schema changes are fundamentally different from application deployments because they touch persistent data.

A bad Lambda is a 30-second alias flip back to the previous version. A bad `ALTER TABLE` that drops a column is gone — the data does not come back. Adding a NOT NULL column without a default value silently breaks every INSERT until you fix it. And someone connecting to production with a SQL client and running commands manually is the worst case: no review, no audit trail, no way to reproduce the change in another environment. For financial data that's unacceptable.

This is why every schema change goes through the pipeline. The pipeline gives you version control on the SQL, the same migration runs in dev, staging, and production, and there's a complete record of every change."

---

## Section 2: The Migration Pattern (5 minutes)

[SLIDE: Chapter Concepts — highlight row 1]

[SLIDE: How Schema Changes Are Handled — Infrastructure / Schema]
- **Infrastructure side:** Terraform changes the RDS/Aurora cluster; pipeline picks it up: plan, OPA, approval, apply; engine version, parameter group, topology
- **Schema side:** SQL files (`V1__...`, `V2__...`) in the app repo; CodeBuild runs `flyway info` → `migrate` → `info`; forward-fix is the default rollback model

"This is the pattern end to end.

The infrastructure side — engine version, parameter group, cluster topology — is managed by Terraform. When you commit a Terraform change to the RDS/Aurora cluster, the same pipeline shape you already know picks it up: build, OPA, approval, apply.

The schema side — DDL changes — lives as SQL files in your application repository, named with the Flyway convention so they apply in order. A CodeBuild stage runs `flyway info` to show current state, `flyway migrate` to apply pending changes, and `flyway info` again to confirm.

For rollback, the default model is forward-fix: if V3 caused a problem, you deploy V4 to fix it. Forward-fix preserves the migration history and is easier to reason about than undo migrations, which have data-loss limitations of their own. The no-direct-access rule applies on top — we close the chapter on that."

---

## Section 3: Secrets Manager + Flyway (5 minutes)

[SLIDE: Chapter Concepts — highlight row 2]

[SLIDE: Flyway in CodeBuild — The Secrets Manager Pattern]
```yaml
env:
  secrets-manager:
    FLYWAY_URL: "prod/mydb/url"
    FLYWAY_USER: "prod/mydb/username"
    FLYWAY_PASSWORD: "prod/mydb/password"

phases:
  install:
    commands:
      - wget -qO- \
          https://.../flyway-commandline.tar.gz \
          | tar xvz
  build:
    commands:
      - flyway info
      - flyway migrate
      - flyway info
```

"This is the only Flyway buildspec slide in the chapter — and it's the one that matters because it's the security-correct pattern Lab 4 uses end to end.

Notice what is NOT on the command line: no `-url`, no `-user`, no `-password` flags. CodeBuild's `env.secrets-manager` block pulls the values from AWS Secrets Manager at the start of the build and injects them as environment variables. Flyway natively reads `FLYWAY_URL`, `FLYWAY_USER`, and `FLYWAY_PASSWORD` from the environment — no flag mapping needed.

Result: the password never appears on a command line. It's not in `ps` output, it's not in CodeBuild's per-command log captures, it's not in the buildspec file in Git. It only exists in the build process's environment block.

Compare this to the alternative — pulling secrets with `aws secretsmanager get-secret-value`, parsing with `jq`, exporting manually, then passing on the flyway command line. Every step there is a leak risk. `env.secrets-manager` is shorter AND safer. This is the pattern Lab 4 exercises."

[SLIDE: Flyway Commands Used in the Pipeline]

| Command | When the Pipeline Runs It |
|---------|---------------------------|
| `flyway info` | Before migrate — shows what is pending |
| `flyway migrate` | Build stage — applies pending V-files in order |
| `flyway info` | After migrate — confirms success and final state |

"Three commands. That's the entire Flyway surface you need.

`flyway info` first — shows the current state of the `flyway_schema_history` table and which migrations are pending. `flyway migrate` — applies the pending V-files in version order. `flyway info` again — confirms the final state. The build log captures all three, which becomes your audit trail.

Other Flyway commands exist (`baseline`, `validate`, `repair`) but you won't run them in the pipeline — those are platform-team operations for fixing history-table issues or onboarding an existing database, and they happen out-of-band with security approval. Treat the pipeline as info/migrate/info, full stop."

---

## Section 4: Aurora Blue/Green via Terraform — Lab 4 Preview (4 minutes)

[SLIDE: Chapter Concepts — highlight row 3]

[SLIDE: Aurora Blue/Green via Terraform — Lab 4 Preview]
- Lab 4: you change one Terraform attribute on the Aurora cluster
- `aws_rds_cluster` resource gains a `blue_green_update` block
- Pipeline picks up the Terraform change — plan, OPA, approval, apply
- Aurora creates the green cluster, logical replication keeps it in sync
- Switchover under a minute typically; only proceeds when lag is zero
- You observe blue + green clusters and the switchover in AWS CloudTrail

"This slide sets up Lab 4.

The blue/green pattern is how Aurora handles schema changes that would normally lock tables for minutes or hours — like adding an index to a billion-row table — without taking the application down. Conceptually: Aurora creates a green copy of your production cluster, logical replication keeps green in sync with blue, you apply schema changes to green while blue keeps serving traffic, then you switchover and green becomes the new blue.

What makes this *our* pattern is that you don't call the AWS RDS APIs directly. You modify Terraform — specifically the `aws_rds_cluster` resource gets a `blue_green_update` block — and commit. The pipeline does the rest: `terraform plan`, OPA validates the change, approval gate for production, `terraform apply`. Aurora then orchestrates the green cluster creation, sync, and switchover.

One realistic-expectation note: switchover is typically under a minute for low-write workloads, but for write-heavy clusters it can be longer because Aurora only proceeds once replication lag has reached zero. Plan for that window. In Lab 4 you'll make this Terraform change yourself and watch the switchover event land in CloudTrail."

[SLIDE: No Direct Database Access — Standing / Emergency]
- **Standing access:** no standing credentials to production DBs; all schema changes flow through the pipeline; no exceptions for senior engineers
- **Emergency access:** requires security team approval; session is recorded end to end; audit trail feeds the post-incident review

"Close the chapter by reinforcing the access model.

Nobody on the engineering teams has standing credentials to connect a SQL client to a production Aurora cluster. That's by design and it's non-negotiable for financial data. Every schema change goes through the pipeline, which means every change is reviewed, OPA-validated, approval-gated, and CloudTrail-logged.

Emergency access does exist for real outage scenarios — for example, when you need to read production state to diagnose an active incident. But it requires security team approval, the session is recorded, and the audit trail becomes part of the post-incident review.

Frame this for students: the audit trail isn't a bureaucratic hurdle, it's the compliance evidence regulators look at. The pipeline pattern gives you that evidence automatically; the emergency-access pattern gives you that evidence with extra friction so it stays rare."

---

## Summary and What's Next (1 minute)

[SLIDE: Chapter Summary]
- Explained why schema changes are stateful and require pipeline-driven control
- Described how SQL migrations apply through CodeBuild
- Used the `env.secrets-manager` pattern to keep passwords off command lines
- Previewed the Aurora Blue/Green Terraform workflow for Lab 4

"That's the schema-migration story. Schema changes are stateful — they need pipeline control. Terraform owns the infrastructure side; SQL files run through Flyway own the schema side. The `env.secrets-manager` pattern keeps the password out of every place a password could leak. And the Aurora Blue/Green pattern — driven by one Terraform attribute — is what makes zero-downtime schema changes possible.

Lab 4 is where you exercise the Blue/Green flow end to end. Next up is Chapter 6: Policy-as-Code with OPA — we've referenced OPA validation throughout, now we'll see how it actually works."

---

## Instructor Notes

**Key Points to Emphasise:**
- Schema changes touch persistent data — there's no equivalent of an alias flip rollback
- Forward-fix is the default rollback model, not undo migrations
- `env.secrets-manager` keeps the password off command lines, out of `ps`, and out of build logs
- Aurora Blue/Green is driven by a single Terraform attribute — no direct RDS API calls

**Common Questions:**
- "What if the migration takes hours?" — Blue/green is the answer; that's what Lab 4 covers
- "Can I just connect with a SQL client for a quick fix?" — No. Emergency access exists but is gated by security approval and recorded
- "What about Liquibase?" — Out of scope here; the standard pattern is Flyway via Secrets Manager

**Timing Notes (20 minutes):**
- Opening + objectives: 2 min
- Why schema changes are different: 3 min
- Migration pattern: 5 min
- Secrets Manager + Flyway: 5 min
- Aurora Blue/Green preview: 4 min
- Summary: 1 min
