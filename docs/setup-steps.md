# Setup Guide

Follow this guide to deploy the Azure Sentinel SecOps Lab from scratch. Estimated time: **20–30 minutes**.

---

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Azure CLI | 2.50+ | [Install](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Terraform | 1.5.0+ | [Install](https://developer.hashicorp.com/terraform/install) |
| Git | 2.0+ | [Install](https://git-scm.com/) |
| SSH key pair | — | `ssh-keygen -t rsa -b 4096` |

**Azure Subscription Requirements:**
- An active Azure subscription (Free Trial or Pay-As-You-Go)
- The deploying user must have **Owner** or **Contributor + User Access Administrator** roles at the subscription level
- Microsoft.SecurityInsights, Microsoft.OperationalInsights, and Microsoft.Security resource providers must be registered

### Register Resource Providers

```bash
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Security
az provider register --namespace Microsoft.PolicyInsights
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/<your-username>/azure-sentinel-secops.git
cd azure-sentinel-secops/terraform
```

---

## Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in your editor and fill in:

```hcl
# Your public IP for SSH access (find it: curl -s ifconfig.me)
allowed_ip_ranges = ["<YOUR_IP>/32"]

# SSH public key (contents of ~/.ssh/id_rsa.pub)
admin_ssh_public_key = "ssh-rsa AAAA... user@host"

# Email for budget and security alerts
budget_alert_email = "your.email@example.com"
```

> ⚠️ **Never commit `terraform.tfvars`** — it contains sensitive values. The `.gitignore` already excludes it.

---

## Step 3: Azure CLI Login

```bash
# Login to Azure
az login

# List subscriptions and select the correct one
az account list -o table
az account set --subscription "<SUBSCRIPTION_ID>"

# Verify
az account show --query '{Name:name, Id:id, State:state}' -o table
```

---

## Step 4: Deploy Infrastructure

```bash
# Initialize Terraform (downloads providers)
terraform init
```

**Expected output:**
```
Terraform has been successfully initialized!
```

```bash
# Preview the deployment plan
terraform plan -out=lab.tfplan
```

**Expected output:** ~15–20 resources to create. Review carefully, then:

```bash
# Apply the plan
terraform apply lab.tfplan
```

**Expected output (after ~5–10 minutes):**
```
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

key_vault_uri = "https://secops-kv-abc123.vault.azure.net/"
log_analytics_workspace_id = "/subscriptions/.../secops-law-sentinel"
resource_group_name = "rg-sentinel-secops-lab"
sentinel_workspace_name = "secops-law-sentinel"
vm_public_ip = "20.xxx.xxx.xxx"
```

Save these outputs — you'll reference them in later steps.

---

## Step 5: Verify Sentinel & Data Connectors

1. Open **Azure Portal** → **Microsoft Sentinel**
2. Select the workspace `secops-law-sentinel`
3. Navigate to **Data connectors** — verify:
   - ✅ **Azure Active Directory** — Connected
   - ✅ **Azure Activity** — Connected (via Diagnostic Settings)
4. Navigate to **Logs** → run a test query:

```kql
Heartbeat
| where TimeGenerated > ago(15m)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
```

> **Note:** It may take 10–15 minutes for the first data to appear after deployment.

---

## Step 6: Create Analytics Rules (KQL)

For each KQL file in the `kql/` directory, create a Sentinel Analytics Rule:

1. Go to **Sentinel** → **Analytics** → **+ Create** → **Scheduled query rule**
2. Fill in:

### Rule 1: Failed Sign-In Burst
| Field | Value |
|-------|-------|
| Name | Failed Sign-In Burst Detection |
| Severity | Medium |
| MITRE ATT&CK | Credential Access → T1110 |
| Query | Paste contents of `kql/failed_signin_burst.kql` |
| Run frequency | Every 10 minutes |
| Lookup period | Last 1 hour |
| Alert threshold | Greater than 0 |

### Rule 2: Role Assignment Created
| Field | Value |
|-------|-------|
| Name | Suspicious Role Assignment |
| Severity | High |
| MITRE ATT&CK | Privilege Escalation → T1098 |
| Query | Paste contents of `kql/role_assignment_created.kql` |
| Run frequency | Every 5 minutes |
| Lookup period | Last 24 hours |
| Alert threshold | Greater than 0 |

### Rule 3: NSG Deny Spike
| Field | Value |
|-------|-------|
| Name | NSG Deny Traffic Spike |
| Severity | Medium |
| MITRE ATT&CK | Discovery → T1046 |
| Query | Paste contents of `kql/nsg_deny_spike.kql` |
| Run frequency | Every 5 minutes |
| Lookup period | Last 1 hour |
| Alert threshold | Greater than 0 |

3. Click **Review + create** → **Create**

---

## Step 7: Deploy Logic App Playbook

```bash
# Deploy the auto-tag playbook
az deployment group create \
  --resource-group rg-sentinel-secops-lab \
  --template-file ../playbooks/auto-tag-incident.json \
  --parameters \
    workspaceName="secops-law-sentinel" \
    resourceGroupName="rg-sentinel-secops-lab" \
    notificationEmail="your.email@example.com"
```

After deployment, **authorize the API connections**:

1. Go to **Portal** → **Resource Group** → find the `azuresentinel` API connection
2. Click **Edit API connection** → **Authorize** → **Save**
3. Repeat for the `office365` API connection

Then attach the playbook to Sentinel:

1. Go to **Sentinel** → **Automation** → **+ Create** → **Automation rule**
2. **Trigger**: When incident is created
3. **Action**: Run playbook → select `secops-playbook-auto-tag`
4. **Save**

---

## Step 8: Assign Azure Policies

Follow the detailed steps in [`policy/assignments.md`](../policy/assignments.md):

```bash
RG_ID=$(az group show --name rg-sentinel-secops-lab --query id -o tsv)

# Policy 1: Deny public blob access
az policy assignment create \
  --name "deny-storage-public-access" \
  --policy "34c877ad-507e-4c82-993e-3452a6e0ad3c" \
  --scope "$RG_ID" \
  --params '{"effect": {"value": "Deny"}}'

# Policy 2: Restrict to East US
az policy assignment create \
  --name "allowed-locations-eastus" \
  --policy "e56962a6-4747-49cd-b67b-bf8b01975c4c" \
  --scope "$RG_ID" \
  --params '{"listOfAllowedLocations": {"value": ["eastus"]}}'
```

---

## Step 9: Simulate Test Events

See [`test-scenarios.md`](test-scenarios.md) for detailed commands. Quick summary:

```bash
# Simulate failed sign-ins (requires a test user)
for i in $(seq 1 10); do
  az login -u testuser@yourdomain.onmicrosoft.com -p WrongPassword123! 2>/dev/null
  sleep 2
done

# Create a test role assignment
az role assignment create \
  --assignee "<your-user-object-id>" \
  --role "Reader" \
  --scope "$RG_ID"

# Generate NSG deny events (SSH from non-allowed IP)
# From a machine NOT in your allowed_ip_ranges:
ssh azureadmin@<VM_PUBLIC_IP>  # This will be denied by NSG
```

---

## Step 10: Verify Incidents in Sentinel

1. Go to **Sentinel** → **Incidents**
2. Wait 10–15 minutes after simulating events
3. You should see incidents created by your analytics rules
4. Click an incident to verify:
   - Tags contain `AutoTagged=true` (from the Logic App)
   - Evidence tab shows the triggering entities
   - Timeline shows the related events

---

## Step 11: Cleanup

When you're done with the lab:

```bash
# Remove policy assignments first (they can block resource deletion)
az policy assignment delete --name "deny-storage-public-access" --scope "$RG_ID"
az policy assignment delete --name "allowed-locations-eastus" --scope "$RG_ID"

# Destroy all Terraform-managed resources
cd terraform
terraform destroy

# Confirm with 'yes' when prompted
```

**Expected time:** 3–5 minutes for full teardown.

> **Important:** Key Vault has soft-delete enabled. The vault will remain in a deleted state for 7 days. To purge immediately (if needed): `az keyvault purge --name <vault-name>`
