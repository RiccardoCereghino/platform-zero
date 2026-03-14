# ADR-003: Infrastructure as Code Tooling

**Status:** Implemented
**Date:** 2026-02-28
**Author:** Riccardo Cereghino

## Context

All cloud infrastructure (VMs, networks, firewalls, load balancers, S3 buckets) needs to be provisioned declaratively and reproducibly.

## Alternatives Considered

- **Terraform** — Industry standard, massive ecosystem, but the BSL license change raised concerns about long-term openness.
- **Raw CLI commands / Hetzner UI** — Fast for one-off tasks, but not reproducible, not versionable, and impossible to review in pull requests.

## Decision

Use **OpenTofu**, the open-source fork of Terraform.

## Rationale

OpenTofu is a drop-in replacement for Terraform with identical HCL syntax, full provider compatibility, and an open-source license (MPL 2.0). All existing Terraform knowledge, providers, and modules work without modification. Choosing OpenTofu signals alignment with the open-source ecosystem without sacrificing any practical capability.

## Consequences

- All existing Terraform documentation and community resources remain applicable.
- The `tofu` CLI replaces `terraform` in all commands and CI pipelines.
- Provider ecosystem is shared — Hetzner, AWS (for S3), Talos, and Cloudflare providers all work identically.
- Some newer Terraform-exclusive features may lag behind in OpenTofu, though this has not been an issue in practice.
