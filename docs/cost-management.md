# Cost Management Guide

This document covers estimated costs, monitoring spend, and strategies to keep your lab bill under control.

---

## Estimated Monthly Cost Breakdown

| Resource | SKU / Tier | Estimated Monthly Cost | Notes |
|----------|-----------|----------------------|-------|
| Log Analytics Workspace | PerGB2018 | **$2.76/GB ingested** | Biggest variable — expect 0.5–2 GB/month for a quiet lab |
| Microsoft Sentinel | Pay-as-you-go | **$2.46/GB analyzed** | Applied on top of Log Analytics ingestion |
| Linux VM (Standard_B1s) | Burstable | **$7.59/month** (full uptime) | **~$3.80/month** with auto-shutdown at 19:00 UTC |
| Public IP (Standard SKU) | Static | **$3.65/month** | Charged even when VM is stopped |
| Storage Account (Standard_LRS) | LRS | **< $0.10/month** | Minimal storage for lab use |
| Key Vault | Standard | **$0.03/10K operations** | Negligible — a few cents at most |
| Defender for Cloud | Free tier | **$0.00** | Free tier provides recommendations only |
| Logic App | Consumption | **$0.000025/action** | A few cents per incident response |
| NSG Flow Logs (if enabled) | Traffic Analytics | **$0.50/NSG/month** + ingestion | Optional; adds to Log Analytics cost |

### Estimated Total

| Scenario | Monthly Estimate |
|----------|-----------------|
| **Minimal usage** (VM auto-shutdown, <1 GB ingestion) | **$10–15** |
| **Active testing** (VM running 8h/day, 2–5 GB ingestion) | **$20–35** |
| **Left running accidentally** (VM 24/7, flow logs enabled) | **$40–60** |

> 💡 **Free Trial Credit:** If you're on a new Azure Free Account, you have $200 in credit for 30 days. This lab is designed to stay well within that budget.

---

## Checking Current Spend

### Azure Portal

1. Go to **Cost Management + Billing** → **Cost analysis**
2. Set scope to your resource group: `rg-sentinel-secops-lab`
3. Change view to **Daily costs** for granular tracking

### Azure CLI

```bash
# Get current month's usage for the resource group
az consumption usage list \
  --start-date $(date -u +"%Y-%m-01") \
  --end-date $(date -u +"%Y-%m-%d") \
  --query "[?contains(instanceId, 'rg-sentinel-secops-lab')]
           .{Resource:instanceName, Cost:pretaxCost, Currency:currency}" \
  -o table
```

```bash
# Quick cost summary by resource type
az consumption usage list \
  --start-date $(date -u +"%Y-%m-01") \
  --end-date $(date -u +"%Y-%m-%d") \
  --query "[?contains(instanceId, 'rg-sentinel-secops-lab')]" \
  -o json | jq 'group_by(.consumedService) |
  map({service: .[0].consumedService, total: (map(.pretaxCost | tonumber) | add)})'
```

---

## Budget Alert Configuration

The Terraform configuration in `main.tf` creates an `azurerm_consumption_budget_resource_group` resource with two notifications:

| Alert | Trigger | Type |
|-------|---------|------|
| 80% threshold | When **actual** spend reaches 80% of budget ($16 of $20) | Email |
| 100% threshold | When **forecasted** spend reaches 100% of budget ($20) | Email |

### How It Works

1. Azure evaluates budget thresholds **daily** at approximately 00:00 UTC
2. When a threshold is crossed, an email is sent to `var.budget_alert_email`
3. **Budgets do NOT stop spending** — they only notify. You must manually take action.

### Verifying Budget Configuration

```bash
# List budgets on the resource group
az consumption budget list \
  --resource-group rg-sentinel-secops-lab \
  -o table
```

### Adjusting the Budget

Change `budget_amount` in `terraform.tfvars` and re-apply:

```hcl
budget_amount = 30  # Increase to $30/month
```

```bash
terraform plan -target=azurerm_consumption_budget_resource_group.lab_budget
terraform apply -target=azurerm_consumption_budget_resource_group.lab_budget
```

---

## VM Auto-Shutdown

The `azurerm_dev_test_global_vm_shutdown_schedule` resource automatically shuts down the VM at **19:00 UTC daily**. This alone saves ~50% on VM compute costs.

### Verifying Auto-Shutdown

```bash
# Check the shutdown schedule
az vm auto-shutdown show \
  --resource-group rg-sentinel-secops-lab \
  --name secops-vm-honeypot \
  --query '{Status:status, Time:dailyRecurrence.time, Timezone:timeZoneId}'
```

**Expected output:**
```json
{
  "Status": "Enabled",
  "Time": "1900",
  "Timezone": "UTC"
}
```

### Manually Stopping the VM

If you're done testing before the auto-shutdown time:

```bash
# Deallocate the VM to stop ALL charges (except Public IP and disk)
az vm deallocate \
  --resource-group rg-sentinel-secops-lab \
  --name secops-vm-honeypot

# Start it again when you need it
az vm start \
  --resource-group rg-sentinel-secops-lab \
  --name secops-vm-honeypot
```

> **Note:** `az vm stop` only powers off the OS but keeps the VM allocated (you still pay for compute). Always use `az vm deallocate` to stop billing.

---

## When to Run `terraform destroy`

Run `terraform destroy` when:

- ✅ You've completed all test scenarios and captured screenshots
- ✅ You've exported any workbook configurations or custom analytics rules
- ✅ You don't plan to use the lab for more than a few days
- ✅ Your budget alert fires and you want to stop accumulating costs

Do NOT destroy if:

- ❌ You're in the middle of testing and need log data to accumulate
- ❌ You're waiting for an analytics rule to fire (some take 30+ minutes)

### Partial Cleanup (Keep Logs, Stop Compute)

If you want to keep your Log Analytics data but reduce costs:

```bash
# Stop the VM (biggest cost driver after ingestion)
az vm deallocate -g rg-sentinel-secops-lab -n secops-vm-honeypot

# Delete the public IP (saves $3.65/month)
az network public-ip delete -g rg-sentinel-secops-lab -n secops-pip-vm
```

---

## Defender for Cloud Free Tier Limits

| Feature | Free Tier | Standard (Paid) |
|---------|-----------|-----------------|
| Secure Score | ✅ | ✅ |
| Security recommendations | ✅ | ✅ |
| Azure Security Benchmark | ✅ | ✅ |
| CWPP (Cloud Workload Protection) | ❌ | ✅ |
| Just-in-Time VM access | ❌ | ✅ |
| Adaptive application controls | ❌ | ✅ |
| File integrity monitoring | ❌ | ✅ |
| Container security | ❌ | ✅ |

The Free tier is sufficient for this lab. It provides:
- Security posture assessment and Secure Score
- Built-in recommendations for misconfiguration detection
- Integration with Log Analytics for security logging

To check your current tier:

```bash
az security pricing list --query "[].{Name:name, Tier:pricingTier}" -o table
```
