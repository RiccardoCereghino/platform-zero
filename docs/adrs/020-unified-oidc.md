# ADR-020: Unified OIDC Architecture with Dex

**Status:** Implemented
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

The cluster has multiple components that need human authentication: ArgoCD (deployment dashboard), Hubble UI (network visibility), Grafana (monitoring), and `kubectl` (terminal access). Without a unified identity layer, each component would need its own authentication mechanism — static passwords, long-lived tokens, or separate OAuth apps — creating a fragmented and insecure access model.

## Alternatives Considered

- **Keycloak** — Full-featured identity and access management platform. Enterprise-grade, but heavy: requires its own PostgreSQL database, consumes significant resources, and is complex to operate for a small cluster.
- **Authentik** — Modern alternative to Keycloak with a cleaner UI. Still relatively heavy and requires its own database and Redis.
- **Authelia** — Lightweight auth proxy with MFA support and centralized policy control. Considered as a future upgrade for finer-grained access policies. Deferred in favor of starting with the simpler Dex approach.
- **Auth0 / SaaS IdPs** — Zero operational overhead, but introduces an external dependency and recurring cost. Conflicts with the self-hosted philosophy of the project.

## Decision

Deploy **Dex** as the central OIDC identity hub, backed by a GitHub OAuth App as the upstream identity provider. Dex serves three consumers:

1. **ArgoCD** — native OIDC integration for SSO to the deployment dashboard.
2. **OAuth2-Proxy** — acts as an Identity-Aware Proxy (IAP) in front of "dumb" UIs (Hubble, Grafana) that have no built-in OIDC support.
3. **Kubernetes API** — the API server's `oidc_issuer_url` is pointed at Dex, enabling `kubectl` access via the `kubelogin` plugin through GitHub SSO.

## Rationale

Dex is a lightweight CNCF Sandbox project designed specifically as an OIDC protocol translator. It doesn't store users or manage sessions — it federates authentication to an upstream provider (GitHub) and issues standardized OIDC tokens that any component can consume. This is exactly the right level of abstraction: one GitHub OAuth App, one Dex instance, and every component in the cluster gets SSO.

The combination of Dex + OAuth2-Proxy implements a Zero Trust Network Access (ZTNA) model: no internal service is accessible without identity verification, even from within the cluster network.

## Consequences

- All human access flows through GitHub authentication via Dex.
- Dex is a single point of failure for authentication — if it goes down, SSO stops working across the entire stack. Static admin credentials remain as emergency fallback.
- GitHub OAuth App client credentials are stored as SOPS-encrypted secrets.
- Adding a new authenticated service requires either native OIDC integration or an OAuth2-Proxy sidecar.
- Authelia remains a future consideration for MFA and more granular policy control (e.g., IP-based restrictions, device trust).
