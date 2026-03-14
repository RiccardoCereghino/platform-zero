# ADR-025: Self-Hosted Password Manager with Vaultwarden

**Date:** 2026-03-01
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

The project needed a self-hosted password manager to replace a 1Password subscription. This serves dual purposes: managing daily-use passwords and storing infrastructure secrets (including the SOPS age private key that unlocks all cluster secrets).

### Alternatives Considered

- **Infisical** — Focused on infrastructure secrets management, not general password management. Doesn't cover the daily-use case.
- **Bitwarden Secrets Manager** — SaaS offering, which contradicts the self-hosted goal.

## Decision

Deploy **Vaultwarden**, a lightweight Rust reimplementation of the Bitwarden server API, backed by **PostgreSQL managed by the CloudNativePG (CNPG) operator**.

## Rationale

This was the most contentious sub-decision. The safe recommendation was to use Vaultwarden's default **SQLite** database — simpler to deploy, no additional operator needed, and sufficient for a single-user instance. This was explicitly suggested as the prudent path for a weekend showcase.

That recommendation was rejected in favor of deploying a full **PostgreSQL cluster via CloudNativePG**. The rationale: SQLite is a single-file database with no replication, no connection pooling, and limited concurrent write performance. CNPG provides a production-grade PostgreSQL deployment with automated failover, continuous archiving, and proper backup integration — aligning with the project's goal of demonstrating production practices rather than taking shortcuts.

The decision paid off: the CNPG operator was successfully deployed and PostgreSQL has been running without issues.

## Consequences

- Vaultwarden is the critical backup for the SOPS age private key. If both Vaultwarden and the local copy are lost, all encrypted secrets become unrecoverable.
- CNPG adds an operator pod and PostgreSQL pods to the cluster resource footprint.
- The Vaultwarden admin token is stored as a SOPS-encrypted secret.
- Vaultwarden is exposed via the Cilium Gateway with Coraza WAF protection (though WAF is now deprecated per ADR-022).
