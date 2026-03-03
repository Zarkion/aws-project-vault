# <Real-Time Log Monitoring Dashboard> — Module 4
**Goal:** Detect errors in application logs in near‑real time, trigger alerts, and view live trends.
**Architecture:**  A CloudWatch‑driven pipeline with metric filters + alarms (SNS), a Lambda log processor that writes incidents to DynamoDB, and a CloudWatch Dashboard. (Optional) Ship logs to S3/Athena for QuickSight analytics.
**App/Lambda/Service → CloudWatch Logs (Log Group)**

→ (**A**) **Metric Filter → Alarm → SNS (email)**

→ (**B**) **Subscription Filter → Lambda (LogAlertProcessor) → DynamoDB (incidents)**

→ **CloudWatch Dashboard** (metric + log query + alarm widget)
**How to run:**
**Acceptance checklist:**
**Portfolio deliverables:**
**Cleanup:**

