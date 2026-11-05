# Phase 4: SLA Breach Auditing & Data Governance - Context

**Gathered:** 2026-10-28  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Phase 4 concludes Pillar 4 (Milestone Lifecycle & SLA Governance) by packaging automated SLA breach tracking actions ([GOV-01](file:///home/elsner/Salesforce/SalesforceProject/.planning/REQUIREMENTS.md)), enforcing strict data immutability through [VR_Case_Lock_Customer_And_SLA_Data](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml) with Custom Permission gating ([GOV-02](file:///home/elsner/Salesforce/SalesforceProject/.planning/REQUIREMENTS.md)), and creating an end-to-end integration verification test suite proving the full ticket lifecycle from intake through closure.

</domain>

<decisions>
## Implementation Decisions

### Breach Automation Mechanism
- **D-01 (Workflow Field Update Packaging):** Package standard workflow field updates in `force-app/main/default/workflows/Case.workflow-meta.xml` for declarative Entitlement Process violation triggers (matching the `ChangePriorityToHigh` pattern from Phase 1):
  - `Set_SLA_Breached_True`: Updates `SLA_Breached__c` to `true`.
  - `Set_SLA_Violation_Yes`: Updates `SLAViolation__c` to `'Yes'`.
  - Configured to execute upon 100% milestone breach.
  - **Reversibility:** reversible — declarative metadata definitions.

### Validation Rule Scope Extension
- **D-02 (Include SLAViolation__c in Lock Scope):** Update `VR_Case_Lock_Customer_And_SLA_Data` to add `ISCHANGED(SLAViolation__c)` to the existing locked fields:
  - Locked intake fields: `AccountId`, `ContactId`, `EntitlementId`, `Origin`, `Customer_Product__c`, `Customer_Rating__c`, `Feedback_Comments__c`, `Reopened_Count__c`.
  - Locked SLA metrics: `SLA_Breached__c`, `SLAViolation__c`.
  - **Reversibility:** reversible.

### Strict Immutability with Custom Permission Gating
- **D-03 (Custom Permission Bypass):** Implement enterprise permission-based immutability:
  - Create Custom Permission `Bypass_Case_Lock` in `force-app/main/default/customPermissions/Bypass_Case_Lock.customPermission-meta.xml`.
  - In `VR_Case_Lock_Customer_And_SLA_Data`, evaluate:
    ```apex
    AND(
        NOT($Permission.Bypass_Case_Lock),
        NOT(ISNEW()),
        OR(
            ISCHANGED(AccountId),
            ISCHANGED(ContactId),
            ISCHANGED(EntitlementId),
            ISCHANGED(Origin),
            ISCHANGED(Customer_Product__c),
            ISCHANGED(Customer_Rating__c),
            ISCHANGED(Feedback_Comments__c),
            ISCHANGED(SLA_Breached__c),
            ISCHANGED(SLAViolation__c),
            ISCHANGED(Reopened_Count__c)
        )
    )
    ```
  - By default, ALL users (including standard administrators) are prohibited from modifying or clearing customer intake and SLA breach metrics unless explicitly assigned a Permission Set granting `Bypass_Case_Lock`.
  - **Reversibility:** costly — enforces enterprise data immutability and compliance auditing.

### End-to-End Pillar 4 Integration Suite
- **D-04 (Dedicated Pillar 4 Integration Test):** Implement `Pillar4SlaGovernanceIntegrationTest.cls` and metadata descriptor verifying:
  1. Intake & Entitlement Assignment: Case creation assigns tier entitlement.
  2. Priority Protection: `Case_Critical_Priority_Guard` ensures Critical tickets cannot be downgraded.
  3. Escalation Telemetry: `Case_Escalation_Flow` stamps `Priority = 'Critical'`, `Escalation_Reason__c = 'SLA Breach Risk'`, and `IsEscalated = true`.
  4. Outbound First Response: `EmailMessageTrigger` auto-completes First Response milestone.
  5. Case Closure: `CaseTrigger` auto-completes all remaining open milestones.
  6. Data Immutability: `VR_Case_Lock_Customer_And_SLA_Data` blocks unauthorized modifications to `SLA_Breached__c`, `SLAViolation__c`, and `EntitlementId`.
  - **Reversibility:** reversible.

### Antigravity's Discretion
- Custom Permission XML metadata formatting.
- Validation Rule error message refinement.
- Integration test setup structure and assertions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Objects & Fields
- `force-app/main/default/objects/Case/fields/SLA_Breached__c.field-meta.xml` — SLA Breached checkbox field.
- `force-app/main/default/objects/Case/fields/SLAViolation__c.field-meta.xml` — SLA Violation picklist field.
- `force-app/main/default/objects/Case/fields/Escalation_Reason__c.field-meta.xml` — Escalation Reason picklist.

### Validation Rules & Workflows
- `force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml` — Target validation rule for immutability locking.
- `force-app/main/default/workflows/Case.workflow-meta.xml` — Target workflow metadata for `Set_SLA_Breached_True` and `Set_SLA_Violation_Yes`.

### Prior Pillar 4 Artifacts
- `force-app/main/default/flows/Case_Critical_Priority_Guard.flow-meta.xml` — Phase 1 Priority guard.
- `force-app/main/default/flows/Case_Escalation_Flow.flow-meta.xml` — Phase 2 Single-Admin escalation engine.
- `force-app/main/default/classes/MilestoneCompletionService.cls` — Phase 3 Milestone completion engine.
- `force-app/main/default/triggers/EmailMessageTrigger.trigger` — Phase 3 outbound email trigger.
- `force-app/main/default/triggers/CaseTrigger.trigger` — Phase 3 case closure trigger.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- [Case.workflow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/workflows/Case.workflow-meta.xml): Existing workflow field update file containing `ChangePriorityToHigh`.
- [VR_Case_Lock_Customer_And_SLA_Data](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml): Existing validation rule locking customer intake data.
- [CasePriorityGuardTest.cls](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/classes/CasePriorityGuardTest.cls), [CaseEscalationFlowTest.cls](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/classes/CaseEscalationFlowTest.cls), [MilestoneCompletionServiceTest.cls](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/classes/MilestoneCompletionServiceTest.cls): Test patterns.

### Established Patterns
- Custom Permission check via `$Permission.Permission_Name` in formula expressions.
- Workflow Field Updates on Case (`operation: Literal`).
- `@IsTest` with `@TestSetup` and `System.runAs()` for permission-isolated testing.

</code_context>

<specifics>
## Specific Ideas

- Packaging `Set_SLA_Breached_True` and `Set_SLA_Violation_Yes` in `Case.workflow-meta.xml`.
- Creating `Bypass_Case_Lock` Custom Permission in `force-app/main/default/customPermissions/`.
- Testing validation rule denial using `System.DmlException` catch and asserting error message.

</specifics>

<deferred>
## Deferred Ideas

- None — Phase 4 is the final phase of Milestone v1.1. All 12 requirements across Pillars 1-4 are completed with this phase.

</deferred>

---

*Phase: 04-SLA Breach Auditing & Data Governance*  
*Context gathered: 2026-10-28*
