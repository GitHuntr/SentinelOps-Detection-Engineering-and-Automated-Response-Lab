# SentinelOps — System Changelog & Implementation Record

This document records all significant architectural decisions, schema changes, feature implementations, security controls, and modifications made across the **SentinelOps** platform.

---

## Format & Maintenance Standard
Every entry follows the format:
- **Date / Timestamp** (ISO or YYYY-MM-DD HH:MM)
- **Scope / Module**: (e.g., `Architecture`, `Backend`, `SIEM/Wazuh`, `Frontend`, `Database`, `Simulation`)
- **Type**: `[FEATURE]`, `[SECURITY]`, `[REFACTOR]`, `[SCHEMA]`, `[BUGFIX]`, `[DOCS]`
- **Summary**: Concise description of what was changed and why.
- **Key Files Modified / Created**: Explicit file list with paths.
- **Security & Architectural Notes**: Any impact on isolation, allowlisting, human-in-the-loop approvals, or threat framework mappings.

---

## Change Log

### [2026-11-07 18:32] Phase 00: Architecture Correction (Wazuh 4.8 LTS Pinning, Reliable Ingestion, Staged Resource Sizing)
- **Scope**: Complete Architecture Specifications & Sizing Calibration
- **Type**: `[REFACTOR]` / `[SECURITY]` / `[DOCS]`
- **Summary**: Corrected all architecture documents in `docs/` under execution freeze to satisfy all compliance review items. Pinned Wazuh explicitly to **4.8 LTS**, corrected cryptographic framing to official Wazuh 128-bit symmetric key documentation, redesigned Active Response around native JSON stdin/stdout protocols, established a realistic staged resource plan (preserving 8.0–10.0 GB for Windows 11), documented at-least-once ingestion with durable checkpointing, and separated safe containment rollback from destructive emergency power-off.
- **Key Technical Revisions**:
  1. **Pinned Wazuh 4.8 LTS**: Differentiated telemetry (TCP 1514 symmetric encryption), enrollment (TCP 1515 TLS), mTLS to indexer (9200), and dashboard communications.
  2. **Official Encryption Standards**: Removed inaccurate "AES-128/Blowfish with pre-shared HMAC keys". Documented actual 128-bit symmetric key derivation from `client.keys` per official Wazuh documentation.
  3. **Wazuh 4.8 Active Response Protocol**: Redesigned to use native `/var/ossec/active-response/bin/` binaries receiving JSON documents via `stdin` from `wazuh-execd`, with 10-second execution timeouts and verified rollback (`command: delete`).
  4. **Staged Resource Operating Plan**: Replaced the unfeasible 7GB + 7GB + 2GB allocation with 3 staged profiles: Profile 1 (VM 1 at 6.0 GB, Windows has 10.0 GB free); Profile 2 (VM 1 at 6.0 GB + VM 2 at 2.0 GB, Windows has 8.0 GB free); Profile 3 (VM 2 + Kali sequentially). VM 1, VM 2, and VM 3 never run concurrently on 16 GB host.
  5. **Safe Containment Rollback vs. Emergency Shutdown**: Explicitly preserved out-of-band management subnets (`192.168.56.0/24`) in containment firewall rules for automated rollback. Separated destructive emergency shutdown (`poweroff`) as a last-resort fail-safe.
  6. **At-Least-Once Ingestion Architecture**: Designed durable `.tailer_checkpoint` with inode/offset tracking, line-buffer accumulator for partial JSON lines, 50 MB bounded disk spooling, exponential back-pressure, and PostgreSQL idempotent upsert.
  7. **Storage Ceilings & Thresholds**: Labeled all EPS/retention values as pre-operational estimates subject to empirical validation. Established 20 GB host free space minimum, 15 GB warning threshold, and 10 GB critical purge threshold.
- **Key Files Modified**:
  - `docs/PROJECT_REQUIREMENTS.md`
  - `docs/SYSTEM_ARCHITECTURE.md`
  - `docs/INFRASTRUCTURE_ARCHITECTURE.md`
  - `docs/DATA_FLOW.md`
  - `docs/SECURITY_ARCHITECTURE.md`
  - `docs/TECH_STACK.md`
  - `CHANGELOG.md`
- **Security & Architectural Notes**:
  - No application code, dependency installs, Git commits, or VM operations were performed. All work strictly confined to architectural documentation.
