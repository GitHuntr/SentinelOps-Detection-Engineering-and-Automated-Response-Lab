# SentinelOps — Project Requirements Document (PRD)

## 1. Document Control
- **Document Version**: 2.1.0 (Phase 00 Final Architecture Correction)
- **Status**: Pending User Review & Approval
- **Classification**: Internal / Lab Specification

---

## 2. Executive Overview & Problem Statement
Modern Security Operations Centers (SOCs) face alert fatigue, complex adversary techniques, fragmented tooling, and high operational friction between detection engineering and automated incident response.

**SentinelOps** is an end-to-end SOC simulation platform and automated response lab engineered specifically for a realistic, resource-constrained virtualization environment:
- **Host**: Windows 11 development machine (16 GB physical RAM, <100 GB available SSD storage).
- **Hypervisor**: Oracle VirtualBox.
- **VM 1 (SOC Server)**: Ubuntu Server 24.04 LTS (Wazuh 4.8.x Manager, Wazuh 4.8.x Indexer, Wazuh 4.8.x Dashboard, SentinelOps FastAPI Backend, PostgreSQL 16 DB).
- **VM 2 (Victim Endpoint)**: Ubuntu 24.04 LTS (Wazuh 4.8.x Agent, Linux Auditd, FIM, Atomic Red Team).
- **VM 3 (Attacker)**: Existing Kali Linux VM (Optional, invoked sequentially on demand).

The project simulates the complete detection-to-response lifecycle:
1. Endpoint telemetry generation (Auditd, FIM, Syslog).
2. Telemetry ingestion, decoding, and custom detection in Wazuh 4.8 SIEM.
3. Explicit MITRE ATT&CK technique mapping.
4. Reliable alert ingestion into SentinelOps Backend via an at-least-once alert tailer with durable state checkpointing, bounded disk buffering, and exponential back-pressure handling.
5. Ingestion deduplication and threat intelligence enrichment using PostgreSQL and local/external connectors.
6. Incident lifecycle management and analyst triage.
7. Safe, allowlisted SOAR playbooks utilizing native Wazuh 4.8 Active Response (Wazuh AR message protocol, registered executables with JSON stdin/stdout, and verified rollback) with mandatory Human-in-the-Loop (HITL) gates for disruptive actions.
8. Controlled containment rollback and safe emergency recovery procedures, maintaining an isolated out-of-band management channel.

---

## 3. Pinned Wazuh Architecture & Protocol Details (Wazuh 4.8)

To avoid ambiguity and prevent mixing 4.x and 5.x mechanisms, SentinelOps explicitly pins **Wazuh 4.8 LTS**:

### 3.1 Inter-Component Protocols & Cryptography

| Communication Link | Transport Protocol | Cryptography / Authentication Standard | Official Wazuh 4.8 Mechanism |
| :--- | :--- | :--- | :--- |
| **Agent $\rightarrow$ Manager (Data)** | TCP/UDP 1514 | Symmetric Encryption (AES-128 / Blowfish). Key size: 128-bit key negotiated from the pre-shared agent key string stored in `/var/ossec/etc/client.keys`. | `wazuh-remoted` daemon handles encrypted payload framing. |
| **Agent Enrollment** | TCP 1515 | TLS 1.2+ encrypted tunnel | `wazuh-authd` daemon verifies password/token and issues unique agent ID & 128-bit key. |
| **Active Response (AR)** | TCP 1514 (Internal channel) | Encrypted message within the persistent agent session | Manager sends an internal AR control message: `(msg_to_agent) [] AR_command JSON_payload`. |
| **Manager $\rightarrow$ Indexer** | HTTPS / Port 9200 | TLS 1.3 / Mutual TLS (mTLS) with internal x509 certs | OpenSearch REST API indexing via `Filebeat-oss` / native output. |
| **Dashboard $\rightarrow$ Indexer/Manager**| HTTPS / Port 443, 55000 | TLS 1.3 with Basic Auth & JWT tokens | Node.js Dashboard app queries OpenSearch (9200) and Wazuh Manager API (55000). |

---

## 4. Realistic Staged Resource Planning (Windows 11 / 16 GB Physical RAM)

The Windows 11 host OS requires a **guaranteed 6.0 GB to 8.0 GB RAM headroom** to support OS services, VSCode/IDE, browser tabs, Git, background antivirus, and the VirtualBox hypervisor process overhead. 

To prevent physical RAM exhaustion and host paging/swapping, SentinelOps establishes a **Strict Staged Deployment Strategy**:

```
Mode 1: SIEM & Ingestion Baseline (VM 1 Only)
┌─────────────────────────────────┬─────────────────────────────────┐
│ Windows 11 Host: 10.0 GB RAM    │ VM 1 (SOC Server): 6.0 GB RAM   │
│ (Development, Browser, IDE)     │ (Wazuh Stack + FastAPI + PG16)  │
└─────────────────────────────────┴─────────────────────────────────┘

Mode 2: Live Detection & ART Emulation (VM 1 + VM 2)
┌─────────────────────────────────┬───────────────────┬─────────────┐
│ Windows 11 Host: 8.0 GB RAM     │ VM 1: 6.0 GB RAM  │ VM 2: 2.0 GB│
│ (Browser, IDE, Git)             │ (Tuned JVM Heap)  │ (Victim)    │
└─────────────────────────────────┴───────────────────┴─────────────┘

Mode 3: External Exploitation Scenario (Sequential Mode)
┌─────────────────────────────────┬───────────────────┬─────────────┐
│ Windows 11 Host: 8.0 GB RAM     │ VM 2: 2.0 GB RAM  │ VM 3: 2.0 GB│
│ (VM 1 paused or offline)        │ (Victim Target)   │ (Kali Linux)│
└─────────────────────────────────┴───────────────────┴─────────────┘
*Note: VM 1, VM 2, and VM 3 NEVER run simultaneously on 16 GB host RAM.*
```

### 4.1 Operating Profiles

| Profile Name | Active Virtual Machines | RAM Allocation Breakdown | Host RAM Headroom | Operational Rules & Constraints |
| :--- | :--- | :--- | :--- | :--- |
| **Profile 1: SIEM & Platform Baseline** | **VM 1 Only** (SOC Server) | • Windows 11: **10.0 GB**<br>• VM 1: **6.0 GB** | **10.0 GB Free** | Rule development, backend coding, dashboard testing. VM 2 and Kali remain powered off. |
| **Profile 2: Live Detection & ART Emulation** | **VM 1 + VM 2** (SOC + Victim) | • Windows 11: **8.0 GB**<br>• VM 1: **6.0 GB**<br>• VM 2: **2.0 GB** | **8.0 GB Free** | Atomic Red Team runs locally on VM 2. SIEM detects and SOAR initiates containment. Total committed RAM: 8.0 GB (VMs). Preserves 8.0 GB for Windows. |
| **Profile 3: External Multi-Node Emulation** | **VM 2 + VM 3 (Sequential)** | • Windows 11: **8.0 GB**<br>• VM 2: **2.0 GB**<br>• VM 3: **2.0 GB** | **12.0 GB Free** | If Kali is used to generate network traffic, VM 1 is paused or offline to capture raw PCAP, or run sequentially. |

---

## 5. Storage Sizing, Retention & Validation Thresholds

All disk, EPS, and log volume estimates are **pre-operational estimates subject to empirical validation** in Phase 02/03.

### 5.1 Storage Allocations & Ceilings
- **Host Free Disk Boundary**: Maintain a minimum of **20 GB unallocated host SSD space** at all times.
- **Dynamic Virtual Disks (VDI)**:
  - VM 1 (SOC Server): Max ceiling 45 GB dynamic (initial disk image: ~12 GB).
  - VM 2 (Victim Endpoint): Max ceiling 15 GB dynamic (initial disk image: ~5 GB).
  - VM 3 (Kali Linux): Existing VM image (~18 GB).
- **Initial Total Disk Consumed**: ~35 GB (leaving >50 GB free on the host).

### 5.2 Estimated Telemetry Volume & Retention Policy
- **Estimated EPS**: Baseline idle ~1–3 EPS; active Atomic Red Team test ~15–30 EPS.
- **Estimated Ingest Volume**: ~150–250 MB raw JSON logs per lab day.
- **OpenSearch Index Retention**: 14-day rolling retention ceiling (estimated $\le 3.5\text{ GB}$).
- **Logrotate Policy**: Wazuh Manager `/var/ossec/logs/alerts/` and PostgreSQL WAL rotated daily with a 3-day max retention.

### 5.3 Storage Space Thresholds & Verification Procedure
- **Warning Threshold**: If free host SSD space drops below **15 GB**, development must pause and unneeded build artifacts/logs must be cleared.
- **Critical Threshold**: If free host SSD space drops below **10 GB**, OpenSearch indices older than 3 days are purged immediately.
- **Validation Procedure**: In Phase 02, verify actual dynamic disk size using:
  ```powershell
  Get-Item "$HOME\VirtualBox VMs\*\*.vdi" | Select-Object Name, @{Name="SizeGB";Expression={[math]::round($_.Length/1GB, 2)}}
  ```

---

## 6. Functional Requirements (FR)

### 6.1 Telemetry Collection & SIEM Ingestion (FR-TEL)
- **FR-TEL-01**: Centralized ingestion of OS security telemetry (Auditd syscalls, execve, authentication logs, FIM) from VM 2 via Wazuh Agent.
- **FR-TEL-02**: Transport security: Wazuh Agent communicates with Wazuh Manager on TCP 1514 using Wazuh’s native encrypted protocol (128-bit symmetric key from `/var/ossec/etc/client.keys`) and TLS on TCP 1515 for agent enrollment.
- **FR-TEL-03**: Heartbeat monitoring: Agent reports status every 60 seconds; manager raises rule 501/502 on agent disconnection.

### 6.2 Detection Engineering & Threat Mapping (FR-DET)
- **FR-DET-01**: Custom Wazuh XML detection rules stored in `/var/ossec/etc/rules/local_rules.xml`.
- **FR-DET-02**: Mandatory tagging of all custom rules with MITRE ATT&CK Tactics (`<mitre><tactic>`) and Techniques (`<mitre><id>`).
- **FR-DET-03**: Rule severity mapping (Low: 1–4, Medium: 5–8, High: 9–11, Critical: 12–15).
- **FR-DET-04**: Detection test harness using Atomic Red Team locally on VM 2 to validate rule firing and telemetry extraction.

### 6.3 At-Least-Once Alert Ingestion & Idempotency (FR-ING)
- **FR-ING-01**: Alert ingestion pipeline: Wazuh Manager writes alerts to `/var/ossec/logs/alerts/alerts.json`. SentinelOps Ingestion Engine uses a local durable tailer forwarding to FastAPI (`POST /api/v1/alerts/ingest`) with pre-shared HMAC token authentication.
- **FR-ING-02**: Durable checkpointing: Tracks file inode, byte offset, and CRC32 checksum in `.tailer_checkpoint` flushed fsync on every batch.
- **FR-ING-03**: Bounded disk spillover: In-memory queue with local SQLite/flat-file fallback queue (capped at 50 MB / ~50,000 alerts) during backend downtime.
- **FR-ING-04**: Deduplication via PostgreSQL: Atomic upsert on `dedup_hash` within a 5-minute sliding window; duplicate alerts increment `occurrence_count` and update `last_seen_at`.

### 6.4 Alert Enrichment (FR-ENR)
- **FR-ENR-01**: Asset inventory lookup (IP, hostname, OS, criticality, lab zone).
- **FR-ENR-02**: Threat intelligence enrichment: Local mock reputation fixtures (pre-seeded malicious hashes/IPs) with optional external API connector (VirusTotal/AbuseIPDB) if keys are provided in `.env`.
- **FR-ENR-03**: MITRE ATT&CK knowledge base mapping (technique name, tactic, description, mitigations).

### 6.5 Incident Lifecycle Management (FR-INC)
- **FR-INC-01**: Automatic incident promotion for High/Critical alerts (severity $\ge 10$) or correlated attack sequences.
- **FR-INC-02**: Strict state machine: `NEW` $\rightarrow$ `TRIAGED` $\rightarrow$ `CONTAINING` $\rightarrow$ `REMEDIATED` $\rightarrow$ `CLOSED`.
- **FR-INC-03**: Analyst assignment, investigation notes, and chronological timeline tracking.

### 6.6 SOAR & Controlled Response (FR-SOA)
- **FR-SOA-01**: Allowlisted Playbook Registry: Predefined playbooks with strict Pydantic parameter schemas.
- **FR-SOA-02**: Zero Arbitrary Command Execution: Incoming alert fields are never passed to shell interpreters (`sh -c`, `eval`).
- **FR-SOA-03**: Supported Wazuh 4.8 Active Response: Remediation commands dispatch via Wazuh Manager `AR` protocol to agent-side registered executables (`/var/ossec/active-response/bin/`) accepting JSON via stdin.
- **FR-SOA-04**: Mandatory Human-in-the-Loop (HITL) Gate: Disruptive actions (`isolate_host`, `kill_process`, `quarantine_file`) require affirmative two-step analyst approval in the UI before execution.
- **FR-SOA-05**: Tested Containment Rollback: Automated reversal playbooks (`unisolate_host`, `restore_quarantine`) with a dedicated out-of-band management IP path that is never blocked.
- **FR-SOA-06**: Last-Resort Emergency Shutdown: Explicitly labeled, potentially destructive emergency power-off script (`scripts/emergency_poweroff.ps1`) for runaway host compromise.

### 6.7 Auditability & Compliance (FR-AUD)
- **FR-AUD-01**: Append-only audit table in PostgreSQL (`audit_logs`) where application DB role has `INSERT` and `SELECT` only (no `UPDATE` or `DELETE`).
- **FR-AUD-02**: Application-level SHA-256 cryptographic chaining of audit log entries for tamper detection.
- **FR-AUD-03**: Automated incident report export (Markdown/HTML/JSON) documenting complete forensic timeline.

---

## 7. Non-Functional Requirements (NFR)

### 7.1 Security & Network Isolation (NFR-SEC)
- **NFR-SEC-01**: Hypervisor Network Segmentation: VirtualBox Internal Network (`SentinelOps-LabNet`) for Victim and Attacker VMs; Host-Only Network (`SentinelOps-MgmtNet`) for Windows 11 host access to SOC Server.
- **NFR-SEC-02**: Zero inbound public internet access to any VM. Outbound internet restricted to host NAT during initial package installation, then disabled or firewalled during lab runs.
- **NFR-SEC-03**: Principle of least privilege across all system components and database users.

### 7.2 Reliability & Fault Handling (NFR-REL)
- **NFR-REL-01**: Idempotent alert ingestion handling duplicate deliveries gracefully.
- **NFR-REL-02**: Ingestion buffer recovery: File tailer resumes from last committed offset on process restarts; handles partial JSON lines with a line-buffer accumulator.
- **NFR-REL-03**: Graceful degradation if external threat intel APIs are unreachable (fall back to offline mock database).
