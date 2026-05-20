# MyApi Infrastructure

Terraform-managed Azure infrastructure for the MyApi application. Deploys three isolated environments (development, staging, production) using a shared module library, with full CI/CD via GitHub Actions.

## Architecture

```
                        ┌─────────────────────────────────┐
                        │        Azure Container Apps       │
                        │  ┌──────────────────────────┐   │
                        │  │  myapi container app      │   │
                        │  │  (User-assigned identity) │   │
                        │  └────────────┬─────────────┘   │
                        │               │ AcrPull           │
                        └───────────────┼─────────────────┘
                                        │
              ┌─────────────────────────┼─────────────────────────┐
              │                         │                           │
    ┌─────────▼──────┐       ┌──────────▼────────┐    ┌──────────▼────────┐
    │  Azure          │       │  Key Vault         │    │  PostgreSQL        │
    │  Container      │       │  (db-connection-   │    │  Flexible Server   │
    │  Registry       │       │   string secret)   │    │  (v16)             │
    │  (shared)       │       └────────────────────┘    └────────────────────┘
    └─────────────────┘
```

Each environment is a self-contained Terraform root that composes four shared modules:

| Module | Resources |
|---|---|
| `app-environment` | Resource group, Log Analytics workspace, ACA environment |
| `container-app` | User-assigned identity, AcrPull role assignment, Container App |
| `postgres` | PostgreSQL Flexible Server v16, firewall rule, database |
| `key-vault` | Key Vault, Secrets Officer role assignment, connection string secret |

## Environment Comparison

| Configuration | Development | Staging | Production |
|---|---|---|---|
| CPU | 0.25 | 0.5 | 0.5 |
| Memory | 0.5 Gi | 1 Gi | 1 Gi |
| Replicas | 1 – 3 | 1 – 5 | 1 – 5 |
| PostgreSQL SKU | B_Standard_B1ms | B_Standard_B2ms | GP_Standard_D2s_v3 |
| Storage | 32 GB | 32 GB | 64 GB |
| Geo-redundant backup | No | No | Yes |
| Backup retention | 7 days | 7 days | 14 days |
| ASPNETCORE_ENVIRONMENT | Development | Staging | Production |

All three environments deploy to `southafricanorth`.

## Repository Structure

```
MyApi-Infra/
├── .github/workflows/
│   ├── Infra-CI.yml                   # Main CI/CD pipeline (PR + push to main)
│   ├── Infra-Drift-Scheduled.yml      # Nightly drift detection
│   ├── Infra-Provision-Development.yml
│   ├── Infra-Provision-Staging.yml
│   ├── Infra-Provision-Production.yml
│   ├── Infra-Provision-Manual.yml     # Universal manual trigger with destroy option
│   └── _shared-terraform-planapply.yml  # Reusable plan/apply workflow
├── modules/
│   ├── app-environment/
│   ├── container-app/
│   ├── key-vault/
│   └── postgres/
├── development/
├── staging/
├── production/
├── bootstrap/                         # One-time setup scripts (excluded from scans)
├── .checkov.yaml                      # Global Checkov suppressions
└── sonar-project.properties           # SonarCloud configuration
```

## CI/CD Pipelines

### Infra-CI (main pipeline)

Triggers on pull requests to `main` and pushes to `main` (when `development/**`, `staging/**`, `production/**`, `modules/**`, or workflow files change).

```
format-check ──┬── validate (dev/stg/prd matrix)
               ├── checkov
               └── sonarcloud
                       │
               plan-apply-development
               plan-apply-staging
               plan-apply-production ← requires manual approval (production environment)
                       │
               ci-status  ← single required branch protection check
```

**On pull requests**: runs format, validate, scan, and plan. Plan output is posted as a PR comment. Apply is skipped.

**On push to main**: same steps, then applies for each environment where the plan detected changes (exit code 2). Production requires a required reviewer approval via GitHub Environments.

**Concurrency**: PR runs cancel in-progress on new commits; push-to-main runs queue to prevent concurrent state modifications.

### Drift Detection

Runs nightly at 01:00 UTC. Executes `terraform plan` for each environment and:
- Opens a GitHub Issue labelled `infrastructure-drift-<env>` when drift is detected.
- Adds a comment with updated plan output on subsequent runs.
- Closes the issue automatically when drift resolves.

### Manual Provision

Two options for out-of-band applies:

- **Environment-specific workflows** (`Infra-Provision-Development.yml` etc.) — single-click dispatch per environment.
- **Universal workflow** (`Infra-Provision-Manual.yml`) — choose environment and optionally enable `destroy`.

All manual workflows share the same concurrency groups as CI to prevent state conflicts.

## Shared Workflow (`_shared-terraform-planapply.yml`)

The plan/apply logic lives in one reusable workflow called by all callers.

**Plan job** (always runs):
1. Azure login via OIDC
2. `terraform init` against Azure Blob remote state
3. `terraform fmt -check`, `terraform validate`
4. `terraform plan -detailed-exitcode`
5. Posts plan to PR comment (capped at 60k characters)

**Apply job** (conditional):
- Runs only when: branch matches `apply_branch` (or `workflow_dispatch`) **and** plan exit code is `2` (changes detected).
- Re-plans before applying to guarantee a fresh state snapshot.
- `terraform apply -auto-approve`

`PG_ADMIN_PASSWORD` is injected as `TF_VAR_pg_admin_password` so it never appears in plan output.

## Authentication

### Terraform → Azure

OIDC federation — no long-lived credentials stored in GitHub. The GitHub Actions app registration is granted **Contributor** and **User Access Administrator** on the subscription (User Access Administrator is required to assign the AcrPull and Key Vault Secrets User roles during apply).

### Container App → Azure Services

A user-assigned managed identity (`id-{app_name}`) is created per environment and granted:
- **AcrPull** on the shared container registry — allows image pulls.
- **Key Vault Secrets User** on the environment Key Vault — allows the app to read `db-connection-string` at runtime.

The CD pipeline (not this repo) assigns this identity to the deployed container revision.

## State Management

| Setting | Value |
|---|---|
| Backend | Azure Blob Storage |
| Storage account | `myapiterraformstate` |
| Container | `tfstate` |
| Keys | `development/api.tfstate`, `staging/api.tfstate`, `production/api.tfstate` |
| Locking | Azure Blob lease (native) |
| Lock timeout | 5 minutes |

## Security Scanning

### Checkov

Runs static IaC analysis against CIS Azure benchmarks (1000+ policies). SARIF results are uploaded to the GitHub Security tab as code-scanning alerts.

Active global suppressions (all pending VNet + private endpoint hardening):

| Check | Resource | Reason |
|---|---|---|
| CKV_AZURE_183 / CKV_AZURE_109 | Key Vault | Network ACL default-deny requires private endpoint |
| CKV2_AZURE_5 / CKV2_AZURE_32 | Key Vault | Private endpoint not yet provisioned |
| CKV2_AZURE_57 | PostgreSQL | Private endpoint not yet provisioned |
| CKV2_AZURE_26 | PostgreSQL | `0.0.0.0/0.0.0.0` is Azure's allow-Azure-services sentinel — removed with VNet |
| CKV_AZURE_130 / CKV_AZURE_131 | PostgreSQL | Same private endpoint roadmap item |

When a VNet module with private endpoints is added, all suppressions can be removed.

### SonarCloud

Configured in `sonar-project.properties`. Analyses `development/`, `staging/`, `production/`, and `modules/` for code quality, IaC security hotspots, and hardcoded secrets. PR decoration and dashboard at [sonarcloud.io](https://sonarcloud.io).

**Required secret**: `SONAR_TOKEN_INFRA` (repository secret).
**Main branch**: `main` (configure in SonarCloud → Administration → Branches and Pull Requests).

## Resource Naming

```
{prefix}-{app}-{env-suffix}

Resource group:          rg-myapi-dev / rg-myapi-staging / rg-myapi-production
ACA environment:         aca-myapi-dev / aca-myapi-staging / aca-myapi-production
Log Analytics:           law-myapi-dev / law-myapi-staging / law-myapi-production
Container App:           myapi-dev / myapi-stg / myapi
PostgreSQL server:       psql-myapi-dev / psql-myapi-stg / psql-myapi-prd
Key Vault:               kv-myapi-dev / kv-myapi-stg / kv-myapi-prd
Managed identity:        id-myapi-dev / id-myapi-stg / id-myapi
```

## Required GitHub Secrets

| Secret | Scope | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | Repository | App registration client ID for OIDC |
| `AZURE_TENANT_ID` | Repository | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Repository | Target subscription ID |
| `PG_ADMIN_PASSWORD` | Repository | PostgreSQL administrator password |
| `SONAR_TOKEN_INFRA` | Repository | SonarCloud authentication token |

## One-Time Setup

1. **Remote state storage** — run the bootstrap scripts in `bootstrap/` to create the storage account and resource group before first apply.
2. **OIDC federation** — configure the GitHub Actions app registration with federated credentials for `main` branch and each GitHub Environment (`development`, `staging`, `production`).
3. **GitHub Environments** — create `development`, `staging`, and `production` environments in repository Settings. Add required reviewers to `production`.
4. **Branch protection** — in Settings → Branches → `main` → Require status checks, add `CI Status` as a required check.
5. **SonarCloud** — create a project at sonarcloud.io, link the repository, set the main branch to `main`, and add `SONAR_TOKEN_INFRA` as a repository secret.

## CD Pipeline Integration

This repository provisions infrastructure only. The application CD pipeline (separate repository) owns:
- Pushing images to the shared ACR (`acrimagereg` in resource group `Playground`).
- Updating the container revision with the new image tag.

Terraform ignores changes to the container image and environment variables after initial provisioning (`lifecycle.ignore_changes`) so CD pipeline updates are not reverted on the next infrastructure apply.

The CD pipeline reads the database connection string from Key Vault using the ACA managed identity — no secrets are passed directly to the application.
