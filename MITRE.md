# MITRE ATT&CK Coverage

This document maps every analytic detection in the lab to the [MITRE ATT&CK](https://attack.mitre.org/) framework and explains the rationale behind each detection threshold.

---

## Detection → ATT&CK Mapping

| Detection Name | KQL File | MITRE Tactic | MITRE Technique | Technique ID | Severity |
|---|---|---|---|---|---|
| Failed Sign-In Burst | [`failed_signin_burst.kql`](kql/failed_signin_burst.kql) | Credential Access (TA0006) | Brute Force | T1110 | Medium |
| Role Assignment Created | [`role_assignment_created.kql`](kql/role_assignment_created.kql) | Privilege Escalation (TA0004) / Persistence (TA0003) | Account Manipulation | T1098 | High |
| NSG Deny Spike | [`nsg_deny_spike.kql`](kql/nsg_deny_spike.kql) | Discovery (TA0007) / Reconnaissance (TA0043) | Network Service Discovery | T1046 | Low–Medium |

---

## Threshold Rationale

### 1. Failed Sign-In Burst — ≥ 5 failures per IP per user in 10 minutes

| Factor | Detail |
|---|---|
| **Why 10-minute bins?** | Brute-force tools typically cycle through password lists in minutes. A 10-minute window captures a coherent attack burst without merging separate user sessions. |
| **Why ≥ 5 failures?** | Legitimate users occasionally mistype passwords or hit MFA timeouts, producing 1–3 failures. A threshold of 5 filters out these benign events while still catching slow-and-low spray attacks. Microsoft's own research shows most automated attacks exceed 10 failures per minute, so 5 in 10 minutes is conservative. |
| **Tuning guidance** | Increase the threshold in environments with heavy SSO retry traffic or self-service password reset flows. Decrease it for privileged account monitoring (e.g., global admins). |

### 2. Role Assignment Created — Every successful event (no numeric threshold)

| Factor | Detail |
|---|---|
| **Why alert on every event?** | RBAC role assignments are low-volume, high-impact operations. Granting a principal `Owner` or `Contributor` on a subscription is an existential risk if unauthorized. In a lab environment there is no legitimate automation creating role assignments, so every event is worth reviewing. |
| **False-positive sources** | Azure PIM (Privileged Identity Management) role activations, CI/CD service principals used for deployment, and Lighthouse delegated access. In production, exclude known SPNs via a `where Caller !in ("spn-1", "spn-2")` clause. |
| **Tuning guidance** | Maintain an allowlist of known callers. Alert only on `Owner`, `Contributor`, and `User Access Administrator` roles at subscription or management-group scope to reduce noise. |

### 3. NSG Deny Spike — Current 5-min bin > 3× the 30-minute rolling average

| Factor | Detail |
|---|---|
| **Why a 3× multiplier?** | Port scans and network sweeps produce deny-event volumes orders-of-magnitude above baseline. A 3× multiplier on a 30-minute rolling average absorbs normal traffic fluctuations (e.g., cron jobs, periodic health checks) while still detecting the sharp spike characteristic of `nmap` scans or lateral-movement probing. |
| **Why a 10-event floor?** | Without a minimum absolute count, a single denied packet after 30 minutes of silence would register as an infinite spike. Requiring ≥ 10 denies prevents false positives from trivially small baselines. |
| **Tuning guidance** | In production, raise the multiplier to 5× and the floor to 50 to account for noisier load-balancer health probes. For honeypot subnets with zero legitimate traffic, drop both values aggressively. |

---

## References

- [MITRE ATT&CK Enterprise Matrix](https://attack.mitre.org/matrices/enterprise/)
- [T1110 — Brute Force](https://attack.mitre.org/techniques/T1110/)
- [T1098 — Account Manipulation](https://attack.mitre.org/techniques/T1098/)
- [T1046 — Network Service Discovery](https://attack.mitre.org/techniques/T1046/)
- [Microsoft Sentinel Analytics Rule Best Practices](https://learn.microsoft.com/en-us/azure/sentinel/best-practices-analytics-rules)
