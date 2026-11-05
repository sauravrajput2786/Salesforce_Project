# Phase 3: Milestone Auto-Completion Engine (Fix BUG-001) - Context

**Gathered:** 2026-10-28  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Phase 3 implements an automated, idempotent milestone completion engine in Apex to fix **BUG-001**. In standard Salesforce Service Cloud, open milestones remain open and ticking indefinitely unless programmatically closed. This phase builds `MilestoneCompletionService.cls`, `EmailMessageTrigger.trigger`, and `CaseTrigger.trigger` to automatically set `CaseMilestone.CompletionDate = System.now()` upon outbound customer communications (`EmailMessage` with `Incoming == false`) and Case closure (`Status = 'Closed'`), ensuring 100% SLA compliance accuracy and zero orphaned milestones in the Service Console tracker (`support:milestones`).

</domain>

<decisions>
## Implementation Decisions

### Implementation Architecture
- **D-01 (Apex Service & Trigger Architecture):** Power milestone auto-completion using an enterprise Apex Service pattern:
  - `EmailMessageTrigger.trigger` (after insert) -> dispatches to `MilestoneCompletionService.completeFirstResponseMilestones(List<EmailMessage>)`.
  - `CaseTrigger.trigger` (after update) -> dispatches to `MilestoneCompletionService.completeCaseCloseMilestones(List<Case>, Map<Id, Case>)`.
  - Service class `MilestoneCompletionService.cls` encapsulates all SOQL, milestone type matching, idempotency filters, and bulk DML updates.
  - Avoids Flow junction query limitations and governor limit issues during bulk email ingestion.
  - **Reversibility:** reversible — modular Apex service and trigger handlers.

### First Response Completion Scope
- **D-02 (Outbound EmailMessage Only):** Completion of the *"First Response to Customer"* `CaseMilestone` is triggered exclusively by outbound customer emails (`Incoming == false` and `ParentId != null` where `ParentId` begins with `500` / Case prefix).
  - Internal agent comments and internal Chatter posts do not count as First Response.
  - **Reversibility:** reversible.

### Case Closure Completion Scope
- **D-03 (Complete ALL Remaining Open Milestones on Close):** When a Case transitions to `Status = 'Closed'` (or `IsClosed == true`):
  - Automatically complete **ALL open `CaseMilestone` records** (`CompletionDate == null`) linked to the Case, regardless of milestone name (e.g. *"First Response to Customer"*, *"Resolution"*, *"Close Case"*).
  - Eliminates orphaned or stuck milestone counters on resolved tickets in the `support:milestones` Lightning Console component.
  - **Reversibility:** costly — impacts SLA completion auditing and operational reporting.

### Idempotency & Recursion Safety
- **D-04 (Comprehensive Idempotency Guard):**
  - **Null Filter:** SOQL queries strictly filter `WHERE CaseId IN :caseIds AND CompletionDate = null`. If no matching milestones exist, 0 DML statements are executed.
  - **Status Change Guard:** For Case updates, only process records where `oldCase.Status != 'Closed' && newCase.Status == 'Closed'`. Repeated edits on already-closed tickets are immediately ignored.
  - **Entitlement Guard:** Cases without an assigned entitlement (`EntitlementId == null`) are filtered out before querying `CaseMilestone`.
  - **Static Recursion Set:** `MilestoneCompletionService` maintains a `static Set<Id> processedCaseIds` to prevent re-entrant execution within the same transaction.
  - **Reversibility:** reversible.

### Antigravity's Discretion
- Packaging trigger logic via dedicated trigger handler methods or unified `MilestoneCompletionService.cls`.
- Error logging and graceful exception handling using `try-catch` with `System.debug` to prevent customer email send blocking in the event of milestone lock contention.
- Bulkified test utility methods and mock entitlement setup in test classes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Entitlement Processes & SLA Metadata
- `force-app/main/default/entitlementProcesses/Gold_Tier_SLA_Process.entitlementProcess-meta.xml` — Defines Gold tier "First Response to Customer" (60m) and "Close Case" milestones.
- `force-app/main/default/entitlementProcesses/Silver_Tier_SLA_Process.entitlementProcess-meta.xml` — Defines Silver tier First Response (240m) and Close Case milestones.
- `force-app/main/default/entitlementProcesses/Platinum_Tier_SLA_Process.entitlementProcess-meta.xml` — Defines Platinum tier First Response (480m) and Close Case milestones.

### Planning Context & Requirements
- `.planning/PROJECT.md` — System architecture, Pillar 4 milestone lifecycle, BUG-001 details.
- `.planning/REQUIREMENTS.md` — Requirements `MILE-01`, `MILE-02`, `MILE-03`.
- `.planning/ROADMAP.md` — Phase 3 scope and success criteria.
- `.planning/phases/01-sla-entitlement-warning-synchronization/01-CONTEXT.md` — Phase 1 decision D-05 on BUG-001 alignment.

### Data Governance & Validation Rules
- `force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml` — Validates locked SLA fields; confirms milestone completion operations do not collide with validation rules.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- [Case_Entitlement_Gatekeeper.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Entitlement_Gatekeeper.flow-meta.xml): Assigns Entitlements on Case creation.
- [Case_Escalation_Flow.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Escalation_Flow.flow-meta.xml): Reconfigured in Phase 2 for single-admin scheduled escalation.
- [CasePriorityGuardTest.cls](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/classes/CasePriorityGuardTest.cls) & [CaseEscalationFlowTest.cls](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/classes/CaseEscalationFlowTest.cls): Test setup patterns.

### Established Patterns
- Enterprise Service pattern (`MilestoneCompletionService.cls` with public static methods).
- Bulkified triggers operating on collections outside loops.
- Static recursion sets for transaction-safe idempotency.

### Integration Points
- `EmailMessage` insert lifecycle: Triggers First Response milestone completion.
- `Case` update lifecycle (`Status` -> `Closed`): Triggers all remaining open milestone completions.
- `support:milestones` UI component in `Case_Record_Page`: Displays live countdown and checks off completed milestones in real-time.

</code_context>

<specifics>
## Specific Ideas

- When `EmailMessage` is inserted:
  1. Filter for `Incoming == false` and `ParentId != null` and `ParentId.getSObjectType() == Case.sObjectType`.
  2. Query `CaseMilestone WHERE CaseId IN :caseIds AND MilestoneType.Name = 'First Response to Customer' AND CompletionDate = null`.
  3. Set `CompletionDate = System.now()` and execute `update`.
- When `Case` is updated:
  1. Filter for `Status == 'Closed'` and `oldCase.Status != 'Closed'`.
  2. Query `CaseMilestone WHERE CaseId IN :closedCaseIds AND CompletionDate = null`.
  3. Set `CompletionDate = System.now()` and execute `update`.

</specifics>

<deferred>
## Deferred Ideas

- **Custom Milestone Countdown LWC:** Standard Lightning Console `support:milestones` is confirmed and verified.
- **Phase 4 (SLA Breach Auditing & Data Governance):** Automated breach tracking (`SLA_Breached__c`, `SLAViolation__c`) and immutability lock validation rule enforcement.

</deferred>

---

*Phase: 03-Milestone Auto-Completion Engine (Fix BUG-001)*  
*Context gathered: 2026-10-28*
