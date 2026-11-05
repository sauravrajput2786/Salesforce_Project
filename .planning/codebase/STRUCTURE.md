# Codebase Structure

**Analysis Date:** 2026-10-27

## Directory Layout

```
salesforce-project/
├── .agents/                          # GSD workflow skills, templates, hooks, and configuration
├── .husky/                           # Git pre-commit hook triggering automated code verification
├── .vscode/                          # Editor settings, extensions, and launch profiles
├── config/                           # Salesforce scratch org definition files
│   └── project-scratch-def.json      # Developer edition scratch org template
├── force-app/                        # Core Salesforce DX package directory
│   └── main/
│       └── default/                  # Default package namespace and metadata source
│           ├── aura/                 # Legacy Aura components (authentication and login)
│           ├── classes/              # Apex classes, controllers, services, actions, and tests
│           ├── contentassets/        # Static assets, branding, and imagery
│           ├── customMetadata/       # Configurable business logic metadata
│           ├── externalClientApps/   # OAuth client configurations
│           ├── externalCredentials/  # Callout authentication credentials
│           ├── flexipages/           # Lightning App and Record Page layout definitions (e.g. Case_Record_Page)
│           ├── flows/                # Declarative Service & Sales Flows (Gatekeeper, AutoLinker, Resolvers)
│           ├── layouts/              # Traditional page layout assignments
│           ├── lwc/                  # Lightning Web Components (modern UI)
│           ├── namedCredentials/     # External endpoint connection definitions
│           ├── objects/              # Standard and Custom Object schema definitions
│           │   ├── Account/          # Account schema & validation rules
│           │   ├── Case/             # Case schema, validation rules, record types, business processes
│           │   ├── Case_Known_Issue__c/ # Junction object connecting Case and Known Issue
│           │   ├── Customer_Product__c/ # Subscribed products and renewal dates
│           │   ├── Known_Issue__c/   # Engineering defects and workarounds
│           │   └── Opportunity/      # Opportunity schema & validation rules
│           ├── permissionsets/       # User security and access permission sets
│           ├── presenceUserConfigs/  # Omni-Channel user presence and capacity configurations
│           ├── queueRoutingConfigs/  # Omni-Channel queue routing and weighting configurations
│           ├── queues/               # Support and sales queue definitions
│           ├── remoteSiteSettings/   # Authorized outbound callout domains
│           ├── staticresources/      # Bundled third-party libraries and CSS
│           └── triggers/             # Apex database triggers
├── manifest/                         # Deployment and retrieval metadata manifests (package.xml)
├── scripts/                          # Developer scratchpad scripts
│   ├── apex/                         # Anonymous Apex execution scripts
│   └── soql/                         # Reusable SOQL query definitions
├── eslint.config.js                  # ESLint flat config with LWC and Aura rules
├── jest.config.js                    # LWC Jest unit test configuration
├── package.json                      # Node.js dev dependencies, scripts, and pre-commit config
├── package-lock.json                 # NPM deterministic dependency tree
├── sfdx-project.json                 # Salesforce DX project definition and API version mapping
└── .prettierrc                       # Prettier formatting rules for Apex, LWC, and XML
```

## Directory Purposes

**`force-app/main/default/flexipages/`:**
- Purpose: Declarative Lightning Record Pages and Console Workspaces.
- Contains: XML layout definitions (`.flexipage-meta.xml`).
- Key files:
  - `Case_Record_Page.flexipage-meta.xml`: 3-column Lightning Service Console workspace embedding contact history, feed, milestone SLA tracker, knowledge base, and related known issues.

**`force-app/main/default/flows/`:**
- Purpose: Service Cloud declarative orchestration, automated intake, and mass resolution engines.
- Contains: Flow definition metadata (`.flow-meta.xml`).
- Key files:
  - `Case_Entitlement_Gatekeeper.flow-meta.xml`: **Pillar 1** Before-save flow assigning Gold, Silver, or Platinum SLA entitlements.
  - `Case_Known_Issue_AutoLinker.flow-meta.xml`: **Pillar 3** After-save AI defect matcher and customer workaround dispatcher.
  - `Case_Repeat_Contact_Intelligence.flow-meta.xml`: **Pillar 3** After-save sibling linking and priority elevation.
  - `Case_Cascading_Resolution_Engine.flow-meta.xml`: **Pillar 3** After-save resolution propagation from root cases to open siblings.
  - `Known_Issue_Mass_Resolver.flow-meta.xml`: **Pillar 3** After-save bulk resolution engine on defect fix.
  - `Case_Escalation_Flow.flow-meta.xml`: Scheduled SLA milestone and notification flow.

**`force-app/main/default/objects/Case/`:**
- Purpose: Case data model, life-cycle policies, validation rules, and record types.
- Contains:
  - `validationRules/`:
    - `VR_Case_Require_Resolution_On_Close.validationRule-meta.xml`: Enforces mandatory resolution type and summary on closure.
    - `VR_Case_Require_Product_Tech_Bugs.validationRule-meta.xml`: Mandates customer product selection for technical defects.
    - `VR_Case_Lock_Customer_And_SLA_Data.validationRule-meta.xml`: Prevents agent tampering with customer intake data and assigned SLA entitlements.
  - `recordTypes/Technical_Support.recordType-meta.xml`: Record type for technical bugs, outages, and software defects.
  - `businessProcesses/Technical_Support_Process.businessProcess-meta.xml`: Stage progression (`New`, `Working`, `Escalated`, `Closed`).
  - `listViews/Technical_Support_Queue_Case.listView-meta.xml`: Queue monitoring view for incoming technical tickets.

**`force-app/main/default/queues/` & `force-app/main/default/queueRoutingConfigs/`:**
- Purpose: Omni-Channel routing definitions and queue assignment.
- Contains:
  - `queues/Technical_Support_Queue.queue-meta.xml`: **Pillar 2** Queue for technical support cases tied to Omni-Channel routing.
  - `queueRoutingConfigs/Case_Omni_Routing.queueRoutingConfig-meta.xml`: **Pillar 2** Routing model (`MOST_AVAILABLE`, Priority 1).
  - `presenceUserConfigs/Support_Agent_Omni_Config.presenceUserConfig-meta.xml`: **Pillar 2** Agent presence configuration (3-unit concurrent capacity limit).

**`force-app/main/default/classes/`:**
- Purpose: All backend application logic, APIs, and tests.
- Contains: Apex classes (`.cls`) and metadata descriptors (`.cls-meta.xml`).
- Key files: `AIAssistantController.cls`, `OpportunityTriggerHandler.cls`, `ExternalOrderCalloutService.cls`, `LeadWebhookRestService.cls`, `AccountCaseMetricsBatch.cls`.

**`force-app/main/default/triggers/`:**
- Purpose: Database event routing for standard and custom SObjects.
- Key files: `OpportunityTrigger.trigger`, `OpportunityCompetitorTrigger.trigger`, `SubscriptionProductTrigger.trigger`.

**`force-app/main/default/lwc/`:**
- Purpose: Modern responsive UI components built with Lightning Web Components.
- Key files: `customer360Widget`, `aiAssistantWidget`, `opportunityPipelineSummary`, `quickOpportunityCreator`.

## Key File Locations

**Service Cloud Pillars (Pillars 1 to 3):**
- **Pillar 1 (SLA Gatekeeper):** `force-app/main/default/flows/Case_Entitlement_Gatekeeper.flow-meta.xml`
- **Pillar 2 (Omni Routing):** `force-app/main/default/queues/Technical_Support_Queue.queue-meta.xml`, `force-app/main/default/queueRoutingConfigs/Case_Omni_Routing.queueRoutingConfig-meta.xml`
- **Pillar 3 (AI Defect Linker):** `force-app/main/default/flows/Case_Known_Issue_AutoLinker.flow-meta.xml`
- **Pillar 3 (Repeat Intelligence):** `force-app/main/default/flows/Case_Repeat_Contact_Intelligence.flow-meta.xml`
- **Pillar 3 (Cascading Engine):** `force-app/main/default/flows/Case_Cascading_Resolution_Engine.flow-meta.xml`
- **Pillar 3 (Mass Resolver):** `force-app/main/default/flows/Known_Issue_Mass_Resolver.flow-meta.xml`
- **Pillar 3 (Closure Validation):** `force-app/main/default/objects/Case/validationRules/VR_Case_Require_Resolution_On_Close.validationRule-meta.xml`
- **Service Console Workspace (UI):** `force-app/main/default/flexipages/Case_Record_Page.flexipage-meta.xml`

**Sales & Core Integration:**
- Opportunity Pipeline: `force-app/main/default/classes/OpportunityTriggerHandler.cls`, `DealHealthService.cls`
- Inbound Webhook: `force-app/main/default/classes/LeadWebhookRestService.cls`
- ERP Callout: `force-app/main/default/classes/ExternalOrderCalloutService.cls`
- Agentforce Invocable Actions: `force-app/main/default/classes/*AgentAction.cls`

## Naming Conventions

**Salesforce Metadata:**
- **Flows:** UpperCamelCase with descriptive snake_case segments (`Case_Entitlement_Gatekeeper`, `Case_Known_Issue_AutoLinker`, `Case_Cascading_Resolution_Engine`).
- **Validation Rules:** Prefixed with `VR_<Object>_<RuleName>` (`VR_Case_Require_Resolution_On_Close`, `VR_Case_Require_Product_Tech_Bugs`, `VR_Case_Lock_Customer_And_SLA_Data`).
- **Queues:** Descriptive PascalCase with `_Queue` suffix (`Technical_Support_Queue`, `Customer_Support_Queue`).
- **Queue Routing Configs:** UpperCamelCase (`Case_Omni_Routing`).
- **Flexipages:** UpperCamelCase with descriptive suffix (`Case_Record_Page.flexipage-meta.xml`).
- **Record Types & Support Processes:** UpperCamelCase (`Technical_Support`, `Technical_Support_Process`).
- **Apex Classes:** PascalCase with functional suffix (`AIAssistantController`, `DealHealthService`, `AccountCaseMetricsBatch`).

## Where to Add New Code

**Service Cloud Automated Logic:**
- **SLA & Field Defaults (Before-Save):** Add logic elements inside `force-app/main/default/flows/Case_Entitlement_Gatekeeper.flow-meta.xml` or create new `RecordBeforeSave` flows on `Case` for zero-DML execution.
- **Cross-Object Intelligence & Alerts (After-Save):** Add new flows under `force-app/main/default/flows/` configured for `RecordAfterSave`, ensuring collection loops update via a single bulk `recordUpdates` element outside loops.
- **Data Integrity & Entry Validation:** Add XML definitions under `force-app/main/default/objects/<Object>/validationRules/VR_<Object>_<RuleName>.validationRule-meta.xml`.
- **Omni-Channel Routing:** Add queue configs under `force-app/main/default/queues/` and routing definitions under `force-app/main/default/queueRoutingConfigs/`.
- **Agent Workspaces & Flexipages:** Configure regions and facet tabs under `force-app/main/default/flexipages/`.

---

*Structure analysis: 2026-10-27*
