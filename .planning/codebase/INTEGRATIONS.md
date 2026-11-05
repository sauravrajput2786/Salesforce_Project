# External Integrations

**Analysis Date:** 2026-10-26

## APIs & External Services

**Outbound ERP Order Provisioning:**
- **External Order Service** - Sends Closed Won Opportunity headers, related Account data, Primary Contact info, and OpportunityLineItems to an external ERP for fulfillment.
  - Implementation: `ExternalOrderCalloutService.cls`
  - Client / Mechanism: Apex `HttpRequest` executing via `@future(callout=true)` or `SyncOrderToERPAgentAction.cls`
  - Named Credential: `callout:External_Order_Service` defined in `force-app/main/default/namedCredentials/External_Order_Service.namedCredential-meta.xml`
  - External Credential: `External_Order_Credential` defined in `force-app/main/default/externalCredentials/`
  - Target URL: `https://webhook.site/5faeabf7-a551-4af5-9ed8-80d767f03c1d` (configured for test callout capture)
  - Remote Site Setting: `WebhookSite` in `force-app/main/default/remoteSiteSettings/WebhookSite.remoteSite-meta.xml`
  - Payload Model: Structured JSON payload defined by `ExternalOrderPayloadDTO.cls`

**Inbound Website Webhook:**
- **Lead Capture REST API** - Ingests external website marketing submissions to create or update Salesforce Leads.
  - Implementation: `LeadWebhookRestService.cls`
  - Resource URI: `/services/apexrest/v1/webhook/leads/*`
  - Auth: Salesforce OAuth 2.0 Bearer Token (Connected App / External Client App)
  - Handling: Deserializes inbound payload into `LeadInboundPayload`, executes mandatory field validation (`name`, `company`), enforces positive budget rules, and executes de-duplication against existing Lead email records using `WITH USER_MODE`.

**Postman Collection:**
- `Salesforce_Day26_REST_API.postman_collection.json` - Collection for testing inbound webhook endpoints and authentication contracts.

## Data Storage

**Databases:**
- **Salesforce Lightning Core Database:**
  - Multi-tenant relational object store accessed natively via SOQL, SOSL, and DML.
  - Standard CRM Objects: `Account`, `Contact`, `Opportunity`, `OpportunityLineItem`, `Product2`, `Case`, `Lead`.
  - Custom Objects:
    - `Customer_Product__c` (`force-app/main/default/objects/Customer_Product__c/`)
    - `Customer_Subscription__c` (`force-app/main/default/objects/Customer_Subscription__c/`)
    - `Opportunity_Competitor__c` (`force-app/main/default/objects/Opportunity_Competitor__c/`)
    - `Competitor__c` (`force-app/main/default/objects/Competitor__c/`)
    - `Customer_Onboarding__c` (`force-app/main/default/objects/Customer_Onboarding__c/`)
    - `Known_Issue__c` (`force-app/main/default/objects/Known_Issue__c/`)
    - `Case_Known_Issue__c` (`force-app/main/default/objects/Case_Known_Issue__c/`)
    - `Sales_Handoff__c` (`force-app/main/default/objects/Sales_Handoff__c/`)
    - `Subscription_Product__c` (`force-app/main/default/objects/Subscription_Product__c/`)
    - `Book__c`, `Loan__c`, `Member__c` (Library domain objects)

**File Storage:**
- Salesforce Files & ContentAssets (`force-app/main/default/contentassets/`).

**Caching:**
- Salesforce Platform Cache / Client-side LWC caching (`@wire` reactive service cache and `refreshApex`).

## Authentication & Identity

**Auth Provider:**
- **Salesforce OAuth 2.0 & Identity:**
  - External Client Apps configured in `force-app/main/default/externalClientApps/`, `extlClntAppOauthPolicies/`, and `extlClntAppGlobalOauthSets/`.
  - Experience Cloud Authentication: Custom Aura components and Apex controllers providing self-registration, password reset, and login in `force-app/main/default/aura/` (`CommunitiesLoginController.cls`, `CommunitiesSelfRegController.cls`, `ForgotPasswordController.cls`, `LightningLoginFormController.cls`).

## Monitoring & Observability

**Error Tracking:**
- Handled via `System.debug(LoggingLevel.ERROR, ...)` and transactional try-catch blocks in service and controller layers.
- Custom validation and status responses returned to callers (`AssistantResponse`, `LeadWebhookResponse`).

**Logs:**
- Salesforce standard Apex Execution Logs and Flow Orchestration Logs (`force-app/main/default/objects/FlowOrchestrationLog/`).

## CI/CD & Deployment

**Hosting:**
- Salesforce Cloud Infrastructure (Production / Scratch / Sandbox environments).

**CI Pipeline:**
- Husky pre-commit hooks (`.husky/pre-commit`) triggering Prettier formatting (`prettier --write`) and ESLint validation (`eslint`) on staged files prior to Git commit.

## Environment Configuration

**Required env vars / Org Settings:**
- Target org authentication alias (configured via `sf org login web` or JWT auth).
- Named Credential endpoint target: `callout:External_Order_Service`.
- Remote Site Setting active: `force-app/main/default/remoteSiteSettings/WebhookSite.remoteSite-meta.xml`.

**Secrets location:**
- Stored exclusively on-platform within Salesforce Named Credentials, External Credentials, and Protected Custom Metadata. No plaintext secrets or passwords in source control.

## Webhooks & Callbacks

**Incoming:**
- Endpoint: `/services/apexrest/v1/webhook/leads/*` (`LeadWebhookRestService.cls`)
  - Method: `HTTP POST`
  - Purpose: Real-time lead capture from marketing forms.

**Outgoing:**
- Endpoint: `callout:External_Order_Service` (`ExternalOrderCalloutService.cls`)
  - Method: `HTTP POST`
  - Trigger: Asynchronous after Opportunity transitions to `Closed Won`.

---

*Integration audit: 2026-10-26*
