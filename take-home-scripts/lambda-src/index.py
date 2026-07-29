"""Bounded take-home invocation proof; uses only the Python standard library."""

from datetime import datetime, timezone
import json


def lambda_handler(event, context):
    payload = {
        "marker": "RTV_TAKE_HOME_INVOCATION",
        "fired_at": datetime.now(timezone.utc).isoformat(),
        "event_source": event.get("source", "manual-proof") if isinstance(event, dict) else "unknown",
        "invocation_id": context.aws_request_id,
        "function_name": context.function_name,
    }
    print(json.dumps(payload, sort_keys=True))
    return payload
