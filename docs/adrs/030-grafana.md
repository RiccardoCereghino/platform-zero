# ADR-030: Grafana as Observability Frontend

**Status:** Accepted
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

The `kube-prometheus-stack` deploys Prometheus for metrics collection and Alertmanager for alert routing. A visualization frontend is needed to explore metrics, build dashboards, and provide operational visibility into the cluster.

## Alternatives Considered

No full evaluation was conducted. Grafana is the de facto standard for Prometheus visualization and ships as part of the `kube-prometheus-stack` Helm chart. Other observability frontends (Datadog, New Relic, commercial alternatives) were briefly considered but dismissed due to cost — the project has no budget for SaaS observability tooling.

## Decision

Use **Grafana** as included in the kube-prometheus-stack, with dashboard provisioning via ConfigMaps managed through GitOps.

## Rationale

Grafana is the default. It works, it's free, and it integrates with Prometheus out of the box. There is no compelling open-source alternative with equivalent functionality and community support.

That said, the experience is not without friction. Grafana's UI-first approach to dashboard management conflicts with a GitOps philosophy where everything should be declarative and version-controlled. Dashboards created in the UI are ephemeral — they disappear on pod restart unless exported and committed as ConfigMaps. The ConfigMap provisioning approach (sidecar-based auto-discovery) solves this but adds maintenance overhead: every dashboard must be exported as JSON, wrapped in a ConfigMap, and managed in the Git repository.

## Current State

Grafana is running and accessible at `grafana.cereghino.me` behind OAuth2-Proxy (ADR-020). Admin credentials are stored as a SOPS-encrypted secret. Some dashboards have been imported manually via the UI; full ConfigMap-based provisioning is planned but not yet complete (tracked in TODO.md).

## Consequences

- Dashboard provisioning as ConfigMaps is the path to consistency, but requires discipline to export and commit every dashboard change.
- Grafana's plugin ecosystem and alerting features are available but not yet utilized.
- If a better open-source alternative emerges, migration would require re-creating all dashboards — another reason to have them in ConfigMaps rather than only in the UI.
- Grafana admin credentials are a SOPS-encrypted secret; access is gated behind Dex SSO via OAuth2-Proxy.
