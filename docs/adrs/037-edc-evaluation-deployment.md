# ADR-037: Evaluation Deployment of Eclipse Dataspace Connector

**Date:** 2026-03-15
**Status:** Evaluating
**Author(s):** Riccardo Cereghino

## Context

The Eclipse Dataspace Connector (EDC) is the open-source framework powering sovereign data exchange in production dataspaces like Catena-X. Understanding its operational characteristics — resource requirements, deployment complexity, failure modes, and platform dependencies — requires hands-on experience that documentation alone cannot provide.

This ADR proposes deploying a minimal EDC evaluation environment on the cluster to build operational familiarity with the connector stack. The goal is not to run a production dataspace. It is to understand what deploying and operating EDC connectors demands from a platform engineering perspective.

### What EDC Involves

EDC follows a dual-plane architecture:

- **Control Plane** — A Java (Spring Boot) application that handles catalog publishing, contract negotiation via ODRL policies, and transfer process coordination. It exposes a management API for administrative operations and communicates with other connectors via the Dataspace Protocol (DSP). Requires a PostgreSQL database for persisting contract state and catalog entries.
- **Data Plane** — A separate Java application that executes the actual data transfer between organizations. Receives transfer instructions from the control plane and streams data between source and destination endpoints (HTTP, S3, Azure Blob, or custom). Can be scaled independently.

External dependencies for a functional deployment:

- **PostgreSQL** — Contract state, catalog entries, and transfer process records. Losing this database means losing the legal basis for active data sharing agreements.
- **HashiCorp Vault or equivalent** — Stores connector credentials, signing keys, and API tokens. EDC retrieves secrets at runtime from Vault rather than from Kubernetes Secrets directly.
- **Identity infrastructure** — In production Catena-X, connectors authenticate using Verifiable Credentials issued by a Decentralized Identity Module (DIM). For evaluation, a simplified OIDC/OAuth2 setup or the in-memory identity mock is sufficient.

### Tractus-X Helm Charts

The Tractus-X project (Eclipse's Catena-X reference implementation) provides two Helm charts:

- **tractusx-connector** — Production-oriented chart deploying separate control plane and data plane pods with PostgreSQL and Vault dependencies.
- **tractusx-connector-memory** — In-memory variant for testing. No external dependencies, but all state is lost on restart. Suitable for validating connectivity and understanding the API surface without committing to a full deployment.

Helm repository: `https://eclipse-tractusx.github.io/charts/dev`

### The Connector Landscape

EDC is not the only dataspace connector implementation. The IDSA tracks over 20 implementations. The relevant alternatives:

- **FIWARE Data Space Connector** — A fundamentally different architecture. Where EDC is a Java framework with a control plane / data plane split, FIWARE is a Helm umbrella chart composing independent components: NGSI-LD (ETSI standard) as the data exchange API, Open Policy Agent for authorization (ABAC model), and native Gaia-X Trust Framework integration. More opinionated and batteries-included than EDC, but less extensible. Deployed on Kubernetes via Helm.
- **sovity Community Edition** — EDC underneath, with a usability layer on top: a management UI, simplified configuration, and a managed Connector-as-a-Service (CaaS) offering. sovity is a Cofinity-X certified partner. Represents the "managed EDC" approach — relevant because production dataspace operators often provide this abstraction to participants who lack platform engineering capacity.
- **TRUE Connector (Engineering) / Trusted Connector (Fraunhofer AISEC)** — Earlier IDS implementations predating the Dataspace Protocol (DSP) standardization. Less relevant now that DSP 1.0.0 was finalized in July 2025, but still present in legacy deployments.
- **TNO Security Gateway** — Dutch government-backed, microservices architecture. Focused on cross-sector interoperability for public sector dataspaces.

EDC was chosen for this evaluation because it is the framework underlying Tractus-X (the Catena-X reference implementation), has the largest community, and is the connector the target production environment uses. The alternatives are noted here because understanding the landscape — particularly the distinction between EDC-as-framework, sovity-as-managed-service, and FIWARE-as-alternative-architecture — is necessary for making informed platform decisions.

### Deployment Alternatives Considered

- **Read documentation only** — No deployment. Lower risk, but documentation describes the intended architecture, not the operational reality. Missing: actual resource consumption, startup behavior, failure modes under constrained resources, interaction with existing platform components (Cilium, cert-manager, ArgoCD).
- **Local development (Docker Compose)** — Run EDC on a laptop outside the cluster. Faster to start, but doesn't exercise the Kubernetes deployment model, network policies, or GitOps workflow. Misses the platform engineering perspective entirely.
- **Full production deployment with Vault and CNPG** — Deploy the production tractusx-connector chart with a dedicated CloudNativePG cluster and HashiCorp Vault. Most realistic, but introduces significant resource overhead and operational complexity for an evaluation. Vault alone is a substantial platform component.

## Decision

Deploy the **tractusx-connector-memory** chart for initial evaluation, managed as an ArgoCD Application in a dedicated `edc-evaluation` namespace.

If the in-memory deployment validates basic connectivity and API behavior, a follow-up phase will deploy the production tractusx-connector chart using the existing CloudNativePG operator (ADR-025) for PostgreSQL and Kubernetes Secrets (via SOPS+age) for credential storage — deferring Vault to a future decision.

## Implementation Plan

### Phase 1: In-memory evaluation

1. Add the Tractus-X Helm repository to the platform.
2. Create the `edc-evaluation` namespace.
3. Deploy `tractusx-connector-memory` via an ArgoCD Application with minimal values.
4. Validate: management API responds, catalog is queryable, a self-negotiated contract completes.
5. Document: actual resource consumption (CPU/memory), startup time, log verbosity, any conflicts with existing Cilium network policy or Pod Security Admission.

### Phase 2: Persistent deployment (conditional)

1. Provision a CNPG PostgreSQL cluster in the `edc-evaluation` namespace (same pattern as Vaultwarden — ADR-025).
2. Switch to the `tractusx-connector` chart with PostgreSQL backend.
3. Configure SOPS-encrypted secrets for connector credentials (same KSOPS workflow as all other secrets — ADR-017).
4. Deploy a second connector instance to test connector-to-connector contract negotiation and data transfer.
5. Document: database schema management, migration scripts, inter-connector DSP communication, certificate requirements.

### Phase 3: Platform integration assessment

1. Evaluate how EDC interacts with existing platform components:
   - **cert-manager** — Can it manage connector TLS certificates?
   - **Dex** — Can it serve as the OIDC provider for the management API?
   - **CiliumNetworkPolicy** — What network policies does an EDC deployment require?
   - **ArgoCD** — Does the connector chart reconcile cleanly with self-heal and auto-prune?
   - **Prometheus** — Does EDC expose metrics? What ServiceMonitor configuration is needed?
2. Document findings as operational notes, feeding back into the reference mapping in `docs/reference/`.

## Rationale

The in-memory chart eliminates external dependencies for the first evaluation pass, keeping the blast radius small. If it works, the path to a persistent deployment reuses existing platform patterns (CNPG, SOPS, ArgoCD) rather than introducing new components. If it reveals that EDC demands infrastructure the platform does not yet provide (e.g., Vault for secret management, a DID resolver for identity), those become their own ADRs with clear justification.

Deploying on the actual cluster rather than locally ensures the evaluation exercises real platform constraints: resource limits, network encryption, pod security, GitOps reconciliation.

## Consequences

- **Positive:** Builds hands-on operational understanding of EDC deployment requirements, failure modes, and resource characteristics that documentation cannot provide.
- **Positive:** Identifies gaps in the current platform (missing components, insufficient policies, resource constraints) before they become surprises in a production context.
- **Positive:** The evaluation namespace is isolated and can be torn down without affecting any production workload.
- **Negative:** EDC's Java runtime has a significant memory footprint. Even the in-memory variant will likely require 1-2 GB per pod (control plane + data plane). On a resource-constrained homelab cluster, this may require temporarily scaling down other non-essential workloads.
- **Negative:** The in-memory variant is not representative of production behavior for stateful operations (contract persistence, transfer recovery after restart). Phase 2 is needed to evaluate those.
- **Neutral:** This evaluation may reveal that certain platform components (Vault, a DID resolver) are prerequisites for meaningful EDC operation, generating follow-up ADRs.
