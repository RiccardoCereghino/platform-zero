# ADR-023: Pod Security and Policy Enforcement

**Date:** 2026-03-03
**Status:** Proposed
**Author(s):** Riccardo Cereghino

## Context

The cluster needs a mechanism to enforce security standards on workloads: preventing containers from running as root, requiring resource limits, mandating specific labels, and verifying image signatures. Without automated enforcement, security depends entirely on manual code review during pull requests.

## Current State

The cluster currently uses **Kubernetes Pod Security Admission (PSA)** labels, inherited from the upstream module. These are applied as namespace labels:

- `monitoring` and `velero` namespaces have `pod-security.kubernetes.io/enforce: privileged` (required because node-exporter and velero node-agent need host access).
- No other namespaces have explicit PSA labels, defaulting to no enforcement.

PSA provides basic namespace-level isolation (privileged, baseline, restricted) but has significant limitations: it cannot mutate resources, cannot enforce custom policies (like label requirements), and cannot verify image signatures.

### Alternatives Evaluated

- **Native PSA (current)** — Zero overhead, built into Kubernetes, but limited to three fixed profiles with no customization or mutation capability.
- **OPA / Gatekeeper** — Powerful policy engine using Rego language. Steep learning curve due to Rego's custom syntax. Strong community adoption.
- **Kyverno** — Policy-as-Code engine using native Kubernetes YAML resources instead of a custom language. Supports validation, mutation (e.g., auto-injecting sidecars), and image signature verification via Cosign/Sigstore.

## Decision

Adopt **Kyverno** as the automated policy enforcement engine, keeping PSA labels as a baseline safety net underneath.

## Rationale

Kyverno's use of native Kubernetes YAML for policy definitions means no new language to learn — the same syntax used for every other resource in the cluster works for policies. Its mutation capability is particularly valuable: automatically injecting labels, setting resource defaults, or adding security contexts without requiring developers to remember every policy. Image signature verification via Cosign/Sigstore adds supply chain security.

## Open Questions (Resolved)

- **What is the minimum set of policies needed before enabling enforcement?** Start with: (1) disallow privileged containers outside exempted namespaces, (2) require resource requests/limits on all pods, (3) require standard labels (`app.kubernetes.io/name`, `app.kubernetes.io/component`). These three cover the highest-risk gaps without blocking current workloads. Expand after a 14-day audit-mode soak.
- **Should policies run in `audit` mode first?** Yes. All policies will be deployed in `audit` mode for a minimum of 14 days. Kyverno generates PolicyReport resources that surface violations without blocking — these will be scraped by Prometheus and visualized in Grafana before enforcement is enabled.
- **How does Kyverno interact with ArgoCD's sync process?** Kyverno admission webhooks reject non-compliant resources at the API server level. This means an ArgoCD sync will fail if it tries to create a resource that violates an enforced policy. This is the desired behavior — it prevents policy drift. The mitigation is the audit-mode soak: by the time policies are enforced, all existing manifests will already be compliant.

## Consequences

- Insecure deployments would be automatically rejected before running.
- Existing workloads need to be audited for compliance before enforcement is enabled.
- Kyverno controller pods add resource overhead to the cluster.
- Policy definitions become another set of manifests to maintain in the GitOps repository.
- In regulated environments (e.g., sovereign data exchange platforms), policy enforcement is a compliance requirement — having Kyverno operational and auditable via Git positions the platform for workloads where admission control is not optional.
