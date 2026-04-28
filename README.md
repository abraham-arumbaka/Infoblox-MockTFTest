# Terraform + Infoblox Mock — IPAM-Driven Azure Network Provisioning

## Problem Statement

Enterprise customers using **Infoblox NIOS** as their IPAM solution require all network CIDR allocations to be registered in Infoblox before cloud resources are created. When implementing Terraform automation for these customers, developers need a live Infoblox WAPI endpoint to test the `infobloxopen/infoblox` Terraform provider.

Standing up a real Infoblox Grid Manager involves licensing, Grid configuration, network views, and extensible attribute setup — often taking weeks. This blocks developers from building and validating automation early.

**This repo solves that by providing a lightweight mock Infoblox WAPI server** that runs locally in seconds, allowing full end-to-end testing of Terraform plans and applies without any Infoblox infrastructure.

---

## What This Repo Does

This project demonstrates an **IPAM-driven Azure network provisioning pattern** using Terraform:

1. **Requests the next available `/24` CIDR** from a mock Infoblox IPAM server (parent container `10.0.0.0/8`)
2. **Creates an Azure Resource Group** and **Virtual Network** using the allocated CIDR
3. **Carves `/27` subnets** from that CIDR for app, data, and management tiers

The mock server (`mock_infoblox.py`) implements the Infoblox WAPI v2.5 REST endpoints that the Terraform provider actually calls — including extensible attribute registration, network container queries, and network object lifecycle (create / read / update / delete).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer Machine                        │
│                                                             │
│  ┌──────────────────────┐    HTTPS :8443    ┌────────────┐  │
│  │   Terraform CLI       │ ───────────────► │  Mock WAPI │  │
│  │                       │                  │  (Flask)   │  │
│  │  infoblox provider    │ ◄─────────────── │            │  │
│  │  azurerm  provider    │   CIDR allocated  └────────────┘  │
│  └──────────┬────────────┘                                   │
│             │ Azure REST API                                 │
└─────────────┼───────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Resource Group  (rg-<name>-vnet)                   │   │
│  │                                                     │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │  VNet  e.g. 10.0.0.0/24  (from Infoblox)       │ │   │
│  │  │                                                │ │   │
│  │  │  ┌──────────────┐ ┌────────────┐ ┌──────────┐  │ │   │
│  │  │  │ snet-app /27 │ │snet-data/27│ │snet-mgmt │  │ │   │
│  │  │  └──────────────┘ └────────────┘ └──────────┘  │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### WAPI Call Flow

```
Terraform Init
  └─► GET  /wapi/v2.5/extensibleattributedef?name=Terraform+Internal+ID  → []
  └─► POST /wapi/v2.5/extensibleattributedef                              → 201

Terraform Apply
  └─► POST /wapi/v2.5/network  { "network": "func:nextavailablenetwork:10.0.0.0/8,default,24" }
        └─► Mock allocates next free /24 → returns ref  e.g. network/ZG5z:10.0.0.0/24/default
  └─► GET  /wapi/v2.5/network/<ref>   (provider reads back allocated object)
  └─► Azure: create Resource Group → VNet (10.0.0.0/24) → 3x Subnets (/27)

Terraform Destroy
  └─► Azure resources deleted
  └─► DELETE /wapi/v2.5/network/<ref>
```

---

## Project Structure

```
mock/
├── mock_infoblox.py       # Flask mock Infoblox WAPI server (HTTPS :8443)
├── main.tf                # Infoblox network allocation + Azure resources
├── providers.tf           # infobloxopen/infoblox + hashicorp/azurerm providers
├── variables.tf           # All input variable declarations
├── outputs.tf             # VNet CIDR, subnet map, Infoblox ref outputs
├── terraform.tfvars       # Values pointing at mock server
└── README.md
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Python | 3.8+ |
| pip packages | `flask`, `pyopenssl` |
| Terraform | >= 1.5.0 |
| Azure CLI | Any recent version (for `az login`) |

---

## How to Test

### Step 1 — Install Python dependencies

```bash
pip install flask pyopenssl
```

### Step 2 — Terminal 1: Start the mock Infoblox WAPI server

```bash
python mock_infoblox.py
```

Expected output:
```
 * Serving Flask app 'mock_infoblox'
 * Running on https://127.0.0.1:8443
 * Running on https://192.168.x.x:8443
```

Leave this terminal running.

### Step 3 — Terminal 2: Authenticate to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Step 4 — Configure variables

Edit `terraform.tfvars` with your Azure subscription details:

```hcl
azure_subscription_id = "<your-subscription-id>"
azure_tenant_id       = "<your-tenant-id>"
resource_group_name   = "rg-test-vnet"
vnet_name             = "vnet-test"
```

The Infoblox settings already point at the mock and require no changes:

```hcl
infoblox_server   = "localhost"
infoblox_port     = "8443"
infoblox_sslmode  = false
```

### Step 5 — Run Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### Step 6 — Verify outputs

```bash
terraform output
```

Example output:
```
infoblox_network_ref = "network/ZG5z:10.0.0.0/24/default"
subnet_cidrs = {
  "snet-app"  = "10.0.0.0/27"
  "snet-data" = "10.0.0.32/27"
  "snet-mgmt" = "10.0.0.64/27"
}
vnet_cidr = "10.0.0.0/24"
```

### Step 7 — Tear down

```bash
terraform destroy -auto-approve
```

---

## Switching to a Real Infoblox Instance

Change four values in `terraform.tfvars`:

```hcl
infoblox_server   = "your-nios-grid-master.internal"
infoblox_port     = "443"
infoblox_username = "your-service-account"
infoblox_password = "your-password"
infoblox_sslmode  = true
```

No changes to Terraform resources or modules are required.

---

## Mock Server — Supported WAPI Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/wapi/v2.5/extensibleattributedef` | EA lookup (provider init) |
| POST | `/wapi/v2.5/extensibleattributedef` | EA registration |
| GET | `/wapi/v2.5/networkcontainer` | List parent containers |
| POST | `/wapi/v2.5/networkcontainer/<ref>` | Next available network (EA-based allocation) |
| POST | `/wapi/v2.5/network` | Create network / allocate via `func:nextavailablenetwork` |
| GET | `/wapi/v2.5/network/<ref>` | Read network object |
| PUT | `/wapi/v2.5/network/<ref>` | Update comment / extensible attributes |
| DELETE | `/wapi/v2.5/network/<ref>` | Release network |

