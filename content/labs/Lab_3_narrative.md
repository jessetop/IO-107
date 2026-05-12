# Lab 3: Policy-as-Code Evaluation & Failure Remediation — Teaching Narrative

**Duration:** 45 minutes

---

## Lab Introduction (3 minutes)

"Now we're going to deliberately break things. In this lab, you'll deploy a template with intentional policy violations. You'll see the pipeline halt at the OPA validation stage, interpret the error output, and then fix each violation.

This is perhaps the most practical lab of the day. Understanding how to read and remediate policy violations is something you'll do regularly when working with these pipelines."

[SLIDE: Lab 3 - Policy-as-Code Evaluation & Failure Remediation]

**Objectives:**
- Deploy a template with intentional policy violations
- Observe the pipeline halt at OPA policy validation
- Read and interpret OPA evaluation output
- Identify EKS-specific policy violations
- Remediate each violation and successfully deploy

**Prerequisites:**
- Access to the CI/CD platform
- Git client configured
- Understanding of OPA/Conftest from Module 6

---

## Section 1: Clone the Repository with Violations (5 minutes)

"We have a repository set up with intentional violations. Let's clone it and see what's wrong."

[SLIDE: Clone the Violations Repository]

**Commands:**
```bash
# Clone the training repository
git clone https://codecommit.us-east-1.amazonaws.com/v1/repos/io107-lab3-policy-violations

# Navigate to the repository
cd io107-lab3-policy-violations

# Review the structure
ls -la
```

**Expected structure:**
```
io107-lab3-policy-violations/
├── terraform/
│   ├── main.tf          # Infrastructure with violations
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/
│   └── deployment.yaml  # K8s manifest with violations
├── buildspec.yml
└── README.md
```

"This repository has both Terraform and Kubernetes configurations, both with policy violations. Let's look at what's wrong."

---

## Section 2: Review the Intentional Violations (10 minutes)

"Open `terraform/main.tf` and let's identify the violations."

[SLIDE: Review Terraform Violations]

**terraform/main.tf:**
```hcl
# VIOLATION 1: S3 bucket with wrong naming convention
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-bucket"  # Should be client-{env}-{app}-{purpose}

  # VIOLATION 2: Missing encryption configuration
  # (no server_side_encryption_configuration block)

  # VIOLATION 3: Missing required tags
  tags = {
    Name = "My Bucket"
    # Missing: Environment, Application, Owner, CostCenter, DataClass
  }
}

# VIOLATION 4: Lambda with excessive timeout
resource "aws_lambda_function" "processor" {
  function_name = "data-processor"
  runtime       = "python3.11"
  handler       = "app.handler"
  timeout       = 600  # Exceeds maximum allowed (300)
  memory_size   = 512
  filename      = "lambda.zip"

  tags = {
    Name = "Processor"
    # Missing required tags
  }
}
```

"Let me point out each violation:
1. The S3 bucket name doesn't follow the naming convention
2. No encryption configuration on the S3 bucket
3. Missing required tags on the S3 bucket
4. Lambda timeout exceeds the maximum allowed
5. Missing required tags on the Lambda function"

[SLIDE: Review Kubernetes Violations]

**kubernetes/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
  # VIOLATION: Missing required labels
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          # VIOLATION: Image from unapproved registry
          image: docker.io/library/nginx:latest
          # VIOLATION: Missing resource limits
          ports:
            - containerPort: 80
```

"The Kubernetes manifest has violations too:
1. Missing required labels (environment, owner)
2. Image from Docker Hub instead of approved ECR registry
3. No resource limits defined on the container"

**Participant task:** Review the files and list all violations you can identify.

---

## Section 3: Trigger the Pipeline and Observe Failure (8 minutes)

"Now let's trigger the pipeline and see how OPA reports these violations."

[SLIDE: Trigger Pipeline]

**Commands:**
```bash
# Make a small change to trigger the pipeline
# (Add a comment or modify a variable)
echo "# Lab 3 test run" >> terraform/main.tf

git add .
git commit -m "Trigger pipeline for policy validation test"
git push origin main
```

"Navigate to CodePipeline and watch. The pipeline will pass the source and build stages, then fail at the validation stage."

[SLIDE: Observe OPA Failure Output]

"Click into the CodeBuild logs for the validation stage. You'll see output like this:"

**Expected OPA output:**
```
Running policy validation...

FAIL - terraform/main.tf - main - S3 bucket 'my-bucket' does not match naming pattern 'client-{env}-{app}-{purpose}'
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' must have server-side encryption enabled
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Environment
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Application
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: Owner
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: CostCenter
FAIL - terraform/main.tf - main - S3 bucket 'data_bucket' missing required tag: DataClass
FAIL - terraform/main.tf - main - Lambda 'data-processor' timeout 600 exceeds maximum of 300 seconds
FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Environment
FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Application
FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: Owner
FAIL - terraform/main.tf - main - Lambda 'processor' missing required tag: CostCenter
FAIL - kubernetes/deployment.yaml - main - Container 'myapp' must have memory limit defined
FAIL - kubernetes/deployment.yaml - main - Container 'myapp' must have CPU limit defined
FAIL - kubernetes/deployment.yaml - main - Container 'myapp' uses image from unapproved registry 'docker.io'
FAIL - kubernetes/deployment.yaml - main - Deployment 'myapp' missing required label: environment
FAIL - kubernetes/deployment.yaml - main - Deployment 'myapp' missing required label: owner

17 tests, 0 passed, 0 warnings, 17 failures

Policy validation failed. Fix violations before deployment.
```

"This is exactly what we expected. 17 violations. The output is clear about what's wrong and where."

**Participant task:** Copy the failure output and create a checklist of items to fix.

---

## Section 4: Remediate Terraform Violations (10 minutes)

"Now let's fix each violation. Start with the Terraform file."

[SLIDE: Remediate Terraform]

**Fixed terraform/main.tf:**
```hcl
# FIXED: Correct naming convention
resource "aws_s3_bucket" "data_bucket" {
  bucket = "client-dev-lab3-data"

  tags = {
    # FIXED: All required tags present
    Environment = "dev"
    Application = "lab3"
    Owner       = "training@client.com"
    CostCenter  = "CC-TRAINING"
    DataClass   = "internal"
  }
}

# FIXED: Encryption configuration added
resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# FIXED: Timeout reduced, tags added
resource "aws_lambda_function" "processor" {
  function_name = "client-dev-lab3-processor"
  runtime       = "python3.11"
  handler       = "app.handler"
  timeout       = 30  # FIXED: Within allowed limit
  memory_size   = 512
  filename      = "lambda.zip"

  tags = {
    Environment = "dev"
    Application = "lab3"
    Owner       = "training@client.com"
    CostCenter  = "CC-TRAINING"
  }
}
```

**What we fixed:**
1. S3 bucket name follows `client-{env}-{app}-{purpose}` pattern
2. Added encryption configuration with SSE-S3
3. Added all required tags to S3 bucket
4. Reduced Lambda timeout to 30 seconds (under 300 limit)
5. Added all required tags to Lambda function

**Participant task:** Update your terraform/main.tf with these fixes.

---

## Section 5: Remediate Kubernetes Violations (8 minutes)

"Now let's fix the Kubernetes manifest."

[SLIDE: Remediate Kubernetes]

**Fixed kubernetes/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: lab3
  labels:
    # FIXED: Required labels added
    app: myapp
    environment: dev
    owner: training-at-client-com
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        environment: dev
        owner: training-at-client-com
    spec:
      containers:
        - name: myapp
          # FIXED: Image from approved ECR registry
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/nginx:1.21
          ports:
            - containerPort: 80
          # FIXED: Resource limits added
          resources:
            limits:
              memory: "256Mi"
              cpu: "500m"
            requests:
              memory: "128Mi"
              cpu: "100m"
```

**What we fixed:**
1. Added required labels (environment, owner) to deployment metadata
2. Changed image from Docker Hub to approved ECR registry
3. Added resource limits (memory and CPU)
4. Added resource requests for scheduling

"Notice we also changed the namespace from 'default' to 'lab3'. While not a policy violation, it's a best practice."

**Participant task:** Update your kubernetes/deployment.yaml with these fixes.

---

## Section 6: Re-run the Pipeline (5 minutes)

"Now let's commit the fixes and re-run the pipeline."

[SLIDE: Re-run Pipeline]

**Commands:**
```bash
git add terraform/main.tf kubernetes/deployment.yaml
git commit -m "Fix all OPA policy violations"
git push origin main
```

"Watch the pipeline again. This time, the validation stage should pass."

**Expected output:**
```
Running policy validation...

17 tests, 17 passed, 0 warnings, 0 failures

Policy validation passed. Proceeding to deployment.
```

"All 17 tests pass. The pipeline can now proceed to approval and deployment."

---

## Lab Validation Checklist (3 minutes)

[SLIDE: Lab 3 Validation]

**Confirm these outcomes:**
- [ ] Initial pipeline failed at validation stage
- [ ] OPA output listed all 17 violations
- [ ] Terraform violations fixed:
  - [ ] S3 bucket naming corrected
  - [ ] S3 encryption configured
  - [ ] All required tags added
  - [ ] Lambda timeout reduced
- [ ] Kubernetes violations fixed:
  - [ ] Required labels added
  - [ ] Image from approved registry
  - [ ] Resource limits defined
- [ ] Re-run pipeline passes validation
- [ ] Pipeline proceeds to deployment stage

"Verify each checkbox. If you're still seeing violations, check the error messages carefully — they tell you exactly what's wrong."

---

## Lab Summary

"Excellent work! You've now experienced the OPA policy validation workflow:
- Seen what happens when policies are violated
- Read and interpreted OPA evaluation output
- Fixed both Terraform and Kubernetes policy violations
- Successfully re-deployed after remediation

This is the exact cycle you'll follow when your real deployments have policy violations. The key is reading the error messages — they're designed to be helpful."

---

## Bonus Challenge (if time permits)

"For those who finish early, try adding another intentional violation and see if you can predict the error message before running the pipeline."

Suggestions:
- Remove encryption from S3
- Use a timeout of 900 for Lambda
- Add a container without resource limits
- Use an image from a different public registry

---

## Instructor Notes

**Common Issues:**
- Typos in tag names (case-sensitive)
- Wrong ECR registry URL format
- Forgetting to stage all changed files

**Time Management:**
- Clone and review: 15 min
- Trigger and observe failure: 8 min
- Remediate Terraform: 10 min
- Remediate Kubernetes: 8 min
- Re-run and validate: 5 min

**Preparation:**
- Ensure OPA policies are installed in validation stage
- Verify policy error messages are clear
- Test the complete flow (fail then pass)
