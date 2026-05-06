import base64
import gzip
import json
import os
import re
import uuid
from datetime import datetime, timezone

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
REGION = os.environ["REGION"]

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)


def _infer_action_type(message: str) -> str:
    if "UNAUTHORIZED" in message:
        return "AUTH_FAILURE"
    if "bulk" in message or "BULK" in message:
        return "BULK_EXPORT"
    if "DELETE" in message:
        return "DELETE"
    if "WRITE" in message:
        return "WRITE"
    return "READ"


def _infer_severity(action_type: str, message: str, level: str) -> str:
    if action_type == "AUTH_FAILURE":
        return "CRITICAL"
    if action_type == "BULK_EXPORT":
        match = re.search(r"records[=:\s]+(\d+)", message, re.IGNORECASE)
        if match and int(match.group(1)) > 500:
            return "CRITICAL"
        return "WARN"
    if level.upper() == "WARN":
        return "WARN"
    return "INFO"


def handler(event, context):
    raw = base64.b64decode(event["awslogs"]["data"])
    log_data = json.loads(gzip.decompress(raw))

    log_group = log_data.get("logGroup", "")
    log_events = log_data.get("logEvents", [])

    for log_event in log_events:
        incident_id = str(uuid.uuid4())
        message = log_event.get("message", "")
        timestamp_ms = log_event.get("timestamp", 0)
        event_time = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc).isoformat()
        ingest_time = datetime.now(tz=timezone.utc).isoformat()

        try:
            actor_match = re.search(r"actor=(\S+)", message)
            resource_match = re.search(r"resource=(\S+)", message)
            level_match = re.search(r"\b(ERROR|WARN|INFO)\b", message)

            actor_id = actor_match.group(1) if actor_match else "UNKNOWN"
            resource_accessed = resource_match.group(1) if resource_match else "UNKNOWN"
            level = level_match.group(1) if level_match else ""

            action_type = _infer_action_type(message)
            severity = _infer_severity(action_type, message, level)

            record = {
                "incidentId": incident_id,
                "actorId": actor_id,
                "resourceAccessed": resource_accessed,
                "actionType": action_type,
                "eventTime": event_time,
                "ingestTime": ingest_time,
                "severity": severity,
                "logGroup": log_group,
                "rawMessage": message[:1024],
            }
        except Exception:
            record = {
                "incidentId": incident_id,
                "actorId": "UNKNOWN",
                "resourceAccessed": "UNKNOWN",
                "actionType": "UNKNOWN",
                "eventTime": event_time,
                "ingestTime": ingest_time,
                "severity": "WARN",
                "logGroup": log_group,
                "rawMessage": message[:1024],
            }

        table.put_item(Item=record)
        print(json.dumps({"incidentId": incident_id, "actionType": record["actionType"]}))
