# Lab 2: Lambda Deployment with SAM

| | |
|---|---|
| **Course** | IO-107: SDLC Pipeline & Deployment Guardrails |
| **Module** | Module 4 — Lambda Deployment Pipelines |
| **Duration** | 45 minutes |
| **Difficulty** | Intermediate |
| **Prerequisites** | Lab 1 complete; access to the CI/CD platform; AWS CLI configured; Git client configured |
| **Builds On** | Lab 1 — reuses the CodePipeline + CodeBuild project, IAM execution roles, and S3 artifact bucket. Do not recreate that infrastructure. |

---

## Learning Objectives

By the end of this lab, you will:

- Clone a serverless repository containing an AWS SAM template and Lambda function code <!-- source: course_outline_v2.md Lab 2 -->
- Review the SAM template structure and identify the Lambda configuration, alias, and deployment preference <!-- source: Lab_2_narrative.md §"Review the SAM Template" -->
- Add a new API endpoint to the function by editing both the SAM template and the Python handler <!-- source: course_outline_v2.md Lab 2 -->
- Trigger the pipeline and observe AWS SAM build and deploy stages in AWS CodeBuild <!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->
- Configure and observe traffic shifting between Lambda versions using an alias <!-- source: course_outline_v2.md Lab 2 -->
- Validate the deployed function by invoking both the existing and new endpoints <!-- source: Lab_2_narrative.md §"Lab Validation Checklist" -->

---

## Task 1: Clone the Serverless Repository

1. **Open a terminal** on your lab workstation with the AWS CLI and Git already configured.
   <!-- source: Lab_2_narrative.md §"Section 1: Clone the Repository" -->

2. Clone the training repository for this lab.

    ```bash
    git clone https://github.com/[client-org]/io107-lab2-sam-app.git
    cd io107-lab2-sam-app
    ```
    <!-- source: Lab_2_narrative.md §"Section 1: Clone the Repository" -->
    <!-- TODO: replace with real SYF repo URL before delivery -->

3. List the repository contents and confirm the structure.

    ```bash
    ls -la
    ```
    <!-- source: Lab_2_narrative.md §"Section 1: Clone the Repository" -->

    Expected structure:

    ```
    io107-lab2-sam-app/
    ├── src/
    │   ├── app.py              # Lambda function code
    │   └── requirements.txt    # Python dependencies
    ├── template.yaml           # SAM template
    ├── buildspec.yml           # Pipeline configuration
    ├── samconfig.toml          # SAM deployment config
    └── README.md
    ```
    <!-- source: Lab_2_narrative.md §"Section 1: Clone the Repository" -->

4. Create a working branch for your changes.

    ```bash
    git checkout -b lab2-add-post-endpoint
    ```
    <!-- source: https://git-scm.com/docs/git-checkout -->

> **Note:** Lab 1 already provisioned the AWS CodePipeline, AWS CodeBuild project, IAM execution role, and S3 artifact bucket that this lab uses. You do not need to recreate any of that infrastructure. <!-- source: course_outline_v2.md Lab 2 ("Builds On" — pipeline + roles carry over from Lab 1) -->

---

## Task 2: Review the SAM Template

5. **Open `template.yaml`** in your editor and locate the `Transform` line at the top.
   <!-- source: Module_4_narrative.md §"SAM Template Structure" -->

    ```yaml
    AWSTemplateFormatVersion: '2010-09-09'
    Transform: AWS::Serverless-2016-10-31
    Description: IO-107 Lab 2 - Serverless API
    ```
    <!-- source: facts_extracted_v2.md §"SAM (Serverless Application Model)" -->

6. Locate the `Globals` block. This sets defaults for every Lambda function in the template — runtime, timeout, memory, and shared environment variables.

    ```yaml
    Globals:
      Function:
        Timeout: 30
        Runtime: python3.11
        MemorySize: 256
        Environment:
          Variables:
            ENVIRONMENT: !Ref Environment
            LOG_LEVEL: !Ref LogLevel
    ```
    <!-- source: Module_4_narrative.md §"SAM Template Structure" + Lab_2_narrative.md §"Section 2: Review the SAM Template" -->

7. Locate the `ApiFunction` resource and identify the four key properties listed below.

    - **AutoPublishAlias:** `live` — SAM creates an alias named `live` and updates it automatically on each deploy. <!-- source: Module_4_narrative.md §"Traffic Shifting Configuration" -->
    - **DeploymentPreference Type:** `Canary10Percent5Minutes` — 10% of traffic shifts to the new version for 5 minutes, then 100%. <!-- source: Module_4_narrative.md §"Traffic Shifting Options" -->
    - **Events:** Two API events (`GetItems` on `GET /items`, `HealthCheck` on `GET /health`). <!-- source: Lab_2_narrative.md §"Section 2: Review the SAM Template" -->
    - **DeploymentPreference Alarms:** References `ApiErrorAlarm` so the deployment rolls back automatically if the error metric breaches the threshold during the canary window. <!-- source: Lab_2_narrative.md §"Section 2: Review the SAM Template" -->

8. Locate the `ApiErrorAlarm` resource further down. This is a standard CloudWatch alarm that watches the function's `Errors` metric. The deployment preference uses this alarm to decide whether to roll back during the canary period.

    ```yaml
    ApiErrorAlarm:
      Type: AWS::CloudWatch::Alarm
      Properties:
        MetricName: Errors
        Namespace: AWS/Lambda
        Statistic: Sum
        Period: 60
        EvaluationPeriods: 1
        Threshold: 5
        ComparisonOperator: GreaterThanThreshold
    ```
    <!-- source: Lab_2_narrative.md §"Section 2: Review the SAM Template" -->

> **What Just Happened?** You confirmed that the template wires together three things that make safe Lambda deployments possible: an alias (`live`) that callers reference instead of `$LATEST`, a deployment preference that shifts traffic gradually, and a CloudWatch alarm that triggers automatic rollback. This is the pattern used for every production Lambda. <!-- source: Module_4_narrative.md §"Section 3: Lambda Versioning and Alias Strategies" -->

---

## Task 3: Review the Function Code

9. **Open `src/app.py`** and read the existing `handler` function.
   <!-- source: Lab_2_narrative.md §"Section 3: Review the Function Code" -->

    ```python
    import json
    import os
    import logging

    logger = logging.getLogger()
    logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

    def handler(event, context):
        path = event.get('path', '')
        method = event.get('httpMethod', '')
        logger.info(f"Request: {method} {path}")

        if path == '/health':
            return health_check()
        elif path == '/items' and method == 'GET':
            return get_items()
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not found'})
            }
    ```
    <!-- source: Lab_2_narrative.md §"Section 3: Review the Function Code" -->

10. Confirm the handler routes on `event['path']` and `event['httpMethod']`. The next task will add a third branch for `POST /items`.
    <!-- source: Lab_2_narrative.md §"Section 4: Add a New API Endpoint" -->

---

## Task 4: Add a New `POST /items` Endpoint

11. **Edit `template.yaml`** and add a new `CreateItem` event inside the `ApiFunction` `Events` block.

    ```yaml
    Events:
      GetItems:
        Type: Api
        Properties:
          Path: /items
          Method: GET
      CreateItem:
        Type: Api
        Properties:
          Path: /items
          Method: POST
      HealthCheck:
        Type: Api
        Properties:
          Path: /health
          Method: GET
    ```
    <!-- source: Lab_2_narrative.md §"Section 4: Add a New API Endpoint" -->

12. **Edit `src/app.py`** and add the `POST /items` route plus a `create_item` function.

    ```python
    def handler(event, context):
        path = event.get('path', '')
        method = event.get('httpMethod', '')
        logger.info(f"Request: {method} {path}")

        if path == '/health':
            return health_check()
        elif path == '/items' and method == 'GET':
            return get_items()
        elif path == '/items' and method == 'POST':
            return create_item(event)
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not found'})
            }

    def create_item(event):
        try:
            body = json.loads(event.get('body', '{}'))
            name = body.get('name', 'Unnamed')
            new_item = {'id': 4, 'name': name, 'created': True}
            logger.info(f"Created item: {new_item}")
            return {
                'statusCode': 201,
                'body': json.dumps(new_item)
            }
        except json.JSONDecodeError:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid JSON'})
            }
    ```
    <!-- source: Lab_2_narrative.md §"Section 4: Add a New API Endpoint" -->

13. Save both files. Do not commit yet — the next task triggers the pipeline.

> **Note:** The handler dispatches on `path` and `httpMethod`. If you add more routes later, follow the same `elif` pattern rather than introducing a routing library — the OPA policies flag unnecessary Lambda dependencies. <!-- source: Module_4_narrative.md §"Section 6: Serverless Policy Validation" -->

---

## Task 5: Commit and Trigger the Pipeline

14. Stage both modified files.

    ```bash
    git add template.yaml src/app.py
    ```
    <!-- source: https://git-scm.com/docs/git-add -->

15. Commit with a descriptive message.

    ```bash
    git commit -m "Add POST /items endpoint for creating items"
    ```
    <!-- source: Lab_2_narrative.md §"Section 5: Trigger the Pipeline" -->

16. Push your branch to the remote.

    ```bash
    git push origin lab2-add-post-endpoint
    ```
    <!-- source: https://git-scm.com/docs/git-push -->

    Then open a pull request and merge it into `main` per the normal review process. The merge into `main` is what triggers AWS CodePipeline.
    <!-- source: facts_extracted_v2.md §"AWS CodePipeline" — Event-driven: Amazon EventBridge triggers on changes -->

    > **Note:** If you are working solo in the training account, the instructor will toggle branch protection off so you can merge your own PR. Otherwise pair with another student to review and merge.

17. **Open the AWS CodePipeline console** and select the `io107-lab2-sam-app` pipeline. Watch the stages execute in order:

    - **Source** — pulls the merged commit.
    - **Build** — runs `sam build` inside AWS CodeBuild to package the function. <!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->
    - **Deploy** — runs `sam deploy`, which creates a CloudFormation changeset and executes it. <!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->

18. **Click into the Build stage** and open the CodeBuild logs. You should see the buildspec phases executing in this order:

    ```yaml
    phases:
      install:
        runtime-versions:
          python: 3.11
        commands:
          - pip install aws-sam-cli
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
              --parameter-overrides Environment=$ENVIRONMENT \
              --no-fail-on-empty-changeset
    ```
    <!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->

> **Note:** `--no-fail-on-empty-changeset` prevents the pipeline from failing if a re-run produces no infrastructure changes. `--capabilities CAPABILITY_IAM` is required because SAM creates IAM roles for the Lambda function. <!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->

---

## Task 6: Observe Traffic Shifting on the Alias

19. **Open the AWS Lambda console** and navigate to **Functions**.
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

20. Click the function whose name starts with **lab2-api-ApiFunction-**. The exact suffix is generated by CloudFormation.
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

21. Click the **Aliases** tab, then click the **live** alias.
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

22. Look at the **Weights** section. During the 5-minute canary window you should see something like:

    ```
    Version 2: 10%
    Version 1: 90%
    ```

    After the canary window completes, it should look like this:

    ```
    Version 2: 100%
    ```
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" + Module_4_narrative.md §"Traffic Shifting Options" -->

> **What Just Happened?** You watched AWS SAM publish an immutable version of your function code and shift traffic to it gradually. If the `ApiErrorAlarm` had breached its threshold during those 5 minutes, the deployment preference would have automatically routed all traffic back to the previous version. This is what makes safe Lambda deployments possible. <!-- source: Module_4_narrative.md §"Section 3: Lambda Versioning and Alias Strategies" -->

---

## Task 7: Test Both Endpoints

23. Retrieve the API Gateway endpoint URL from the CloudFormation outputs.

    ```bash
    API_ENDPOINT=$(aws cloudformation describe-stacks \
      --stack-name io107-lab2-sam-app \
      --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
      --output text)
    echo "$API_ENDPOINT"
    ```
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" + https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-stacks.html -->

24. Test the existing `GET /items` endpoint. The SAM-generated `ApiEndpoint` output does **not** include a trailing slash (it resolves to `https://<id>.execute-api.us-east-1.amazonaws.com/Prod`), so always join paths with an explicit `/`. The `${API_ENDPOINT%/}` shell pattern below also strips any accidental trailing slash defensively.

    ```bash
    curl "${API_ENDPOINT%/}/items"
    ```
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

    Expected response:

    ```json
    {"items": [{"id": 1, "name": "Item 1"}, {"id": 2, "name": "Item 2"}, {"id": 3, "name": "Item 3"}]}
    ```
    <!-- source: Lab_2_narrative.md §"Section 3: Review the Function Code" -->

25. Test your new `POST /items` endpoint.

    ```bash
    curl -X POST "${API_ENDPOINT%/}/items" \
      -H "Content-Type: application/json" \
      -d '{"name": "New Item"}'
    ```
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

    Expected response:

    ```json
    {"id": 4, "name": "New Item", "created": true}
    ```
    <!-- source: Lab_2_narrative.md §"Section 6: Configure and Observe Traffic Shifting" -->

26. If the POST returns a 502 or 500, open **CloudWatch Logs > Log groups > /aws/lambda/lab2-api-ApiFunction-...** and read the most recent log stream for the Python traceback.
    <!-- source: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html -->

---

## Task 8: Inspect the Alias from the CLI (Reference Only)

27. Retrieve the current alias configuration.

    ```bash
    aws lambda get-alias \
      --function-name lab2-api-ApiFunction-xxx \
      --name live
    ```
    <!-- source: https://docs.aws.amazon.com/cli/latest/reference/lambda/get-alias.html + Lab_2_narrative.md §"Section 7: Simulate a Rollback" -->

    Replace the `xxx` suffix with the actual function name you confirmed in Task 6.

28. Note the `FunctionVersion` field. If the canary completed cleanly, this is the new version. If a rollback occurred, it will be the previous version.

> **Note:** Do not run `aws lambda update-alias` manually in production. The `DeploymentPreference` in the SAM template manages alias updates and rollbacks. The CLI command above is shown only so you understand the underlying mechanism. <!-- source: Lab_2_narrative.md §"Section 7: Simulate a Rollback" -->

---

## Troubleshooting

### `sam build` fails in CodeBuild with a missing-package error

**Check:** Open the Build stage CodeBuild log and look at the `install` phase. Confirm `pip install aws-sam-cli` completed without errors, and that `requirements.txt` lists every package your function imports.

**Fix:** Add the missing package to `src/requirements.txt`, commit, and push to retrigger the pipeline.

```bash
echo "boto3" >> src/requirements.txt
git add src/requirements.txt
git commit -m "Add boto3 to requirements"
git push
```
<!-- source: Lab_2_narrative.md §"Instructor Notes" -->

### API Gateway returns 500 Internal Server Error on `POST /items`

**Check:** Open **CloudWatch Logs** for the function log group `/aws/lambda/lab2-api-ApiFunction-...` and read the most recent log stream. Look for a Python traceback.
<!-- source: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html -->

**Fix:** Most commonly this is a JSON parse error in `create_item` because the request body is empty or malformed. Re-send the request with `-H "Content-Type: application/json"` and a valid JSON body.
<!-- source: Lab_2_narrative.md §"Instructor Notes" -->

### Traffic shifting weights never appear on the alias

**Check:** You may have missed the 5-minute canary window. Verify by looking at the **Versions** tab on the function — if a new version exists and the `live` alias points to it at 100%, the deployment already finished.

**Fix:** Trigger another deployment with a trivial code change and watch the alias weights immediately after the Deploy stage completes.
<!-- source: Lab_2_narrative.md §"Instructor Notes" -->

### Pipeline Deploy stage fails with "CAPABILITY_IAM" error

**Check:** The CodeBuild log shows a CloudFormation error stating it cannot create IAM resources.

**Fix:** Confirm the `sam deploy` command in `buildspec.yml` includes `--capabilities CAPABILITY_IAM`. SAM creates an IAM execution role for each Lambda function and CloudFormation requires explicit acknowledgement to create IAM resources.
<!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->

### `sam deploy` reports "no changes to deploy" and the pipeline fails

**Check:** You re-ran the pipeline without modifying any code or template content.

**Fix:** This is expected — the `--no-fail-on-empty-changeset` flag in the buildspec should prevent the failure. If the pipeline is still failing on an empty changeset, confirm the flag is present in `buildspec.yml`.
<!-- source: Module_4_narrative.md §"SAM Build and Deploy in CodeBuild" -->

---

## Knowledge Check

**Question 1:** In the SAM template you reviewed, the `AutoPublishAlias: live` property triggers two automatic behaviours on each deploy. What are they?
<!-- source: Module_4_narrative.md §"Traffic Shifting Configuration" -->

**Question 2:** Production Lambda deployments standardise on `Canary10Percent5Minutes`. Why is this preferred over `AllAtOnce`?
<!-- source: Module_4_narrative.md §"Traffic Shifting Options" -->

**Question 3:** What is the difference between `$LATEST` and a published Lambda version, and why should event sources reference an alias rather than `$LATEST`?
<!-- source: Module_4_narrative.md §"Lambda Versions" + §"Lambda Aliases" -->

**Question 4:** During the canary window, the `ApiErrorAlarm` defined in the template breaches its threshold. What happens to the traffic weights on the `live` alias, and who performs the rollback?
<!-- source: Lab_2_narrative.md §"Section 2: Review the SAM Template" + Module_4_narrative.md §"Section 3: Lambda Versioning and Alias Strategies" -->

**Question 5:** The standard is to use AWS SAM rather than raw CloudFormation for Lambda deployments. Name two SAM features that justify this choice.
<!-- source: Module_4_narrative.md §"Section 1: Serverless Deployment Patterns" + facts_extracted_v2.md §"SAM (Serverless Application Model)" -->

*Answers are in the Knowledge Check Bank.*

---

## Completion Checklist

- [ ] Cloned the `io107-lab2-sam-app` repository and confirmed the directory structure
- [ ] Identified `Transform: AWS::Serverless-2016-10-31` and confirmed it as a SAM template
- [ ] Located the `AutoPublishAlias`, `DeploymentPreference`, and `Alarms` properties on `ApiFunction`
- [ ] Located `ApiErrorAlarm` and understood its role in automatic rollback
- [ ] Added a `CreateItem` event for `POST /items` to `template.yaml`
- [ ] Added the `create_item` handler and route branch to `src/app.py`
- [ ] Committed and pushed the branch, merged to `main`, and triggered the pipeline
- [ ] Observed the Source, Build, and Deploy stages complete in AWS CodePipeline
- [ ] Reviewed the AWS CodeBuild log and confirmed `sam build` and `sam deploy` ran successfully
- [ ] Inspected the `live` alias on the Lambda console and observed weighted traffic shifting
- [ ] Successfully invoked `GET /items` against the API Gateway endpoint
- [ ] Successfully invoked `POST /items` and received a 201 response with the new item
- [ ] Retrieved the alias configuration via `aws lambda get-alias` and confirmed the current `FunctionVersion`

---

## Cost Considerations

| Component | Type | Approximate Cost |
|-----------|------|------------------|
| AWS Lambda invocations (lab traffic) | Requests + GB-seconds | Negligible — well under free tier <!-- source: https://aws.amazon.com/lambda/pricing/ verified 2026-04-07 --> |
| API Gateway requests (lab traffic) | REST API requests | Negligible — well under free tier <!-- source: https://aws.amazon.com/api-gateway/pricing/ verified 2026-05-11 --> |
| AWS CodeBuild build minutes | `general1.small` Linux | A few cents per pipeline run <!-- source: https://aws.amazon.com/codebuild/pricing/ verified 2026-04-07 --> |
| AWS CodePipeline | Active pipeline | $1.00 per active pipeline per month (pro-rated) <!-- source: https://aws.amazon.com/codepipeline/pricing/ verified 2026-04-07 --> |
| CloudWatch Logs storage | Function + build logs | Negligible for lab duration <!-- source: https://aws.amazon.com/cloudwatch/pricing/ verified 2026-05-11 --> |

**Cleanup:** The pipeline, IAM roles, and S3 artifact bucket from Lab 1 stay in place — Lab 3 will reuse them. If your lab account is being torn down at the end of the day, delete the `io107-lab2-sam-app` CloudFormation stack from the AWS CloudFormation console; that removes the Lambda function, API Gateway, alarm, and IAM role created by SAM. <!-- source: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-delete-stack.html -->

---

## Next Steps

In **Lab 3: Policy-as-Code Evaluation & Failure Remediation**, you will deploy a template containing intentional OPA policy violations, interpret the evaluation output in the pipeline, and remediate each violation. The pipeline, OPA validation stage, and IAM roles you have been using carry forward. <!-- source: course_outline_v2.md Lab 3 -->

---

## Resources

- [AWS SAM Developer Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/) — SAM template reference and CLI commands
- [AWS Lambda Deployment Guide](https://docs.aws.amazon.com/lambda/latest/dg/deploying-lambda-apps.html) — Deployment patterns and packaging
- [Lambda Versioning and Aliases](https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html) — Versions, aliases, and qualified ARNs
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/) — Pipeline stages and execution
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/) — buildspec.yml reference
- [CloudWatch Logs for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html) — Log group naming and access
