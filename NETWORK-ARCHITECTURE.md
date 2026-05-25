# Private Networking Architecture — MyAPI Infrastructure

## 1. Per-Environment Resource Layout

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║  Azure Resource Group: rg-myapi-{env}                                            ║
║                                                                                  ║
║  ┌───────────────────────────────────────────────────────────────────────────┐   ║
║  │  Virtual Network  vnet-myapi-{env}                                        │   ║
║  │  dev: 10.0.0.0/16  │  staging: 10.1.0.0/16  │  prod: 10.2.0.0/16          │   ║
║  │                                                                           │   ║
║  │  ┌──────────────────────┐    ┌──────────────────────────────────────────┐ │   ║
║  │  │ snet-aca             │    │ snet-postgres                            │ │   ║
║  │  │ 10.{e}.0.0/23        │    │ 10.{e}.4.0/24                            │ │   ║
║  │  │                      │    │ delegated →                              │ │   ║
║  │  │  ┌────────────────┐  │    │ Microsoft.DBforPostgreSQL/flexibleServers│ │   ║
║  │  │  │ ACA Environment│  │    │                                          │ │   ║
║  │  │  │ (VNet-injected)│  │    │  ┌────────────────────────────────────┐  │ │   ║
║  │  │  │                │  │    │  │ PostgreSQL Flexible Server         │  │ │   ║
║  │  │  │ ┌────────────┐ │  │    │  │ VNet-injected, no public endpoint  │  │ │   ║
║  │  │  │ │ Container  │─┼──┼────┼─▶│ :5432  private only                │  │ │   ║
║  │  │  │ │ App (API)  │ │  │    │  └────────────────────────────────────┘  │ │   ║
║  │  │  │ └─────┬──────┘ │  │    └──────────────────────────────────────────┘ │   ║
║  │  │  └───────┼────────┘  │                                                 │   ║
║  │  └──────────┼───────────┘    ┌──────────────────────────────────────────┐ │   ║
║  │             │                │ snet-private-endpoints                   │ │   ║
║  │             │                │ 10.{e}.5.0/24                            │ │   ║
║  │             │                │                                          │ │   ║
║  │             │                │  ┌────────────────────────────────────┐  │ │   ║
║  │             └────────────────┼─▶│ Private Endpoint NIC               │  │ │   ║
║  │                              │  │ Key Vault → 10.{e}.5.x             │  │ │   ║
║  │                              │  └────────────────────────────────────┘  │ │   ║
║  │                              └──────────────────────────────────────────┘ │   ║
║  │                                                                           │   ║
║  │                              ┌──────────────────────────────────────────┐ │   ║
║  │                              │ snet-runner                              │ │   ║
║  │                              │ 10.{e}.6.0/27                            │ │   ║
║  │                              │                                          │ │   ║
║  │                              │  ┌────────────────────────────────────┐  │ │   ║
║  │                              │  │ ACA Job — self-hosted runner       │  │ │   ║
║  │                              │  │ ghcr.io/actions/runner             │  │ │   ║
║  │                              │  │ ephemeral · scales to zero         │  │ │   ║
║  │                              │  └────────────────────────────────────┘  │ │   ║
║  │                              └──────────────────────────────────────────┘ │   ║
║  └───────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                  ║
║  ┌───────────────────────────────────────────────────────────────────────────┐   ║
║  │  Private DNS Zones  (linked to VNet — override public DNS inside VNet)    │   ║
║  │  privatelink.vaultcore.azure.net         → resolves to 10.{e}.5.x         │   ║
║  │  privatelink.postgres.database.azure.com → resolves to server VNet IP     │   ║
║  └───────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                  ║
║  Key Vault  (Azure PaaS — no subnet, lives at control plane level)               ║
║  network_acls: default_action = Deny  │  bypass = AzureServices                  ║
║  Reachable only via private endpoint NIC in snet-private-endpoints               ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

---

## 2. Traffic Flows

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  INTERNET                                                               │
  └──────────────────────────┬──────────────────────────────────────────────┘
                             │  HTTPS — public ingress (stays public)
                             ▼
              ┌──────────────────────────────┐
              │  Container App               │
              │  public FQDN                 │
              │  snet-aca                    │
              └──────┬───────────────┬───────┘
                     │               │
     private :5432   │               │  private HTTPS via endpoint
                     ▼               ▼
          ┌──────────────┐    ┌───────────────────────────┐
          │ PostgreSQL   │    │ Private Endpoint NIC      │
          │ snet-postgres│    │ snet-private-endpoints    │
          │ (VNet-inject)│    │       │                   │
          └──────────────┘    │       │ (Azure internal)  │
                              │  ┌────▼───────────────┐   │
                              │  │   Key Vault        │   │
                              │  │   (PaaS)           │   │
                              │  └────────────────────┘   │
                              └───────────────────────────┘


  ┌─────────────────────────────────────────────────────────────────────────┐
  │  GitHub Actions — hosted runner (ubuntu-latest)                         │
  │                                                                         │
  │  Can reach    →  Azure control plane (ARM)             ✓                │
  │  Cannot reach →  Key Vault data plane (blocked by ACL) ✗                │
  │  Cannot reach →  PostgreSQL :5432 (no public endpoint) ✗                │
  └──────────────────────────────┬──────────────────────────────────────────┘
                                 │  triggers ACA Job via Azure API
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  ACA Job — self-hosted runner                                           │
  │  snet-runner (inside VNet)                                              │
  │                                                                         │
  │  Can reach  →  Key Vault via private endpoint          ✓                │
  │  Can reach  →  PostgreSQL :5432 via VNet               ✓                │
  │  Can reach  →  GitHub.com (internet egress for runner) ✓                │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. DNS Resolution — How Private Endpoints Work

```
  OUTSIDE VNet (GitHub-hosted runner, local machine)
  ┌─────────────────────────────────────────────────────────────┐
  │  resolve: myvault.vault.azure.net                           │
  │  → 52.x.x.x  (Azure public IP)                              │
  │  → TCP connect → BLOCKED  (network_acls default_action Deny)│
  └─────────────────────────────────────────────────────────────┘

  INSIDE VNet (Container App, ACA runner job)
  ┌─────────────────────────────────────────────────────────────┐
  │  resolve: myvault.vault.azure.net                           │
  │  → Azure DNS sees private DNS zone linked to this VNet      │
  │  → 10.{e}.5.x  (private endpoint NIC)                       │
  │  → TCP connect → ALLOWED                                    │
  └─────────────────────────────────────────────────────────────┘

  PostgreSQL (VNet injection — different model to private endpoint)
  ┌─────────────────────────────────────────────────────────────┐
  │  Inside VNet  → resolves to server's injected subnet IP  ✓  │
  │  Outside VNet → no public endpoint exists at all         ✗  │
  └─────────────────────────────────────────────────────────────┘
```

---

## 4. GitHub Actions Job Routing (post-lockdown)

```
  Infra-CI.yml / _shared-terraform-planapply.yml

  ┌─────────────────┬──────────────────────┬────────────────────────────┐
  │ Job             │ Runner               │ Why                        │
  ├─────────────────┼──────────────────────┼────────────────────────────┤
  │ format-check    │ ubuntu-latest        │ no Azure access needed     │
  │ validate        │ ubuntu-latest        │ -backend=false, static     │
  │ checkov         │ ubuntu-latest        │ static analysis only       │
  │ sonarcloud      │ ubuntu-latest        │ static analysis only       │
  ├─────────────────┼──────────────────────┼────────────────────────────┤
  │ plan  (dev)     │ self-hosted azure-dev│ reads Azure state + KV     │
  │ apply (dev)     │ self-hosted azure-dev│ writes KV secrets via PE   │
  ├─────────────────┼──────────────────────┼────────────────────────────┤
  │ plan  (staging) │ self-hosted azure-stg│ (after staging PR)         │
  │ plan  (prod)    │ self-hosted azure-prd│ (after production PR)      │
  └─────────────────┴──────────────────────┴────────────────────────────┘
```

---

## 5. Multi-Environment Isolation

```
  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │  dev             │   │  staging         │   │  production      │
  │  10.0.0.0/16     │   │  10.1.0.0/16     │   │  10.2.0.0/16     │
  │                  │   │                  │   │                  │
  │  snet-aca  /23   │   │  snet-aca  /23   │   │  snet-aca  /23   │
  │  snet-postgres   │   │  snet-postgres   │   │  snet-postgres   │
  │  snet-pe   /24   │   │  snet-pe   /24   │   │  snet-pe   /24   │
  │  snet-runner /27 │   │  snet-runner /27 │   │  snet-runner /27 │
  │                  │   │                  │   │                  │
  │  No VNet peering │   │  No VNet peering │   │  No VNet peering │
  └──────────────────┘   └──────────────────┘   └──────────────────┘
         │                       │                       │
  [self-hosted,          [self-hosted,           [self-hosted,
   azure-dev]             azure-stg]              azure-prd]
```

---

## 6. Subnet & NSG Reference

| Subnet | CIDR (dev) | NSG | Delegation |
|---|---|---|---|
| `snet-aca` | `10.0.0.0/23` | `nsg-aca-myapi-{env}` | `Microsoft.App/environments` |
| `snet-postgres` | `10.0.4.0/24` | `nsg-postgres-myapi-{env}` | `Microsoft.DBforPostgreSQL/flexibleServers` |
| `snet-private-endpoints` | `10.0.5.0/24` | `nsg-pe-myapi-{env}` | none |
| `snet-runner` | `10.0.6.0/27` | `nsg-runner-myapi-{env}` | none |

Staging uses `10.1.x.x` and production uses `10.2.x.x` with the same layout.

---

## 7. NSG Inbound Rules

```
  nsg-aca-myapi-{env}
  ┌──────┬──────────────────────────┬───────┬──────────┐
  │ Pri  │ Source                   │ Port  │ Action   │
  ├──────┼──────────────────────────┼───────┼──────────┤
  │  100 │ Internet                 │  443  │ Allow    │  ← public HTTPS ingress
  │  110 │ AzureLoadBalancer        │  *    │ Allow    │  ← ACA health probes
  │  120 │ VirtualNetwork           │  *    │ Allow    │  ← ACA internal management
  │ 4096 │ *                        │  *    │ Deny     │
  └──────┴──────────────────────────┴───────┴──────────┘

  nsg-postgres-myapi-{env}
  ┌──────┬──────────────────────────┬───────┬──────────┐
  │ Pri  │ Source                   │ Port  │ Action   │
  ├──────┼──────────────────────────┼───────┼──────────┤
  │  100 │ VirtualNetwork           │ 5432  │ Allow    │  ← app + runner → DB
  │ 4096 │ *                        │  *    │ Deny     │
  └──────┴──────────────────────────┴───────┴──────────┘

  nsg-pe-myapi-{env}  (private endpoints)
  ┌──────┬──────────────────────────┬───────┬──────────┐
  │ Pri  │ Source                   │ Port  │ Action   │
  ├──────┼──────────────────────────┼───────┼──────────┤
  │  100 │ VirtualNetwork           │  443  │ Allow    │  ← Key Vault HTTPS
  │ 4096 │ *                        │  *    │ Deny     │
  └──────┴──────────────────────────┴───────┴──────────┘

  nsg-runner-myapi-{env}
  ┌──────┬──────────────────────────┬───────┬──────────┐
  │ Pri  │ Source                   │ Port  │ Action   │
  ├──────┼──────────────────────────┼───────┼──────────┤
  │ 4096 │ *                        │  *    │ Deny     │  ← runner is outbound-only
  └──────┴──────────────────────────┴───────┴──────────┘

  All NSGs: outbound left to Azure defaults (allow VNet + Internet).
  Runner outbound to GitHub (443) and Azure services is unrestricted.
```

---

## 8. Key Design Decisions

| Decision | Reason |
|---|---|
| PostgreSQL uses **VNet injection**, not a private endpoint | Flexible Server is deployed *into* the delegated subnet directly — it has no public endpoint at all |
| Key Vault uses a **private endpoint**, not VNet injection | Key Vault is a PaaS service and cannot be VNet-injected; a NIC in `snet-private-endpoints` fronts it instead |
| ACA keeps **public ingress** | `internal_load_balancer_enabled = false` — the API must remain reachable from the internet; only backend connections go private |
| Runner in its **own subnet** | Runner needs internet egress (GitHub.com) and VNet access (Key Vault); isolation limits blast radius |
| **No VNet peering** between environments | A compromised dev runner cannot reach staging or production resources |
| **Three separate VNets** | Matches existing per-environment resource group isolation pattern |
| **NSG on every subnet** | CKV2_AZURE_31 compliance; also provides defence-in-depth at the network layer |
