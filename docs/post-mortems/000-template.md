# Post-Mortem: [Incident Number/Name]

**Date of Incident:** [YYYY-MM-DD]
**Status:** [Draft | Review | Published]
**Author(s):** [Name]

## 1. Summary
[A brief, executive-level explanation of what happened, why it happened, and the resulting impact. Keep it under 3-4 sentences.]

## 2. Impact
* **Duration:** [Time the incident started to time it was resolved]
* **Severity:** [e.g., SEV-1, SEV-2, Low, Critical]
* **User/System Impact:** [e.g., "Internal deployment pipelines blocked for 24 hours. No customer-facing downtime."]

## 3. Detection
[How was the incident discovered? e.g., Automated alert from Prometheus, customer support ticket, manual operator discovery during routine tasks.]

## 4. Timeline
* **[YYYY-MM-DD HH:MM]** - Triggering event occurs.
* **[YYYY-MM-DD HH:MM]** - Incident detected by [System/Person].
* **[YYYY-MM-DD HH:MM]** - Investigation begins.
* **[YYYY-MM-DD HH:MM]** - Root cause identified.
* **[YYYY-MM-DD HH:MM]** - Mitigation applied.
* **[YYYY-MM-DD HH:MM]** - Full resolution confirmed.

## 5. Root Cause
[The underlying technical or process failure that allowed the incident to happen. Avoid blaming people; focus on systems.]

## 6. Contributing Factors
[What architectural choices, environmental constraints, or technical debt made this incident possible or worsened its impact?]
* [Factor 1]
* [Factor 2]

## 7. Resolution
* **Immediate Mitigation:** [Band-aid fix to stop the bleeding]
* **Long-term Fix:** [Systemic fix being planned/implemented]

## 8. Lessons Learned
* **What went well:** [e.g., Recovery was fast once the issue was identified.]
* **What went wrong:** [e.g., We wasted 2 hours looking at RBAC instead of the network.]

## 9. Action Items
* [ ] [Task 1 - e.g., Implement VPN]
* [ ] [Task 2 - e.g., Add monitoring alert]