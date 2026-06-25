"""
RTV demo persistence Lambda.

Fires on an EventBridge schedule. Demonstrates that a compromised build role
can plant durable, self-refreshing access into an AWS account using only
native services.

Prints evidence of access to CloudWatch Logs so the audience can watch the
Lambda "wake up" every few minutes long after the original build ran.

In a real attack this Lambda would POST to an attacker-controlled endpoint.
For the demo we keep everything in-AWS.
"""

import datetime
import json
import os

import boto3


def lambda_handler(event, context):
    sts = boto3.client("sts")
    sm = boto3.client("secretsmanager")

    identity = sts.get_caller_identity()

    secrets = sm.list_secrets(MaxResults=20)
    reachable = [s["Name"] for s in secrets.get("SecretList", [])]

    payload = {
        "fired_at": datetime.datetime.utcnow().isoformat() + "Z",
        "running_as": identity["Arn"],
        "account": identity["Account"],
        "secrets_reachable": reachable,
        "note": "Persistence is alive. In a real attack, credentials would be exfiltrated here.",
        "invocation_id": context.aws_request_id,
    }

    print(json.dumps(payload, indent=2))
    return {"statusCode": 200, "body": json.dumps(payload)}
