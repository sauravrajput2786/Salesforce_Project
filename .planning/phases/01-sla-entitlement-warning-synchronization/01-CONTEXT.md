# Phase 1: SLA Entitlement Warning Synchronization - Context

**Gathered:** 2026-10-27  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Phase 1 synchronizes proactive SLA warning time triggers across all three tier Entitlement Processes (`Gold_Tier_SLA_Process`, `Silver_Tier_SLA_Process`, `Platinum_Tier_SLA_Process`) at exactly 75% elapsed milestone time. It establishes proactive internal Chatter alerts at the 75% threshold, reserves Priority elevation exclusively for 100% SLA violations, guards against Critical priority downgrades, and aligns Entitlement Process metadata for subsequent milestone completion (BUG-001).

</domain>

<decisions>
## Implementation Decisions

### Milestone Warning Scope & 75% Elapsed Synchronization
- **D-01 (75% Warning Scope):** Configure 75% elapsed warning time triggers strictly on the *"First Response to Customer"* milestone across all three SLA processes:
  - **Gold Tier (60 min total):** Warning at 45 min elapsed (`timeLength = -15` minutes before deadline).
  - **Silver Tier (240 min total):** Warning at 180 min elapsed (`timeLength = -60` minutes before deadline).
  - **Platinum Tier (480 min total):** Warning at 360 min elapsed (`timeLength = -120` minutes before deadline).
  - Secondary milestones (*"Escalate Case"* and *"Close Case"*) do not have intermediate warning actions; they follow their lifecycle closure and scheduled escalation flows.
  - **Reversibility:** costly — changes XML milestone trigger parameters across all entitlement tiers.

- **D-02 (75% Warning Action Behavior):** At the 75% warning threshold, do **NOT** change Case `Priority` to `High`. The warning action is strictly for proactive internal alerting (Chatter feed alert tagging the Case Owner with remaining time until breach).
  - **Reversibility:** reversible — modular action definition.

### Priority Elevation & Violation Actions (100% Breach)
- **D-03 (Priority Elevation on Breach Only):** Elevating Case `Priority` to `High` belongs strictly to the **100% SLA Breach (Violation Action)**, never during the 75% warning.
  - Entitlement Processes will configure `<name>ChangePriorityToHigh</name><type>FieldUpdate</type>` under milestone `<actions>` for SLA violations.
  - Package `ChangePriorityToHigh` workflow field update in `force-app/main/default/workflows/Case.workflow-meta.xml`.
  - **Reversibility:** costly — affects SLA violation handling and case prioritization.

### Priority Downgrade Protection (Critical Outage Guard)
- **D-04 (Critical Priority Immunity):** Implement a lightweight Before-Save guard (via Flow or handler) ensuring that if Case `Priority` is already `Critical`, it is strictly preserved and never downgraded to `High` when an SLA breach or field update executes.
  - Formula/Decision logic: `IF(ISCHANGED(Priority) && PRIORVALUE(Priority) == 'Critical' && Priority == 'High', 'Critical', Priority)`.
  - **Reversibility:** reversible — self-contained before-save evaluation.

### Core Priority of Pillar 4
- **D-05 (BUG-001 Priority Alignment):** Phase 1 configurations must seamlessly prepare the ground for BUG-001 (Phase 3), ensuring that when a Case is closed or an outbound email is sent, the open milestones are automatically completed to freeze the ticking SLA clock.
  - **Reversibility:** one-way — foundational architecture for milestone completion lifecycle.

### Antigravity's Discretion
- Chatter notification template body formatting for the 75% proactive warning alert tagging Case Owner.
- XML metadata schema formatting and packaging for `Case.workflow-meta.xml`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Entitlement Processes & SLA Metadata
- `force-app/main/default/entitlementProcesses/Gold_Tier_SLA_Process.entitlementProcess-meta.xml` — Gold 60m First Response definition and warning trigger structure.
- `force-app/main/default/entitlementProcesses/Silver_Tier_SLA_Process.entitlementProcess-meta.xml` — Silver 240m First Response definition and warning trigger structure.
- `force-app/main/default/entitlementProcesses/Platinum_Tier_SLA_Process.entitlementProcess-meta.xml` — Platinum 480m First Response definition and warning trigger structure.

### Project & Milestone Architecture
- `.planning/PROJECT.md` — Core value, validated capabilities (Pillars 1–3), active requirements, and key decisions.
- `.planning/REQUIREMENTS.md` — Requirements `SLA-01`, `SLA-02`, `SLA-03`, `SLA-04`.
- `.planning/ROADMAP.md` — Phase 1 scope, deliverables, and success criteria.
- `.planning/codebase/ARCHITECTURE.md` — System overview, Service Cloud pillar architecture, and data immutability constraints.

### Validation Rules
- `force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml` — Validates locked fields to ensure field updates do not collide with immutability rules.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- [Gold_Tier_SLA_Process.entitlementProcess-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/entitlementProcesses/Gold_Tier_SLA_Process.entitlementProcess-meta.xml): Active Entitlement Process for Gold accounts.
- [Silver_Tier_SLA_Process.entitlementProcess-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/entitlementProcesses/Silver_Tier_SLA_Process.entitlementProcess-meta.xml): Active Entitlement Process for Silver accounts.
- [Platinum_Tier_SLA_Process.entitlementProcess-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/entitlementProcesses/Platinum_Tier_SLA_Process.entitlementProcess-meta.xml): Active Entitlement Process for Platinum accounts.
- [Case_Entitlement_Gatekeeper.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Entitlement_Gatekeeper.flow-meta.xml): Assigns Entitlements on Case creation.

### Established Patterns
- Fast Field Update (`RecordBeforeSave`) on `Case` for zero-DML validation and value guarding.
- Declarative Entitlement Process time triggers specifying negative minute offsets (`<timeLength>-15</timeLength>`).
- Strict immutability of customer intake and SLA metrics via `VR_Case_Lock_Customer_And_SLA_Data`.

### Integration Points
- `Case.workflow-meta.xml`: Target location for `ChangePriorityToHigh` workflow field update.
- Case Before-Save lifecycle: Guard preserving `Critical` priority against downgrade.

</code_context>

<specifics>
## Specific Ideas

- Proactive Chatter alert at 75% warning: `"[SLA Warning] Case #{!$Record.CaseNumber} has reached 75% of its First Response window. Please respond to the customer to prevent an SLA breach."`
- Priority elevation to `High` occurs strictly on 100% breach/violation, not warning.
- Critical priority protection is mandatory.

</specifics>

<deferred>
## Deferred Ideas

- **Single-Admin Escalation Flow**: Scheduled path reconfiguration in `Case_Escalation_Flow` is scheduled for Phase 2.
- **Automated Milestone Completion Engine (BUG-001)**: Trigger/flow automation to complete CaseMilestones on outbound email or Case closed is scheduled for Phase 3.
- **SLA Breach Telemetry & Audit Integrity**: Complete audit logging and immutability verification is scheduled for Phase 4.

</deferred>

---

*Phase: 01-SLA Entitlement Warning Synchronization*  
*Context gathered: 2026-10-27*
