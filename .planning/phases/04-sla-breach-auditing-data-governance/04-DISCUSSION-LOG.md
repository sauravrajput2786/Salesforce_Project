# Phase 4: SLA Breach Auditing & Data Governance - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-28  
**Phase:** 04-SLA Breach Auditing & Data Governance  
**Areas discussed:** Breach Automation Mechanism, Validation Rule Field Scope, Agent Immutability & Admin Bypass Strategy, End-to-End Pillar 4 Integration Suite  

---

## Breach Automation Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Workflow Field Updates in Case.workflow-meta.xml | Package Set_SLA_Breached_True and Set_SLA_Violation_Yes field updates for declarative Entitlement Process violation triggers (matches ChangePriorityToHigh pattern) | ✓ |
| Apex Service Method | Add markSlaBreached(CaseId) in MilestoneCompletionService to update fields programmatically | |
| Record-Triggered Flow on Milestone Breach | Build a flow that detects milestone breaches and updates the parent Case | |

**User's choice:** Workflow Field Updates in `Case.workflow-meta.xml`.  
**Notes:** Matches the established declarative architecture of Phase 1 (`ChangePriorityToHigh`), packaging tracked source metadata for Entitlement Process milestone breach actions.

---

## Validation Rule Field Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Add ISCHANGED(SLAViolation__c) | Lock SLAViolation__c alongside SLA_Breached__c, EntitlementId, and intake data in VR_Case_Lock_Customer_And_SLA_Data | ✓ |
| Lock Only Breach Clearing (Anti-Tamper) | Only block when SLA_Breached__c is changed from true to false or SLAViolation__c is changed from Yes to No/null | |
| Separate Dedicated Validation Rule | Keep VR_Case_Lock_Customer_And_SLA_Data as-is and create VR_Case_Lock_SLA_Breach_Fields solely for breach metrics | |

**User's choice:** Add `ISCHANGED(SLAViolation__c)` to `VR_Case_Lock_Customer_And_SLA_Data`.  
**Notes:** Unifies customer intake and SLA immutability enforcement in a single authoritative validation rule.

---

## Agent Immutability & Admin Bypass Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Profile Exception ($Profile.Name != 'System Administrator') | Support agents are strictly blocked, while System Administrators retain bypass capability | |
| Strict Immutability with Custom Permission | Require a custom permission ($Permission.Bypass_Case_Lock) to modify locked fields | ✓ |
| Universal Absolute Lock | Block all users including System Administrators without exception | |

**User's choice:** Strict Immutability with Custom Permission (`$Permission.Bypass_Case_Lock`).  
**Notes:** Establishes enterprise-grade principle of least privilege. Prevents accidental edits by administrators and support agents alike unless explicitly granted the `Bypass_Case_Lock` permission.

---

## End-to-End Pillar 4 Integration Suite

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated Pillar4SlaGovernanceIntegrationTest.cls | Comprehensive E2E test verifying Entitlement assignment, Priority guard, 72h telemetry, outbound completion, closure completion, and validation rule lock enforcement | ✓ |
| Split into Unit & E2E | Separate ValidationRuleTest.cls for lock checks and Pillar4IntegrationTest.cls for end-to-end flow verification | |
| Extend Existing Test Classes | Add integration test methods into CasePriorityGuardTest and MilestoneCompletionServiceTest | |

**User's choice:** Dedicated `Pillar4SlaGovernanceIntegrationTest.cls`.  
**Notes:** Provides a single end-to-end test validating the complete ticket lifecycle and verifying that all 12 Milestone v1.1 requirements are satisfied.

---

## Antigravity's Discretion

- Packaging `Bypass_Case_Lock` Custom Permission.
- Validation rule formula error message refinement.
- Integration test assertion structure.

---

## Deferred Ideas

- None. Phase 4 is the final milestone phase.
