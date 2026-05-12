# Lab 2: Lambda Deployment with SAM — Teaching Narrative

**Duration:** 45 minutes

---

## Lab Introduction (3 minutes)

"In Lab 1, we deployed to EKS. Now let's experience serverless deployment with AWS SAM. This lab will walk you through deploying a Lambda function, adding a new API endpoint, and configuring traffic shifting between versions.

By the end of this lab, you'll have hands-on experience with SAM templates, Lambda versioning, aliases, and the traffic shifting that enables safe deployments."

[SLIDE: Lab 2 - Lambda Deployment with SAM]

**Objectives:**
- Clone a serverless repository with a SAM template
- Review the SAM template structure and Lambda configuration
- Add a new API endpoint to the function
- Trigger the pipeline and observe SAM build/deploy
- Configure and test traffic shifting between Lambda versions

**Prerequisites:**
- Access to the CI/CD platform
- AWS CLI configured
- Git client configured

---

## Section 1: Clone the Repository (5 minutes)

"Let's start by cloning the serverless application repository."

[SLIDE: Clone the Repository]

**Commands:**
```bash
# Clone the training repository
git clone https://codecommit.us-east-1.amazonaws.com/v1/repos/io107-lab2-sam-app

# Navigate to the repository
cd io107-lab2-sam-app

# Review the structure
ls -la
```

**Expected structure:**
```
io107-lab2-sam-app/
├── src/
│   ├── app.py              # Lambda function code
│   └── requirements.txt    # Python dependencies
├── template.yaml           # SAM template
├── buildspec.yml          # Pipeline configuration
├── samconfig.toml         # SAM deployment config
└── README.md
```

"The key file here is `template.yaml` — the SAM template. Let's look at it closely."

**Participant task:** Clone the repository and explore the structure.

---

## Section 2: Review the SAM Template (10 minutes)

"Open `template.yaml` and let's walk through it together."

[SLIDE: Review SAM Template]

**template.yaml:**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: IO-107 Lab 2 - Serverless API

Globals:
  Function:
    Timeout: 30
    Runtime: python3.11
    MemorySize: 256
    Environment:
      Variables:
        ENVIRONMENT: !Ref Environment
        LOG_LEVEL: !Ref LogLevel

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - stg
      - prd
  LogLevel:
    Type: String
    Default: INFO

Resources:
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: app.handler
      Description: Lab 2 API Function
      AutoPublishAlias: live
      DeploymentPreference:
        Type: Canary10Percent5Minutes
        Alarms:
          - !Ref ApiErrorAlarm
      Events:
        GetItems:
          Type: Api
          Properties:
            Path: /items
            Method: GET
        HealthCheck:
          Type: Api
          Properties:
            Path: /health
            Method: GET
      Tags:
        Environment: !Ref Environment
        Application: lab2-api
        Owner: training@client.com
        CostCenter: CC-TRAINING

  ApiErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${AWS::StackName}-errors"
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref ApiFunction

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/"
  FunctionArn:
    Description: Lambda function ARN
    Value: !GetAtt ApiFunction.Arn
```

**Key points to discuss:**
- `Transform: AWS::Serverless-2016-10-31` enables SAM
- `Globals` section sets defaults for all functions
- `AutoPublishAlias: live` creates an alias automatically
- `DeploymentPreference: Canary10Percent5Minutes` enables traffic shifting
- The CloudWatch alarm triggers rollback if errors spike

"Notice the deployment preference. When we deploy a new version, only 10% of traffic goes to it initially. If errors exceed the threshold, the deployment automatically rolls back."

**Participant task:** Identify the deployment preference type and what it means.

---

## Section 3: Review the Function Code (5 minutes)

"Now let's look at the actual function code in `src/app.py`."

[SLIDE: Review Function Code]

**src/app.py:**
```python
import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

def handler(event, context):
    """Main Lambda handler"""
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

def health_check():
    """Health check endpoint"""
    return {
        'statusCode': 200,
        'body': json.dumps({
            'status': 'healthy',
            'environment': os.environ.get('ENVIRONMENT', 'unknown')
        })
    }

def get_items():
    """Get items endpoint"""
    items = [
        {'id': 1, 'name': 'Item 1'},
        {'id': 2, 'name': 'Item 2'},
        {'id': 3, 'name': 'Item 3'}
    ]
    return {
        'statusCode': 200,
        'body': json.dumps({'items': items})
    }
```

"This is a simple API with two endpoints: `/health` and `/items`. We're going to add a third endpoint."

---

## Section 4: Add a New API Endpoint (10 minutes)

"Your task is to add a new endpoint: `POST /items` that creates a new item. This will require changes to both the SAM template and the function code."

[SLIDE: Add New Endpoint]

**Step 1: Update template.yaml**

Add a new event to the function:
```yaml
Events:
  GetItems:
    Type: Api
    Properties:
      Path: /items
      Method: GET
  CreateItem:           # Add this event
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

**Step 2: Update src/app.py**

Add the new route handler:
```python
def handler(event, context):
    """Main Lambda handler"""
    path = event.get('path', '')
    method = event.get('httpMethod', '')

    logger.info(f"Request: {method} {path}")

    if path == '/health':
        return health_check()
    elif path == '/items' and method == 'GET':
        return get_items()
    elif path == '/items' and method == 'POST':  # Add this condition
        return create_item(event)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Not found'})
        }

def create_item(event):
    """Create a new item"""
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

**Participant task:** Make these changes to your local files.

---

## Section 5: Trigger the Pipeline (8 minutes)

"Now commit and push your changes to trigger the pipeline."

[SLIDE: Trigger Pipeline]

**Commands:**
```bash
# Stage your changes
git add template.yaml src/app.py

# Commit
git commit -m "Add POST /items endpoint for creating items"

# Push to trigger pipeline
git push origin main
```

"Navigate to CodePipeline and watch the deployment. Let's observe what happens."

[SLIDE: Observe Pipeline Stages]

**What to watch for:**
1. **Source stage:** Code pulled from repository
2. **Build stage:** `sam build` compiles the function
3. **Deploy stage:** `sam deploy` creates/updates stack
4. **Traffic shifting:** Watch the alias routing

"In the CodeBuild logs, you'll see `sam build` packaging the function, then `sam deploy` creating a CloudFormation changeset and executing it. The deployment preference we configured means traffic will shift gradually."

**Instructor demonstrates:** Navigating to Lambda console, showing:
- The new version being published
- The alias routing configuration
- Traffic weight during canary deployment

---

## Section 6: Configure and Observe Traffic Shifting (10 minutes)

"Let's understand what's happening with traffic shifting. Navigate to the Lambda console."

[SLIDE: Traffic Shifting]

**Observing traffic weights:**
1. Go to Lambda console
2. Find the function (lab2-api-ApiFunction-xxx)
3. Click on "Aliases"
4. Select the "live" alias
5. View the weighted routing configuration

"During the canary period, you'll see something like:
- Version 2: 10% weight
- Version 1: 90% weight

After 5 minutes (our canary duration), it becomes:
- Version 2: 100% weight"

**Testing the deployment:**
```bash
# Get the API endpoint from CloudFormation outputs
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name io107-lab2-sam-app \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

# Test GET /items
curl ${API_ENDPOINT}items

# Test POST /items (your new endpoint)
curl -X POST ${API_ENDPOINT}items \
  -H "Content-Type: application/json" \
  -d '{"name": "New Item"}'

# Expected response: {"id": 4, "name": "New Item", "created": true}
```

"If your new endpoint works, congratulations! You've successfully deployed a Lambda update with traffic shifting."

**Participant task:** Test both endpoints and verify the POST endpoint works.

---

## Section 7: Simulate a Rollback (Optional - 5 minutes)

"If we have time, let's see what happens when a deployment fails."

[SLIDE: Rollback Scenario]

"In a real scenario, if the error alarm triggers during the canary period, CodeDeploy automatically rolls back. Let's simulate this by looking at how you would manually roll back."

**Manual rollback (for understanding):**
```bash
# View current alias configuration
aws lambda get-alias --function-name lab2-api-ApiFunction-xxx --name live

# To manually roll back to previous version:
aws lambda update-alias \
  --function-name lab2-api-ApiFunction-xxx \
  --name live \
  --function-version 1
```

"You typically wouldn't do this manually — the deployment preference handles it. But understanding the mechanism helps with troubleshooting."

---

## Lab Validation Checklist (4 minutes)

[SLIDE: Lab 2 Validation]

**Confirm these outcomes:**
- [ ] Repository cloned successfully
- [ ] New POST /items endpoint added to template and code
- [ ] Pipeline triggered and completed
- [ ] New Lambda version published
- [ ] Alias shows traffic shifting (or completed)
- [ ] GET /items returns items list
- [ ] POST /items creates and returns new item

"Verify each of these checkboxes. If the POST endpoint isn't working, check your code changes and the CloudWatch logs for errors."

---

## Lab Summary

"Great work! You've now deployed a Lambda function using SAM with:
- SAM template defining the function and API
- Multiple endpoints on a single function
- Automatic versioning and alias management
- Canary traffic shifting for safe deployments
- CloudWatch alarm integration for automatic rollback

This is the pattern you'll use for serverless deployments. The traffic shifting gives you confidence that new code won't break production — issues are caught when only 10% of traffic sees the new version."

---

## Instructor Notes

**Common Issues:**
- SAM build fails: Check Python syntax and requirements.txt
- API Gateway 500 errors: Check CloudWatch logs for Lambda errors
- Traffic shifting not visible: May need to catch it during the 5-minute window

**Time Management:**
- Clone and explore: 5 min
- Review SAM template: 10 min
- Review function code: 5 min
- Add endpoint: 10 min
- Trigger pipeline: 8 min
- Traffic shifting: 10 min
- Validation: 4 min

**Preparation:**
- Ensure SAM CLI is installed in CodeBuild
- Verify API Gateway endpoint is accessible
- Test the complete flow before class
