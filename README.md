# Azure Resource Management

Terraform-managed Azure infrastructure for my side-projects — networking, remote state, governance policies, and (planned) database configs, etc. Each concern lives in its own module, provisioned independently via GitHub Actions.

[![Terraform network CI/CD](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/network.yml/badge.svg?branch=main)](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/network.yml)
[![Terraform states CI/CD](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/tfstates.yml/badge.svg?branch=main)](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/tfstates.yml)
[![Terraform Management Group CI/CD](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/management-group.yml/badge.svg?branch=main)](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/management-group.yml)
[![Terraform Policies CI/CD](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/policies.yml/badge.svg?branch=main)](https://github.com/Raffael-Eloi/raffalab-azure-resource-management/actions/workflows/policies.yml)

## Structure

| Path                | Purpose                                          |
| ------------------- | ------------------------------------------------ |
| `network/`          | VNets, subnets, IP ranges                        |
| `tfstate/`          | Remote state backend (storage account, container)|
| `management-group/` | Management group and subscription association    |
| `policies/`         | Baseline governance policy initiative (required tags, allowed locations) assigned to the management group |

## CI/CD

- `network.yml` — plan/apply on changes to `network/`
- `tfstates.yml` — plan/apply on changes to `tfstate/`
- `management-group.yml` — plan/apply on changes to `management-group/`
- `policies.yml` — plan/apply on changes to `policies/`
- `provision-infrastructure.yml` — shared/reusable provisioning workflow

## Local setup

Prerequisites:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `1.15.8` (matches the version pinned in CI)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), authenticated via `az login` (the `azurerm` provider uses your CLI session locally; CI uses OIDC instead)

Steps (per module, e.g. `network/`):

```bash
cd network

# modules with a remote backend (see env/*.tfbackend) need it passed explicitly
terraform init -backend-config="env/azurerm-config-development.tfbackend"

terraform plan -var-file="env/development.tfvars"
terraform apply -var-file="env/development.tfvars"
```

> Some modules (like `tfstate/`, which bootstraps the state backend itself) don't have a `.tfbackend` file — for those, just run `terraform init` without `-backend-config`.
