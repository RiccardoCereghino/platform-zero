# ADR-017: Secret Management with SOPS + age

**Status:** Implemented
**Date:** 2026-03-03
**Author:** Riccardo Cereghino

## Context

A GitOps workflow requires all configuration to live in Git. Kubernetes Secrets contain sensitive credentials (API tokens, database passwords, OAuth client secrets) that cannot be stored in plaintext. A mechanism is needed to encrypt secrets at rest in the repository while allowing ArgoCD to decrypt them at sync time.

## Alternatives Considered

- **External Secrets Operator (ESO) + Vaultwarden** — ESO could bridge to the self-hosted Vaultwarden instance via a headless Bitwarden CLI webhook. Architecturally elegant but requires a running operator pod and creates a runtime dependency on Vaultwarden being available.
- **Bitnami Sealed Secrets** — Encrypts secrets with a cluster-specific certificate. Simple, but the certificate must be backed up carefully, and re-encrypting secrets requires access to the running controller.
- **HashiCorp Vault** — Industry-standard secrets management, but extremely heavy for a homelab cluster. Requires its own HA deployment, storage backend, and operational overhead.

## Decision

Use **Mozilla SOPS with age encryption**, integrated into ArgoCD via the **KSOPS** kustomize exec plugin.

## Rationale

SOPS encrypts the values within YAML files while leaving the keys as structural plaintext, which means `git diff` shows exactly which fields changed without revealing the values. Unlike ESO or Sealed Secrets, SOPS requires zero running controller pods in the cluster — it consumes 0MB of RAM. The age private key is the single decryption mechanism, stored as a Kubernetes Secret (`sops-age-key` in the `argocd` namespace) provisioned via a Talos inline manifest so it's available before ArgoCD starts.

KSOPS v4.3.2 embeds the SOPS Go library directly (no standalone `sops` binary needed) and runs as an init container in the ArgoCD repo-server to copy the `ksops` + `kustomize` binaries.

The master age private key is stored in Vaultwarden as the backup of last resort.

## Consequences

- All secrets in `platform/*-secrets.yaml` are committed to Git encrypted.
- New secrets must follow the naming pattern and be registered in `platform/ksops-generator.yaml`.
- CI linting works without decryption — SOPS-encrypted files are valid YAML.
- Losing the age private key means losing the ability to decrypt all secrets. The Vaultwarden backup is critical.
- SOPS-encrypted files must use the `.sops.yaml` configuration to ensure consistent encryption rules.
