# Lab 1: End-to-End EKS Deployment Pipeline

**Duration:** 60 min
**Companion lecture:** Module 3 — EKS Deployment Pipelines

## What this directory holds

When complete, this directory will contain a small containerised application + Helm chart that students clone, push a commit on, and watch deploy to a training EKS cluster via the pipeline.

## Files to author

- `src/app.py` — small Flask / Express "hello world" handler (returns 200 + identifies which IRSA role it's running as via `boto3.client('sts').get_caller_identity()`)
- `src/requirements.txt` (or `package.json`)
- `Dockerfile` — base on Python 3.12-slim or Node 20-alpine
- `charts/myapp/Chart.yaml` — chart metadata, version 0.1.0
- `charts/myapp/values.yaml` — base values; **`tag` defaults to `""`** so pipeline must override (matches lab guide policy)
- `charts/myapp/values-dev.yaml` — 1 replica, 250m/256Mi resources, dev IRSA role ARN
- `charts/myapp/values-stg.yaml` — 3 replicas, 500m/512Mi resources, stg IRSA role ARN
- `charts/myapp/templates/deployment.yaml` — references `Values.image.repository:Values.image.tag`
- `charts/myapp/templates/service.yaml` — `type: LoadBalancer`, port 80
- `charts/myapp/templates/serviceaccount.yaml` — annotation `eks.amazonaws.com/role-arn: {{ .Values.serviceAccount.annotations.role-arn }}`
- `buildspec.yml` — install Helm + kubectl, ECR auth, docker build/push (tag = git SHA), `helm upgrade --install --atomic`, `kubectl rollout status`
- `README.md` (this file)

## Lab guide reference

See `SYF-IO-107 - Lab 1 - End-to-End EKS Deployment Pipeline` in the deliverables Drive folder.

## Outstanding

- All code files. ~2 hr authoring.
- Real GitHub repo URL (currently the lab guide uses `https://github.com/[client-org]/[repo-name].git` placeholder; this directory will be cloned/forked under that real URL at delivery time).
