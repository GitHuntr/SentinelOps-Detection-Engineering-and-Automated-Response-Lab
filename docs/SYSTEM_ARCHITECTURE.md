# SentinelOps — System Architecture Document

## 1. Architectural Philosophy & Physical Deployment Topology

SentinelOps adheres to a **Modular Monolith** pattern deployed across a multi-tier virtualized infrastructure on a Windows 11 development workstation.

### Physical vs. Virtual Topology
- **Host Machine**: Windows 11 (Development, Git, IDE, Browser Client).
- **Virtualization**: Oracle VirtualBox.
- **VM 1: SOC Server (Ubuntu Server 24.04 LTS)**: Centralized SIEM, custom SentinelOps backend, and relational datastore.
- **VM 2: Victim Endpoint (Ubuntu 24.04 LTS)**: Target asset with Wazuh Agent and Atomic Red Team harness.
- **VM 3: Attacker (Kali Linux - Optional)**: Secondary offensive testing node used sequentially.

```mermaid
flowchart TD
    subgraph Host_Windows11["Windows 11 Development Host (16 GB Physical RAM / <100 GB SSD)"]
        Browser["Analyst Web Browser\n(React UI Client: http://192.168.56.10:3000)"]
        DevTools["Git, VSCode, Terminal Client"]
    end

    subgraph Net_HostOnly["Host-Only Management Network (192.168.56.0/24)"]
        Browser <-->|HTTP/WS: Ports 3000, 8000| SOC_Server
        DevTools -.->|SSH: Port 22| SOC_Server
    end

    subgraph Net_Internal["Isolated Lab Internal Network (172.28.0.0/24 - VirtualBox 'intnet')"]
        Victim["VM 2: Victim Endpoint (Ubuntu 24.04)\nIP: 172.28.0.20\nWazuh 4.8 Agent + Auditd + ART"]
        Attacker["VM 3: Attacker (Kali Linux - Optional)\nIP: 172.28.0.30\nSequential Execution Only"]
        Victim <-->|Wazuh Protocol: TCP 1514\nAgent Enrollment: TCP 1515| SOC_Server
        Attacker -.->|Lab Simulation Exploits| Victim
    end

    subgraph SOC_Server["VM 1: SOC Server (Ubuntu Server 24.04 LTS - 192.168.56.10 / 172.28.0.10)"]
        subgraph SIEM_Stack["Wazuh 4.8 SIEM Components"]
            WazuhMgr["Wazuh Manager 4.8\n(Rule Engine, Analysisd, Remoted, AR)"]
            WazuhIdx["Wazuh Indexer 4.8\n(OpenSearch Engine - JVM Heap: 1.5G)"]
            WazuhDsh["Wazuh Dashboard 4.8\n(OpenSearch Dashboards: Port 443/5601)"]
            WazuhMgr -->|Filebeat mTLS 9200| WazuhIdx
            WazuhDsh -->|HTTPS 9200 / 55000| WazuhIdx
        end

        subgraph SentinelOps_Core["SentinelOps Custom Platform (Modular Monolith)"]
            Tailer["Wazuh Alert Forwarder / Tailer\n(Durable Checkpointing + Spool Buffer)"]
            FastAPI["FastAPI Backend Engine\n(Ingestion, Dedup, Enrichment, Incident State, SOAR)"]
            PostgreSQL[(PostgreSQL 16 DB\nAlerts, Incidents, Dedup, RBAC, Append-Only Audit)]
            ReactUI["React + TypeScript Frontend\n(Nginx static server / Vite preview)"]
            
            Tailer -->|Local HTTP POST + HMAC| FastAPI
            FastAPI <--> PostgreSQL
            FastAPI -.->|Wazuh API: Port 55000 / AR Trigger| WazuhMgr
            ReactUI <-->|REST + WebSockets| FastAPI
        end
    end
```

---

## 2. Pinned Wazuh Architecture & Protocol Details (Wazuh 4.8)

SentinelOps pins **Wazuh 4.8 LTS** across all SIEM components to guarantee predictable protocol behavior and prevent feature mismatch.

### 2.1 Communication Links & Security Standards

| Communication Link | Transport Protocol | Cryptography / Authentication Standard | Official Wazuh 4.8 Mechanism |
| :--- | :--- | :--- | :--- |
| **Agent $\rightarrow$ Manager (Telemetry)** | TCP/UDP 1514 | Symmetric Encryption (AES-128 / Blowfish). Key size: 128-bit key negotiated from the pre-shared agent key string stored in `/var/ossec/etc/client.keys`. | `wazuh-remoted` daemon handles encrypted payload framing. (Official doc: Wazuh Agent-Manager communication). |
| **Agent Enrollment** | TCP 1515 | TLS 1.2+ encrypted tunnel | `wazuh-authd` daemon verifies password/token and issues unique agent ID & 128-bit key. |
| **Active Response (AR)** | TCP 1514 (Internal channel) | Encrypted message within the persistent agent session | Manager sends an internal AR control message: `(msg_to_agent) [] AR_command JSON_payload`. |
| **Manager $\rightarrow$ Indexer** | HTTPS / Port 9200 | TLS 1.3 / Mutual TLS (mTLS) with internal x509 certs | OpenSearch REST API indexing via `Filebeat-oss` / native output. |
| **Dashboard $\rightarrow$ Indexer/Manager**| HTTPS / Port 443, 55000 | TLS 1.3 with Basic Auth & JWT tokens | Node.js Dashboard app queries OpenSearch (9200) and Wazuh Manager API (55000). |

---

## 3. Supported Wazuh 4.8 Active Response Architecture

Active Response in Wazuh 4.8 operates via predefined agent-side binaries communicating through JSON over standard input (stdin) and standard output (stdout):

```mermaid
sequenceDiagram
    autonumber
    actor Analyst as SOC Analyst (UI)
    participant Backend as SentinelOps Backend (FastAPI)
    participant WazuhMgr as Wazuh Manager (VM 1)
    participant WazuhAgent as Wazuh Agent (VM 2)
    participant Script as /var/ossec/active-response/bin/firewall-drop (VM 2)

    Note over Analyst, Backend: 1. Human Approval Gate
    Analyst->>Backend: POST /api/v1/soar/executions/{id}/approve (Password + Justification)
    Backend->>Backend: Verify HITL Token & Validate Parameters (Pydantic)

    Note over Backend, WazuhMgr: 2. Manager Trigger
    Backend->>WazuhMgr: PUT /active-response?agents_list=001 (Wazuh API Port 55000)
    Note over WazuhMgr: Payload: {"command": "firewall-drop0", "custom": false, "alert": {...}}

    Note over WazuhMgr, WazuhAgent: 3. Protocol Message
    WazuhMgr->>WazuhAgent: Transmit AR message over persistent TCP 1514 channel

    Note over WazuhAgent, Script: 4. Execution via Stdin JSON
    WazuhAgent->>Script: Fork process as root / ossec user, pipe JSON to stdin
    Note over Script: Stdin JSON format:<br/>{"version":1,"origin":{"name":"..."},"command":"add","parameters":{"keys":["172.28.0.20"]}}
    Script->>Script: Execute iptables rule (drop traffic except management subnet)
    Script-->>WazuhAgent: Write status JSON to stdout:<br/>{"version":1,"origin":{"name":"firewall-drop"},"command":"check"}
    
    Note over WazuhAgent, Backend: 5. Logging & Verification
    WazuhAgent->>WazuhAgent: Append outcome to /var/ossec/logs/active-responses.log
    WazuhAgent-->>WazuhMgr: Execution acknowledgment
    Backend->>WazuhMgr: GET /active-response (Verify execution state)
    Backend->>Backend: Append to Immutable Audit Log & Update Incident State
```

### 3.1 Wazuh 4.8 JSON Input Schema (Stdin)
When an Active Response command executes on the agent, Wazuh 4.8 pipes a structured JSON document to the script's standard input (`stdin`):
```json
{
  "version": 1,
  "origin": {
    "name": "node01",
    "module": "wazuh-execd"
  },
  "command": "add",
  "parameters": {
    "keys": ["172.28.0.20"],
    "alert": {
      "rule": { "id": "100201", "level": 12 },
      "agent": { "id": "001", "name": "ubuntu-victim" },
      "data": { "srcip": "172.28.0.20" }
    }
  }
}
```

### 3.2 Key Operational Constraints
- **Execution Privileges**: The executable is invoked by `wazuh-execd` (running as root on Linux).
- **Execution Timeout**: Default execution timeout is 10 seconds. If the script does not return a zero status code within 10 seconds, `wazuh-execd` terminates the child process and logs an error in `/var/ossec/logs/active-responses.log`.
- **Reversal / Rollback**: Supported commands (e.g., `firewall-drop`) implement a `delete` command mode (`"command": "delete"`). When rollback is triggered via the SentinelOps UI, the same script is executed with `"command": "delete"` to remove the iptables rule cleanly.

---

## 4. Controlled Containment Rollback vs. Last-Resort Emergency Shutdown

SentinelOps strictly bifurcates **safe operational rollback** from **destructive emergency shutdown**:

### 4.1 Safe Containment & Tested Rollback Procedure
1. **Preserved Out-of-Band Management Path**:
   - The containment firewall script (`firewall-drop`) is explicitly programmed to **never block** management subnet traffic:
     - Allow: `192.168.56.0/24` (Host management) and `172.28.0.10:1514` (Wazuh telemetry/AR channel).
     - Block: All other inbound/outbound packets to the victim node.
   - This ensures the Wazuh Agent connection remains active, allowing immediate automated rollback.
2. **Standard Rollback Workflow**:
   - The analyst clicks **"Rollback Containment"** on the Incident workbench.
   - SentinelOps backend calls Wazuh API to issue the `"command": "delete"` action to the agent.
   - The agent script flushes the containment rule and restores network routing without rebooting or corrupting disk state.

### 4.2 Last-Resort Emergency Shutdown (Potentially Destructive)
If an adversary escapes lab containment or executes an uncontrollable denial-of-service:
- **Procedure**: An out-of-band host script (`scripts/emergency_poweroff.ps1`) executes:
  ```powershell
  VBoxManage controlvm "SentinelOps-Victim" poweroff
  ```
- **Risk Label**: Clearly labeled as **Potentially Destructive (Simulates pulling physical power plug)**. May cause filesystem corruption or loss of uncommitted in-memory forensic evidence. Reserved strictly for catastrophic lab safety boundaries.
