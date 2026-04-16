# Screenshots Guide

This document lists exactly which screenshots to capture for portfolio evidence. Organize them in a `screenshots/` folder and reference them from your README or portfolio presentation.

---

## Recommended Screenshots

### 1. Infrastructure Deployment

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 1.1 | `terraform-plan-output.png` | Terminal — output of `terraform plan` showing resources to create |
| 1.2 | `terraform-apply-complete.png` | Terminal — output of `terraform apply` showing "Apply complete!" |
| 1.3 | `resource-group-overview.png` | Azure Portal → Resource Group → Overview showing all deployed resources |
| 1.4 | `vm-overview.png` | Azure Portal → VM → Overview showing size, OS, and auto-shutdown |

### 2. Microsoft Sentinel

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 2.1 | `sentinel-overview.png` | Sentinel → Overview dashboard showing event counts and data sources |
| 2.2 | `data-connectors.png` | Sentinel → Data Connectors showing connected sources |
| 2.3 | `analytics-rules.png` | Sentinel → Analytics showing all 3 custom rules enabled |
| 2.4 | `incident-list.png` | Sentinel → Incidents showing detected incidents |
| 2.5 | `incident-detail.png` | Click an incident → show details, tags, and entities |
| 2.6 | `incident-investigation.png` | Incident → Investigation → entity graph visualization |

### 3. KQL & Workbooks

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 3.1 | `kql-failed-signins.png` | Sentinel → Logs → run failed_signin_burst.kql showing results |
| 3.2 | `kql-role-assignment.png` | Sentinel → Logs → run role_assignment_created.kql showing results |
| 3.3 | `kql-nsg-deny.png` | Sentinel → Logs → run nsg_deny_spike.kql showing results |
| 3.4 | `workbook-overview.png` | Sentinel → Workbooks → custom workbook with all panels |

### 4. Automation & Response

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 4.1 | `logic-app-designer.png` | Logic App → Designer view showing the workflow |
| 4.2 | `logic-app-run-history.png` | Logic App → Run history showing successful execution |
| 4.3 | `email-notification.png` | Your inbox showing the formatted incident email |
| 4.4 | `automation-rule.png` | Sentinel → Automation → rule linking incidents to playbook |

### 5. Governance & Compliance

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 5.1 | `policy-compliance.png` | Azure Policy → Compliance dashboard for the resource group |
| 5.2 | `policy-deny-action.png` | Failed deployment showing policy denial message |
| 5.3 | `defender-secure-score.png` | Defender → Secure Score overview |
| 5.4 | `defender-recommendations.png` | Defender → Recommendations list |

### 6. Cost Management

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 6.1 | `cost-analysis.png` | Cost Management → Cost analysis for the resource group |
| 6.2 | `budget-alert-config.png` | Cost Management → Budgets showing threshold configuration |
| 6.3 | `vm-auto-shutdown.png` | VM → Auto-shutdown configuration page |

### 7. Security Hardening

| # | Screenshot | Where to Capture |
|---|-----------|-----------------|
| 7.1 | `nsg-rules.png` | NSG → Inbound security rules showing deny-all + SSH allowlist |
| 7.2 | `keyvault-rbac.png` | Key Vault → Access control (IAM) showing RBAC assignments |
| 7.3 | `storage-no-public.png` | Storage Account → Configuration showing public access disabled |
| 7.4 | `keyvault-secrets.png` | Key Vault → Secrets showing stored VM password (name only, not value) |

---

## Screenshot Tips

1. **Use a clean browser profile** — Remove bookmarks bars and personal tabs before capturing
2. **Dark mode** — Azure Portal supports dark mode (Settings → Appearance); dark screenshots look more professional in portfolio presentations
3. **Highlight key areas** — Use a tool like Snip & Sketch (Win+Shift+S) and add red rectangles around important elements
4. **Consistent resolution** — Capture all screenshots at the same browser zoom level (100%)
5. **Redact sensitive data** — Blur or black out subscription IDs, email addresses, and IP addresses in public-facing screenshots
6. **Include timestamps** — Make sure the portal's time display is visible to prove the lab was live

---

## Organizing for Portfolio

```
screenshots/
├── 01-infrastructure/
│   ├── terraform-plan-output.png
│   ├── terraform-apply-complete.png
│   └── resource-group-overview.png
├── 02-sentinel/
│   ├── sentinel-overview.png
│   ├── analytics-rules.png
│   └── incident-detail.png
├── 03-kql/
│   ├── kql-failed-signins.png
│   └── workbook-overview.png
├── 04-automation/
│   ├── logic-app-designer.png
│   └── email-notification.png
├── 05-governance/
│   ├── policy-compliance.png
│   └── defender-secure-score.png
└── 06-cost/
    ├── cost-analysis.png
    └── budget-alert-config.png
```
