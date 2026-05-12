# IO-107: SDLC Pipeline & Deployment Guardrails

**Status:** Testing scaffold — will be moved to a permanent location once labs are validated end-to-end.

This umbrella repo holds the lab code and supporting materials for IO-107, a one-day course on shipping code through an enterprise SDLC pipeline. The course covers Service Catalog-driven Terraform, the orchestration tool mix (Jenkins / CloudBees / AWS CodePipeline / AWS CodeDeploy), and deployment patterns for EKS, Lambda, and Aurora with OPA / SCP / tag-policy guardrails.

## Course shape

- **Duration:** 1 day, 6.5 hr content (8 hr classroom day with lunch + breaks)
- **8 lecture modules** + **4 hands-on labs**
- Audience: cloud engineers, DevOps engineers, application developers, infrastructure operators

See `course_outline.md` for the authoritative module + lab list, durations, and learning objectives.

## Repo layout

```
IO-107/
├── README.md                       # this file
├── course_outline.md               # canonical course outline
├── content/                        # source course materials (modules, labs, deliverables)
├── docs/
│   └── links.md                    # Google Slides + Google Docs URLs for review
└── labs/
    ├── io107-lab1-eks-app/             # End-to-End EKS Deployment Pipeline
    ├── io107-lab2-sam-app/             # Lambda Deployment with SAM
    ├── io107-lab3-policy-violations/   # Policy-as-Code Evaluation & Remediation
    └── io107-lab4-aurora-bluegreen/    # Aurora Blue/Green via Terraform
```

Directory names under `labs/` match the `git clone` target names in each lab guide. When SYF spins up individual delivery repos, the path students see locally is consistent.

Each `labs/<lab>/` directory will hold the application code, Terraform / Helm / SAM / Rego files, and `buildspec.yml` that the lab guide references.

## Current state

| Asset | Status |
|---|---|
| Module slides (8) | ✅ Generated (Google Slides — see `docs/links.md`) |
| Lab guides (4) | ✅ Authored (Google Docs — see `docs/links.md`) |
| Deliverables (5: facilitator guide, KC bank, pre-course, ref sheet, marketing) | ✅ Authored (Google Docs — see `docs/links.md`) |
| Lab code (Terraform / Helm / SAM / Rego) | ✅ Authored — see `labs/io107-lab*/` |
| Training-account infrastructure (EKS cluster, Aurora cluster, CodePipeline, IAM roles, secrets) | 🔧 **Pending** — provisioned out-of-band by platform team |

## Why this repo exists

This repo is the **single source of truth for lab code**. The lab markdown guides (Google Docs) reference paths like `charts/myapp/values.yaml` and `scenario1-region/main.tf`; those files live in this repo under the appropriate `labs/<lab>/` subdirectory.

Once a lab's code is authored, the relevant `labs/<lab>/` subtree is typically split out into its own per-lab repo for the actual classroom delivery — but for testing and iteration, keeping everything in one umbrella repo is faster.
