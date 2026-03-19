# ADR-038: Self-Hosted GitHub Actions Runners via Actions Runner Controller

**Date:** 2026-03-19
**Status:** Accepted
**Supersedes:** ADR-029
**Author(s):** Riccardo Cereghino

## Context

Side projects under the `cerre-lab` GitHub Organization have CI workloads that exceed what GitHub-hosted runners provide efficiently. Specifically, Tauri application release builds run for tens of minutes, consuming significant free-tier minutes and creating risk of exhausting the monthly allowance across multiple repositories. ADR-029 previously rejected self-hosted runners because the CI workload at the time (linting, validation, `tofu plan`) was lightweight and fit comfortably within the free tier. That assessment no longer holds.

### Alternatives Considered

- **GitHub-hosted runners (status quo)** — Zero operational overhead, but heavy build workloads across multiple repositories risk hitting free-tier limits. Larger hosted runners are available at per-minute cost, but recurring SaaS spend conflicts with the project's self-hosted philosophy.
- **Standalone self-hosted runner on a dedicated VM** — A Hetzner VM running the GitHub Actions runner agent directly. Simple to set up, but requires separate infrastructure management outside the cluster, doesn't scale to zero, and wastes resources when idle.
- **Buildkite / Woodpecker / Drone** — Alternative CI systems with self-hosted runners. Would require migrating workflow definitions away from GitHub Actions, fragmenting the CI/CD tooling across platforms.

## Decision

Deploy **Actions Runner Controller (ARC)** on the Platform Zero cluster using the `gha-runner-scale-set-controller` and `gha-runner-scale-set` Helm charts. Runners are registered at the `cerre-lab` GitHub Organization level, making them available to all repositories under the organization. Authentication uses a GitHub App with scoped permissions.

## Rationale

ARC is the official Kubernetes-native solution for self-hosted GitHub Actions runners, maintained by GitHub. It uses runner scale sets that create ephemeral runner pods on demand and scale to zero when idle — no wasted resources during quiet periods. Deploying at the org level means any repository under `cerre-lab` can target self-hosted runners without per-repo ARC configuration changes.

Running ARC on the existing cluster reuses compute capacity that is already being paid for, rather than provisioning additional infrastructure. If build workloads outgrow the current node capacity, the cluster can be scaled up — which is a simpler operational response than managing separate build infrastructure.

Platform-specific builds (macOS, Windows) remain on GitHub-hosted runners, as these require platform-native toolchains and hardware that cannot run in Linux containers. ARC handles Linux and web builds only.

## Consequences

- Any repository under `cerre-lab` can use `runs-on: self-hosted` (or a custom label) for Linux-based CI jobs.
- Runner pods are ephemeral — each job gets a clean environment with no state leakage between builds.
- Scale-to-zero means no resource consumption when no builds are running.
- A GitHub App must be created under `cerre-lab` with the required permissions (Organization Self-hosted runners: Read & Write). The App private key is stored as a SOPS-encrypted secret.
- ARC controller pods add a small baseline resource footprint to the cluster even when no builds are running.
- Heavy concurrent builds may compete with platform workloads for cluster resources. Resource requests and limits on runner pods mitigate this.
- macOS and Windows builds continue to use GitHub-hosted runners — this is a hybrid model, not a full migration.
- Custom runner images (e.g., with project-specific build toolchains) are the responsibility of the consuming project, not the platform. The platform provides the runner infrastructure; projects define what runs on it.
- `platform-zero` remains on the personal GitHub account and continues using GitHub-hosted runners until migrated to `cerre-lab`.
