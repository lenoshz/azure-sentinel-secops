# Azure Policy Assignments

This guide covers the two Azure Policy assignments used in this lab to enforce governance baselines, along with instructions for verifying compliance.

---

## 1. Storage Accounts Should Prevent Public Blob Access

| Property | Value |
|----------|-------|
| **Built-in Policy ID** | `4fa4b6c0-31ca-4c0d-b10d-24b96f62a751` |
| **Display Name** | Storage accounts should prevent shared key access *(Note: for public blob access, see alternative ID below)* |
| **Public Access Policy ID** | `34c877ad-507e-4c82-993e-3452a6e0ad3c` |
| **Effect** | Deny |
| **Category** | Storage |
| **Scope** | Resource Group: `rg-sentinel-secops-lab` |

### Assignment Steps

```bash
# Step 1: Get your resource group ID
RG_ID=$(az group show \
  --name rg-sentinel-secops-lab \
  --query id -o tsv)

# Step 2: Create the policy assignment with Deny effect
az policy assignment create \
  --name "deny-storage-public-access" \
  --display-name "Deny public blob access on storage accounts" \
  --policy "34c877ad-507e-4c82-993e-3452a6e0ad3c" \
  --scope "$RG_ID" \
  --params '{"effect": {"value": "Deny"}}' \
  --enforcement-mode Default

# Step 3: Verify the assignment was created
az policy assignment show \
  --name "deny-storage-public-access" \
  --scope "$RG_ID" \
  --query '{name:name, effect:parameters.effect.value, scope:scope}'
```

### What This Prevents

Once assigned, any attempt to create or modify a storage account with
`allowBlobPublicAccess = true` will be **denied** at the ARM level. This
policy enforces the principle that no storage data should be accidentally
exposed to the internet.

### Compliance Check

```bash
# Trigger an on-demand compliance scan
az policy state trigger-scan --resource-group rg-sentinel-secops-lab

# Check compliance state
az policy state summarize \
  --filter "policyAssignmentName eq 'deny-storage-public-access'" \
  -o table
```

---

## 2. Allowed Locations

| Property | Value |
|----------|-------|
| **Built-in Policy ID** | `e56962a6-4747-49cd-b67b-bf8b01975c4c` |
| **Display Name** | Allowed locations |
| **Effect** | Deny |
| **Category** | General |
| **Scope** | Resource Group: `rg-sentinel-secops-lab` |

### Assignment Steps

```bash
# Step 1: Create the policy assignment restricted to East US only
az policy assignment create \
  --name "allowed-locations-eastus" \
  --display-name "Restrict resource deployment to East US" \
  --policy "e56962a6-4747-49cd-b67b-bf8b01975c4c" \
  --scope "$RG_ID" \
  --params '{
    "listOfAllowedLocations": {
      "value": ["eastus"]
    }
  }' \
  --enforcement-mode Default

# Step 2: Verify
az policy assignment show \
  --name "allowed-locations-eastus" \
  --scope "$RG_ID" \
  --query '{name:name, locations:parameters.listOfAllowedLocations.value, scope:scope}'
```

### What This Prevents

Any attempt to deploy a resource to a region **other than East US** within
the scoped resource group will be denied. This ensures all lab resources
remain co-located for:
- **Lower latency** between resources
- **Simplified data-residency compliance**
- **Cost predictability** (cross-region egress charges)

### Compliance Check

```bash
az policy state summarize \
  --filter "policyAssignmentName eq 'allowed-locations-eastus'" \
  -o table
```

---

## Checking Overall Compliance State

Run the following command to get a summary of all policy compliance across the resource group:

```bash
# Full compliance summary for the resource group
az policy state summarize \
  --resource-group rg-sentinel-secops-lab \
  -o table
```

**Expected output** (when all resources are compliant):

```
PolicyAssignmentName           NonCompliantResources    NonCompliantPolicies
-----------------------------  ----------------------  --------------------
deny-storage-public-access     0                       0
allowed-locations-eastus       0                       0
```

### Listing Non-Compliant Resources

```bash
# List resources that are NOT compliant
az policy state list \
  --resource-group rg-sentinel-secops-lab \
  --filter "complianceState eq 'NonCompliant'" \
  --query '[].{Resource:resourceId, Policy:policyAssignmentName, State:complianceState}' \
  -o table
```

---

## Screenshots Guidance

For your portfolio, capture the following screenshots:

1. **Azure Portal → Policy → Compliance** — Shows the compliance dashboard
   with both policies listed and their compliance percentage
2. **Policy Assignment Details** — Click into each assignment to show the
   parameters (Deny effect, allowed locations list)
3. **Deny in Action** — Attempt to create a storage account with public
   access enabled, screenshot the ARM validation error showing the policy
   denial
4. **Non-Compliant Resource** — If any resource drifts, capture the
   non-compliant state and remediation options

> **Tip**: Use the browser's DevTools (F12 → Network) to capture the exact
> ARM error response for role-play investigation write-ups.
