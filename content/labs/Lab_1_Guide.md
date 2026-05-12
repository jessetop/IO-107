# Lab 1: End-to-End EKS Deployment Pipeline

| | |
|---|---|
| **Course** | IO-107 SDLC Pipeline & Deployment Guardrails |
| **Module** | Module 3 — EKS Deployment Pipelines |
| **Duration** | 60 minutes |
| **Difficulty** | Intermediate |
| **Prerequisites** | Modules 1–3 completed; access to the training AWS account, CodeCommit/Git, and the training Amazon EKS cluster; `kubectl`, `git`, and AWS CLI configured locally |
| **Builds On** | None — Lab 1 is the foundation lab; it provisions the shared AWS CodePipeline, AWS CodeBuild project, IAM execution roles, and S3 artifact bucket reused by Labs 2–5. |

---

## Learning Objectives

By the end of this lab, you will:

- Clone an application repository containing Kubernetes manifests and a Helm chart, and inspect the `buildspec.yml` that drives the AWS CodeBuild stage. <!-- source: course_outline_v2.md Lab 1 -->
- Modify Helm values and trigger an AWS CodePipeline execution by pushing to the source branch. <!-- source: course_outline_v2.md Lab 1 -->
- Observe each pipeline stage — build, OPA policy validation, and Amazon EKS deployment — and read CodeBuild logs to confirm `helm upgrade --install` ran with `--atomic`. The standard pattern **requires** a manual approval gate on any pipeline targeting `stg` or `prd`; this lab deploys to `dev`, where approval is intentionally not enforced so you can iterate quickly. **Never extrapolate the dev path to higher environments — staging and prod always require approval.** <!-- source: Module_3_narrative.md §"Helm Commands in CodeBuild" + Lab_1_narrative.md §"Review the Pipeline Configuration" -->
- Verify the deployed pods, the LoadBalancer service, and that IRSA (IAM Roles for Service Accounts) is granting the pod AWS API access without static credentials. <!-- source: facts_extracted_v2.md §"IRSA (IAM Roles for Service Accounts)" + course_outline_v2.md Lab 1 -->

---

## Task 1: Clone the Application Repository

1. **Open** your terminal (or the lab environment's Cloud9 / CloudShell session, whichever your environment provides).

2. **Clone** the training application repository. Your instructor will provide the actual URL on the lab whiteboard — paste it into the command below:

    ```bash
    git clone https://github.com/[client-org]/[repo-name].git io107-lab1-eks-app
    ```
    <!-- TODO: replace with real repo URL before delivery -->
    <!-- source: Lab_1_narrative.md §"Clone the Repository" -->

3. **Change directory** into the repo and list the top level:

    ```bash
    cd io107-lab1-eks-app
    ls -la
    ```
    <!-- source: Lab_1_narrative.md §"Clone the Repository" -->

    Expected structure:

    ```
    io107-lab1-eks-app/
    ├── src/                    # Application source code
    ├── charts/
    │   └── myapp/
    │       ├── Chart.yaml
    │       ├── values.yaml
    │       ├── values-dev.yaml
    │       ├── values-stg.yaml
    │       └── templates/
    │           ├── deployment.yaml
    │           ├── service.yaml
    │           └── serviceaccount.yaml
    ├── Dockerfile
    ├── buildspec.yml
    └── README.md
    ```
    <!-- source: Lab_1_narrative.md §"Clone the Repository" -->

4. **Open** `charts/myapp/values.yaml`, `charts/myapp/values-dev.yaml`, and `buildspec.yml` in your editor of choice so you can refer to them in the next tasks.

> **Note:** If `git clone` returns an authentication error, confirm you have configured your Git credentials for the source control system (CodeCommit HTTPS git credentials, or the SSO Git helper, depending on your environment).

---

## Task 2: Walk Through the buildspec.yml

5. **Open** `buildspec.yml` and read each phase. The pipeline uses the following structure:

    ```yaml
    version: 0.2

    env:
      variables:
        CLUSTER_NAME: "training-eks-cluster"
        NAMESPACE: "lab1"
        APP_NAME: "myapp"

    phases:
      install:
        runtime-versions:
          docker: 20
        commands:
          - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
          - aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

      pre_build:
        commands:
          - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
          - COMMIT_SHA=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
          - IMAGE_TAG="${COMMIT_SHA}"

      build:
        commands:
          - docker build -t $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG .
          - docker push $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG

      post_build:
        commands:
          - |
            helm upgrade --install $APP_NAME charts/myapp \
              --namespace $NAMESPACE \
              --create-namespace \
              --values charts/myapp/values-$ENVIRONMENT.yaml \
              --set image.tag=$IMAGE_TAG \
              --atomic \
              --timeout 10m
          - kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=5m
          - kubectl get pods -n $NAMESPACE -l app=$APP_NAME
    ```
    <!-- source: Lab_1_narrative.md §"Review the Pipeline Configuration" + Module_3_narrative.md §"Helm Commands in CodeBuild" -->

6. **Identify** the purpose of each phase by writing down (mentally or on paper) what each block does. The four phases map to the pipeline stages we covered in Module 3: install Helm + configure `kubectl`, authenticate to Amazon ECR, build and push the image, then `helm upgrade` against Amazon EKS with rollback safety. <!-- source: Module_3_narrative.md §"Helm Commands in CodeBuild" -->

7. **Note** two things in particular:

    - `aws eks update-kubeconfig` writes a kubeconfig for the CodeBuild role so `kubectl` and `helm` authenticate to the cluster. <!-- source: https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html -->
    - The `--atomic` flag on `helm upgrade --install` causes Helm to automatically roll back the release if any resource fails to become ready within `--timeout`. `--atomic` is required in all production pipelines. <!-- source: Module_3_narrative.md §"Rollback Strategies" + https://helm.sh/docs/helm/helm_upgrade/ -->

> **What Just Happened?** You confirmed that the deployment is fully described as code — the `buildspec.yml` is the single, reviewable source for how Amazon EKS will be updated. There is no console click path that performs this deployment, which is the central guardrail of the SDLC model. <!-- source: Module_3_narrative.md §"Opening" -->

---

## Task 3: Review the Helm Chart and IRSA Hook

8. **Open** `charts/myapp/values.yaml` and locate the `serviceAccount` block:

    ```yaml
    replicaCount: 2

    image:
      repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
      # Policy: image tag MUST be set by the pipeline (--set image.tag=$IMAGE_TAG).
      # Default left empty so a missing override fails fast at `helm template` time
      # rather than silently deploying a mutable "latest" tag.
      tag: ""
      pullPolicy: IfNotPresent

    service:
      type: LoadBalancer
      port: 80

    serviceAccount:
      create: true
      name: myapp-sa
      annotations:
        eks.amazonaws.com/role-arn: ""
    ```
    <!-- source: Lab_1_narrative.md §"Review the Helm Chart" -->

9. **Open** `charts/myapp/values-dev.yaml` and observe the environment-specific overrides — fewer replicas, smaller resource requests, and the real IRSA role ARN that the base file leaves empty:

    ```yaml
    replicaCount: 1

    resources:
      limits:
        cpu: 250m
        memory: 256Mi

    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/myapp-dev-role

    environment: dev
    ```
    <!-- source: Lab_1_narrative.md §"Review the Helm Chart" -->

10. **Open** `charts/myapp/templates/serviceaccount.yaml` (or the equivalent template) and confirm that the `eks.amazonaws.com/role-arn` annotation is being templated from `.Values.serviceAccount.annotations`. This is the annotation that EKS reads to bind a Kubernetes ServiceAccount to an IAM role via the cluster's OIDC provider. <!-- source: Module_3_narrative.md §"Service Account Configuration" + https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html -->

> **Note:** The IAM role that `myapp-dev-role` points to has already been provisioned for the lab environment, including its trust policy that scopes assumption to `system:serviceaccount:lab1:myapp-sa`. You are not creating it in this lab — you are confirming the chart wires the annotation through correctly. <!-- source: Module_3_narrative.md §"IAM Role Trust Policy for IRSA" -->

---

## Task 4: Modify Helm Values and Push

11. **Edit** `charts/myapp/values-dev.yaml` and change `replicaCount` from `1` to `2`. Save the file.
    <!-- source: Lab_1_narrative.md §"Modify Helm Values and Trigger Pipeline" -->

12. **Stage, commit, and push** the change to trigger the pipeline:

    ```bash
    git add charts/myapp/values-dev.yaml
    git commit -m "Lab 1: bump dev replicaCount to 2"
    git push origin main
    ```
    <!-- source: Lab_1_narrative.md §"Modify Helm Values and Trigger Pipeline" -->

13. **Switch** to the AWS Management Console and navigate to **CodePipeline > Pipelines**. Find the pipeline named after your repo (your instructor will confirm the exact name) and click it. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-view-console.html -->

14. **Watch** the stages execute in order. Within a few seconds of the push, the **Source** stage should turn green and **Build** should start. <!-- source: facts_extracted_v2.md §"AWS CodePipeline" + Lab_1_narrative.md §"Modify Helm Values and Trigger Pipeline" -->

---

## Task 5: Observe Each Pipeline Stage

15. **Click** into the **Build** stage > **Details** link to open the AWS CodeBuild execution. The CodeBuild console will show the live log stream. <!-- source: https://docs.aws.amazon.com/codebuild/latest/userguide/view-build-details.html -->

16. **Scan** the log for these checkpoints, in order:
    - `aws eks update-kubeconfig` returned `Updated context ... in /root/.kube/config`.
    - `docker build` and `docker push` completed without errors.
    - `helm upgrade --install` printed `STATUS: deployed` and a revision number.
    - `kubectl rollout status deployment/myapp -n lab1` printed `deployment "myapp" successfully rolled out`.
    <!-- source: Module_3_narrative.md §"Validation Commands in CodeBuild" + https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout -->

17. **Return** to the CodePipeline view. The standard pattern **requires** a manual approval gate on every pipeline targeting `stg` or `prd`. This lab's pipeline targets `dev` only, so no approval stage is traversed and the **Deploy** stage proceeds automatically. **Never extrapolate the dev path to higher environments — staging and prod always require approval.** <!-- source: facts_extracted_v2.md §"AWS CodePipeline" + Module_3_narrative.md §"EKS Deployment Pipeline" -->

18. **Confirm** the pipeline completes with overall status **Succeeded**.

> **What Just Happened?** A single Git push moved a configuration change through source, build, image publish, policy validation, and a live `helm upgrade` against Amazon EKS — without anyone touching the cluster directly. This is the exact flow used for every container deployment. <!-- source: Module_3_narrative.md §"Opening" -->

---

## Task 6: Verify Pods, Service, and Endpoint

19. **From your local terminal**, confirm `kubectl` is pointing at the training cluster. If you have not done this already in this session:

    ```bash
    aws eks update-kubeconfig --name training-eks-cluster --region us-east-1
    ```
    <!-- source: https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html -->

20. **List** the pods in the `lab1` namespace:

    ```bash
    kubectl get pods -n lab1 -l app=myapp
    ```
    <!-- source: Lab_1_narrative.md §"Verify the Deployment" + https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get -->

    Expected: **two** pods, both in `Running` state with `READY 1/1`. The new replica count from your push should now be reflected.

21. **Describe** one of the pods to confirm it is using the expected ServiceAccount:

    ```bash
    kubectl describe pod -n lab1 -l app=myapp | grep -i "service account"
    ```
    <!-- source: Lab_1_narrative.md §"Verify the Deployment" + https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe -->

    Expected: `Service Account:  myapp-sa`

22. **Get** the LoadBalancer service and copy the `EXTERNAL-IP` (or hostname) it has been assigned:

    ```bash
    kubectl get svc -n lab1
    ```
    <!-- source: Lab_1_narrative.md §"Verify the Deployment" + https://kubernetes.io/docs/concepts/services-networking/service/ -->

23. **Hit** the application's health endpoint through the LoadBalancer (replace `<lb-host>` with the value from the previous step):

    ```bash
    curl http://<lb-host>/health
    ```
    <!-- source: Lab_1_narrative.md §"Verify the Deployment" -->

    Expected JSON: `{"status": "healthy"}`

> **Note:** AWS-managed LoadBalancers can take 2–4 minutes after the pods are healthy before the DNS name resolves and accepts traffic. If `curl` fails immediately, wait a minute and retry before assuming the deployment is broken.

---

## Task 7: Validate IRSA from Inside the Pod

24. **Confirm** the ServiceAccount object carries the IAM role annotation:

    ```bash
    kubectl get sa myapp-sa -n lab1 -o yaml
    ```
    <!-- source: Lab_1_narrative.md §"Validate IRSA" -->

    Expected: An `eks.amazonaws.com/role-arn:` annotation under `metadata.annotations`, pointing to `arn:aws:iam::<account>:role/myapp-dev-role`.

25. **Capture** one pod name into a shell variable and inspect the IRSA environment variables that the IRSA admission webhook injects:

    ```bash
    POD_NAME=$(kubectl get pods -n lab1 -l app=myapp -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n lab1 $POD_NAME -- env | grep AWS
    ```
    <!-- source: Lab_1_narrative.md §"Validate IRSA" + https://docs.aws.amazon.com/eks/latest/userguide/pod-configuration.html -->

    Expected: at minimum `AWS_ROLE_ARN=arn:aws:iam::...:role/myapp-dev-role` and `AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token`. These are the two variables the AWS SDKs key off of to assume the role via `sts:AssumeRoleWithWebIdentity`. <!-- source: Module_3_narrative.md §"IAM Role Trust Policy for IRSA" -->

26. **Test** that the pod can actually call an AWS API using IRSA — list S3 buckets the role is permitted to see:

    ```bash
    kubectl exec -n lab1 $POD_NAME -- aws s3 ls
    ```
    <!-- source: Lab_1_narrative.md §"Validate IRSA" + https://docs.aws.amazon.com/cli/latest/reference/s3/ls.html -->

    Expected: a list of S3 buckets (could be empty if the dev role has zero allowed buckets — an empty list with **no error** is still a success). If you instead see `Unable to locate credentials` or `AccessDenied`, IRSA is not wired correctly — see Troubleshooting below.

> **What Just Happened?** The pod has no AWS access keys baked in anywhere — no environment variables with secrets, no instance profile assumed broadly across the node. The AWS SDK inside the container exchanged the projected service-account token for short-lived STS credentials scoped to `myapp-dev-role`. That is the entire point of IRSA: pod-level, least-privilege AWS access without long-lived credentials. <!-- source: Module_3_narrative.md §"The IRSA Problem" + Module_3_narrative.md §"How IRSA Works" -->

---

## Troubleshooting

### Pipeline does not trigger after `git push`

**Check:** In the CodePipeline console, open the pipeline > **Source** stage. Confirm the source action shows the latest commit SHA.

**Fix:** If the commit is not visible, the source webhook may be disconnected. Re-run the pipeline manually by clicking **Release change** at the top of the pipeline page. If that succeeds, raise a ticket to have the webhook reconnected — do not work around the issue permanently. <!-- source: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-rerun-manually.html -->

### CodeBuild fails at `docker push` with "no basic auth credentials"

**Check:** Scroll the CodeBuild log up to the `aws ecr get-login-password` line — confirm it returned without error.

**Fix:** If the ECR login failed, the CodeBuild service role is missing `ecr:GetAuthorizationToken` permission. Verify the role attached to the CodeBuild project includes the policy the platform team distributes for ECR access. <!-- source: https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html -->

### `helm upgrade` fails and pipeline reports the deployment was rolled back

**Check:** Look immediately above the rollback message in the CodeBuild log for the failing resource. Usually it is a pod that never became `Ready` within the `--timeout 10m` window — image pull error, failing readiness probe, or CrashLoopBackOff.

**Fix:** `--atomic` already rolled the release back, so the previous revision is live. Run `kubectl get pods -n lab1 -l app=myapp` and `kubectl describe pod <pod>` to see the underlying error, fix in the chart or app code, commit, and re-run. <!-- source: Module_3_narrative.md §"Rollback Strategies" + https://helm.sh/docs/helm/helm_upgrade/ -->

### `kubectl exec ... aws s3 ls` returns "Unable to locate credentials"

**Check:** Run `kubectl get sa myapp-sa -n lab1 -o yaml` and confirm the `eks.amazonaws.com/role-arn` annotation is present and non-empty. Then confirm the pod was created **after** the annotation was applied — IRSA injection only happens at pod admission. <!-- source: Module_3_narrative.md §"How IRSA Works" -->

**Fix:** If the annotation is missing, your `helm upgrade` likely used a values file without the IRSA override (check `values-$ENVIRONMENT.yaml`). If the annotation is present but the pod is old, delete the pod (`kubectl delete pod $POD_NAME -n lab1`) — the Deployment will recreate it with the IRSA env vars injected.

### `curl http://<lb-host>/health` times out

**Check:** Run `kubectl get svc -n lab1` again — the `EXTERNAL-IP` column may still show `<pending>`.

**Fix:** Wait 2–4 minutes for the AWS Load Balancer Controller to provision the ELB and for DNS to propagate. If after 5 minutes the EXTERNAL-IP is still `<pending>`, check that the cluster has the AWS Load Balancer Controller installed and that the service subnets are tagged correctly for the controller to discover. <!-- source: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html -->

---

## Knowledge Check

**Question 1:** Why does the buildspec.yml pass the `--atomic` flag to `helm upgrade --install`, and what does Helm do when a deployment under `--atomic` fails to become healthy before `--timeout`?
<!-- source: Module_3_narrative.md §"Rollback Strategies" -->

**Question 2:** A teammate proposes putting AWS access keys into a Kubernetes Secret and mounting it as environment variables on the pod, so the application can call S3. Citing what you saw in Task 7, give two specific reasons IRSA is preferred over that approach.
<!-- source: Module_3_narrative.md §"The IRSA Problem" + Module_3_narrative.md §"How IRSA Works" -->

**Question 3:** In the IRSA trust policy that backs `myapp-dev-role`, what string under the `Condition` block ties the role to a specific namespace and ServiceAccount, and what would happen if that string were left as `*`?
<!-- source: Module_3_narrative.md §"IAM Role Trust Policy for IRSA" -->

**Question 4:** Walking from your `git push` to pods running in Amazon EKS, name the four AWS services that participated in the deployment, in order of involvement.
<!-- source: facts_extracted_v2.md §"AWS CodePipeline" + facts_extracted_v2.md §"AWS CodeBuild" + Module_3_narrative.md §"EKS Deployment Pipeline" -->

*Answers are in the Knowledge Check Bank.*

---

## Completion Checklist

- [ ] Repository cloned and directory structure confirmed
- [ ] `buildspec.yml` read end-to-end; install / pre_build / build / post_build phases each understood
- [ ] Helm chart `values.yaml` and `values-dev.yaml` reviewed; IRSA annotation identified
- [ ] `replicaCount` change committed and pushed
- [ ] AWS CodePipeline executed all stages to **Succeeded**
- [ ] AWS CodeBuild log shows `helm upgrade` printed `STATUS: deployed`
- [ ] AWS CodeBuild log shows `kubectl rollout status` returned `successfully rolled out`
- [ ] `kubectl get pods -n lab1` shows **2** pods in `Running` 1/1
- [ ] LoadBalancer service has an `EXTERNAL-IP` and `/health` returns `{"status": "healthy"}`
- [ ] `kubectl get sa myapp-sa -n lab1 -o yaml` shows the IRSA `eks.amazonaws.com/role-arn` annotation
- [ ] `kubectl exec ... env | grep AWS` shows `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`
- [ ] `kubectl exec ... aws s3 ls` runs without "Unable to locate credentials"

---

## Cost Considerations

| Component | Type | Hourly Cost (us-east-1, on-demand) |
|-----------|------|------------------------------------|
| Amazon EKS cluster (control plane) | Shared training cluster | ~$0.10/hour <!-- source: https://aws.amazon.com/eks/pricing/ verified 2026-04-07 --> |
| Worker capacity for 2 pods (`250m` CPU / `256Mi` mem each) | Fraction of shared `m5.large` worker | ~$0.02/hour share |
| Network Load Balancer (created by `type: LoadBalancer`) | ELB | ~$0.0225/hour + data <!-- source: https://aws.amazon.com/elasticloadbalancing/pricing/ verified 2026-04-07 --> |
| Amazon ECR storage for image | Per GB-month | <$0.01/hour share <!-- source: https://aws.amazon.com/ecr/pricing/ verified 2026-04-07 --> |
| AWS CodePipeline (one active pipeline) | Per active pipeline-month | <$0.02/hour share <!-- source: https://aws.amazon.com/codepipeline/pricing/ verified 2026-04-07 --> |
| AWS CodeBuild (build minutes) | `general1.small` build-minute | ~$0.005/build-minute <!-- source: https://aws.amazon.com/codebuild/pricing/ verified 2026-04-07 --> |
| **Total (this lab, ~1 hour)** | | **~$0.15–$0.25/hour** |

**Cleanup:** The training EKS cluster and pipeline persist between cohorts — do **not** delete them. To release the resources your specific deployment created:

```bash
helm uninstall myapp -n lab1
kubectl delete namespace lab1
```
<!-- source: https://helm.sh/docs/helm/helm_uninstall/ + https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete -->

Removing the Helm release also removes the LoadBalancer service, which terminates the ELB and stops its hourly charge. Leave the EKS cluster, ECR repo, and the CodePipeline / CodeBuild project alone — your instructor or platform team owns those.

---

## Next Steps

In **Lab 2: Lambda Deployment with SAM**, you'll deploy a serverless application through the pipeline using AWS SAM, publish Lambda versions, and configure alias-based traffic shifting for a canary release. The pipeline-driven model is the same; the compute target changes from Amazon EKS to AWS Lambda. <!-- source: course_outline_v2.md Lab 2 -->

---

## Resources

- [Amazon EKS User Guide — IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Amazon EKS User Guide — Create or update kubeconfig](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [AWS CodeBuild User Guide — buildspec reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
- [Helm — `helm upgrade` reference](https://helm.sh/docs/helm/helm_upgrade/)
- [Kubernetes — `kubectl rollout status`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout)
