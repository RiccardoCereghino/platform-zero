# ADR-027: Crossplane as Infrastructure Control Plane

**Status:** Accepted — not yet operational
**Date:** 2026-03-06
**Author:** Riccardo Cereghino

## Context

Provisioning external cloud infrastructure (load balancers, S3 buckets, managed databases) currently requires writing OpenTofu HCL and running it through the CI/CD pipeline. For a platform engineering vision where developers self-serve, this creates a bottleneck: developers must learn HCL, submit infrastructure PRs, and wait for the pipeline to run. There is also no continuous drift detection on infrastructure managed by OpenTofu — if a resource is modified manually, the drift persists until the next `tofu plan`.

## Alternatives Considered

- **OpenTofu/Terraform via CI/CD (Atlantis-style)** — The current approach. Works well for operator-managed infrastructure but doesn't enable developer self-service through Kubernetes-native APIs.

## Decision

Adopt **Crossplane** as the infrastructure control plane, deployed via ArgoCD with providers for Kubernetes, Helm, AWS, and Hetzner Cloud.

## Rationale

Crossplane turns the Kubernetes API into a universal infrastructure API. Developers can request cloud resources using standard Kubernetes YAML (e.g., a `Bucket` custom resource), and Crossplane continuously reconciles the desired state against the actual cloud state — providing the same drift detection for infrastructure that ArgoCD provides for applications. Its Compositions feature enables abstracting complex infrastructure dependencies into simplified, opinionated APIs.

## Current State

The base Crossplane install is deployed via an ArgoCD Application with an empty `valuesObject`. No providers are actively configured, no Compositions are written, and no infrastructure is managed through Crossplane yet. This is a strategic investment — the platform is ready to onboard Crossplane-managed resources when the need arises.

## Consequences (Expected)

- Developers will be able to provision cloud resources via `kubectl apply` without learning HCL.
- Crossplane adds CRDs and controller pods to the cluster, increasing resource consumption.
- The relationship between OpenTofu-managed and Crossplane-managed infrastructure needs clear boundaries to avoid conflicts (e.g., both trying to manage the same S3 bucket).
- Provider credentials (Hetzner API token, AWS keys) need to be available to Crossplane controllers as in-cluster secrets.
