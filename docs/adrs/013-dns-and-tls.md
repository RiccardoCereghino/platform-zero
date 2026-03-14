# ADR-013: Automated DNS and TLS Certificate Management

**Date:** 2026-02-28
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

Every exposed service needs a DNS record pointing to the load balancer and a valid TLS certificate. Managing these manually for each new HTTPRoute is tedious and error-prone.

## Decision

**Domain registrar:** Cloudflare, for `cereghino.me`. Chosen for zero-markup domain pricing and a robust API for Kubernetes integrations. Alternatives were Hetzner, Porkbun, GoDaddy, and Namecheap.

**DNS automation:** ExternalDNS deployed via Helmfile, configured to watch Gateway API HTTPRoute annotations and automatically create/update Cloudflare DNS records using a Cloudflare API token. The alternative was manual record creation in the Cloudflare UI.

**TLS certificates:** cert-manager using Let's Encrypt with the DNS-01 challenge via Cloudflare. This enables wildcard certificates (`*.cereghino.me`) without requiring inbound HTTP access for challenge validation. The alternative was HTTP-01 challenges, which don't support wildcards.

## Rationale

Tools were chosen to enable fully declarative, zero-touch certificate operations avoiding any manual interventions, as justified inline in the decisions above.

## Consequences

- Adding a new service only requires an HTTPRoute with the correct annotation — DNS and TLS are fully automated.
- Both ExternalDNS and cert-manager depend on a Cloudflare API token stored as a SOPS-encrypted secret.
- DNS propagation adds a small delay (1-5 minutes) when exposing a new service.
- The Cloudflare API token is a single point of failure for both DNS and certificate operations.
