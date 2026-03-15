# ADR-036: Observability Frontend — Evaluating Perses as Grafana Replacement

**Date:** 2026-03-15
**Status:** Evaluating
**Author(s):** Riccardo Cereghino

## Context

The cluster uses Grafana as the observability frontend, deployed as part of kube-prometheus-stack (ADR-030). While Grafana is functional, several concerns have emerged during operation:

1. **Scope creep** — Grafana has evolved from a dashboard tool into a full observability platform (alerting, log aggregation, tracing, incident management, SLOs). For a platform where monitoring should be a standard, solved problem, this adds unnecessary complexity. The cluster needs metric visualization and ad-hoc PromQL queries — not an observability product suite.

2. **Commercial pressure** — Grafana Labs actively steers the open-source ecosystem toward their proprietary stack (Loki, Tempo, Mimir, Grafana Cloud). Adopting Grafana as the frontend creates gravitational pull toward these products for log aggregation, tracing, and long-term storage — decisions that should be evaluated independently, not as a consequence of dashboard tooling.

3. **Dashboard management** — Grafana stores dashboards in a database by default. Exporting them as JSON and managing them via ConfigMaps or Helm values is possible but awkward. Dashboards drift from their Git-stored definitions when edited through the UI, and reconciling that drift requires discipline that tooling should enforce, not rely on.

4. **CNCF alignment** — Grafana is not a CNCF project. It is a Grafana Labs product under AGPLv3 (changed from Apache 2.0 in 2021 for the enterprise features). Prometheus and Alertmanager are both CNCF graduated projects. The visualization layer is the gap.

### Alternatives Evaluated

- **Grafana (current)** — Mature, massive ecosystem, extensive panel types. But over-scoped for this use case, commercially pressured, not CNCF, and stores dashboards in a database rather than as code.
- **Prometheus UI only** — Built into Prometheus, zero additional components. Supports ad-hoc PromQL queries and basic graphing. No persistent dashboards, no layout, no saved views. Functional for debugging but not for ongoing operational visibility.
- **Perses** — CNCF sandbox project (accepted 2024). Purpose-built as a Prometheus-native dashboard tool with dashboards-as-code as a core design principle. Apache 2.0 licensed.

## Decision (Preliminary)

Evaluate **Perses** as a replacement for Grafana, with a phased migration contingent on functional validation.

## Perses Assessment

### Strengths

**Dashboards as code** — Perses dashboards are defined in YAML or JSON and can be provisioned via Kubernetes CRDs (Perses Operator) or ConfigMaps. This means dashboards are version-controlled in Git, deployed by ArgoCD, and cannot drift from their declared state. This is how dashboards should work in a GitOps-managed platform.

**Focused scope** — Perses does one thing: visualize Prometheus metrics. It does not include alerting (Alertmanager handles that — ADR-035), log aggregation, tracing, or incident management. Each concern is handled by the right tool rather than bundled into a monolith.

**CNCF sandbox** — Aligns with the platform's preference for CNCF-backed projects (Cilium, Prometheus, cert-manager). Apache 2.0 license with no commercial entity steering the roadmap toward a proprietary product suite.

**Kubernetes-native deployment** — Perses Operator provides CRDs for Perses instances, dashboards, and datasources. Fits naturally into the ArgoCD Application model.

**Native PromQL** — First-class Prometheus integration. PromQL builder, metrics explorer, and a built-in PromQL debugger.

### Limitations

**Pre-1.0 maturity** — Perses is versioned at 0.x. API surface may change. Documentation is limited compared to Grafana. This is sandbox-level software.

**Panel types** — Covers the core set: time-series charts, gauges, stat panels, heatmaps, markdown. Missing specialized panels (pie charts, advanced scatter plots, conditional rendering). Sufficient for infrastructure monitoring, but not for executive dashboards or customer-facing analytics.

**No authentication** — RBAC and user management are on the roadmap but not implemented. Acceptable for a single-operator cluster behind OAuth2 Proxy (ADR-021), but would be a blocker for multi-team environments.

**Smaller community** — ~1.9K GitHub stars, emerging plugin ecosystem. Community mixins for standard dashboards exist but are not as comprehensive as Grafana's library.

**No auto-discovery** — Prometheus datasource auto-discovery in Kubernetes is planned but not yet implemented. Datasources must be explicitly configured.

## Migration Strategy (If Validated)

### Phase 1: Parallel deployment

Deploy Perses alongside Grafana. Recreate the 3-5 most-used dashboards (node health, pod resource usage, ArgoCD sync status) in Perses using CRDs. Compare usability and identify any gaps in panel types or query support.

### Phase 2: Primary switch

If Phase 1 validates the core workflow, make Perses the primary observability frontend. Update the Grafana HTTPRoute (ADR-011) to point at Perses. Keep Grafana deployed but stop maintaining its dashboards.

### Phase 3: Grafana removal

Remove Grafana from kube-prometheus-stack values and delete the Grafana HTTPRoute, secrets, and ReferenceGrant. The monitoring namespace simplifies to Prometheus + Alertmanager + Perses.

## Rationale

The argument for Perses is not that Grafana is bad — it is that Grafana is more than this platform needs, and the excess creates operational and philosophical friction. Perses aligns with the same principles that drove other decisions in this repository: choose the tool that solves the specific problem (Cilium for CNI, not Calico+Flannel; Dex for OIDC, not Keycloak; SOPS+age for secrets, not Vault). A dashboard tool should provide dashboards, not an observability platform.

The pre-1.0 maturity is a real risk, which is why this ADR is in Evaluating status with a phased migration. If Perses cannot replicate the essential dashboards during Phase 1, the migration stops and this ADR is updated accordingly.

## Consequences (Expected)

- **Positive:** Dashboards become fully GitOps-managed Kubernetes resources — no more database-backed state or UI drift.
- **Positive:** Removes the implicit pull toward Grafana Labs' commercial stack for future observability decisions.
- **Positive:** Reduces the resource footprint of the monitoring namespace (Perses is a single lightweight Go binary vs. Grafana's server + database).
- **Negative:** Fewer available panel types and pre-built community dashboards. Some kube-prometheus-stack default dashboards will need to be rebuilt manually.
- **Negative:** Pre-1.0 software carries risk of breaking changes between releases.
- **Negative:** The Perses Operator and CRDs add another set of custom resources to manage, partially offsetting the complexity reduction from removing Grafana.
- **Neutral:** Alerting is unaffected — Alertmanager (ADR-035) handles all notification logic regardless of which frontend is used for visualization.
