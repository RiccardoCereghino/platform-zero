# Post-Mortem: 001 - Firewall IP Lockout

**Date of Incident:** 2026-03-14
**Status:** Published
**Author(s):** Riccardo Cereghino

## 1. Summary
Lost all access to the Kubernetes and Talos APIs because the Hetzner Cloud firewall only allowed inbound traffic from an IP address that was no longer current.

## 2. Impact
* **Duration:** ~1 day (noticed when kubectl commands started timing out)
* **Severity:** Full cluster access loss (kubectl, talosctl)
* **User/System Impact:** Dial tcp timeout for API connections.

## 3. Detection
Manually detected when `kubectl get pods` began hanging and eventually returning: `dial tcp 46.225.238.232:6443: i/o timeout`.

## 4. Timeline
* **2026-03-13 (approx)** - ISP assigned a new dynamic IPv4 address to the home connection.
* **2026-03-14 ~10:58** - `kubectl get pods` hangs, returning `dial tcp 46.225.238.232:6443: i/o timeout`.
* **2026-03-14** - Root cause identified — Hetzner firewall rules still referenced the old IP. Current IP (94.33.13.77) was not in the allowlist.
* **2026-03-14** - Fixed via `tofu apply -target='hcloud_firewall.this[0]'`, which re-detected the current IP and updated the firewall rules. Access restored.

## 5. Root Cause
The `infrastructure/firewall.tf` configuration auto-detects the operator's public IPv4 at `tofu apply` time (via icanhazip.com) and creates firewall rules scoped to that IP. The firewall allows inbound TCP on ports 6443 (Kubernetes API) and 50000 (Talos API) only from the detected IP.
With a dynamic IP from the ISP, any IP rotation silently breaks access. There is no monitoring or alerting for this condition — the failure mode is a silent timeout.

## 6. Contributing Factors
* **Direct Public API Exposure**: The Kubernetes and Talos APIs are bound directly to the public internet without an abstraction layer (like a VPN, overlay network, or load balancer). This forces reliance on strict, brittle IP whitelisting for security.
* **Environmental Constraint**: The home ISP provisions dynamic IPv4 addresses, guaranteeing eventual IP rotation.
* **Tooling Limitation**: OpenTofu resolves the operator's public IP only during execution. There is no automated reconciliation loop to update the Hetzner firewall state when the external IP changes.

## 7. Resolution
* **Immediate Mitigation:** Targeted `tofu apply -target='hcloud_firewall.this[0]'` to update the firewall rule with the current IP.
* **Long-term Fix:** Under evaluation — options include deploying a VPN service on the cluster to provide a stable access path regardless of the operator's public IP.

## 8. Lessons Learned
* **What went wrong:**
  * The initial symptom (`kubectl` timeout) was misattributed to an RBAC/authentication issue, which delayed diagnosis. TCP-level timeouts always indicate a network/firewall problem, not an auth problem.
  * The auto-detected IP in the firewall is a single point of failure for cluster access.
* **What went well:**
  * `tofu apply -target='hcloud_firewall.this[0]'` is the fastest recovery path.

## 9. Action Items
* [ ] Evaluate and implement a VPN solution (e.g., Tailscale, WireGuard) for stable cluster access.
* [ ] Create a short-term workaround script to detect local public IP changes and automatically trigger `tofu apply -target='hcloud_firewall.this[0]'`.
* [ ] Implement basic API endpoint monitoring (external TCP check on port 6443) to alert on unreachable APIs before manual discovery.
* [ ] Document the `tofu apply -target` recovery procedure in runbooks.
* [ ] Update the project README to document the firewall IP limitation.