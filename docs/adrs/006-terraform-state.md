# ADR-006: Terraform State Storage

**Date:** 2026-03-01
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

OpenTofu state contains the full mapping between declared infrastructure and actual cloud resources. Losing it means losing the ability to manage infrastructure declaratively. Storing it on local disk is a disaster recovery risk.

### Alternatives Considered

- **Local disk** — Simple, but a single disk failure or laptop loss means the state is gone. Rebuilding requires importing every resource manually.

## Decision

Store state remotely in a **Hetzner Object Storage (S3-compatible) bucket** named `cereghino-tf-state`, created manually before the first `tofu init`.

## Rationale

Remote state provides durability, team access (if needed in the future), and state locking. Hetzner's S3-compatible storage keeps costs near zero and avoids introducing a dependency on AWS. The bucket was created manually (not via IaC) because it's a bootstrapping dependency — you can't use Terraform to create the bucket that Terraform needs to store its state.

Object Lock was evaluated for ransomware protection but disabled to avoid write friction during rapid iteration. Standard bucket versioning provides a safety net for accidental state corruption.

## Consequences

- `tofu init` requires backend configuration with Hetzner's endpoint format.
- CI/CD workflows need S3 credentials (AWS_ACCESS_KEY_ID/SECRET_ACCESS_KEY) configured as secrets.
- The state bucket itself is outside of IaC management — changes to it require manual intervention.
