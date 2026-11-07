# SentinelOps — REST & WebSocket API Specification

## 1. API Standards & Communication Protocol
- **Format**: RESTful JSON over HTTP/1.1 (Prefix: `/api/v1`).
- **Real-time Push**: WebSockets (`/api/v1/ws/alerts`, `/api/v1/ws/incidents`).
- **Target Host Binding**: Binds to `0.0.0.0:8000` inside VM 1; reachable by Windows 11 host at `http://192.168.56.10:8000`.
- **Validation**: Strict Pydantic v2 schemas; unvalidated input is rejected with HTTP 422 before reaching service logic.

---

## 2. Authentication & Authorization

### 2.1 Login
- `POST /api/v1/auth/login`
- **Request**:
```json
{
  "email": "analyst@sentinelops.lab",
  "password": "SecureLabPassword123!"
}
```
- **Response** (`200 OK`):
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "c1f7b8e2-...",
    "email": "analyst@sentinelops.lab",
    "role": "ANALYST"
  }
}
```

---

## 3. Ingestion & Alert Endpoints

### 3.1 Local Wazuh Forwarder Ingestion
- `POST /api/v1/alerts/ingest`
- **Headers**: `X-SentinelOps-Webhook-Key: <PRE_SHARED_SECRET>`
- **Description**: Receives single or batched alerts from the local VM 1 file tailer.
- **Idempotency**: Duplicate external IDs or identical dedup hashes within the 5-minute sliding window update occurrence counts and return `200 OK` without duplicating incidents.

### 3.2 List Alerts
- `GET /api/v1/alerts?severity=HIGH&mitre_technique=T1059.004&page=1&limit=50`

---

## 4. Incident Management Endpoints

### 4.1 List Incidents
- `GET /api/v1/incidents?status=NEW,TRIAGED&page=1&limit=20`

### 4.2 Get Incident Details
- `GET /api/v1/incidents/{incident_id}`
- **Response** (`200 OK`): Returns incident record, linked alerts array, chronological timeline, analyst comments, and proposed playbooks.

### 4.3 Update Incident Status / Assignment
- `PATCH /api/v1/incidents/{incident_id}`
- **Request**:
```json
{
  "status": "TRIAGED",
  "assigned_to_user_id": "c1f7b8e2-..."
}
```

### 4.4 Add Investigation Comment
- `POST /api/v1/incidents/{incident_id}/comments`
- **Request**:
```json
{
  "comment_body": "Confirmed malicious base64 execution from PID 4815. Containment recommended."
}
```

---

## 5. SOAR Playbooks & HITL Approval Endpoints

### 5.1 List Allowlisted Playbooks
- `GET /api/v1/soar/playbooks`
- **Response** (`200 OK`): Returns metadata and JSON parameter schemas for registered playbooks.

### 5.2 Request Playbook Execution
- `POST /api/v1/incidents/{incident_id}/playbooks/request`
- **Request**:
```json
{
  "playbook_id": "pb-isolate-host",
  "parameters": {
    "agent_id": "001"
  }
}
```
- **Response** (`201 Created`):
```json
{
  "execution_id": "e4b9821a-...",
  "status": "PENDING_APPROVAL",
  "is_disruptive": true,
  "message": "Human approval required for disruptive playbook execution."
}
```

### 5.3 Human Approval Gate (HITL Confirmation)
- `POST /api/v1/soar/executions/{execution_id}/approve`
- **Headers**: `Authorization: Bearer <JWT>`
- **Request**:
```json
{
  "decision": "APPROVED",
  "approval_reason": "Malicious reverse shell confirmed on victim machine 01."
}
```
- **Response** (`200 OK`):
```json
{
  "execution_id": "e4b9821a-...",
  "status": "RUNNING"
}
```

### 5.4 Emergency Kill Switch / Break-Glass API
- `POST /api/v1/soar/emergency-abort`
- **Requires Role**: `ADMIN`
- **Description**: Immediately terminates running playbooks, cancels queued tasks, and signals Wazuh to restore network connectivity on victim nodes.

---

## 6. Audit & Reporting Endpoints

### 6.1 Query Audit Trail
- `GET /api/v1/audit?limit=100`

### 6.2 Export Incident Report
- `GET /api/v1/incidents/{incident_id}/report?format=markdown` (or `pdf`)
- **Response**: Comprehensive post-incident forensic summary.
