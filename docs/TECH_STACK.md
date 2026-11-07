# SentinelOps — Technology Stack & Architectural Justifications

## 1. Stack Evaluation Matrix & Decision Record

Every technology selected for SentinelOps has been evaluated against architectural alternatives, resource footprints, operational overhead, and security isolation requirements on a Windows 11 host (16 GB physical RAM, <100 GB available SSD).

| Layer | Selected Technology | Evaluated Alternatives | Rationale & Justification |
| :--- | :--- | :--- | :--- |
| **Host OS** | **Windows 11** | Linux Bare Metal | User's fixed development workstation. Runs AI agents, Git, VSCode, VirtualBox hypervisor, and analyst browser. |
| **Guest OS** | **Ubuntu Server 24.04 LTS** | Debian 12, Rocky Linux 9, Alpine | Official LTS platform supported by Wazuh Manager and Agent. Native Auditd and Linux kernel 6.8+ security telemetry. |
| **Virtualization** | **Oracle VirtualBox 7.x** | VMware Workstation, Hyper-V | Fully supported on Windows 11, robust CLI automation (`VBoxManage`), native Internal Network (`intnet`) and Host-Only support. |
| **SIEM & Endpoint Engine**| **Wazuh 4.14.10** | Elastic Security (ELK), Zeek + Suricata, Wazuh 5.x | Pinned to exact release 4.14.10. Open-source, unified Auditd/FIM/Syslog collection, built-in Active Response protocol (JSON stdin), native MITRE ATT&CK mapping. Avoids unreleased/experimental 5.x breaking changes. *(Note: Wazuh uses standard semantic versioning; releases are supported under standard release lifecycles and are not labeled "LTS" without official upstream vendor designation)*. |
| **Backend Framework** | **Python 3.12 + FastAPI** | Go (Gin/Fiber), Node.js (NestJS), Django | Python is standard in detection engineering. FastAPI offers async I/O, automatic OpenAPI documentation, and strict Pydantic v2 validation essential for preventing injection in SOAR. |
| **Frontend Framework** | **React 18 + TypeScript + Tailwind** | Vue 3, Next.js, Angular | Strict compile-time typing for complex event schemas, lightweight client-side SPA routing, rich component ecosystem. |
| **Database** | **PostgreSQL 16** | SQLite, MongoDB, MySQL | Provides ACID transactional consistency for incident lifecycles, native JSONB GIN indexing for event telemetry, and database-level append-only role permissions for audit trails. |
| **Ingestion Deduplication**| **PostgreSQL 16 (Indexed Hash)** | Redis 7 | **Architectural Optimization**: Using PostgreSQL for 5-minute sliding window deduplication saves 150–250 MB of RAM, leaving critical headroom for Wazuh Indexer and OS page caches on our 6 GB VM 1 target. Redis is deferred unless measured EPS requires an in-memory cache. |
| **Attack Simulation** | **Atomic Red Team** | Caldera, Infection Monkey, Metasploit | Open-source, deterministic, library of atomic adversary emulation scripts mapped to ATT&CK IDs. Can execute locally on VM 2 without external C2 infrastructure. |
| **Threat Matrix Standard**| **MITRE ATT&CK (v15+)** | Cyber Kill Chain, D3FEND | Universal standard for tagging detection rules, mapping simulation coverage, and communicating threat context. |

---

## 2. Resource Footprint & Compatibility Validation

### 2.1 VM 1 (SOC Server) Constrained Memory Breakdown (6.0 GB RAM Target)
To ensure all required SOC components run reliably within the tuned 6.0 GB RAM boundary on VM 1, preserving 8.0–10.0 GB for Windows 11:

| Component | Resident Memory Allocation | Tuning / Configuration Applied |
| :--- | :--- | :--- |
| **Wazuh Indexer (OpenSearch)**| ~1.8 GB resident | JVM Heap tuned to `-Xms1500m -Xmx1500m` in `jvm.options`. |
| **Wazuh Manager 4.14.10** | ~1.4 GB resident | `analysisd` and `remoted` tuned for single-agent lab workload. |
| **Wazuh Dashboard 4.14.10** | ~600 MB resident | Node.js max heap tuned (`--max-old-space-size=400`). |
| **SentinelOps Backend** | ~350 MB resident | FastAPI + Uvicorn (single async worker process). |
| **PostgreSQL 16** | ~400 MB resident | `shared_buffers = 128MB`, `work_mem = 16MB`, `max_connections = 30`. |
| **Ubuntu 24.04 OS & Buffers** | ~1.4 GB resident | Kernel, systemd, and page cache buffers. |
| **Total Memory Required** | **~5.95 GB** | **Fits inside 6.0 GB allocation (Experimental Lab Mode)**. |

---

## 3. Pinned Wazuh 4.14.10 Architecture & Official References

1. **Wazuh Agent-to-Manager Cryptography**:
   - Official Documentation Reference: [Wazuh User Manual: Agent communication](https://documentation.wazuh.com/current/user-manual/agent/agent-communication.html)
   - Telemetry protocol: Handled by `wazuh-remoted` over TCP/UDP port 1514. Encrypted using symmetric cryptography (AES block cipher or Blowfish with 128-bit key) negotiated from the pre-shared agent key in `/var/ossec/etc/client.keys`.
2. **Wazuh Agent Enrollment**:
   - Official Documentation Reference: [Wazuh User Manual: Agent enrollment](https://documentation.wazuh.com/current/user-manual/agent/agent-enrollment/index.html)
   - Uses `wazuh-authd` on TCP port 1515 secured by standard TLS 1.2+ encryption.
3. **Wazuh Active Response Execution**:
   - Official Documentation Reference: [Wazuh User Manual: Custom active response](https://documentation.wazuh.com/current/user-manual/capabilities/active-response/custom-active-response.html)
   - Executable format: Agent executes registered scripts in `/var/ossec/active-response/bin/` as root/ossec user.
   - Data passing: The agent daemon (`wazuh-execd`) writes a single-line JSON string to the executable's standard input (`stdin`) and captures execution return code and stdout status JSON.
4. **Wazuh Manager-to-Indexer Communication**:
   - Official Documentation Reference: [Wazuh Deployment Guide: Wazuh indexer](https://documentation.wazuh.com/current/deployment-guide/wazuh-indexer/index.html)
   - Uses Filebeat over HTTPS port 9200 with mutual TLS (mTLS) client certificate verification.
