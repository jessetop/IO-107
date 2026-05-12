# Chapter 3: EKS Deployment Pipelines — Teaching Narrative

**Duration:** 40 minutes

---

## Opening (2 minutes)

"Alright — Chapter 2 covered an S3 pipeline run end to end. Now we're moving from infrastructure provisioning to application deployment, specifically containerised applications on Amazon EKS.

EKS is the platform for running containerised workloads here. If your application runs in Docker, it's almost certainly running on EKS. And just like with S3, we don't deploy manually — no kubectl from laptops, no SSH into nodes. Everything goes through the pipeline.

We've got 40 minutes, so this is a focused tour: how the EKS deployment pipeline is shaped, Helm via CodeBuild, kubectl with Kustomize as the alternative, IRSA for pod permissions, and Fargate plus deployment validation. Let's go."

[SLIDE: Chapter 3 Title]

[SLIDE: Chapter Objectives]
- Deploy applications to EKS using Helm charts via CodeBuild pipelines
- Deploy applications using kubectl apply and Kustomize via CodeBuild
- Configure IRSA (IAM Roles for Service Accounts) for secure pod-to-AWS access
- Read EKS deployment rollout status and pod health from the pipeline

---

## Chapter Concepts — You Are Here (1 minute)

[SLIDE: Chapter Concepts — highlight row 0]

"Five concepts. We'll walk through them in order: the pipeline shape itself, then Helm, then kubectl, then IRSA, then Fargate and validation."

---

## Section 1: The EKS Deployment Pipeline (3 minutes)

[SLIDE: The EKS Deployment Pipeline — build side / deploy side]

"Push-based deployment is the primary EKS pattern here: the pipeline actively deploys to the cluster. CodeBuild runs `helm upgrade` or `kubectl apply` and the deployment happens. The pipeline is in control, which integrates well with the existing CodePipeline infrastructure and approval gates. Pull-based GitOps with ArgoCD or Flux exists and is being evaluated for future use, but push-based is what you'll see today.

The pipeline shape is the standard one. Build side: source pulls the application code and Kubernetes manifests, build compiles the app and pushes a Docker image to ECR, and OPA validates the manifests before any deployment runs — we cover OPA in Chapter 6. Deploy side: CodeBuild runs `helm upgrade --install` or `kubectl apply` against the target cluster, then validates the rollout before reporting success.

We'll cover Helm first, then kubectl, then permissions via IRSA, and finally Fargate plus deployment validation."

---

## Section 2: Helm Chart Deployments via CodeBuild (10 minutes)

[SLIDE: Chapter Concepts — highlight row 1]

"Helm is the package manager for Kubernetes. If you've used apt, yum, or npm, the model is similar — but for Kubernetes applications."

[SLIDE: What is Helm?]
- Package manager for Kubernetes (like apt, yum, or npm)
- Charts: templated Kubernetes manifests plus a values file
- Values: per-environment configuration (replicas, image tag, IAM role)
- Releases: deployed instances with revision history and rollback
- Shared charts are stored in ECR (Amazon ECR supports OCI Helm artifacts)

"A Helm chart is a collection of Kubernetes manifest templates plus a values file. The templates have placeholders — image tag, replica count, resource limits — and the values file fills them in for a specific deployment. When you deploy a chart, Helm creates a *release* that tracks what was deployed, so you can upgrade, roll back, or delete it as a unit. That release management is Helm's key value over raw kubectl.

On storage: Amazon ECR supports OCI Helm chart artifacts, which is the standard for shared charts that multiple teams use. Application-specific charts typically live in the same Git repository as the application code — that keeps the chart and the code that uses it versioned together."

[SLIDE: values.yaml for Environment Configuration]
```yaml
# values-dev.yaml
replicaCount: 1
image:
  repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
  tag: "1.0.0"
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
environment: dev
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: >-
      arn:aws:iam::123456789012:role/myapp-dev-role
```

"One values file per environment. This is the dev one — smaller replica count, lower resource limits, and a dev-specific IAM role for IRSA (we'll get to IRSA in a few slides). Staging and production would have their own files with more replicas, higher resource limits, and different IAM roles. The pipeline picks the right file based on the target environment, so the same chart deploys differently to dev, stg, and prd without any template duplication."

[SLIDE: Helm Commands in CodeBuild]
```yaml
# buildspec.yml
phases:
  install:
    commands:
      - curl -L \
          https://raw.githubusercontent.com/helm/\
            helm/main/scripts/get-helm-3 \
          | bash
      - aws eks update-kubeconfig --name $CLUSTER_NAME \
        --region $AWS_REGION
  build:
    commands:
      - helm upgrade --install myapp ./charts/myapp \
          --namespace $NAMESPACE \
          --values ./charts/myapp/values-$ENVIRONMENT.yaml \
          --set image.tag=$IMAGE_TAG \
          --atomic \
          --timeout 10m
```

"Install phase: install Helm and configure kubectl using `aws eks update-kubeconfig` — this uses CodeBuild's IAM role credentials. Build phase: `helm upgrade --install` is idempotent (installs if the release does not exist, upgrades if it does). We pass the per-environment values file and override the image tag with the one built earlier in the pipeline.

Two flags matter most. `--atomic` is the rollback flag — if pods don't become healthy, Helm automatically rolls back. `--timeout` caps the wait so the build doesn't hang forever.

Production caveat on the install line: piping `curl` to `bash` from a public GitHub URL is a teaching shortcut. Real production CodeBuild images pin a specific Helm version, pull from an internal mirror, or bake Helm directly into the build image — never trust a public raw GitHub URL at runtime."

[SLIDE: Rollback Strategies — Automatic vs. Manual]
- **Automatic:** `--atomic` flag triggers rollback on failure; required in production pipelines; no manual intervention
- **Manual:** `helm rollback <release> <revision>`; view history with `helm history myapp`; pipeline-triggered on detected failure

"With `--atomic`, Helm handles rollback automatically: if pods don't become healthy, the release reverts. That's required in production pipelines — a failed deployment must auto-revert, not leave the cluster in a broken state.

For manual rollback, `helm rollback myapp 2` reverts to revision 2, and `helm history myapp` shows you the revision list. Manual rollback is rare in practice because `--atomic` catches most failures during the deploy itself; it's mainly used when an issue surfaces after the deploy finished apparently-successfully."

---

## Section 3: kubectl Apply via CodeBuild (8 minutes)

[SLIDE: Chapter Concepts — highlight row 2]

"Some teams prefer raw Kubernetes manifests over Helm charts. That's fine — `kubectl apply` is supported too."

[SLIDE: kubectl Apply with Kustomize — left/right callout]
- **kubectl apply:** direct manifest deployment — no charts, no releases; simpler than Helm for straightforward apps; good for teams new to Kubernetes
- **Kustomize overlays:** `base/` holds shared manifests; `overlays/dev|stg|prd/` patch the base; change namespace, replicas, image tag, resources

"`kubectl apply` takes YAML manifests and applies them to the cluster — no charts, no releases, just manifests. For simple applications or teams new to Kubernetes, this can be easier to understand and troubleshoot than Helm.

The environment-configuration problem — different replicas, namespaces, image tags per environment — is solved by Kustomize: you have a base directory with shared manifests, and overlay directories for dev, stg, and prd that patch the base without duplicating it. An overlay might change the namespace to `myteam-prd`, set replicas to 5, and override the image tag. Kustomize merges all of that at deployment time."

[SLIDE: kubectl Commands in CodeBuild]
```yaml
# buildspec.yml
phases:
  install:
    commands:
      - aws eks update-kubeconfig --name $CLUSTER_NAME \
        --region $AWS_REGION
  build:
    commands:
      - kubectl apply -k manifests/overlays/$ENVIRONMENT \
        --dry-run=server
      - kubectl apply -k manifests/overlays/$ENVIRONMENT
      - kubectl rollout status deployment/myapp -n $NAMESPACE \
        --timeout=5m
```

"Configure kubeconfig, then run `kubectl apply` with `-k` for Kustomize.

Critical line: `--dry-run=server` before the real apply. Server-side dry-run sends the request to Kubernetes without creating resources and validates it against the actual cluster state, admission webhooks, and policies. That catches errors the client-side dry-run would miss — for example, a manifest that's syntactically valid but violates a Pod Security policy. Always use server-side dry-run in pipelines.

After the real apply, `kubectl rollout status` waits for the deployment to complete and reports success or failure. If rollout status fails or times out, the pipeline fails."

---

## Section 4: IRSA — IAM Roles for Service Accounts (10 minutes)

[SLIDE: Chapter Concepts — highlight row 3]

"Now permissions. Pods need to call AWS APIs — read from S3, publish to SNS, query Aurora through the RDS Data API. How do pods authenticate to AWS?"

[SLIDE: The IRSA Problem]
- Pods need AWS credentials to call AWS APIs (S3, SNS, Aurora)
- Old approach 1: EC2 instance profile — every pod on the node gets the same broad permissions
- Old approach 2: hardcoded credentials — a security incident waiting to happen
- IRSA: pod-level IAM roles via Kubernetes service accounts
- No credentials stored in the pod; uses short-lived projected tokens

"Before IRSA, you had two bad options. Option one: use the EC2 instance profile, which meant every pod on the node had the same permissions — way too broad. Option two: put AWS credentials in environment variables or files, which is a security incident waiting to happen.

IRSA — IAM Roles for Service Accounts — solves both by giving each pod its own IAM role with exactly the permissions it needs. No credentials are stored in the pod; the pod receives a short-lived projected token that AWS SDKs automatically exchange for temporary credentials. This is the pattern for every pod that needs to call AWS — no static keys, no shared instance-profile permissions."

[SLIDE: How IRSA Works]
- EKS cluster registers an OIDC identity provider with IAM
- IAM role created with trust policy scoped to that OIDC provider
- Trust condition: specific namespace + service account only
- Kubernetes service account is annotated with the IAM role ARN
- Pod uses the service account; IRSA admission webhook injects the projected token
- AWS SDKs detect the token and assume the role automatically

"Your EKS cluster has an OIDC identity provider registered with IAM. You create an IAM role that trusts this provider — and critically, the trust policy is scoped to a specific Kubernetes namespace and service account combination, not just 'any pod in this cluster'.

You then create a Kubernetes service account and annotate it with the IAM role ARN. When a pod runs with that service account, the IRSA admission webhook injects a projected service-account token into the pod at scheduling time. AWS SDKs detect the token and automatically call `sts:AssumeRoleWithWebIdentity` to get temporary credentials.

Result: tight scoping. Even if someone compromises a different pod in a different namespace, they cannot assume this role — their token won't match the trust policy's namespace/service-account conditions.

We'll show the full trust policy JSON in Lab 1 when you set up IRSA hands-on; for now just remember the model: OIDC provider trust + namespace/SA conditions = pod-scoped permissions."

[SLIDE: IRSA in Pipelines]
- IRSA role provisioned via Terraform in the same pipeline as the app
- Terraform creates the IAM role with correct trust policy + namespace/SA scope
- Kubernetes manifests reference the role via service account annotation
- Cross-account IRSA enables access to shared data lakes and central logging
- Cross-account IRSA crosses an audit boundary — extra review required

"The IRSA role is provisioned through the same pipeline that deploys the application. Terraform creates the IAM role with the correct trust policy and namespace/service-account scope, and the Kubernetes manifests reference it via the service-account annotation. So the IAM role and the workload that uses it are versioned and reviewed together.

Cross-account IRSA follows the same pattern but the IAM role lives in a different account — this is the common pattern for accessing shared data lakes or centralised logging.

Important callout: cross-account IRSA crosses an audit boundary. The platform team reviews the trust policy on every new cross-account IRSA role, and both accounts' CloudTrail trails must be wired to the central trail — the cluster's account-A trail records the `AssumeRoleWithWebIdentity` call, and the resource's account-B trail records the subsequent API actions. Don't treat cross-account IRSA as a frictionless copy of single-account IRSA — it's the same mechanism with more review."

---

## Section 5: Fargate and Deployment Validation (5 minutes)

[SLIDE: Chapter Concepts — highlight row 4]

[SLIDE: EKS on Fargate — Benefits and Limits]
- **Benefits:** serverless pods (no EC2 nodes to manage); per-pod isolation and pricing; profiles select pods by namespace + labels
- **Limitations:** private subnets only (NAT required); no daemonsets, privileged containers, or hostPath; no GPU/Inferentia; 1-minute minimum billing

"With Fargate, you don't manage EC2 nodes — AWS handles the compute infrastructure. You define a Fargate profile that selects which pods run on Fargate based on namespace and labels (for example: namespace `myteam`, label `compute=fargate`). You get per-pod isolation and pricing, which is great for variable workloads or teams that don't want node-management overhead.

The limitations matter. Fargate only works in private subnets, so you need a NAT gateway for internet egress. You cannot run daemonsets, privileged containers, or anything using hostPath volumes. There is no GPU or Inferentia option — accelerator workloads must use EC2 node groups. And Fargate enforces a 1-minute minimum billing per pod, so short-lived pods pay for a full minute even if they exit in seconds.

Workloads needing accelerators, hostPath, or sub-minute lifecycles belong on EC2 node groups."

[SLIDE: Reading Deployment Status from the Pipeline]
- **kubectl checks:** `rollout status` — deployment object completed; `get pods` — Running, not CrashLoopBackOff; compare `readyReplicas` vs. `spec.replicas`
- **Probes do the real work:** readiness — pod gets traffic only when ready; liveness — Kubernetes restarts unresponsive pods; both required by OPA policy

"The pipeline should not report success just because kubectl returned zero — we need to confirm the deployment actually works. Three checks in order. First, `kubectl rollout status` with a timeout confirms the Deployment object reached the desired state. Second, `kubectl get pods` shows actual pod state — Running, Pending, CrashLoopBackOff. Third, compare `readyReplicas` against `spec.replicas`; if they don't match, fail the build.

Underneath, two probe types do the real work: readiness probes determine when a new pod starts receiving traffic during a rolling update, and liveness probes restart pods that have stopped responding. Without probes, Kubernetes will route traffic to pods that aren't yet ready, and your users will see errors during every deployment. Every deployment manifest must define both probes — that's the OPA-enforced expectation we cover in Chapter 6."

---

## Summary and What's Next (1 minute)

[SLIDE: Chapter Summary]
- Deployed applications to EKS using Helm charts with `--atomic` rollback via CodeBuild
- Deployed applications using `kubectl apply` with Kustomize overlays and server-side dry-run
- Configured IRSA for pod-scoped, credential-free access to AWS APIs
- Read EKS rollout status, pod health, and readiness/liveness probe output from the pipeline

"That's the EKS deployment story. Two deployment paths — Helm and kubectl — both driven by CodeBuild. IRSA for pod permissions with no static keys. Fargate when you don't want node overhead, with the limits to be aware of. And validation that confirms the deployment actually works before reporting success.

Lab 1 will put this end-to-end: you'll set up the pipeline, deploy a sample app, configure IRSA, and read the rollout status. Next up is Chapter 4 — Lambda deployments. Different compute model, same pipeline-driven approach."

---

## Instructor Notes

**Key Points to Emphasise:**
- `--atomic` is non-negotiable in production Helm deployments
- Server-side dry-run catches policy violations the client-side check misses
- IRSA's trust policy must scope to namespace + service account (not just the cluster)
- Cross-account IRSA is the same mechanism but crosses an audit boundary

**Common Questions:**
- "Can we use ArgoCD/GitOps?" — Being evaluated; currently push-based is standard
- "How do I debug a failed deployment?" — Chapter 8 covers troubleshooting
- "What if IRSA doesn't work?" — Check OIDC provider, service account annotation, trust policy conditions

**Timing Notes (40 minutes):**
- Opening + objectives: 3 min
- Pipeline shape: 3 min
- Helm: 10 min
- kubectl + Kustomize: 8 min
- IRSA: 10 min
- Fargate + validation: 5 min
- Summary: 1 min
