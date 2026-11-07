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

### [2026-11-07 18:38] Phase 00: Final Architecture Fix & Closeout Baseline
- **Scope**: Complete Architectural Baseline & Verification
- **Type**: `[REFACTOR]` / `[SECURITY]` / `[DOCS]`
- **Summary**: Executed single consolidated final correction pass on all Phase 00 architecture documents in `docs/` to produce a completely verified, consistent system baseline. Pinned **Wazuh 4.14.10** across all components without unsupported "LTS" designations; corrected cryptographic descriptions to official 128-bit symmetric key mechanisms; redesigned Active Response around native JSON stdin/stdout protocols; defined safe containment with out-of-band management preservation; designed a realistic staged operating plan for Windows 11 (explicitly labeling 6 GB SOC VM as a constrained experimental configuration); documented at-least-once ingestion with durable checkpoint ordering and bounded spooling (no silent drops); and labeled all storage/EPS values as planning estimates with strict monitoring thresholds.
- **Key Architectural Decisions & Fixes**:
  1. **Pinned Wazuh 4.14.10**: Differentiated telemetry (TCP 1514 symmetric encryption), enrollment (TCP 1515 TLS), mTLS to indexer (HTTPS 9200), and dashboard tokens (HTTPS 443 / 55000). Removed unsupported LTS claims.
  2. **Official Encryption Standards**: Documented actual 128-bit symmetric key derivation from `/var/ossec/etc/client.keys` over `wazuh-remoted` (AES/Blowfish). Clarified that TLS is restricted to `wazuh-authd` (1515).
  3. **Wazuh 4.14.10 Active Response Protocol**: Redesigned to use native `/var/ossec/active-response/bin/` binaries receiving JSON documents via `stdin` from `wazuh-execd`, with 10-second execution timeouts and verified rollback (`command: delete`).
  4. **Staged Resource Operating Plan**: Explicitly documented that running the full SOC stack in 6.0 GB RAM is a constrained experimental lab configuration. Engineered 3 staged profiles: Profile 1 (VM 1 at 6.0 GB, Windows has 10.0 GB free); Profile 2 (VM 1 at 6.0 GB + VM 2 at 2.0 GB, Windows has 8.0 GB free); Profile 3 (VM 2 + Kali run sequentially with VM 1 offline). VM 1, 2, and 3 never run concurrently on 16 GB host.
  5. **Safe Containment Rollback vs. Emergency Shutdown**: Explicitly preserved out-of-band management subnets (`192.168.56.0/24`) in containment firewall rules for automated rollback. Verified that management preservation cannot create an attacker bypass because victim/attacker VMs lack interfaces on `SentinelOps-MgmtNet`. Separated destructive emergency shutdown (`poweroff`) as a last-resort fail-safe.
  6. **At-Least-Once Ingestion Architecture**: Designed durable `.tailer_checkpoint` with inode/offset tracking, line-buffer accumulator for partial JSON lines, 50 MB bounded disk spooling with back-pressure (never silently dropping events), exponential back-pressure, and PostgreSQL idempotent upserts on `dedup_hash`. Checkpoints never advance beyond safely persisted data.
  7. **Storage Ceilings & Thresholds**: Labeled all EPS/retention values as pre-operational estimates subject to empirical validation. Established 20 GB host free space minimum, 15 GB warning threshold, and 10 GB critical purge threshold.
- **Key Files Modified**:
  - `docs/PROJECT_REQUIREMENTS.md`
  - `docs/SYSTEM_ARCHITECTURE.md`
  - `docs/INFRASTRUCTURE_ARCHITECTURE.md`
  - `docs/DATA_FLOW.md`
  - `docs/SECURITY_ARCHITECTURE.md`
  - `docs/TECH_STACK.md`
  - `docs/IMPLEMENTATION_ROADMAP.md`
  - `CHANGELOG.md`
- **Security & Architectural Notes**:
  - Phase 00 is complete and ready for human approval. No application code, dependency installs, Git commits, or VM operations were performed.
