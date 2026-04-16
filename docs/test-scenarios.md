# Test Scenarios

This document provides three complete test scenarios to validate the detection rules in this lab. Each scenario includes exact commands, expected timing, and investigation steps.

---

## Scenario 1: Failed Sign-In Burst (Brute Force Simulation)

### Objective

Verify that the `failed_signin_burst.kql` analytics rule detects ≥ 5 failed sign-ins from the same IP within 10 minutes and generates a Sentinel incident.

### MITRE ATT&CK

- **Tactic:** Credential Access (TA0006)
- **Technique:** T1110 — Brute Force

### Prerequisites

- A test user in your Entra ID tenant (e.g., `testuser@yourdomain.onmicrosoft.com`)
- Azure AD sign-in logs flowing to Log Analytics (verify via Data Connectors)

### Step-by-Step

```bash
# Option A: Simulate failed logins via Azure CLI (from a single IP / your machine)
# This will produce 10 failed sign-in events in rapid succession.
for i in $(seq 1 10); do
  echo "Attempt $i..."
  az login \
    --username testuser@yourdomain.onmicrosoft.com \
    --password "Deliberately-Wrong-Password-$i!" \
    --only-show-errors 2>/dev/null || true
  sleep 3
done
```

```bash
# Option B: Use curl against the OAuth2 token endpoint
TENANT_ID="<your-tenant-id>"
for i in $(seq 1 10); do
  echo "Attempt $i..."
  curl -s -X POST \
    "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=04b07795-cd7b-4f4d-9f1b-4d0b9a65e367" \
    -d "scope=https://management.azure.com/.default" \
    -d "grant_type=password" \
    -d "username=testuser@yourdomain.onmicrosoft.com" \
    -d "password=Wrong-Password-$i!" \
    > /dev/null
  sleep 2
done
```

### Expected Timeline

| Event | Expected Time |
|-------|--------------|
| Sign-in failures appear in `SigninLogs` | 2–5 minutes after commands |
| Analytics rule evaluates | Next scheduled run (every 10 minutes) |
| Alert generated | 5–15 minutes after first failure |
| Incident created in Sentinel | Immediately after alert |
| Logic App tags incident | Within 1 minute of incident creation |

### Verification in Sentinel

1. Go to **Sentinel → Logs** and run:

```kql
SigninLogs
| where TimeGenerated > ago(30m)
| where ResultType != "0"
| where UserPrincipalName contains "testuser"
| project TimeGenerated, IPAddress, UserPrincipalName, ResultType, ResultDescription
| order by TimeGenerated desc
```

2. Go to **Sentinel → Incidents** and look for:
   - **Title:** "Failed Sign-In Burst Detection"
   - **Severity:** Medium
   - **Entities:** The test user UPN and your source IP
   - **Tags:** `AutoTagged=true`, `ReviewStatus=Pending`

3. Click the incident → **Investigation** to see the entity graph

### Cleanup

No cleanup required — failed sign-in events are read-only log entries.

---

## Scenario 2: Role Assignment Creation (Privilege Escalation)

### Objective

Verify that the `role_assignment_created.kql` analytics rule detects new RBAC role grants and generates a High-severity incident.

### MITRE ATT&CK

- **Tactic:** Privilege Escalation (TA0004)
- **Technique:** T1098 — Account Manipulation

### Prerequisites

- Your user account needs **User Access Administrator** or **Owner** role at the resource group scope
- A target principal (your own Object ID is fine for testing)

### Step-by-Step

```bash
# Get your user Object ID
USER_OID=$(az ad signed-in-user show --query id -o tsv)

# Get the resource group ID
RG_ID=$(az group show --name rg-sentinel-secops-lab --query id -o tsv)

# Create a test role assignment (Reader role on the resource group)
az role assignment create \
  --assignee "$USER_OID" \
  --role "Reader" \
  --scope "$RG_ID" \
  --description "Test role assignment for Sentinel detection validation"
```

### Expected Timeline

| Event | Expected Time |
|-------|--------------|
| Activity log entry generated | Immediate |
| Event appears in `AzureActivity` table | 2–10 minutes |
| Analytics rule evaluates | Next scheduled run (every 5 minutes) |
| High-severity incident created | 5–15 minutes after role creation |

### Verification in Sentinel

1. Run this query in **Sentinel → Logs**:

```kql
AzureActivity
| where TimeGenerated > ago(1h)
| where OperationNameValue =~ "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, ResourceGroup, SubscriptionId
```

2. Check **Sentinel → Incidents** for:
   - **Title:** "Suspicious Role Assignment"
   - **Severity:** High
   - **Details:** Your UPN as the Caller, Reader role, resource group scope

### Cleanup

```bash
# Remove the test role assignment
az role assignment delete \
  --assignee "$USER_OID" \
  --role "Reader" \
  --scope "$RG_ID"
```

---

## Scenario 3: NSG Deny Spike (Network Reconnaissance)

### Objective

Verify that the `nsg_deny_spike.kql` analytics rule detects an anomalous spike in NSG-denied traffic.

### MITRE ATT&CK

- **Tactic:** Discovery (TA0007)
- **Technique:** T1046 — Network Service Discovery

### Prerequisites

- The VM must be running and the NSG must have diagnostic settings sending to Log Analytics
- Access to a machine **outside** your `allowed_ip_ranges` (or temporarily remove your IP from the allowlist)
- Network flow logs may require **Traffic Analytics** to be enabled on the NSG

### Enabling Traffic Analytics (if not already enabled)

```bash
# Create a Network Watcher (if one doesn't exist in your region)
az network watcher configure \
  --resource-group NetworkWatcherRG \
  --locations eastus \
  --enabled true

# Enable NSG flow logs with Traffic Analytics
NSG_ID=$(az network nsg show \
  --resource-group rg-sentinel-secops-lab \
  --name secops-nsg-workload \
  --query id -o tsv)

STORAGE_ID=$(az storage account show \
  --resource-group rg-sentinel-secops-lab \
  --name $(terraform output -raw storage_account_name) \
  --query id -o tsv)

LAW_ID=$(terraform output -raw log_analytics_workspace_id)

az network watcher flow-log create \
  --name secops-nsg-flowlog \
  --nsg "$NSG_ID" \
  --storage-account "$STORAGE_ID" \
  --workspace "$LAW_ID" \
  --enabled true \
  --traffic-analytics true \
  --interval 10 \
  --resource-group NetworkWatcherRG \
  --location eastus
```

### Step-by-Step: Generate Denied Traffic

```bash
# Option A: Rapid SSH connection attempts from a non-allowed IP
# Run this from a machine NOT in your allowed_ip_ranges
VM_IP=$(terraform output -raw vm_public_ip)

for i in $(seq 1 50); do
  echo "Connection attempt $i..."
  timeout 2 ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=1 \
    azureadmin@$VM_IP 2>/dev/null || true
done
```

```bash
# Option B: Port scan using nmap (from a non-allowed IP)
# WARNING: Only scan YOUR OWN resources
nmap -sS -T4 --top-ports 100 $VM_IP
```

```bash
# Option C: Use hping3 for rapid SYN probing
# This sends 200 SYN packets across various ports
for port in 80 443 8080 3389 21 25 53 8443 9090 5432; do
  hping3 -S -p $port -c 20 --faster $VM_IP 2>/dev/null &
done
wait
```

### Expected Timeline

| Event | Expected Time |
|-------|--------------|
| NSG deny events logged | Immediate per connection |
| Events appear in `AzureNetworkAnalytics_CL` | 10–15 minutes (Traffic Analytics processing) |
| Spike detected over baseline | After ≥ 30 minutes of baseline data + spike |
| Analytics rule fires | Next scheduled run (every 5 minutes) |

> **Note:** This scenario requires the longest baseline period. For a fresh deployment, you may need to wait 30+ minutes for enough baseline data before the spike detection triggers. Run a small amount of traffic first, wait 30 minutes, then run the burst.

### Verification in Sentinel

1. Check raw NSG events:

```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| where FlowStatus_s == "D"
| summarize Count = count() by bin(TimeGenerated, 5m), NSGList_s
| render timechart
```

2. Check for spike detection:

```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(1h)
| where FlowStatus_s == "D"
| summarize DenyCount = count(), Ports = make_set(DestPort_d, 10) by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

3. Look for the incident in **Sentinel → Incidents**:
   - **Title:** "NSG Deny Traffic Spike"
   - **Severity:** Medium
   - **Details:** NSG name, spike ratio, top denied ports

### Cleanup

No resource cleanup needed. If you enabled Traffic Analytics, you can disable it after testing to reduce costs:

```bash
az network watcher flow-log delete \
  --name secops-nsg-flowlog \
  --resource-group NetworkWatcherRG \
  --location eastus
```

---

## Test Execution Checklist

Use this checklist to track your testing progress:

- [ ] Scenario 1: Failed sign-ins simulated
- [ ] Scenario 1: Events visible in `SigninLogs`
- [ ] Scenario 1: Sentinel incident created
- [ ] Scenario 1: Logic App tagged the incident
- [ ] Scenario 2: Role assignment created
- [ ] Scenario 2: Event visible in `AzureActivity`
- [ ] Scenario 2: High-severity incident created
- [ ] Scenario 2: Test role assignment cleaned up
- [ ] Scenario 3: NSG deny traffic generated
- [ ] Scenario 3: Events visible in `AzureNetworkAnalytics_CL`
- [ ] Scenario 3: Spike incident created
- [ ] All three incidents visible in Sentinel Incidents view
- [ ] Screenshots captured for portfolio evidence
