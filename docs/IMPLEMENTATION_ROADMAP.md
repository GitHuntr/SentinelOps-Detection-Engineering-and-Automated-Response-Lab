# SentinelOps — Master Implementation Roadmap (12 Phases)

## 1. Roadmap Overview & Phasing Structure

The project follows a 12-phase development plan. Each phase must satisfy all **Acceptance Criteria** and pass a formal verification gate before advancing to the next phase.

```mermaid
gantt
    title SentinelOps 12-Phase Master Implementation Roadmap
    dateFormat  YYYY-MM-DD
    section Architecture
    Phase 00: Architecture & Planning                 :done, p00, 2026-11-07, 1d
    section Infrastructure
    Phase 01: Dev Environment & Repository            :active, p01, 2026-11-08, 2d
    Phase 02: SOC Lab Infrastructure                  :p02, 2026-11-10, 3d
    section Detection Engineering
    Phase 03: Telemetry Collection & Processing       :p03, 2026-11-13, 3d
    Phase 04: Detection Engineering                   :p04, 2026-11-16, 3d
    section Platform Core
    Phase 05: Backend Development & SIEM Integration  :p05, 2026-11-19, 4d
    Phase 06: Alert Enrichment & Threat Intelligence  :p06, 2026-11-23, 3d
    section Analyst Operations
    Phase 07: Frontend & SOC Dashboard                :p07, 2026-11-26, 4d
    Phase 08: SOAR & Automated Response               :p08, 2026-11-30, 4d
    Phase 09: Incident Investigation & Reporting      :p09, 2026-12-04, 3d
    section Hardening & Demo
    Phase 10: Testing, Validation & Security Hardening:p10, 2026-12-07, 3d
    Phase 11: Documentation & Final Demonstration     :p11, 2026-12-10, 2d
```

---

## 2. Phase-by-Phase Deliverables & Acceptance Criteria

### Phase 00 — Architecture & Planning (Current Phase)
- **Objective**: Design complete system, hardware sizing, network topology, threat model, and API specs for Windows 11 / VirtualBox constraints.
- **Deliverables**: PRD, System Architecture, Infrastructure Architecture, Data Flow, Database Design, API Design, Security Architecture, Agent Workflow, Tech Stack, Roadmap, Changelog.
- **Acceptance Criteria**: All 10 documents fully aligned with Windows 11, VirtualBox, 16 GB RAM, and <100 GB SSD constraints; user sign-off.

---

### Phase 01 — Development Environment & Repository
- **Objective**: Establish developer toolchains on Windows 11 host and initialize project structure.
- **Deliverables**:
  - Root directory structure (`backend/`, `frontend/`, `detection/`, `simulation/`, `scripts/`, `docs/`).
  - Python virtual environment and Poetry/pip-tools configuration.
  - Node.js / Vite / React baseline project scaffolding.
  - Pre-commit hooks for linting (ruff, black, eslint) and secret scanning.
  - Baseline `.env.example` and `.gitignore`.
- **Acceptance Criteria**: Clean git commits, linting passes, no secrets checked into git.

---

### Phase 02 — SOC Lab Infrastructure
- **Objective**: Provision virtual machines in Oracle VirtualBox with isolated networking.
- **Deliverables**:
  - VirtualBox Host-Only Network (`SentinelOps-MgmtNet`: `192.168.56.0/24`) and Internal Network (`SentinelOps-LabNet`: `172.28.0.0/24`).
  - VM 1: Ubuntu Server 24.04 LTS (Static IPs: `192.168.56.10`, `172.28.0.10`).
  - VM 2: Ubuntu 24.04 LTS Victim (Static IP: `172.28.0.20`).
  - UFW firewall rules on VM 1 and VM 2.
  - Emergency isolation script (`scripts/emergency_isolate.ps1`).
- **Acceptance Criteria**: VM 1 communicates with VM 2 over internal lab net; Windows 11 host reaches VM 1 over host-only net; zero internet access from victim during lab runs.

---

### Phase 03 — Telemetry Collection & Processing
- **Objective**: Deploy Wazuh single-node cluster on VM 1 and enroll VM 2 agent.
- **Deliverables**:
  - Wazuh Indexer (OpenSearch with heap `-Xms1800m -Xmx1800m`), Wazuh Manager, and Wazuh Dashboard running on VM 1.
  - Wazuh Agent installed and registered on VM 2 over TCP 1514/1515.
  - Linux `auditd` rules configured on VM 2 capturing execve, syscalls, and user auth.
  - Wazuh File Integrity Monitoring (FIM) configured for `/etc`, `/bin`, `/usr/bin`.
- **Acceptance Criteria**: Wazuh Dashboard displays VM 2 in `Active` status; process creation events appear in Wazuh events index.

---

### Phase 04 — Detection Engineering
- **Objective**: Author custom Wazuh detection XML rules mapped to MITRE ATT&CK and validate via Atomic Red Team.
- **Deliverables**:
  - Custom rules in `/var/ossec/etc/rules/local_rules.xml` covering 5 core ATT&CK techniques:
    1. `T1059.004` (Unix Shell Execution & Obfuscation)
    2. `T1053.003` (Cron Persistence)
    3. `T1078` (Privilege Escalation / Suspicious Sudo)
    4. `T1070.004` (File Deletion & Log Wiping)
    5. `T1046` (Network Service Scanning)
  - Atomic Red Team harness configured on VM 2.
- **Acceptance Criteria**: Executing Atomic Red Team tests triggers corresponding custom Wazuh alerts with exact MITRE tags within $<3$ seconds.

---

### Phase 05 — Backend Development & SIEM Integration
- **Objective**: Build FastAPI modular monolith, PostgreSQL schema, and alert ingestion tailer.
- **Deliverables**:
  - PostgreSQL 16 database schemas with Alembic migrations.
  - Local log tailer service forwarding `/var/ossec/logs/alerts/alerts.json` to FastAPI via HTTP POST + HMAC.
  - Ingestion deduplication engine in PostgreSQL (5-minute sliding window).
  - Incident promotion logic for High/Critical alerts.
- **Acceptance Criteria**: Tailer recovers from byte offset on restart; duplicate alerts increment `occurrence_count` without creating duplicate incidents; unit tests pass with $\ge 80\%$ coverage.

---

### Phase 06 — Alert Enrichment & Threat Intelligence
- **Objective**: Build internal asset lookup and threat intelligence enrichment pipelines.
- **Deliverables**:
  - Asset inventory service mapping agent IPs to criticality and lab zones.
  - Threat intelligence module with local mock reputation fixtures (pre-seeded malicious hashes/IPs) and optional live API connector.
  - MITRE ATT&CK technique description cache.
- **Acceptance Criteria**: Ingested alerts automatically receive threat scores and MITRE descriptions in `enrichment_data` JSONB column.

---

### Phase 07 — Frontend & SOC Dashboard
- **Objective**: Build React + TypeScript single-page application for analyst operations.
- **Deliverables**:
  - Centralized SOC Dashboard with incoming alert feed, MTTD/MTTR metrics, and active incidents.
  - Interactive MITRE ATT&CK coverage heatmap.
  - WebSocket client for real-time alert updates without page refresh.
- **Acceptance Criteria**: UI loads from Windows 11 browser (`http://192.168.56.10:3000`); real-time notifications fire on new incidents.

---

### Phase 08 — SOAR & Automated Response
- **Objective**: Implement allowlisted playbooks with strict Pydantic schemas and HITL approval gates.
- **Deliverables**:
  - Playbook registry (`pb-isolate-host`, `pb-kill-proc`, `pb-collect-procs`).
  - Human-in-the-Loop (HITL) approval API with two-step affirmative confirmation.
  - Wazuh Active Response integration scripts (`custom-ar` on VM 2) using structured JSON inputs.
  - Append-only audit logger in PostgreSQL with SHA-256 cryptographic chaining.
  - Emergency Kill Switch (`/api/v1/soar/emergency-abort`).
- **Acceptance Criteria**: Disruptive actions refuse execution without valid human approval; command injection payloads rejected with HTTP 422; audit logs verifiably immutable.

---

### Phase 09 — Incident Investigation & Reporting
- **Objective**: Develop investigation workbench and forensic case export tools.
- **Deliverables**:
  - Interactive Incident Workbench: Linked alert visualizer, chronological event timeline, and analyst notes.
  - Automated report generator exporting Markdown/HTML/PDF incident post-mortems with cryptographic audit signatures.
- **Acceptance Criteria**: Analyst can document investigation and download a comprehensive incident report with one click.

---

### Phase 10 — Testing, Validation & Security Hardening
- **Objective**: Full end-to-end simulation, negative testing, and security hardening.
- **Deliverables**:
  - End-to-end integration test: Atomic simulation $\rightarrow$ Wazuh detection $\rightarrow$ Backend ingestion $\rightarrow$ UI alert $\rightarrow$ HITL approval $\rightarrow$ Active response host isolation $\rightarrow$ Verification.
  - API fuzzing and security test suite verifying zero-shell execution.
  - UFW and Linux system hardening verification on VM 1 and VM 2.
- **Acceptance Criteria**: 100% test pass rate across all suites; system operates reliably without exceeding 12 GB RAM or 50 GB disk.

---

### Phase 11 — Documentation & Final Demonstration
- **Objective**: Complete operator documentation, lab setup guides, and project demonstration.
- **Deliverables**:
  - Comprehensive `README.md` and Operator Lab Manual.
  - Video or step-by-step walkthrough demonstrating attack detection, triage, and automated response.
  - Project presentation deck and final architecture record.
- **Acceptance Criteria**: Clean, reproducible deployment from scratch on any Windows 11 machine with VirtualBox; all 12 phases formally closed.
