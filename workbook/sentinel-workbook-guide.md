# Microsoft Sentinel Workbook Guide

This guide walks you through creating a custom Sentinel workbook that visualizes the security telemetry collected in this lab.

---

## Overview

Azure Monitor Workbooks in Sentinel provide interactive dashboards built on KQL queries. The workbook we'll create includes:

- **Failed Sign-In Heatmap** — Geographic and temporal view of authentication failures
- **RBAC Change Timeline** — Chronological view of role assignment activity
- **NSG Deny Trends** — Traffic denial patterns per NSG over time
- **Overall Security Posture** — Summary tiles with alert counts and severity breakdown

---

## Step-by-Step: Create the Workbook

### Step 1: Navigate to Workbooks

1. Open **Azure Portal** → **Microsoft Sentinel** → select your workspace
2. Click **Workbooks** in the left menu under "Threat management"
3. Click **+ Add workbook**
4. Click **Edit** (pencil icon) to enter edit mode

### Step 2: Add Summary Tiles (KQL)

Click **Add → Add query** and paste:

```kql
// Security Overview Tiles
let FailedSignins = union isfuzzy=true SigninLogs, AADNonInteractiveUserSignInLogs
    | where TimeGenerated > ago(24h)
    | where ResultType != "0"
    | count;
let RoleChanges = AzureActivity
    | where TimeGenerated > ago(24h)
    | where OperationNameValue =~ "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
    | where ActivityStatusValue == "Success"
    | count;
let NSGDenies = AzureNetworkAnalytics_CL
    | where TimeGenerated > ago(24h)
    | where FlowStatus_s == "D"
    | count;
print
    FailedSignIns  = toscalar(FailedSignins),
    RoleAssignments = toscalar(RoleChanges),
    NSGDeniedFlows  = toscalar(NSGDenies)
```

- **Visualization**: Set to **Tiles**
- **Size**: Full width

### Step 3: Add Failed Sign-In Time Chart

Click **Add → Add query** and paste:

```kql
union isfuzzy=true SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(7d)
| where ResultType != "0"
| summarize Count = count() by bin(TimeGenerated, 1h), ResultType
| render timechart
```

- **Visualization**: Time chart
- **Title**: "Failed Sign-Ins Over Time (7 Days)"

### Step 4: Add Top Offending IPs

```kql
union isfuzzy=true SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(24h)
| where ResultType != "0"
| summarize Attempts = count() by IPAddress
| top 10 by Attempts desc
| render barchart
```

- **Visualization**: Bar chart
- **Title**: "Top 10 Source IPs — Failed Sign-Ins (24h)"

### Step 5: Add RBAC Changes Timeline

```kql
AzureActivity
| where TimeGenerated > ago(30d)
| where OperationNameValue =~ "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, Scope = tostring(Properties.scope)
| order by TimeGenerated desc
| render table
```

- **Visualization**: Grid
- **Title**: "Role Assignment Changes (30 Days)"

### Step 6: Add NSG Deny Trend

```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(7d)
| where FlowStatus_s == "D"
| summarize DenyCount = count() by bin(TimeGenerated, 1h), NSGList_s
| render timechart
```

- **Visualization**: Time chart
- **Title**: "NSG Denied Flows by Hour (7 Days)"

### Step 7: Save the Workbook

1. Click **Done editing**
2. Click **Save** (💾 icon)
3. **Title**: `SecOps Lab — Security Overview`
4. **Resource group**: `rg-sentinel-secops-lab`
5. **Location**: East US
6. Click **Apply**

---

## Customization Tips

| Goal | Approach |
|------|----------|
| Add a time range picker | Add a **Parameters** group with a Time range parameter; reference it as `{TimeRange}` in queries |
| Filter by subscription | Add a dropdown parameter querying `AzureActivity \| distinct SubscriptionId` |
| Conditional formatting | In grid visualizations, click **Column Settings** to add color thresholds (e.g., red when count > 100) |
| Export to PDF | Use the workbook's **More (…) → Print workbook** option for portfolio evidence |

---

## Screenshots for Portfolio

Capture the following for your portfolio evidence:

1. **Workbook overview** — Full page showing all tiles and charts populated
2. **Failed Sign-In heatmap** — Zoomed in on the time chart during a simulated attack
3. **RBAC timeline** — Showing the test role assignment event
4. **Edit mode** — Show the KQL behind at least one visualization to demonstrate query authorship
