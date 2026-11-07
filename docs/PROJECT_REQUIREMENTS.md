# SentinelOps — Project Requirements Document (PRD)

## 1. Document Control
- **Document Version**: 3.0.0 (Phase 00 Final Closeout & Architecture Baseline)
- **Status**: Ready for Human Review & Approval
- **Classification**: Internal / Lab Specification

---

## 2. Executive Overview & Problem Statement
Modern Security Operations Centers (SOCs) face escalating alert fatigue, complex adversary techniques, fragmented tooling, and high operational friction between detection engineering and automated incident response.

**SentinelOps** is an end-to-end SOC simulation platform and automated response lab engineered specifically for a realistic, resource-constrained virtualization environment:
- **Host**: Windows 11 development machine (16 GB physical RAM, <100 GB available SSD storage).
- **Hypervisor**: Oracle VirtualBox 7.x.
- **VM 1 (SOC Server)**: Ubuntu Server 24.04 LTS (Wazuh 4.14.10 Manager, Wazuh 4.14.10 Indexer, Wazuh 4.14.10 Dashboard, SentinelOps FastAPI Backend, PostgreSQL 16 DB).
- **VM 2 (Victim Endpoint)**: Ubuntu 24.04 LTS (Wazuh 4.14.10 Agent, Linux Auditd, FIM, Atomic Red Team).
- **VM 3 (Attacker)**: Existing Kali Linux VM (Optional, invoked sequentially on demand).

The project simulates the complete detection-to-response lifecycle:
1. Endpoint telemetry generation (Auditd, FIM, Syslog).
2. Telemetry ingestion, decoding, and custom detection in Wazuh 4.14.10 SIEM.
3. Explicit MITRE ATT&CK technique mapping.
4. Reliable alert ingestion into SentinelOps Backend via an at-least-once alert tailer with durable disk checkpointing, bounded disk buffering, back-pressure handling, and zero silent drops.
5. Ingestion deduplication and threat intelligence enrichment using PostgreSQL 16 (Redis deferred until measured requirements emerge).
6. Incident lifecycle management and analyst triage.
7. Safe, allowlisted SOAR playbooks utilizing native Wazuh 4.14.10 Active Response (manager AR rules, registered binaries in `/var/ossec/active-response/bin/`, JSON stdin/stdout protocol, verified `add`/`delete` rollback) with mandatory Human-in-the-Loop (HITL) gates for disruptive actions.
8. Controlled containment rollback and safe emergency recovery procedures, maintaining an isolated out-of-band management channel, with destructive power-off clearly isolated as a last resort.

---

## 3. Pinned Technology Stack & Versioning

To avoid architectural drift and prevent mixing incompatible subsystem mechanisms, SentinelOps explicitly pins:
- **SIEM Platform**: **Wazuh 4.14.10** (Wazuh Manager, Indexer, Dashboard, and Agent). *(Note: Wazuh uses standard semantic versioning; releases are supported under standard release lifecycles and are not labeled "LTS" without official upstream vendor designation)*.
- **Operating Systems**: Ubuntu Server 24.04 LTS (VM 1 & VM 2); Windows 11 (Host); Kali Linux (VM 3).
- **Backend**: Python 3.12 + FastAPI (Modular Monolith).
- **Database**: PostgreSQL 16.
- **Frontend**: React 18 + TypeScript + Vite.
- **Simulation**: Atomic Red Team.
- **Threat Framework**: MITRE ATT&CK v15+.
- **Cache / Broker**: **Deferred**. Initial deduplication uses PostgreSQL composite indexing. Redis will be evaluated only if measured event ingestion volume demands in-memory caching.

---

## 4. Hardware Constraints & Staged Operating Plan (Windows 11 / 16 GB Physical RAM)

The Windows 11 host requires a **guaranteed 8.0 GB to 10.0 GB RAM headroom** to support OS services, IDE/VSCode, browser tabs, Git, background antivirus, and the VirtualBox hypervisor process overhead.

> [!WARNING]
> Allocating 7 GB to a SOC VM + 7 GB to Windows + 2 GB to a Victim VM commits 100% of physical RAM, inevitably causing severe memory paging and host OS instability.
> Furthermore, running Wazuh Indexer (OpenSearch), Wazuh Manager, Wazuh Dashboard, FastAPI, and PostgreSQL 16 inside a **6.0 GB RAM VM is a constrained, experimental lab configuration**, not an enterprise-supported topology. It requires explicit JVM heap tuning and component scheduling.

To maintain physical system stability, SentinelOps establishes a **Strict Staged Deployment Strategy**:

```
Stage 1: SIEM & Platform Baseline (VM 1 Only)
┌─────────────────────────────────┬─────────────────────────────────┐
│ Windows 11 Host: 10.0 GB RAM    │ VM 1 (SOC Server): 6.0 GB RAM   │
│ (Development, Browser, IDE)     │ (Tuned Wazuh 4.14.10 + PG16)    │
└─────────────────────────────────┴─────────────────────────────────┘

Stage 2: Live Detection & ART Emulation (VM 1 + VM 2)
┌─────────────────────────────────┬───────────────────┬─────────────┐
│ Windows 11 Host: 8.0 GB RAM     │ VM 1: 6.0 GB RAM  │ VM 2: 2.0 GB│
│ (Browser, IDE, Git)             │ (Experimental)    │ (Victim)    │
└─────────────────────────────────┴───────────────────┴─────────────┘

Stage 3: External Multi-Node Emulation (Sequential Mode)
┌─────────────────────────────────┬───────────────────┬─────────────┐
│ Windows 11 Host: 12.0 GB RAM    │ VM 2: 2.0 GB RAM  │ VM 3: 2.0 GB│
│ (VM 1 is SHUT DOWN or PAUSED)   │ (Victim Target)   │ (Kali Linux)│
└─────────────────────────────────┴───────────────────┴─────────────┘
*Rule: VM 1 (SOC), VM 2 (Victim), and VM 3 (Kali) NEVER run simultaneously.*
```

### 4.1 Staged Operating Profiles

| Profile Name | Active Virtual Machines | RAM Allocation Breakdown | Host RAM Headroom | Operational Rules & Component State |
| :--- | :--- | :--- | :--- | :--- |
| **Profile 1: SIEM & Ingestion Baseline** | **VM 1 Only** (SOC Server) | • Windows 11: **10.0 GB**<br>• VM 1: **6.0 GB** | **10.0 GB Free** | Rule authoring, API development, UI testing. VM 2 and Kali remain powered off. |
| **Profile 2: Live Detection & ART Emulation** | **VM 1 + VM 2** (SOC + Victim) | • Windows 11: **8.0 GB**<br>• VM 1: **6.0 GB**<br>• VM 2: **2.0 GB** | **8.0 GB Free** | Atomic Red Team runs locally on VM 2. SIEM detects and SOAR initiates containment. Total committed VM RAM: 8.0 GB. Preserves 8.0 GB for Windows. Kali is powered off. |
| **Profile 3: External Attack Emulation** | **VM 2 + VM 3 (Sequential)** | • Windows 11: **12.0 GB**<br>• VM 2: **2.0 GB**<br>• VM 3: **2.0 GB** | **12.0 GB Free** | When Kali is required for multi-stage external network exploits, VM 1 is paused or shut down. Telemetry/PCAP is captured locally on VM 2, then replayed or analyzed sequentially. |

---

## 5. Storage Sizing, Retention & Validation Thresholds (<100 GB SSD Boundary)

All storage, EPS, and log retention figures are **pre-operational planning estimates subject to empirical validation** in Phase 02/03.

### 5.1 Storage Allocations & Ceilings
- **Host Free Disk Boundary**: Maintain a minimum of **20 GB unallocated host SSD space** at all times.
- **Dynamic Virtual Disks (VDI)**:
  - VM 1 (SOC Server): Max ceiling 45 GB dynamic (initial disk footprint: ~12–14 GB).
  - VM 2 (Victim Endpoint): Max ceiling 15 GB dynamic (initial disk footprint: ~5–6 GB).
  - VM 3 (Kali Linux): Existing VM image (~18 GB).
- **Initial Total Host SSD Consumed**: ~35–38 GB (leaving >50 GB free on the host).

### 5.2 Estimated Telemetry Volume & Retention Policy (To Be Validated)
- **Estimated EPS**: Baseline idle ~1–3 EPS; active Atomic Red Team test bursts ~15–30 EPS.
- **Estimated Ingest Volume**: ~150–250 MB raw JSON logs per active lab day.
- **OpenSearch Index Retention**: 14-day rolling retention ceiling (estimated $\le 3.5\text{ GB}$).
- **Logrotate Policy**: Wazuh Manager `/var/ossec/logs/alerts/` and PostgreSQL WAL rotated daily with a 3-day max retention.

### 5.3 Storage Space Thresholds & Verification Procedure
- **Warning Threshold**: If free host SSD space drops below **15 GB**, development pauses and non-essential logs are pruned.
- **Critical Threshold**: If free host SSD space drops below **10 GB**, OpenSearch indices older than 3 days are purged immediately.
- **Validation Step**: During Phase 02, measure actual disk growth via:
  ```powershell
  Get-ChildItem -Path "$HOME\VirtualBox VMs\*\*.vdi" | Select-Object Name, @{Name="SizeGB";Expression={[math]::round($_.Length/1GB, 2)}}
  ```

---

## 6. Functional Requirements (FR)

### 6.1 Telemetry Collection & SIEM Ingestion (FR-TEL)
- **FR-TEL-01**: Centralized ingestion of OS security telemetry (Auditd syscalls, execve, authentication logs, FIM) from VM 2 via Wazuh 4.14.10 Agent.
- **FR-TEL-02**: Agent Communication Protocol: Wazuh Agent communicates with Wazuh Manager on TCP/UDP 1514 using Wazuh’s proprietary message framing encrypted with a 128-bit or 192-bit symmetric key (Blowfish or AES block cipher) negotiated from the pre-shared agent key in `/var/ossec/etc/client.keys`.
- **FR-TEL-03**: Agent Enrollment: Performed via `wazuh-authd` on TCP port 1515, secured using standard TLS 1.2+ encryption and pre-shared enrollment passwords/tokens.
- **FR-TEL-04**: Heartbeat monitoring: Agent reports status every 60 seconds; manager raises rules 501/502 on agent disconnection.

### 6.2 Detection Engineering & Threat Mapping (FR-DET)
- **FR-DET-01**: Custom Wazuh XML detection rules stored in `/var/ossec/etc/rules/local_rules.xml`.
- **FR-DET-02**: Mandatory tagging of all custom rules with MITRE ATT&CK Tactics (`<mitre><tactic>`) and Techniques (`<mitre><id>`).
- **FR-DET-03**: Rule severity mapping (Low: 1–4, Medium: 5–8, High: 9–11, Critical: 12–15).
- **FR-DET-04**: Detection test harness using Atomic Red Team locally on VM 2 to validate rule firing and telemetry extraction.

### 6.3 At-Least-Once Alert Ingestion & Idempotency (FR-ING)
- **FR-ING-01**: Ingestion Pipeline: Wazuh Manager writes alerts to `/var/ossec/logs/alerts/alerts.json`. SentinelOps Ingestion Engine uses a durable tailer daemon forwarding to FastAPI (`POST /api/v1/alerts/ingest`) with pre-shared HMAC token authentication.
- **FR-ING-02**: Durable Checkpointing: Tracks file inode, byte offset, and CRC32 checksum in `.tailer_checkpoint` flushed via `fsync` only after successful backend persistence.
- **FR-ING-03**: Partial JSON Handling: Line-buffer accumulator buffers incomplete reads until a trailing newline (`\n`) is reached; malformed records are quarantined in `.tailer_corrupt.log` without stalling the stream.
- **FR-ING-04**: Bounded Disk Spooling: During backend downtime, events buffer to a local SQLite/flat-file queue capped at 50 MB (~50,000 alerts). If the spool limit is reached, ingestion pauses to exert back-pressure; events are **never silently discarded**.
- **FR-ING-05**: Deduplication via PostgreSQL: Atomic upsert on `dedup_hash` within a 5-minute sliding window; duplicate alerts increment `occurrence_count` and update `last_seen_at`.

### 6.4 Alert Enrichment (FR-ENR)
- **FR-ENR-01**: Asset inventory lookup (IP, hostname, OS, criticality, lab zone).
- **FR-ENR-02**: Threat intelligence enrichment: Local mock reputation fixtures (pre-seeded malicious hashes/IPs) with optional external API connector (VirusTotal/AbuseIPDB) if keys are provided in `.env`.
- **FR-ENR-03**: MITRE ATT&CK knowledge base mapping (technique name, tactic, description, mitigations).

### 6.5 Incident Lifecycle Management (FR-INC)
- **FR-INC-01**: Automatic incident promotion for High/Critical alerts (severity $\ge 10$) or correlated attack sequences.
- **FR-INC-02**: Strict state machine: `NEW` $\rightarrow$ `TRIAGED` $\rightarrow$ `CONTAINING` $\rightarrow$ `REMEDIATED` $\rightarrow$ `CLOSED`.
- **FR-INC-03**: Analyst assignment, investigation notes, and chronological timeline tracking.

### 6.6 SOAR & Controlled Active Response (FR-SOA)
- **FR-SOA-01**: Allowlisted Playbook Registry: Predefined playbooks with strict Pydantic parameter schemas.
- **FR-SOA-02**: Zero Arbitrary Command Execution: Incoming alert fields are never passed to shell interpreters (`sh -c`, `eval`).
- **FR-SOA-03**: Supported Wazuh 4.14.10 Active Response: Remediation commands dispatch via Wazuh Manager `AR` protocol to agent-side registered executables (`/var/ossec/active-response/bin/`) accepting JSON via stdin.
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
