# Phase 2: Single-Admin Escalation Engine Governance - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-28  
**Phase:** 02-Single-Admin Escalation Engine Governance  
**Areas discussed:** Admin Resolution Mechanism, 24-Hour Recipient Routing, 72-Hour Escalation Telemetry, Escalation Delivery Channels  

---

## Admin Resolution Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Query User by Profile Name | Lookup active User where Profile.Name = 'System Administrator' and IsActive = true (sorted by CreatedDate ASC, first record only) | ✓ |
| Fallback Formula to {!$User.Email} | Use running/automated process user email directly without querying User object | |
| Custom Metadata / Custom Setting | Define escalation admin email in Custom Metadata Type or Hierarchy Custom Setting | |

**User's choice:** Query active User where `Profile.Name = 'System Administrator'` and `IsActive = true`, with fallback formula `IF(ISBLANK({!Get_System_Administrator_User.Email}), {!$User.Email}, {!Get_System_Administrator_User.Email})`.  
**Notes:** Completely eliminates multi-tier user role dependencies (`UserRole.Name = 'Support Manager'`) and manager hierarchy traversing (`User.ManagerId`), ensuring clean single-license execution in developer org environments.

---

## 24-Hour Recipient Routing

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid Smart Routing | Notify Case Owner if owned by a User (005), but route to System Administrator if owned by a Queue (00G) | |
| Strict Admin Routing | Route 24h notification directly to System Administrator regardless of owner type | |
| Dual Recipient (Owner + Admin) | Notify Case Owner and include System Administrator on CC | ✓ |

**User's choice:** Dual Recipient (Owner + Admin) for notifications; if owned by a Queue, route to System Administrator.  
**Notes:** Subsumed by the decision on Delivery Channels to post to the Case Chatter feed instead of dispatching emails at 24h, providing audit visibility without email flooding.

---

## 72-Hour Escalation Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Full Telemetry (Priority + Reason + IsEscalated) | Set Priority='Critical', Escalation_Reason__c='SLA Breach Risk', and IsEscalated=true | ✓ |
| Priority and Reason only | Set Priority='Critical' and Escalation_Reason__c='SLA Breach Risk' (do not touch standard IsEscalated) | |
| Priority only | Keep current behavior (only elevate Priority to Critical) | |

**User's choice:** Full Telemetry (`Priority = 'Critical'`, `Escalation_Reason__c = 'SLA Breach Risk'`, `IsEscalated = true`).  
**Notes:** Sets standard `IsEscalated` flag to enable management dashboard monitoring, and populates restricted picklist `Escalation_Reason__c` with `'SLA Breach Risk'`. Priority is protected against downgrade by Phase 1 guard.

---

## Escalation Delivery Channels

| Option | Description | Selected |
|--------|-------------|----------|
| emailSimple + Chatter Post at 72h | Send email for all paths, plus post a Critical Escalation notice to Case Feed at 72h | |
| emailSimple Only for all paths | Keep notifications strictly in email to match current flow design | |
| Chatter Posts at 24h/48h/72h + Email at 72h Only | Chatter Post on Case at all three thresholds (24h, 48h, 72h) for console audit visibility; Email notification only at 72h (critical alert only) to avoid admin inbox flooding | ✓ |

**User's choice:** Chatter Post on Case at all three thresholds (24h, 48h, 72h) for console audit visibility. Email notification only at 72h (critical alert only) — remove 24h and 48h emails to avoid admin inbox flooding. Admin will monitor escalated cases via Salesforce Dashboard filtered on `IsEscalated = true`.  
**Notes:** Key architectural refinement preventing inbox spam while maintaining full operational visibility in both the Service Console feed and executive dashboards.

---

## Antigravity's Discretion

- Fallback behavior when a Case is in a Queue at 24h: Chatter post tags the System Administrator.
- Specific text templates and formatting for Chatter feed posts and 72h critical email.
- XML metadata formatting for `Case_Escalation_Flow.flow-meta.xml`.

---

## Deferred Ideas

- Standard Salesforce Dashboard component setup for monitoring `IsEscalated = true` cases.
- Automated milestone completion engine for Phase 3 (BUG-001).
