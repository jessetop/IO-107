# Lab 1: End-to-End EKS Deployment Pipeline — Teaching Narrative

**Duration:** 60 minutes

---

## Lab Introduction (5 minutes)

"Alright, it's time to put what we've learned into practice. In this first lab, you're going to execute a complete EKS deployment through the CI/CD pipeline — from code commit to pods running in the cluster.

This lab covers the entire flow: cloning a repository, reviewing the pipeline configuration, modifying the Helm values, triggering the pipeline, and validating the deployment. You'll also verify that IRSA is working correctly by checking that your pods can access AWS services."

[SLIDE: Lab 1 - End-to-End EKS Deployment Pipeline]

**Objectives:**
- Clone an application repository with Kubernetes manifests and Helm chart
- Review the pipeline configuration for EKS deployment stages
- Modify Helm values and trigger a pipeline deployment
- Observe each pipeline stage execution
- Verify deployed pods, services, and IRSA functionality

**Prerequisites:**
- Access to the CI/CD platform
- Git client configured
- kubectl configured for training EKS cluster
- AWS CLI configured

---

## Section 1: Clone the Repository (5 minutes)

"Let's start by getting the application code. We have a sample application repository that's already set up with a Helm chart and pipeline configuration."

[SLIDE: Clone the Repository]

**Instructor demonstrates:**
```bash
# Clone the training repository
git clone https://codecommit.us-east-1.amazonaws.com/v1/repos/io107-lab1-eks-app

# Navigate to the repository
cd io107-lab1-eks-app

# Review the structure
ls -la
```

**Expected structure:**
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

"Take a moment to explore this structure. The `src/` directory has the application code. The `charts/myapp/` directory contains the Helm chart. The `buildspec.yml` defines what the pipeline does."

**Participant task:** Clone the repository and explore the directory structure.

---

## Section 2: Review the Pipeline Configuration (10 minutes)

"Now let's look at how the pipeline is configured. Open the `buildspec.yml` file."

[SLIDE: Review Pipeline Configuration]

**buildspec.yml walkthrough:**
```yaml
version: 0.2

env:
  variables:
    CLUSTER_NAME: "training-eks-cluster"
    NAMESPACE: "lab1"
    APP_NAME: "myapp"
  secrets-manager:
    DOCKER_REGISTRY_TOKEN: "ecr-token:token"

phases:
  install:
    runtime-versions:
      docker: 20
    commands:
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      - aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1

  pre_build:
    commands:
      - echo "Logging in to ECR..."
      - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
      - COMMIT_SHA=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG="${COMMIT_SHA}"

  build:
    commands:
      - echo "Building Docker image..."
      - docker build -t $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG .
      - docker push $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG

  post_build:
    commands:
      - echo "Deploying to EKS..."
      - |
        helm upgrade --install $APP_NAME charts/myapp \
          --namespace $NAMESPACE \
          --create-namespace \
          --values charts/myapp/values-$ENVIRONMENT.yaml \
          --set image.tag=$IMAGE_TAG \
          --atomic \
          --timeout 10m
      - echo "Verifying deployment..."
      - kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=5m
      - kubectl get pods -n $NAMESPACE -l app=$APP_NAME
```

"Let's break this down. The install phase sets up Helm and configures kubectl for our EKS cluster. Pre-build logs into ECR. Build creates and pushes the Docker image. Post-build runs `helm upgrade --install` with the appropriate values file and then verifies the deployment.

Notice the `--atomic` flag. If the deployment fails, Helm rolls back automatically. And we verify with `kubectl rollout status` and `kubectl get pods`."

**Key discussion points:**
- How `aws eks update-kubeconfig` authenticates to EKS
- Why we use `--atomic` for production deployments
- How the image tag is derived from the commit SHA

**Participant task:** Review the buildspec.yml and identify each stage's purpose.

---

## Section 3: Review the Helm Chart (10 minutes)

"Now let's examine the Helm chart itself. Open `charts/myapp/values.yaml` and the templates."

[SLIDE: Review Helm Chart]

**values.yaml:**
```yaml
replicaCount: 2

image:
  repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp
  # Policy: tag MUST be set by the pipeline. Empty default fails
  # fast at helm template time if the pipeline override is missing.
  tag: ""
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

serviceAccount:
  create: true
  name: myapp-sa
  annotations:
    eks.amazonaws.com/role-arn: ""

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
```

"This is the base values file. Notice the IRSA annotation placeholder in the service account section. The environment-specific values files will set the actual role ARN."

**templates/deployment.yaml excerpt:**
```yaml
spec:
  serviceAccountName: {{ .Values.serviceAccount.name }}
  containers:
    - name: {{ .Chart.Name }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      resources:
        {{- toYaml .Values.resources | nindent 12 }}
```

**values-dev.yaml:**
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

"The dev values file reduces replicas and resources, and sets the IRSA role ARN for the dev environment. This is how we customize deployments per environment without duplicating templates."

**Participant task:** Compare values.yaml with values-dev.yaml and identify the differences.

---

## Section 4: Modify Helm Values and Trigger Pipeline (15 minutes)

"Now you're going to make a change and trigger the pipeline. We'll update the replica count in the dev values file."

[SLIDE: Modify and Deploy]

**Participant steps:**

1. **Modify the values file:**
   ```bash
   # Edit values-dev.yaml
   # Change replicaCount from 1 to 2
   ```

2. **Commit and push:**
   ```bash
   git add charts/myapp/values-dev.yaml
   git commit -m "Increase replica count to 2 for lab1 testing"
   git push origin main
   ```

3. **Navigate to CodePipeline console and observe:**
   - Pipeline triggers automatically
   - Watch each stage execute
   - Pay attention to the build logs

"Once you push, the pipeline should trigger within a few seconds. Navigate to CodePipeline in the AWS console and find our pipeline. You'll see it progress through Source, Build, and any other configured stages."

[SLIDE: Observe Pipeline Execution]

**What to look for:**
- Source stage pulls the code
- Build stage shows Docker build and push
- Post-build shows Helm deployment
- Final status: Succeeded or Failed

**Instructor demonstrates:** Walking through the CodePipeline console, clicking into CodeBuild logs, showing the deployment output.

---

## Section 5: Verify the Deployment (10 minutes)

"The pipeline succeeded. Now let's verify that the deployment actually works."

[SLIDE: Verify Deployment]

**Verification commands:**
```bash
# Check pods
kubectl get pods -n lab1 -l app=myapp
# Expected: 2 pods in Running state

# Check pod details
kubectl describe pod -n lab1 -l app=myapp

# Check service
kubectl get svc -n lab1
# Note the LoadBalancer external IP/hostname

# Test the application
curl http://<load-balancer-hostname>/health
# Expected: {"status": "healthy"}

# Check logs
kubectl logs -n lab1 -l app=myapp --tail=20
```

"You should see 2 pods running — matching the replica count you set. The service should have an external LoadBalancer address. And the health endpoint should respond."

**Participant task:** Run these verification commands and confirm the deployment.

---

## Section 6: Validate IRSA (10 minutes)

"The final step is to verify that IRSA is working. Our pods should be able to access AWS services using the IAM role attached to their service account."

[SLIDE: Validate IRSA]

**Check service account annotation:**
```bash
kubectl get sa myapp-sa -n lab1 -o yaml
# Look for eks.amazonaws.com/role-arn annotation
```

**Check pod environment:**
```bash
# Get a pod name
POD_NAME=$(kubectl get pods -n lab1 -l app=myapp -o jsonpath='{.items[0].metadata.name}')

# Check for IRSA token
kubectl exec -n lab1 $POD_NAME -- env | grep AWS
# Should see AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE
```

**Test AWS API access from pod:**
```bash
# The application has an endpoint that lists S3 buckets
curl http://<load-balancer-hostname>/aws-test
# Expected: list of S3 buckets the role can see

# Or exec into pod and test directly
kubectl exec -it -n lab1 $POD_NAME -- aws s3 ls
# Should succeed if IRSA is working
```

"If IRSA is configured correctly, the pod has no static credentials but can still call AWS APIs. The token is automatically injected and refreshed. If you see 'Unable to locate credentials' or access denied, the IRSA configuration needs debugging."

**Troubleshooting IRSA issues:**
- Check service account annotation is correct
- Verify IAM role trust policy matches namespace/SA
- Ensure OIDC provider is configured on the cluster

---

## Lab Validation Checklist (5 minutes)

[SLIDE: Lab 1 Validation]

**Confirm these outcomes:**
- [ ] Repository cloned successfully
- [ ] Pipeline triggered on commit
- [ ] All pipeline stages passed
- [ ] 2 pods running in lab1 namespace
- [ ] Service has LoadBalancer endpoint
- [ ] Health endpoint responds
- [ ] IRSA is working (pod can access AWS APIs)

"Take a moment to verify each of these checkboxes. If any of these aren't working, raise your hand and we'll troubleshoot together."

---

## Lab Summary

"Excellent work! You've just completed an end-to-end EKS deployment through the pipeline. You:
- Cloned a repository with Helm charts
- Reviewed the pipeline and Helm configuration
- Made a change and triggered a deployment
- Verified pods, services, and IRSA functionality

This is the exact workflow you'll use for real deployments. In Lab 2, we'll do something similar with Lambda and SAM."

---

## Instructor Notes

**Common Issues:**
- Pipeline doesn't trigger: Check webhook configuration
- Image pull errors: Verify ECR permissions and image tag
- IRSA not working: Most common issue is trust policy mismatch

**Time Management:**
- Clone and explore: 5 min
- Pipeline review: 10 min
- Helm chart review: 10 min
- Modify and trigger: 15 min (allow for troubleshooting)
- Verify deployment: 10 min
- IRSA validation: 10 min
- Wrap-up: 5 min

**Preparation:**
- Ensure training EKS cluster is ready
- Verify sample repository exists
- Test the complete flow before class
- Have troubleshooting steps ready
