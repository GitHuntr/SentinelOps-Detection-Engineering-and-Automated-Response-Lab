# SentinelOps — Detection Engineering and Automated Response Lab

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2024.04%20%7C%20Windows%2011-blue.svg)](https://github.com/GitHuntr/SentinelOps-Detection-Engineering-and-Automated-Response-Lab)
[![SIEM](https://img.shields.io/badge/SIEM-Wazuh%204.14.10-orange.svg)](https://wazuh.com)
[![Threat Framework](https://img.shields.io/badge/Framework-MITRE%20ATT%26CK%20v15-red.svg)](https://attack.mitre.org)
[![Backend](https://img.shields.io/badge/Backend-FastAPI%20%2B%20Python%203.12-green.svg)](https://fastapi.tiangolo.com)
[![Frontend](https://img.shields.io/badge/Frontend-React%2018%20%2B%20TypeScript-blue.svg)](https://react.dev)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2016-darkblue.svg)](https://www.postgresql.org)

SentinelOps is a modular, end-to-end Security Operations Center (SOC) simulation platform and automated incident response lab. It demonstrates the full defensive security lifecycle: endpoint telemetry generation, SIEM detection engineering, MITRE ATT&CK mapping, alert enrichment, incident management, and allowlisted SOAR playbooks with mandatory Human-in-the-Loop (HITL) approval gates.

---

## Architecture Overview

SentinelOps operates in an isolated virtualization topology engineered to run safely within a 16 GB RAM host environment:

- **Host (Windows 11)**: Developer toolchains (Git, VSCode, Browser, VirtualBox Manager).
- **VM 1: SOC Server (Ubuntu Server 24.04 LTS)**:
  - **SIEM Engine**: Wazuh 4.14.10 Manager, Indexer (OpenSearch), and Dashboard.
  - **Custom Core**: SentinelOps FastAPI Backend (Modular Monolith) & PostgreSQL 16.
  - **Web Dashboard**: React 18 + TypeScript + Vite.
- **VM 2: Victim Endpoint (Ubuntu 24.04 LTS)**:
  - **Telemetry**: Linux Auditd, File Integrity Monitoring (FIM), Wazuh 4.14.10 Agent.
  - **Attack Simulation**: Atomic Red Team harness for deterministic MITRE technique validation.
- **VM 3: Attacker (Kali Linux - Optional)**:
  - Invoked sequentially for multi-stage external network exploit scenarios.

```
Windows 11 Host (192.168.56.1)
      │
      │  [Host-Only: SentinelOps-MgmtNet (192.168.56.0/24)]
      ▼  (Permitted: HTTP 3000, HTTP 8000, SSH 22, HTTPS 443)
VM 1: SOC Server (192.168.56.10 / 172.28.0.10)
      ▲
      │  [Internal Net: SentinelOps-LabNet (172.28.0.0/24)]
      ├──► VM 2: Victim Endpoint (172.28.0.20)  [Wazuh Telemetry: TCP 1514, Auth: TCP 1515]
      └──► VM 3: Attacker Kali   (172.28.0.30)  [EXPLICITLY DROPPED by VM 1 UFW Firewall]
```

---

## Key Features & Security Guardrails

1. **Zero Arbitrary Command Execution**: Incoming alert fields are never passed to shell interpreters (`sh -c`, `eval`). All SOAR actions use allowlisted Pydantic schemas.
2. **Native Wazuh Active Response**: Remediation scripts on victim endpoints receive structured JSON via standard input (`stdin`) from `wazuh-execd`.
3. **Mandatory Human-in-the-Loop (HITL) Approval**: Disruptive containment playbooks (host isolation, process termination) cannot execute without affirmative analyst sign-off and password validation in the SOC dashboard.
4. **Preserved Out-of-Band Management**: Network containment firewall rules preserve management channels (`192.168.56.0/24`) to allow non-destructive rollback without requiring host reboots.
5. **Reliable Alert Ingestion**: At-least-once alert forwarding from Wazuh `alerts.json` with durable checkpointing, line-buffering, and 50 MB bounded disk spooling with back-pressure.
6. **Append-Only Audit Trail**: PostgreSQL table-level privilege revocation (`REVOKE UPDATE, DELETE`) combined with SHA-256 cryptographic chaining.

---

## Master Implementation Roadmap (12 Phases)

- **Phase 00: Architecture & Planning** *(Completed)*
- **Phase 01: Development Environment & Repository** *(In Progress)*
- **Phase 02: SOC Lab Infrastructure**
- **Phase 03: Telemetry Collection & Processing**
- **Phase 04: Detection Engineering**
- **Phase 05: Backend Development & SIEM Integration**
- **Phase 06: Alert Enrichment & Threat Intelligence**
- **Phase 07: Frontend & SOC Dashboard**
- **Phase 08: SOAR & Automated Response**
- **Phase 09: Incident Investigation & Reporting**
- **Phase 10: Testing, Validation & Security Hardening**
- **Phase 11: Documentation & Final Demonstration**

---

## Documentation

Full architectural specifications are located in the [`docs/`](./docs) directory:
- [Project Requirements Document (PRD)](./docs/PROJECT_REQUIREMENTS.md)
- [System Architecture](./docs/SYSTEM_ARCHITECTURE.md)
- [Infrastructure & Network Architecture](./docs/INFRASTRUCTURE_ARCHITECTURE.md)
- [Data Flow & Ingestion Design](./docs/DATA_FLOW.md)
- [Database Schema Design](./docs/DATABASE_DESIGN.md)
- [REST & WebSocket API Design](./docs/API_DESIGN.md)
- [Security & Safety Architecture](./docs/SECURITY_ARCHITECTURE.md)
- [Technology Stack Justifications](./docs/TECH_STACK.md)
- [Multi-Agent Governance Workflow](./docs/AGENT_WORKFLOW.md)
- [Master Implementation Roadmap](./docs/IMPLEMENTATION_ROADMAP.md)

---

## License

This project is licensed under the Apache License 2.0. See [LICENSE](./LICENSE) for details.

