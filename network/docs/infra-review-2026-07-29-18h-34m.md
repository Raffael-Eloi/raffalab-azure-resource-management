# Infrastructure Review — `network/main.tf`

**Date:** 2026-07-29 18:34
**Scope:** `network/main.tf` (resource group, VNet, subnets, NSGs and NSG rules)

## Summary

NSG hygiene is solid — tier separation, explicit deny rules, consistent tagging. The main gap is architectural: the NSG rule set is shaped for a VM/IaaS public+private pair, while the actual target workload (Azure Container Apps talking to a managed database) is PaaS and doesn't fit that shape yet.

## What's solid

- **Tier separation**: `public_nsg` and `private_nsg` are separate resources, each with its own rule set — not a single shared NSG across both subnets.
- **Deliberate address planning**: `cidrsubnet(var.base_address_space, 2, 0/1)` derives the public/private ranges from one variable instead of hardcoding CIDRs.
- **Explicit deny rules**: mgmt (RDP/SSH), DB, and SMB/WinRM ports are explicitly denied rather than relying solely on Azure's default NSG rules — shows deliberate security modeling, not just default trust.
- **Consistent tagging**: resource group, VNet, and both NSGs all use `local.tags`.
- **Comment discipline**: comments are only used to explain non-obvious abbreviations (`mgmt`, `smb`, `winrm`), not to narrate what the code already says.

## Biggest gap: NSG design assumes VM/IaaS, target workload is PaaS

- `allow_app_and_db_traffic` opens port `8080` from the public subnet into the private subnet. Azure Container Apps environments don't work this way — per Microsoft's Container Apps networking docs, the environment terminates TLS itself and only exposes `80`/`443` externally, and it requires its **own dedicated, delegated subnet** (`Microsoft.App/environments`). It cannot simply live inside `public_subnet` as currently modeled.
- The RDP/SSH/SMB/WinRM deny rules all defend against "a VM in the public subnet gets compromised." If the actual deployment is Container Apps + a managed database with no VMs at all, that threat model doesn't apply — and the pieces that *do* apply (a delegated Container Apps subnet, and a Private Endpoint or delegated subnet for the database) aren't in this file yet.

## Forward-looking risk

- `deny_internet_outbound` (priority 120, `private_nsg`) blocks **all** outbound traffic to `Internet`. That's correct for a private tier in general, but if the database ends up being a VNet-injected Postgres/MySQL Flexible Server (rather than a Private Endpoint), Microsoft's docs require outbound access to the `Storage` service tag for WAL log archival — this rule would break that path. Not a bug today since nothing is deployed against it yet, but worth remembering when the DB networking model is chosen (Private Endpoint sidesteps this, since that traffic never gets the `Internet` tag).

## Minor / cosmetic

- No Bastion subnet or other legitimate management path exists, despite several rules defending against RDP/SSH access. Moot if the environment ends up fully PaaS; relevant again if any VM (jump box, self-hosted agent) is introduced later.
- `cidrsubnet(base, 2, 0)` / `(..., 2, 1)` only consume 2 of the 4 blocks the split produces — fine to hold the rest in reserve, but nothing documents what indices 2–3 are being saved for (e.g. a future Container Apps or Application Gateway subnet).
- Minor formatting drift: `destination_address_prefix` is misaligned in a few rules — `terraform fmt` would clean this up.

## Bottom line

The NSG rules themselves are well-reasoned. The mismatch is architectural: this file models a public/private VM pair, but the workload actually being planned (Container Apps → database) needs a third, delegated subnet for the app tier and either a Private Endpoint or a second delegated subnet for the database — neither exists here yet.
