<!-- refreshed: 2026-10-27 -->
# Architecture

**Analysis Date:** 2026-10-27

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 Presentation Layer (UI)                                 │
├───────────────────────────────┬─────────────────────────────┬───────────────────────────┤
│    Agentforce AI Widgets      │     Pipeline & Deal Cards   │   Case Console (Flexipage)│
│  `force-app/.../lwc/ai...`    │  `force-app/.../lwc/deal...`│  `Case_Record_Page` (3-Col)│
└───────────────┬───────────────┴──────────────┬──────────────┴───────────────┬───────────┘
                │                              │                              │
                ▼                              ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      Intake, Validation & Omni-Channel Routing Layer                    │
│   Validation Rules: `VR_Case_Require_Product_Tech_Bugs`, `VR_Case_Lock_Customer_And_SLA`│
│   Routing: `Technical_Support_Queue` -> `Case_Omni_Routing` (MOST_AVAILABLE, Priority 1) │
│   Presence Config: `Support_Agent_Omni_Config` (Capacity: 3)                             │
└───────────────┬──────────────────────────────┬──────────────────────────────┬───────────┘
                │                              │                              │
                ▼                              ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                    Service Cloud Pillars & Declarative Automation Layer                 │
│   Pillar 1: `Case_Entitlement_Gatekeeper` (Before-Save Entitlement & SLA Assignment)    │
│   Pillar 2: Technical Support Queue & Omni-Channel Routing Engine                       │
│   Pillar 3: `Case_Known_Issue_AutoLinker` (AI keyword matching -> Chatter + Workaround) │
│             `Case_Repeat_Contact_Intelligence` (Sibling deduplication & root linking)   │
│             `Case_Cascading_Resolution_Engine` (Cascade root closure to siblings)       │
│             `Known_Issue_Mass_Resolver` (Mass-close linked cases on defect fix)         │
│             `VR_Case_Require_Resolution_On_Close` (Enforce resolution data on close)    │
└───────────────┬──────────────────────────────┬──────────────────────────────┬───────────┘
                │                              │                              │
                ▼                              ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                   Controllers & Inbound Entry Points (Sales / Core)                     │
│   `AIAssistantController.cls`       `OpportunityPipelineController.cls`                 │
│   `LeadWebhookRestService.cls`      (`@RestResource /v1/webhook/leads`)                 │
└───────────────┬──────────────────────────────┬──────────────────────────────┬───────────┘
                │                              │                              │
                ▼                              ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│             Agentforce Action & Orchestration Layer (Apex Invocables)                   │
│   `Customer360AgentAction.cls`       `CRMRecordDetailsAgentAction.cls`                  │
│   `DealApprovalAgentAction.cls`      `LeadConversionAgentAction.cls`                    │
│   `ScheduleFollowUpAgentAction.cls`  `SyncOrderToERPAgentAction.cls`                    │
└───────────────┬──────────────────────────────┬──────────────────────────────┬───────────┘
                │                              │                              │
                ▼                              ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      Business Logic, Domain & Persistence Layer                         │
│   `DealHealthService.cls`            `LeadScoringService.cls`                           │
│   `ExternalOrderCalloutService.cls`  `AccountCaseMetricsBatch.cls`                      │
│   Triggers: `OpportunityTrigger`, `OpportunityCompetitorTrigger`                        │
│   Relational Schema: `Case`, `Account`, `Customer_Product__c`, `Case_Known_Issue__c`    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `Case_Entitlement_Gatekeeper` | **Pillar 1:** Before-save trigger inspecting Account Tier and active `Customer_Product__c` to dynamically assign SLA Entitlements (Gold 60m, Silver 240m, Platinum 480m). | `force-app/main/default/flows/Case_Entitlement_Gatekeeper.flow-meta.xml` |
| `Technical_Support_Queue` | **Pillar 2:** Routing destination for technical support cases, bugs, and outages, paired with Omni-Channel routing. | `force-app/main/default/queues/Technical_Support_Queue.queue-meta.xml` |
| `Case_Omni_Routing` | **Pillar 2:** Queue routing config dispatching cases via `MOST_AVAILABLE` routing model at priority 1 (unit weight 1.0). | `force-app/main/default/queueRoutingConfigs/Case_Omni_Routing.queueRoutingConfig-meta.xml` |
| `Support_Agent_Omni_Config` | **Pillar 2:** Omni-Channel presence config capping agent capacity at 3 concurrent items with decline options. | `force-app/main/default/presenceUserConfigs/Support_Agent_Omni_Config.presenceUserConfig-meta.xml` |
| `Technical_Support` (Record Type) | **Pillar 2:** Dedicated case record type for defects, bugs, and API outages utilizing `Technical_Support_Process`. | `force-app/main/default/objects/Case/recordTypes/Technical_Support.recordType-meta.xml` |
| `Case_Known_Issue_AutoLinker` | **Pillar 3:** After-save flow scanning active `Known_Issue__c` records for keywords (`504`, `Timeout`, `Outage`), creating `Case_Known_Issue__c`, posting Chatter workarounds, and emailing customers. | `force-app/main/default/flows/Case_Known_Issue_AutoLinker.flow-meta.xml` |
| `Case_Repeat_Contact_Intelligence` | **Pillar 3:** After-save intake flow matching new cases against active siblings; flags repeat contact, sets priority High, links to root case, and alerts Chatter. | `force-app/main/default/flows/Case_Repeat_Contact_Intelligence.flow-meta.xml` |
| `Case_Cascading_Resolution_Engine` | **Pillar 3:** After-save flow cascading resolution details and closure from a root primary case to all linked open sibling cases. | `force-app/main/default/flows/Case_Cascading_Resolution_Engine.flow-meta.xml` |
| `Known_Issue_Mass_Resolver` | **Pillar 3:** After-save flow triggered when a `Known_Issue__c` is resolved, bulk-closing all linked open cases with patch verification notes. | `force-app/main/default/flows/Known_Issue_Mass_Resolver.flow-meta.xml` |
| `VR_Case_Require_Resolution_On_Close` | **Pillar 3:** Data validation rule requiring `Resolution_Type__c` and `Resolution_Summary__c` before closing any Case. | `force-app/main/default/objects/Case/validationRules/VR_Case_Require_Resolution_On_Close.validationRule-meta.xml` |
| `VR_Case_Require_Product_Tech_Bugs` | **Pillar 3 Data Governance:** Enforces that `Customer_Product__c` is populated for Technical Support cases on creation. | `force-app/main/default/objects/Case/validationRules/VR_Case_Require_Product_Tech_Bugs.validationRule-meta.xml` |
| `VR_Case_Lock_Customer_And_SLA_Data` | **Enterprise Data Integrity:** Locks customer intake data (Account, Contact, Origin, Product) and Entitlement SLA fields against post-creation tampering. | `force-app/main/default/objects/Case/validationRules/VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml` |
| `Case_Record_Page` (Flexipage) | **Service Cloud UI:** Desktop 3-column Lightning Console workspace embedding customer history, feed, details, milestone SLA tracker, and known issue junction lists. | `force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml` |
| `AIAssistantController` | Enterprise AI Copilot router, intent parser, and guardrail enforcement. | `force-app/main/default/classes/AIAssistantController.cls` |
| `Customer360AgentAction` | Invocable Agent action aggregating 360-degree customer metrics. | `force-app/main/default/classes/Customer360AgentAction.cls` |
| `OpportunityTriggerHandler` | Before-insert deal classification, after-update Closed Won product creation & ERP dispatch. | `force-app/main/default/classes/OpportunityTriggerHandler.cls` |
| `ExternalOrderCalloutService` | Asynchronous outbound HTTP POST dispatch to ERP via Named Credential. | `force-app/main/default/classes/ExternalOrderCalloutService.cls` |
| `LeadWebhookRestService` | Inbound REST endpoint for external website lead capture and de-duplication. | `force-app/main/default/classes/LeadWebhookRestService.cls` |

## Service Cloud Pillars Architecture Deep Dive

### Pillar 1: Smart Gatekeeper & Automated SLA Entitlement Assignment

- **Execution Phase:** Fast Field Update (`RecordBeforeSave` on `Case` create).
- **Trigger Filters:** `AccountId != null` AND `EntitlementId == null`.
- **Architectural Mechanism:**
  1. Executes SOQL lookups against `Account` (to extract `Customer__c` tier) and `Customer_Product__c` (to verify active subscription with `Status__c = 'Active'` and `Renewal_Date__c >= TODAY`).
  2. If an active product exists, routes through a tier decision matrix:
     - **Gold Tier (Rank 1):** Assigns Gold Entitlement (60-minute target SLA).
     - **Silver Tier (Rank 2):** Assigns Silver Entitlement (240-minute target SLA).
     - **Platinum Tier (Rank 3):** Assigns Platinum Entitlement (480-minute target SLA).
  3. Direct in-memory assignment to `$Record.EntitlementId` requires zero additional DML cycles.
  4. Secured by `VR_Case_Lock_Customer_And_SLA_Data`, preventing manual modification of `EntitlementId` or intake data after record creation.

### Pillar 2: Technical Support Intake & Omni-Channel Routing Infrastructure

- **Routing Pipeline:**
  - Case created with `RecordType = Technical_Support` and routed to `Technical_Support_Queue`.
  - Queue is governed by `Case_Omni_Routing` using the `MOST_AVAILABLE` distribution model with priority `1` and weight `1.0`.
  - Agent capacity is managed by `Support_Agent_Omni_Config` (assigned to `Admin` and `Standard` profiles) capping open tickets at `3` concurrent units with agent decline capabilities.
- **Intake Governance:**
  - `Technical_Support_Process` defines standard case lifecycle phases: `New` -> `Working` -> `Escalated` -> `Closed`.
  - `VR_Case_Require_Product_Tech_Bugs` enforces mandatory association with `Customer_Product__c` for all non-Other technical bugs at inception.

### Pillar 3: AI Defect Auto-Linker, Repeat Contact Intelligence & Mass Resolution Engine

- **AI Defect Linker (`Case_Known_Issue_AutoLinker`):**
  - RecordAfterSave flow triggered on Case creation/update when open and `Type != 'Other'`.
  - Queries active defects (`Known_Issue__c` in `Investigating` or `In Progress`).
  - Evaluates formula expression `fx_Is504TimeoutMatch` against Subject and Description (`504`, `Timeout`, `Outage`).
  - Idempotently creates `Case_Known_Issue__c` junction records, drops verified engineering workaround to the Case Chatter feed, and triggers an automated `emailSimple` notification to the customer.
- **Repeat Contact Intelligence (`Case_Repeat_Contact_Intelligence`):**
  - Smooth intake alternative replacing legacy strict blocking.
  - Queries open sibling tickets sharing `AccountId`, `Customer_Product__c`, `RecordTypeId`, and `Type`.
  - Flags incoming case as `Is_Repeat_Contact__c = true`, links it to the root case via `Related_Open_Case__c`, elevates priority to `High`, posts alert to root case Chatter feed, and emails customer with primary case reference.
- **Cascading Resolution Engine (`Case_Cascading_Resolution_Engine`):**
  - Triggered when a root Case (`Related_Open_Case__c IS NULL`) moves to `Status = 'Closed'`.
  - Queries all linked open sibling cases and copies `Resolution_Type__c` and `Resolution_Summary__c`.
  - Bulk updates sibling records in a single DML statement outside loops.
- **Known Issue Mass Resolver (`Known_Issue_Mass_Resolver`):**
  - Triggered when a `Known_Issue__c` status moves to `Resolved` or `Closed`.
  - Queries junction table `Case_Known_Issue__c`, identifies all linked open cases, applies the release version patch notes, and executes a bulk update to `Status = 'Closed'`.
- **Closure Gatekeeper:**
  - `VR_Case_Require_Resolution_On_Close` guarantees that programmatic or manual closure cannot bypass `Resolution_Type__c` and `Resolution_Summary__c`.

## Presentation Layer (Flexipages & Lightning Console)

The primary service interface is defined in `Case_Record_Page.flexipage-meta.xml`:
- **Layout Template:** `flexipage:recordHomeThreeColTemplateDesktop` (Lightning Console 3-column desktop layout).
- **Left Column (Context & Caller 360):**
  - Compact case updater (`console:relatedRecord` via `Case._LightningUpdateCase`).
  - Contact quick card (`console:relatedRecord` via `Contact._LightningRelatedContact`).
  - Caller history (`force:relatedListSingleContainer` displaying contact's past cases).
- **Center Column (Investigation & Collaboration):**
  - Highlights Panel (`force:highlightsPanel`).
  - Tabset containing:
    - **Feed Tab:** `forceChatter:recordFeedContainer` for real-time collaboration and automated workaround posts.
    - **Detail Tab:** `force:detailPanel` for full record attributes.
- **Right Column (Resolution, SLA & Defect Intelligence):**
  - Live SLA tracker (`support:milestones`) showing real-time countdown to entitlement milestones.
  - Sub-tabset:
    - **Knowledge Tab:** `forceKnowledge:articleSearchDesktop` for one-click knowledge search.
    - **Related Lists Tab:**
      - Linked Known Issues (`Case_Known_Issues__r`).
      - Linked Repeat Follow-up Cases (`Repeat_Follow_up_Cases__r`).
      - Files, Open Activities, and Activity History.

## Data Flow: End-to-End Case Lifecycle

```text
1. Case Intake (Web, Email, Portal, or Internal)
   │
   ▼
2. Before-Save Trigger: `Case_Entitlement_Gatekeeper`
   ├─ Check Account Tier & Active Customer_Product__c
   └─ Assign Gold (60m), Silver (240m), or Platinum (480m) Entitlement
   │
   ▼
3. Pre-Commit Validation Rules
   ├─ `VR_Case_Require_Product_Tech_Bugs` (Verify product linked)
   └─ `VR_Case_Lock_Customer_And_SLA_Data` (Enforce intake immutability)
   │
   ▼
4. Database Insert Commit
   │
   ▼
5. Omni-Channel Routing Dispatch
   └─ `Technical_Support_Queue` -> `Case_Omni_Routing` -> Available Agent
   │
   ▼
6. After-Save Automation Pipeline
   ├─ `Case_Repeat_Contact_Intelligence`
   │    └─ Match Sibling Cases? -> Yes: Link to Root Case, Priority High, Notify Customer
   │
   └─ `Case_Known_Issue_AutoLinker`
        └─ Match Defect Keywords (504/Timeout/Outage)?
             └─ Yes: Create `Case_Known_Issue__c`, Post Chatter, Email Customer Workaround
   │
   ▼
7. Case Resolution & Closure Paths
   ├─ Path A: Single Root Closure -> `Case_Cascading_Resolution_Engine` closes siblings
   ├─ Path B: Engineering Fix -> `Known_Issue_Mass_Resolver` mass-closes all linked tickets
   └─ Both paths enforced by `VR_Case_Require_Resolution_On_Close`
```

## Architectural Constraints & Best Practices

- **Zero-DML Before-Save Logic:** Entitlement assignment is strictly placed in `RecordBeforeSave` to avoid DML governor limits and recursive trigger cascades.
- **Bulk Safe Automation:** Flows iterating over collections (`Known_Issue_Mass_Resolver`, `Case_Cascading_Resolution_Engine`) perform variable accumulation inside loops and invoke a single bulk DML `recordUpdates` element outside loops.
- **Recursion Prevention:** Cascading resolution requires `Related_Open_Case__c IS NULL` on the trigger filter, preventing cyclic updates between siblings.
- **Data Immutability:** Sensitive customer intake and SLA metrics are strictly guarded via validation rules to preserve compliance and audit trails.

---

*Architecture analysis: 2026-10-27*
