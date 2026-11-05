# Phase 2: Single-Admin Escalation Engine Governance - Context

**Gathered:** 2026-10-28  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Phase 2 reconfigures [Case_Escalation_Flow.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Escalation_Flow.flow-meta.xml) to eliminate multi-tier manager hierarchy (`User.ManagerId`) and `UserRole` (`Support Manager`) dependencies, targeting the System Administrator directly for single-license Developer Edition org compatibility. It restructures escalation channels by establishing in-app Chatter audit posts on the Case feed across 24h, 48h, and 72h thresholds, reserving email notifications exclusively for the 72h critical alert to prevent admin inbox flooding, and stamping full telemetry (`Priority = 'Critical'`, `Escalation_Reason__c = 'SLA Breach Risk'`, `IsEscalated = true`) for dashboard monitoring.

</domain>

<decisions>
## Implementation Decisions

### Admin Resolution Strategy
- **D-01 (Direct Admin Lookup with Safe Fallback):** In `Case_Escalation_Flow`, query active `User` where `Profile.Name = 'System Administrator'` and `IsActive = true`, sorted by `CreatedDate ASC` (`getFirstRecordOnly = true`). Store the result in a Flow record variable. 
  - Formula `formula_AdminEmail` evaluates `IF(ISBLANK({!Get_System_Administrator_User.Email}), {!$User.Email}, {!Get_System_Administrator_User.Email})`.
  - Removes `Get_Support_Manager_Role_48h`, `Get_Support_Manager_User_48h`, `Get_Support_Manager_Role_72h`, and `Get_Support_Manager_User_72h`.
  - **Reversibility:** reversible — modular Flow query element.

### Escalation Channels & Notification Consolidation
- **D-02 (Chatter Posts for All Thresholds):** At all three scheduled thresholds (24h, 48h, 72h), post an automated escalation notice directly to the Case Chatter feed. This establishes an immutable in-app audit trail visible in the Service Console workspace (`Case_Record_Page`).
  - **Reversibility:** reversible — standard Flow action additions.

- **D-03 (Email Notification at 72h ONLY):** Remove 24h and 48h email notification actions (`emailSimple`) to avoid admin inbox flooding. Email alerts are dispatched strictly at the **72-hour Critical Escalation** threshold, targeted directly to the System Administrator (and Case Owner if assigned to an active user).
  - Admin and management monitor open escalations via Salesforce Reports/Dashboards rather than email blasts.
  - **Reversibility:** reversible — declarative action adjustments.

### 24-Hour Recipient & Queue Handling
- **D-04 (24-Hour Chatter Routing & Queue Fallback):**
  - If Case is owned by an active User (`OwnerId` starts with `005`), tag the Case Owner in the 24h Chatter post.
  - If Case is assigned to a Queue (`OwnerId` starts with `00G`) or unassigned, tag the System Administrator in the 24h Chatter post.
  - No external email is dispatched at 24h.
  - **Reversibility:** reversible.

### 72-Hour Escalation Telemetry
- **D-05 (Full Telemetry Stamping):** At the 72h critical threshold, update the Case with full escalation telemetry:
  - `Priority = 'Critical'` (protected by `Case_Critical_Priority_Guard` against subsequent SLA downgrades).
  - `Escalation_Reason__c = 'SLA Breach Risk'` (restricted picklist value).
  - `IsEscalated = true` (standard Case boolean flag for dashboard filters and list views).
  - **Reversibility:** costly — drives downstream SLA reporting and dashboard filters.

### Scheduled Path Bulkification & Exit Guard
- **D-06 (Bulk-Safe Execution & Immediate Exit):** Retain and verify decision nodes (`Decision_Is_Case_Still_Open_24h`, `Decision_Is_Case_Still_Open_48h`, `Decision_Is_Case_Still_Open_72h`) checking `IsClosed == false`. If the Case is closed prior to the scheduled offset, the flow path immediately exits with 0 DML or notification actions.
  - **Reversibility:** reversible.

### Antigravity's Discretion
- Formatting and text templates for 24h, 48h, and 72h Chatter feed posts.
- Formatting for the 72h critical escalation email alert subject and body.
- Flow layout naming conventions and clean XML metadata structuring.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Flow & Escalation Metadata
- `force-app/main/default/flows/Case_Escalation_Flow.flow-meta.xml` — Target Flow for scheduled path refactoring, admin lookup, Chatter posts, and 72h telemetry.
- `force-app/main/default/flows/Case_Critical_Priority_Guard.flow-meta.xml` — Before-save flow protecting Critical priority cases from downgrade.

### Schema & Fields
- `force-app/main/default/objects/Case/fields/Escalation_Reason__c.field-meta.xml` — Custom picklist definition (`SLA Breach Risk`).
- `force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml` — Data integrity validation rule verifying locked fields.

### Planning Context
- `.planning/PROJECT.md` — Project context, constraints, and architecture.
- `.planning/REQUIREMENTS.md` — Requirements `ESC-01`, `ESC-02`, `ESC-03`.
- `.planning/ROADMAP.md` — Phase 2 scope, deliverables, and success criteria.
- `.planning/phases/01-sla-entitlement-warning-synchronization/01-CONTEXT.md` — Phase 1 decisions including Priority elevation isolation and Critical Priority guard.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- [Case_Escalation_Flow.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Escalation_Flow.flow-meta.xml): Existing Record-Triggered Flow with 3 scheduled paths (`Path_24_Hours`, `Path_48_Hours`, `Path_72_Hours`) based on `CreatedDate`.
- [Case_Critical_Priority_Guard.flow-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/flows/Case_Critical_Priority_Guard.flow-meta.xml): Before-save flow guarding tickets against downgrade from Critical to High.
- [Escalation_Reason__c.field-meta.xml](file:///home/elsner/Salesforce/SalesforceProject/force-app/main/default/objects/Case/fields/Escalation_Reason__c.field-meta.xml): Picklist containing `SLA Breach Risk`.
- `Case.IsEscalated`: Standard Case boolean field.

### Established Patterns
- AutoLaunched Record-Triggered Flow (`RecordAfterSave`) with scheduled paths.
- Decision element checking `$Record.IsClosed == false` on each path before taking action.
- Dynamic lookup for System Administrator via `Profile.Name = 'System Administrator'` without hardcoded IDs.
- Core Action `postToChatter` or `FeedItem` record creation for internal audit logging.

### Integration Points
- `Case_Record_Page` (Flexipage): Embeds Chatter feed where 24h/48h/72h escalation notices will appear.
- Management Dashboard: Reports filtered by `IsEscalated = true` and `Priority = 'Critical'`.

</code_context>

<specifics>
## Specific Ideas

- **24h Chatter Template:** Proactive reminder on Case feed noting the ticket has been open for 24 hours and tagging the assigned owner.
- **48h Chatter Template:** Escalation alert on Case feed noting 48 hours unresolved and tagging the System Administrator.
- **72h Critical Email & Chatter:** Urgent alert tagging Admin and Case Owner, stamping `Priority = Critical`, `Escalation_Reason__c = SLA Breach Risk`, and `IsEscalated = true`.
- Zero emails at 24h and 48h to prevent inbox congestion; single high-severity email at 72h.

</specifics>

<deferred>
## Deferred Ideas

- **Salesforce Dashboard Component:** Custom dashboard configuration for `IsEscalated = true` tracking across queues (can be added as an operational enhancement in future milestones).
- **Phase 3 (Milestone Auto-Completion Engine - BUG-001):** Automating `CaseMilestone.CompletionDate` on outbound communication and case closure.
- **Phase 4 (SLA Breach Auditing & Data Governance):** Automated breach tracking and validation rule lock enforcement.

</deferred>

---

*Phase: 02-Single-Admin Escalation Engine Governance*  
*Context gathered: 2026-10-28*
