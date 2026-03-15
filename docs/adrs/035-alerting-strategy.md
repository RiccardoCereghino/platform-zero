# ADR-035: Alerting Strategy with Alertmanager and ntfy

**Date:** 2026-03-15
**Status:** Proposed
**Author(s):** Riccardo Cereghino

## Context

The cluster runs kube-prometheus-stack (ADR-030) which includes Alertmanager, but no receivers, routes, or custom alert rules are configured. Prometheus collects metrics, Grafana visualizes them, but nothing notifies the operator when something breaks. The cluster is effectively unmonitored outside of manual dashboard checks.

As a single-operator platform, the alerting strategy must be:

- **Low-overhead** — no team chat infrastructure (Slack, Discord) to maintain.
- **Immediate** — push notifications to a mobile device, not email that sits unread.
- **Tiered** — not every alert is worth waking up for. Certificate expiring in 7 days is informational. Node down is critical.
- **Self-contained** — the notification path should not depend on external SaaS services that introduce vendor lock-in or usage limits.

### Alternatives Considered

- **Email (Gmail SMTP)** — Free, native Alertmanager support. But email notifications are easy to miss, may land in spam, and Gmail requires an app-specific password for SMTP auth. Not suitable as the primary channel for critical alerts.
- **Pushover** — $5 one-time purchase, excellent priority system (can bypass Do Not Disturb). But it is proprietary and closed-source, which conflicts with the platform's open-source-first philosophy (ADR-032).
- **Telegram Bot** — Free, real push notifications via bot API. But depends entirely on Telegram's infrastructure — a third-party SaaS dependency for a critical operational function.
- **PagerDuty/Opsgenie Free Tier** — Enterprise-grade incident management. Massive overkill for a single operator. Introduces SaaS dependency and complex configuration for no benefit at this scale.

## Decision

Use **ntfy** as the primary alert notification channel, integrated with Alertmanager via webhook receiver.

### Why ntfy

ntfy is a free, open-source (Apache 2.0) HTTP-based pub-sub notification service. It works by publishing messages to a topic via a simple HTTP POST — Alertmanager's generic webhook receiver can do this natively. The ntfy mobile app (Android/iOS) receives real push notifications.

For initial deployment, use the **public ntfy.sh instance** to avoid the operational overhead of self-hosting. The topic name acts as a lightweight access control — use a randomly generated topic name (not a guessable word) to prevent unauthorized access. Self-hosting ntfy on the cluster is a future option if the public instance becomes insufficient.

### Alert Tiers

Alerts are classified into three severity tiers with distinct notification behaviors:

**Critical** — Requires immediate attention. Service is down or data is at risk.

- Node NotReady for >5 minutes
- etcd cluster health degraded
- Velero backup job failed
- CNPG PostgreSQL primary down or replication lag >60s
- ArgoCD unable to sync for >15 minutes
- Persistent volume usage >90%

**Warning** — Requires attention within hours. Service is degraded but functional.

- Pod in CrashLoopBackOff for >10 minutes
- Certificate expiring within 7 days (cert-manager)
- Pod OOMKilled
- Prometheus scrape target down
- Node disk pressure or memory pressure
- Alertmanager itself unable to send notifications

**Informational** — Logged in Grafana, no push notification. Review during regular checks.

- Pod restart count >5 in 1 hour
- ArgoCD sync succeeded after previous failure (recovery notification)
- Certificate renewed successfully

### Alertmanager Configuration Structure

```
receivers:
  - name: ntfy-critical
    webhook_configs:
      - url: https://ntfy.sh/<random-topic>
        send_resolved: true
        http_config:
          headers:
            Priority: urgent
            Tags: rotating_light

  - name: ntfy-warning
    webhook_configs:
      - url: https://ntfy.sh/<random-topic>
        send_resolved: true
        http_config:
          headers:
            Priority: high
            Tags: warning

  - name: 'null'  # informational — no notification

route:
  receiver: ntfy-warning  # default
  group_by: [alertname, namespace]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: ntfy-critical
      repeat_interval: 1h
    - match:
        severity: info
      receiver: 'null'
```

### Alert Rule Sources

kube-prometheus-stack ships with a comprehensive set of default PrometheusRule resources covering Kubernetes components, node health, and Prometheus internals. These are enabled by default and cover the majority of the critical and warning alerts listed above.

Custom PrometheusRule resources will be added for platform-specific alerts not covered by defaults:

- Velero backup job failures
- CNPG replication lag and primary health
- cert-manager certificate expiration
- ArgoCD sync failures

These custom rules will be stored as platform manifests managed by ArgoCD.

## Rationale

ntfy provides the simplest possible notification path: Alertmanager makes an HTTP POST, ntfy delivers a push notification. No authentication tokens, no API keys (for the public instance), no OAuth flows, no webhook signing secrets. The ntfy topic URL is the only configuration needed in Alertmanager.

The three-tier severity model prevents alert fatigue — the biggest risk for a single operator. If everything is critical, nothing is. Informational events are logged but silent. Warnings notify during waking hours. Critical alerts are persistent and urgent.

Using the public ntfy.sh instance initially avoids adding another service to maintain. The migration path to self-hosting is straightforward: deploy ntfy as a container, change the URL in Alertmanager config, no other changes needed.

## Consequences

- **Positive:** The operator receives immediate push notifications for service-impacting events without maintaining chat infrastructure.
- **Positive:** Alert tiers reduce noise — only actionable events trigger notifications.
- **Positive:** ntfy's simplicity means the notification path itself has very few failure modes.
- **Negative:** The public ntfy.sh instance means alert content is transmitted through a third-party server. Alert messages may contain namespace names and pod names — low sensitivity, but not zero. Self-hosting eliminates this.
- **Negative:** The randomly generated topic name is the only access control on the public instance. Anyone who discovers the topic name can read alerts or send fake ones. Acceptable for a homelab; would require self-hosting with authentication for production.
- **Neutral:** kube-prometheus-stack default alert rules provide broad coverage out of the box, but some will need tuning (thresholds, silences) to match this cluster's normal behavior and avoid false positives during the first week.
