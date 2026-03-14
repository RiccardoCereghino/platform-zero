# ADR-021: Dex Authorization Filtering Strategy

**Date:** 2026-03-03
**Status:** Implemented
**Author(s):** Riccardo Cereghino

## Context

Dex federates authentication through GitHub, but by default any GitHub user can authenticate. Access needs to be restricted to authorized individuals only.

### Alternatives Considered

- **GitHub Organization or Team filtering in Dex** — Dex supports restricting logins to members of specific GitHub Organizations or Teams via the `orgs` field in the GitHub connector config. However, this caused persistent "not in required orgs" errors during testing, likely due to OAuth scope issues or private org membership visibility.

## Decision

Remove the organization restriction from Dex entirely and delegate authorization to **OAuth2-Proxy's `--authenticated-emails-file`**, which maintains an explicit whitelist of allowed personal email addresses.

## Rationale

Separating authentication (Dex verifies "who you are" via GitHub) from authorization (OAuth2-Proxy checks "are you on the list") is a cleaner architectural pattern. The email whitelist is simple, debuggable, and doesn't depend on GitHub organization membership or API scope nuances. When access needs to be granted or revoked, it's a single-line change in a file rather than managing GitHub org invitations.

## Consequences

- Any GitHub user can technically authenticate through Dex, but OAuth2-Proxy will reject them if their email isn't on the whitelist.
- The email whitelist file must be kept in sync — adding a new authorized user requires updating the file and redeploying.
- ArgoCD uses its own RBAC layer (email-based role mappings) for additional authorization beyond the OAuth2-Proxy gate.
- This approach does not scale well to large teams. For a personal/small-team project, it's appropriate.
