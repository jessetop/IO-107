# Lab 2: Lambda Deployment with SAM

**Duration:** 45 min
**Companion lecture:** Module 4 — Lambda Deployment Pipelines

## Files to author

- `template.yaml` — SAM template with:
  - `AWS::Serverless::Function` for `ApiFunction`
  - `AutoPublishAlias: live`
  - `DeploymentPreference: Type: Canary10Percent5Minutes` + `Alarms: [!Ref ApiErrorAlarm]`
  - `AWS::Serverless::Api` with `/items` GET + POST routes
  - `AWS::CloudWatch::Alarm` for 5xx error rate (`ApiErrorAlarm`)
- `src/app.py` — Python 3.12 handler returning API Gateway proxy response shape `{"statusCode": 200, "body": json.dumps(...)}`
- `src/requirements.txt`
- `tests/test_app.py` — pytest tests for the handler
- `samconfig.toml` — stack name + region defaults
- `buildspec.yml` — `sam build` + `sam deploy --no-confirm-changeset --capabilities CAPABILITY_IAM`
- `README.md` (this file)

## Lab guide reference

See `SYF-IO-107 - Lab 2 - Lambda Deployment with SAM` in the deliverables Drive folder.

## Outstanding

- All code files. ~2 hr authoring.
- Confirm Lambda function URL is NOT used (v3 scope drops Function URLs).
