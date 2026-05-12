# Course Pipeline Checklist: IO-107 SDLC Pipeline & Deployment Guardrails

**Course ID:** IO-107
**Last Updated:** 2026-05-12
**Status:** [ ] Not Started | [ ] In Progress | [x] **Content complete — lab infra setup pending on SYF side**

**Outline version:** v3 (8 modules + 4 labs, 6.5 hr cap)
**GitHub testing repo:** https://github.com/jessetop/IO-107

---

## Stage 0: Reference Documentation — DONE

- [x] Official AWS docs URLs in `CLAUDE.md`
- [x] `facts_extracted_v2.md` populated and user-approved
- [x] Course `CLAUDE.md` with Approved Repositories section pointing at `jessetop/IO-107`

## Stage 1: Course Outline — DONE

- [x] v1 outline (archived)
- [x] v2 outline with v2 gap content (archived to `course_outline_v2.md`)
- [x] **v3 outline** (`course_outline_v3.md`) — scope-cut to 6.5 hr, refocused on process over tool internals, added Service Catalog + Jenkins/CloudBees framing, removed all `[Client]` placeholders

## Stage 2: Teaching Narratives — DONE

### 8 module narratives (`content/narratives/Module_{1..8}_narrative.md`)
- [x] All 8 trimmed to v3 durations (30 + 15 + 40 + 20 + 20 + 30 + 25 + 30 = 210 min)
- [x] `[Client]` removed everywhere
- [x] Mod 1 reframed: Pipeline Architecture + Service Catalog + Jenkins/CloudBees/CodeDeploy
- [x] Mod 2 reframed: Anatomy of a Pipeline Run using S3 (not S3-features)
- [x] Mods 3, 4, 5 v3-aligned (process-focus rewrite)
- [x] Mod 5 process-focused: drops Liquibase + Aurora Cloning + Flyway tutorial
- [x] Mod 8 absorbs former Mod 9 wrap-up content

### 3 active lab narratives (Lab 1, 2, 3)
- [x] Lab 4 narrative (Flyway version) archived to `_archive_v2_scope_cut/`
- [x] Lab 5 narrative archived

## Stage 3: Slide JSONs — DONE

### 8 module slide JSONs (`slide_json/Module_{1..8}_slides.json`)
- [x] 107 slides total (Mod 3: 21 incl. Helm code split, all others unchanged from agent-reported counts)
- [x] All PASS `audit_native_layouts.py` including the **new strict rules**:
  - `title_only` table/cards/callout_boxes/objectives length checks
  - `code` strict 14-line ceiling
  - `content`/`objectives`/`summary` bullet count + length checks
- [x] All PASS `audit_deck_style.py` (font + spacing)
- [x] All PASS `audit_deck_overflow.py` (body autofit)

### Auditor bugs found and patched this run
- [x] `title_only` layouts had no checks at all
- [x] Unicode (`→`, em-dashes) caused audit script to crash silently on Windows cp1252
- [x] `code` `visual_budget` was `max(N+1, N*1.3)` — too generous; now strict
- [x] `content`/`objectives`/`summary` layouts had no bullet checks at all

## Stage 4: Google Slides — DONE

- [x] All 8 module decks generated in `roi_syf` template, in folder `1RHTmkxdyWQMi3WVp8bJGKmmuFkv0mciy`
- [x] URLs recorded in `slides/google_slides_links.md`

## Stage 5: Lab Guides — DONE

- [x] Lab 1 (60 min, EKS) — authored via LabForge, citations, [client-org] placeholder repo URL
- [x] Lab 2 (45 min, Lambda SAM) — authored via LabForge
- [x] Lab 3 (45 min, OPA) — authored via LabForge
- [x] Lab 4 v2 (30 min, Aurora Blue/Green via Terraform) — authored via LabForge (replaces Flyway version)
- [x] Lab 5 — dropped in v3 scope cut (archived)
- [x] All 4 active labs PASS `lab_linter.py`
- [x] `[Client]` removed; `[client-org]/[repo-name]` placeholders preserved per LabForge policy

## Stage 5b: Lab Code Repos — DONE (testing scaffold)

- [x] `labforge_iterations/repo_additions/io107-lab1-eks-app/` — 13 files (Flask app, Dockerfile, Helm chart, buildspec)
- [x] `labforge_iterations/repo_additions/io107-lab2-sam-app/` — 8 files (SAM template, src, tests, buildspec)
- [x] `labforge_iterations/repo_additions/io107-lab3-policy-violations/` — 13 files (TF with 8 violations, 5 Rego policies, K8s manifest, buildspec)
- [x] `labforge_iterations/repo_additions/io107-lab4-aurora-bluegreen/` — 9 files (Aurora TF at engine 15.4, engine_version_pin Rego, buildspec, CloudTrail samples)
- [x] All 4 lab subtrees pushed to `https://github.com/jessetop/IO-107` under `labs/`
- [x] `verify_repo_code.py`: files present in `repo_additions/` (PENDING_PUSH status normal pre-fetch); some MISSING entries are script `cwd` tracking quirks not real gaps
- [ ] **SYF-side: provision real per-lab repos** under `[client-org]/`, replace `[client-org]/[repo-name]` placeholders in lab guide markdown
- [ ] **SYF-side: provision training AWS infra** (EKS cluster, Aurora cluster, CodePipeline+CodeBuild, IAM roles, Secrets Manager secrets)

## Stage 6: Deliverables — DONE

### 5 deliverable markdown files (`deliverables/md/`)
- [x] `facilitator_guide.md` — 5183 → ~4124 words after v3 regen
- [x] `knowledge_check_bank.md` — 17 questions across 4 labs (module decks still have 0 KC slides — known gap)
- [x] `pre_course_assessment.md` — 20 self-assessment questions
- [x] `student_reference_sheet.md` — kubectl/Helm/SAM/Terraform Blue/Green quick-ref
- [x] `marketing_one_pager.md` — 6.5 hr / 4-lab / Aurora Blue/Green outcome

## Stage 6b: Google Docs — DONE

- [x] 4 lab Google Docs generated via `labforge/python/generate_lab_docs.py`
- [x] 5 deliverable Google Docs generated via `python/google_docs_generate.py`
- [x] URLs recorded in `deliverables/google_docs_links.md`
- [x] Lab + deliverable Drive folder: `1SEWFlLi-BNCP1td-b_c-PXmTJHZhjUFd`

## Stage 7: PDFs — **SKIPPED per user instruction**

Google Docs are the canonical student-facing artifact. PDF export deferred indefinitely.

## Stage 8: Validation — DONE

### Round 1 (2026-05-11) — 8 personas reviewed; surfaced 4 BLOCKERs + 26 WARNs across reviewers

### Round 2 (2026-05-12) — all BLOCKERs fixed + 7 new WARNs found and fixed
- [x] All Skeptical Expert BLOCKERs + 15/16 WARNs fixed (W16 Helm `curl|bash` retains teaching-shortcut disclaimer)
- [x] Compliance/Security 2/2 BLOCKERs + 7/7 WARNs fixed
- [x] Source Verification 0 BLOCKERs + 3/3 WARNs fixed
- [x] Pipeline Integrity 3/4 BLOCKERs + 5/6 WARNs fixed (the 4th BLOCKER = "What's Next" slides, **user opted to skip**)
- [x] Editorial cleanup: "AWS-native orchestrator", "workhorse", "cloud-native and newer workloads" replaced with neutral source-grounded descriptions
- [x] All audit reports saved to `_audits/`

## Stage 9: Final Completeness — DONE

| Artifact | Expected | Actual |
|---|---|---|
| Course outline | 1 | ✅ v3 |
| Module narratives | 8 | ✅ 8 |
| Active lab narratives | 3 | ✅ 3 (Lab 4 + 5 archived) |
| Lab guides | 4 | ✅ 4 |
| Module slide JSONs | 8 | ✅ 8 |
| Deliverable markdown | 5 | ✅ 5 |
| Lab code repos | 4 | ✅ 4 (43 total files in repo_additions) |
| Module Google Slides | 8 | ✅ 8 |
| Lab Google Docs | 4 | ✅ 4 |
| Deliverable Google Docs | 5 | ✅ 5 |
| GitHub repo | 1 | ✅ jessetop/IO-107 |

---

## Outstanding (NOT blocking content review)

1. **SYF infra setup** (platform team): provision training EKS cluster + Aurora cluster + CodePipeline/CodeBuild + IAM roles + Secrets Manager secrets per `LAB_CODE_AUTHORING_SCOPE.md`.
2. **Lab repo URL placeholders**: replace `[client-org]/[repo-name]` in lab guide markdown with real `[Client]` repo URLs once SYF mirrors the lab subtrees into per-lab repos.
3. **Add in-deck Knowledge Check slides** for Modules 1, 2, 7, 8 (currently only labs have KCs).
4. **Layout diversity (Stage 3.8)**: Modules still 30-50% `content` layout vs 20% target — user opted to defer.
5. **"What's Next" slide on each module**: framework recommends but user opted to skip.

---

## Time budget summary

| Component | Time |
|---|---|
| 8 modules | 210 min |
| 4 labs | 180 min |
| **Content total** | **390 min = 6.5 hr** |
| + 1 hr lunch + 2× 15 min breaks | = 8 hr classroom day |

---

## Notes & Issues Log (latest entries)

| Date | Event | Outcome |
|------|-------|---------|
| 2026-05-12 | v3 scope-cut: dropped Mod 9 + Labs 4 (Flyway) + 5 (capstone) | Archived to `_archive_v2_scope_cut/` |
| 2026-05-12 | Lab 4 re-authored as Aurora Blue/Green via Terraform | New canonical Lab 4 |
| 2026-05-12 | `[Client]` placeholder removed from all v3 active content (~360 refs) | Complete |
| 2026-05-12 | Auditor bugs patched (3x): title_only checks, Unicode crash, code budget + bullet checks | Pipeline auditors hardened |
| 2026-05-12 | Lab code authored in `repo_additions/` for all 4 labs; pushed to jessetop/IO-107 | Testing scaffold ready |
| 2026-05-12 | Stage 9 completeness check PASS | Content ready for review |
