# ADR-018: Local Secrets Workflow Migration

**Date:** 2026-03-03
**Status:** Implemented
**Author(s):** [Name]

**Supersedes:** Previous approach using direnv + 1Password CLI

## Context

Running `tofu plan/apply` and `helmfile` commands locally requires environment variables containing sensitive tokens (Hetzner API token, S3 credentials, SOPS age key). The original approach used `direnv` integrated with the 1Password CLI (`op read`) to inject tokens into the shell upon entering the project directory.

### Alternatives Considered

- **direnv + 1Password CLI (`op read`)** — The original approach. Clean UX (tokens appear automatically when you `cd` into the directory), but depends on an active 1Password subscription. When the subscription ended, this approach became unavailable.
- **Bitwarden CLI (`bw get password`) + Vaultwarden** — Since Vaultwarden was deployed in-cluster, the `bw` CLI could pull secrets from it. However, this creates a circular dependency: you need cluster access to get the credentials needed to manage the cluster.
- **Global `~/.zshrc` or plaintext `.env` files** — Quick but insecure. Tokens visible in shell history, process lists, and on disk.

## Decision

Migrate to a **SOPS-encrypted `secrets/local.env.yaml`** file, decrypted and loaded via `source scripts/env.sh` using the existing age key.

## Rationale

This approach reuses the SOPS + age infrastructure already deployed for cluster secrets (ADR-017), requiring no additional tooling or subscriptions. It works even when the Kubernetes cluster is down (unlike the Vaultwarden/Bitwarden CLI approach), and keeps secrets encrypted at rest on disk. The `scripts/env.sh` wrapper decrypts the file and exports the variables into the current shell session.

## Consequences

- Running any infrastructure command requires `source scripts/env.sh` first.
- The age private key must be available locally (exported as `SOPS_AGE_KEY`).
- Secrets are encrypted at rest in the repository — safe to commit.
- No dependency on external services (1Password, Vaultwarden) for local development.
