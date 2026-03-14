# ADR-028: Backstage as Internal Developer Portal

**Date:** 2026-03-06
**Status:** Accepted — not yet operational
**Author(s):** Riccardo Cereghino

## Context

As the platform matures toward supporting application workloads, developers will need a way to discover services, request new deployments, and navigate the platform without deep Kubernetes expertise. The cognitive load of managing infrastructure scaffolding, CI/CD pipelines, security policies, and Kubernetes manifests creates friction and slows down the "time to hello world."

### Alternatives Considered

- **Port** — SaaS, low-code internal developer portal. Lower setup effort but introduces external dependency and recurring cost.
- **Cortex / OpsLevel** — SaaS service catalogs with scoring and maturity tracking. Commercial products, not self-hosted.
- **KubeVela** — Application-centric delivery platform. More focused on deployment abstraction than developer portal UX.
- **Kratix** — Headless, API-first Internal Developer Platform. Powerful but no built-in UI.
- **Cyclops / Otomi** — Kubernetes-specific developer UIs. Narrower scope than a full developer portal.

## Decision

Adopt **Backstage** (CNCF incubating project) as the unified developer portal and service catalog.

## Rationale

Backstage is the de facto industry standard for Internal Developer Portals. Its Software Templates (Scaffolder) capability enables "Golden Paths" — a developer fills out a form in the UI, and Backstage generates the Git repository, CI pipeline, and Kubernetes manifests automatically. Combined with ArgoCD (ADR-015) and Crossplane (ADR-027), this creates a full self-service chain: Backstage scaffolds, ArgoCD deploys, Crossplane provisions infrastructure.

Backstage is a framework rather than a turnkey product — it requires significant customization and plugin development. This is a trade-off: more flexibility but more engineering investment.

## Current State

Backstage is deployed via an ArgoCD Application. The base installation is running but no Software Templates, catalog entities, or plugins are configured. It is not yet serving any developer workflows.

## Consequences (Expected)

- Backstage is a Node.js application with non-trivial resource requirements (memory, CPU).
- Software Templates need to be authored for each "Golden Path" (new service, new environment, etc.).
- The service catalog needs to be populated with existing services and their metadata.
- Backstage requires its own PostgreSQL database for persistence.
- Plugin ecosystem is large but quality varies — each plugin needs evaluation and maintenance.
