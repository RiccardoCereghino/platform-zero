# ADR-022: Web Application Firewall with Coraza

**Status:** Deprecated — Cloudflare managed firewall recommended for future projects
**Date:** 2026-03-01
**Author:** Riccardo Cereghino

## Context

Exposed endpoints (Vaultwarden, Grafana) are accessible from the public internet and need protection against Layer 7 attacks: SQL injection, XSS, path traversal, and other OWASP Top 10 threats. A Web Application Firewall was needed to inspect and filter HTTP traffic before it reaches the application.

## Alternatives Considered

- **Cloudflare Proxy (orange cloud)** — Cloudflare's managed WAF sits in front of the origin server, providing DDoS protection, bot management, and OWASP rules out of the box. However, enabling the proxy means all traffic flows through Cloudflare's infrastructure, breaking the zero-trust sovereignty model where the cluster controls its own security boundary. Evaluated as a philosophical concern at the time.
- **ModSecurity** — The original open-source WAF, mature and well-documented, but tied to Apache/Nginx and showing its age.
- **BunkerWeb** — All-in-one WAF + reverse proxy. Interesting but less community adoption and harder to integrate with Gateway API.

## Decision

Deployed **Coraza WAF** using the `ghcr.io/coreruleset/coraza-crs:caddy-alpine` image (the official OWASP Core Rule Set image), integrated via a custom "WAF Proxy" pattern.

### Implementation Details

**Why not native Envoy Wasm injection:** Cilium's Gateway API manages Envoy proxies internally. Attempting to inject Coraza as a Wasm filter directly into Envoy failed because the Cilium Operator aggressively reconciles and overwrites Envoy configuration, removing custom filters.

**The WAF Proxy pattern:** Instead of modifying Envoy, a standalone Coraza-Caddy proxy pod was deployed in the `security` namespace, sitting between the Gateway (Envoy) and the backend services. The Gateway routes traffic to the WAF proxy, which inspects it and forwards clean requests to the actual application.

**The image problem:** The initial image choice (`corazawaf/coraza-caddy:latest`) caused `ErrImagePull` (403) errors. The correct image is the community-maintained `ghcr.io/coreruleset/coraza-crs:caddy-alpine`.

**Cross-namespace routing:** The Gateway lives in the `default` namespace while the WAF proxy runs in `security`. This required a Gateway API `ReferenceGrant` resource to explicitly permit cross-namespace traffic routing.

**Custom Helm chart:** Since no off-the-shelf Helm chart existed for this deployment pattern, a hand-authored chart was created at `platform/waf-chart/`.

## Verdict

**Managing your own WAF is operationally too heavy if there's no compelling reason to avoid a managed alternative.**

The Coraza deployment works, but the ongoing burden is significant:

- **Rule tuning:** The OWASP Core Rule Set generates false positives that block legitimate traffic (e.g., Vaultwarden syncs, Grafana API queries). Each false positive requires identifying the specific rule ID and adding an exclusion, which is time-consuming and error-prone.
- **Custom chart maintenance:** The hand-authored Helm chart needs to be maintained alongside every other platform component.
- **Debugging complexity:** When a request fails, the investigation path now includes "is the WAF blocking it?" as a step, adding cognitive overhead to every troubleshooting session.
- **No upstream support:** Unlike ModSecurity with Nginx or managed WAF services, the Coraza-Caddy-Gateway API integration pattern has minimal community documentation.

The original concern about Cloudflare Proxy breaking "zero-trust sovereignty" was valid in theory but outweighed in practice by the operational cost of self-managing a WAF. Cloudflare's managed firewall provides better rules, automatic updates, DDoS protection, and bot management with zero operational overhead.

## Consequences

- The Coraza WAF deployment remains functional in the cluster but is considered deprecated.
- For future projects or a rearchitecture, the recommendation is to enable Cloudflare Proxy and use Cloudflare's managed WAF rules instead.
- The custom `platform/waf-chart/` Helm chart will not receive further investment.
- WAF rule exclusions are undocumented (noted as technical debt in TODO.md).
