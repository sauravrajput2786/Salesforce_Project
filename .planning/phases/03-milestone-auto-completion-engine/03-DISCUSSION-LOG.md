# Phase 3: Milestone Auto-Completion Engine (Fix BUG-001) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-28  
**Phase:** 03-Milestone Auto-Completion Engine (Fix BUG-001)  
**Areas discussed:** Implementation Pattern, First Response Trigger Scope, Case Closure Completion Scope, Idempotency & Recursion Safety  

---

## Implementation Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Apex Trigger Handler (MilestoneCompletionService) | Clean, bulk-safe Apex triggers on EmailMessage and Case delegating to an idempotent service class; standard enterprise Service Cloud pattern | ✓ |
| Declarative Record-Triggered Flows | Flow on EmailMessage and Flow on Case updating CaseMilestone directly without Apex code | |
| Hybrid (Flow + Invocable Apex) | Record-triggered flows invoking an @InvocableMethod Apex service for milestone completion | |

**User's choice:** Apex Trigger Handler (`MilestoneCompletionService.cls` driven by `EmailMessageTrigger.trigger` and `CaseTrigger.trigger`).  
**Notes:** Provides 100% fine-grained bulk safety, clean transactional semantics, direct junction query optimization, and avoids Flow relationship traversal limits.

---

## First Response Trigger Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Outbound EmailMessage + Public CaseComment | Both outbound emails (Incoming=false) and public customer-facing Case comments (IsPublished=true) complete First Response | |
| Outbound EmailMessage Only | Only outbound emails sent to the customer (Incoming=false) complete the First Response milestone | ✓ |
| Outbound EmailMessage + Any Case Comment | Outbound emails or any comment added by an agent | |

**User's choice:** Outbound `EmailMessage` Only (`Incoming == false` and `ParentId` is a Case).  
**Notes:** Preserves strict customer communication definition. Internal notes or private comments do not complete customer-facing SLA milestones.

---

## Case Closure Completion Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Complete ALL Open Milestones | Close every active CaseMilestone (CompletionDate == null) on the ticket to guarantee zero stuck/orphaned milestones in the Console widget | ✓ |
| Complete Only Resolution Milestones | Complete 'Resolution' and 'Close Case' only; do not auto-complete 'First Response' if no email was ever sent | |
| Configurable by Custom Setting | Use a Custom Setting / Metadata to specify which milestone names auto-complete on close | |

**User's choice:** Complete ALL Open Milestones on Case closure.  
**Notes:** Directly fixes BUG-001 by ensuring resolved cases never retain ticking/orphaned milestones in the `support:milestones` UI tracker.

---

## Idempotency & Recursion Safety

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive Idempotency Guard | Filter CompletionDate == null, check Trigger.isChanged for Case Status transition, skip non-entitled cases, and enforce static recursion guard set | ✓ |
| Basic Null Checks Only | Only check CompletionDate == null in the SOQL query without status-transition or recursion guards | |
| Database Partial Success (allOrNone=false) | Wrap DML in Database.update(milestones, false) with debug logging on any error | |

**User's choice:** Comprehensive Idempotency Guard (SOQL null filter, status change check, entitlement presence validation, and static recursion set).  
**Notes:** Guarantees zero extraneous DML statements and prevents trigger recursion or governor limit exhaustion during high-volume bulk operations.

---

## Antigravity's Discretion

- Packaging trigger handlers cleanly in `MilestoneCompletionService.cls`.
- Defensive try-catch blocks with debug logging to prevent email dispatch blocking on milestone locks.
- Unit test mocking and bulk data creation patterns.

---

## Deferred Ideas

- Custom Milestone Countdown LWC (standard `support:milestones` component on `Case_Record_Page` is verified).
- Phase 4: SLA Breach Auditing & Data Governance.
