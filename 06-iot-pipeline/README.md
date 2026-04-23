# Clinical Device Telemetry Pipeline — Simulated FHIR Ingestion on AWS

Ingests simulated clinical device telemetry via AWS IoT Core (MQTT), streams it
through Kinesis Data Firehose, stores FHIR R4-structured Observation resources in S3,
and enables ad-hoc SQL analytics with Athena. Demonstrates a HIPAA-conscious,
fully serverless architecture for patient monitoring data at scale.

**Services:** AWS IoT Core · Kinesis Data Firehose · Amazon S3 · Amazon Athena

---

## Architecture
Device (MQTT) → AWS IoT Core → IoT Rule → Kinesis Data Firehose → S3 → Athena
The IoT Rule appends two fields to every payload before delivery:
- `ingestTs` — pipeline ingestion timestamp (when the record arrived)
- `topic` — MQTT topic the message was published to (e.g. `sensors/monitor-001`)

These fields are stored alongside the FHIR `effectiveDateTime` (when the observation
occurred), enabling correct handling of late-arriving device data — a common challenge
in clinical telemetry where network latency and device buffering cause out-of-order
delivery.

---

## HIPAA Compliance Design

This pipeline is designed with the HIPAA Security Rule Technical Safeguards
(45 CFR §164.312) in mind, making it suitable as a foundation for systems that handle
electronic Protected Health Information (ePHI).

### Access Controls (§164.312(a))

Least-privilege IAM policies are scoped to specific resource ARNs at every service
boundary. No policy in this pipeline uses `*` for actions or resources.

| Role | Permissions granted |
|---|---|
| `IoTRuleToFirehoseRole` | `firehose:PutRecord`, `firehose:PutRecordBatch` on the specific delivery stream ARN only |
| Firehose service role | `s3:PutObject` on the specific S3 bucket only |

### Audit Controls (§164.312(b))

All ingestion events flow through CloudWatch, providing a complete record of pipeline
activity. The dual-timestamp design (see Architecture above) ensures auditability of
both when a measurement was taken and when it entered the system.

### Data Integrity (§164.312(c))

- S3 partitioning by date creates an immutable, timestamped record of all ingested
  observations
- Firehose GZIP compression preserves record integrity during storage
- The error prefix (`errors/!{firehose:error-output-type}/`) captures and retains
  failed delivery records rather than silently discarding them, supporting breach
  investigation and completeness verification

### Transmission Security (§164.312(e))

- All data transmitted over TLS between IoT Core, Kinesis Firehose, and S3
- S3 bucket enforces SSE-AES256 encryption at rest
- Public access blocked at the bucket level
- No ePHI is transmitted or stored in plaintext at any stage of the pipeline

---

## Data Standard

Payloads conform to the HL7 FHIR R4 Observation resource type using real LOINC codes:

| Measurement | LOINC Code |
|---|---|
| Heart rate | `8867-4` |
| Oxygen saturation (SpO2) | `59408-5` |
| Respiratory rate | `9279-1` |

This ensures the pipeline models real-world healthcare interoperability requirements
rather than generic IoT telemetry patterns.

---

## Screenshots

See `/screenshots` for images of the running system.

---

## Cleanup

To avoid ongoing AWS charges after testing:

1. Disable the IoT Rule (stops ingestion immediately)
2. Delete the Firehose delivery stream (after it has flushed)
3. Empty and delete the S3 bucket
4. Drop the Athena database and table
5. Delete `IoTRuleToFirehoseRole`
6. Delete the Athena query results prefix if created