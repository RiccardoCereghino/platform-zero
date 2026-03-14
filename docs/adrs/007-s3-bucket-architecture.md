# ADR-007: S3 Bucket Architecture and Multi-Region DR

**Status:** Implemented
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

The cluster produces two categories of critical data that need durable storage: OpenTofu state and backup artifacts (etcd snapshots, Velero backups). A decision was needed on whether to consolidate into one bucket or separate them, and how to handle regional fault tolerance.

## Alternatives Considered

- **Single bucket for everything** — Simpler management, but a single regional failure could take out both state and backups simultaneously.
- **Manual bucket creation via Hetzner UI** — Quick but not reproducible.

## Decision

Separate buckets in **different Hetzner regions**: `cereghino-tf-state` (hel1) for OpenTofu state, and `cereghino-infra-backups` (nbg1) for etcd snapshots and Velero data. The backup bucket is managed declaratively via IaC using the HashiCorp AWS provider aliased to Hetzner's S3 endpoints.

## Rationale

If a catastrophic failure hits one Hetzner region, the other region's bucket remains accessible. This means either the state or the backups survive, enabling recovery. The backup bucket is provisioned via IaC (unlike the state bucket, which is a bootstrap dependency) to keep it consistent with the project's declarative approach.

## Consequences

- Two sets of S3 credentials may be needed if buckets use different access policies.
- Velero and talos-backup must be configured with the correct regional endpoint for the backup bucket.
- The state bucket remains manually managed — it cannot be imported into the IaC it stores state for without circular dependency.
