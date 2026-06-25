"""RunRacing demo API handler.

Proves the deployed stack end to end from inside the VPC: a public HTTP endpoint
that exercises DynamoDB, S3, Kinesis (telemetry), and Secrets Manager using the
Lambda's least-privilege role, then returns the results as JSON. ElastiCache is
reported as configured (no redis client is bundled in the base runtime).
"""
import json
import os
import time

import boto3

ddb = boto3.client("dynamodb")
s3 = boto3.client("s3")
kinesis = boto3.client("kinesis")
secrets = boto3.client("secretsmanager")

TABLE = os.environ.get("TABLE_NAME", "")
REPLAY_BUCKET = os.environ.get("REPLAY_BUCKET", "")
STREAM = os.environ.get("STREAM_NAME", "")
SECRET_ARN = os.environ.get("SECRET_ARN", "")
REDIS_ENDPOINT = os.environ.get("REDIS_ENDPOINT", "")
REGION = os.environ.get("AWS_REGION", "")


def lambda_handler(event, context):
    checks = {}
    pid = "healthcheck-" + str(int(time.time()))

    try:
        ddb.put_item(
            TableName=TABLE,
            Item={"playerId": {"S": pid}, "note": {"S": "demo health check"}},
        )
        got = ddb.get_item(TableName=TABLE, Key={"playerId": {"S": pid}})
        checks["dynamodb"] = "ok" if "Item" in got else "no-item"
    except Exception as exc:  # noqa: BLE001
        checks["dynamodb"] = "error: " + str(exc)

    try:
        key = "healthcheck/check.txt"
        s3.put_object(Bucket=REPLAY_BUCKET, Key=key, Body=b"demo health check")
        obj = s3.get_object(Bucket=REPLAY_BUCKET, Key=key)
        checks["s3"] = "ok" if obj["Body"].read() else "empty"
    except Exception as exc:  # noqa: BLE001
        checks["s3"] = "error: " + str(exc)

    try:
        kinesis.put_record(
            StreamName=STREAM,
            Data=json.dumps({"event": "healthcheck", "playerId": pid}).encode(),
            PartitionKey=pid,
        )
        checks["kinesis"] = "ok"
    except Exception as exc:  # noqa: BLE001
        checks["kinesis"] = "error: " + str(exc)

    try:
        val = secrets.get_secret_value(SecretId=SECRET_ARN)
        checks["secrets"] = "ok" if val.get("SecretString") else "empty"
    except Exception as exc:  # noqa: BLE001
        checks["secrets"] = "error: " + str(exc)

    checks["redis_endpoint_configured"] = "yes" if REDIS_ENDPOINT else "no"

    body = {
        "status": "ok",
        "service": "runracing-demo-api",
        "region": REGION,
        "checks": checks,
    }
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }
