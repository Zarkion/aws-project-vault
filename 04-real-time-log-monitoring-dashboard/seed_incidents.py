"""
seed_incidents.py — Publish synthetic PHI access log events to CloudWatch Logs.

Events flow through the live pipeline:
  CloudWatch Logs → Subscription Filter → LogAlertProcessor (Lambda) → DynamoDB

This script does NOT write to DynamoDB directly. Records appear in the
audit-incidents table only after Lambda processes each log event, which takes
a few seconds per batch. Check the table after ~30 seconds.

Usage:
    pip install boto3
    python seed_incidents.py

Assumes AWS credentials are configured (via ~/.aws/credentials, env vars, or IAM role).
Requires: logs:CreateLogStream, logs:PutLogEvents on the target log group.
Default region: us-east-1. Override with AWS_DEFAULT_REGION env var.
"""

import boto3
import time
import random
from datetime import datetime, timezone
from botocore.exceptions import ClientError

LOG_GROUP  = "/aws/ehr/application"   # must match var.log_group_name in Terraform
LOG_STREAM = "seed-test-stream"
REGION     = "us-east-1"
BATCH_SIZE = 5    # keep small to stay well under the 1 MB payload limit
DELAY_SEC  = 1    # seconds between batches — avoids InvalidSequenceTokenException

logs = boto3.client("logs", region_name=REGION)

# ── Realistic actors ──────────────────────────────────────────────────────────
ACTORS = [
    "user:dr.chen@hospital.org",
    "user:nurse.patel@hospital.org",
    "user:admin.torres@hospital.org",
    "svc:ehr-api-prod",
    "svc:billing-processor",
    "user:dr.okafor@hospital.org",
    "user:terminated.employee@hospital.org",   # triggers AUTH_FAILURE
]

# ── Realistic FHIR-style resources ────────────────────────────────────────────
RESOURCES = [
    "Patient/10482/Observation",
    "Patient/10482/MedicationRequest",
    "Patient/77391/Condition",
    "Patient/55820/DiagnosticReport",
    "Patient/33104/Encounter",
    "Patient/88273/AllergyIntolerance",
    "Patient/*/Observation",        # bulk wildcard — suspicious
    "Patient/*/MedicationRequest",  # bulk wildcard — suspicious
]

# ── Log message templates ──────────────────────────────────────────────────────
# Must match the metric filter patterns defined in Terraform:
#   PHIUnauthorizedAccessFilter → "*UNAUTHORIZED*"
#   PHIBulkAccessFilter         → "*bulk*" || "*BULK*"
# Lambda parses actor=(\S+), resource=(\S+) and infers actionType from keywords.
TEMPLATES = [
    "INFO  PHI READ: actor={actor} resource={resource} status=200",
    "INFO  PHI READ: actor={actor} resource={resource} status=200",
    "INFO  PHI READ: actor={actor} resource={resource} status=200",
    "INFO  PHI WRITE: actor={actor} resource={resource} status=201",
    "WARN  PHI WRITE outside business hours: actor={actor} resource={resource}",
    "ERROR UNAUTHORIZED PHI access attempt: actor={actor} resource={resource} status=403",
    "ERROR UNAUTHORIZED PHI access attempt: actor={actor} resource={resource} status=401",
    "WARN  PHI bulk query: actor={actor} resource={resource} records=847 threshold=500",
    "ERROR PHI BULK export flagged: actor={actor} resource={resource} records=2341 threshold=500",
    "WARN  PHI DELETE: actor={actor} resource={resource} status=200",
]

# ── Guaranteed events — always included to ensure screenshot coverage ─────────
GUARANTEED = [
    "ERROR UNAUTHORIZED PHI access attempt: actor=user:terminated.employee@hospital.org resource=Patient/*/Observation status=403",
    "ERROR PHI BULK export flagged: actor=svc:billing-processor resource=Patient/*/MedicationRequest records=2341 threshold=500",
    "WARN  PHI WRITE outside business hours: actor=user:dr.okafor@hospital.org resource=Patient/55820/DiagnosticReport",
]


def now_ms():
    """Current UTC time in milliseconds — required by put_log_events."""
    return int(datetime.now(timezone.utc).timestamp() * 1000)


def ensure_log_stream():
    """Create the log stream if it does not already exist."""
    try:
        logs.create_log_stream(logGroupName=LOG_GROUP, logStreamName=LOG_STREAM)
        print(f"  Created log stream: {LOG_STREAM}")
    except ClientError as e:
        if e.response["Error"]["Code"] == "ResourceAlreadyExistsException":
            print(f"  Log stream already exists: {LOG_STREAM}")
        else:
            raise


def get_sequence_token():
    """Return the current upload sequence token for the stream, or None."""
    resp = logs.describe_log_streams(
        logGroupName=LOG_GROUP,
        logStreamNamePrefix=LOG_STREAM,
        limit=1,
    )
    streams = resp.get("logStreams", [])
    if streams:
        return streams[0].get("uploadSequenceToken")
    return None


def put_batch(messages):
    """Publish one batch of log messages, handling the sequence token."""
    events = [{"timestamp": now_ms(), "message": msg} for msg in messages]
    kwargs = {
        "logGroupName":  LOG_GROUP,
        "logStreamName": LOG_STREAM,
        "logEvents":     events,
    }
    token = get_sequence_token()
    if token:
        kwargs["sequenceToken"] = token
    logs.put_log_events(**kwargs)


def seed(n=25):
    print(f"Publishing {n} log events to {LOG_GROUP} (stream: {LOG_STREAM})...\n")
    print("  Events will appear in DynamoDB after Lambda processes them (~10-30s).\n")

    ensure_log_stream()

    # Build message list — guaranteed records first, then random fill
    messages = list(GUARANTEED)
    while len(messages) < n:
        template = random.choice(TEMPLATES)
        actor    = random.choice(ACTORS)
        resource = random.choice(RESOURCES)
        messages.append(template.format(actor=actor, resource=resource))

    random.shuffle(messages)

    # Publish in small batches with a short delay between each
    for i in range(0, len(messages), BATCH_SIZE):
        batch = messages[i:i + BATCH_SIZE]
        put_batch(batch)
        for msg in batch:
            level = msg.split()[0]
            print(f"  [{level:5s}] {msg[len(level):].strip()}")
        if i + BATCH_SIZE < len(messages):
            time.sleep(DELAY_SEC)

    print(f"\n  {len(messages)} events published to CloudWatch Logs.")
    print(f"  Check DynamoDB table 'audit-incidents' in ~30 seconds.")


if __name__ == "__main__":
    seed(25)
