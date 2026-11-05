# Codebase Concerns

**Analysis Date:** 2026-10-26

## Tech Debt

**Hardcoded Record IDs in Scratch Scripts:**
- Issue: Anonymous Apex execution script `share_opp.apex` contains hardcoded 18-character Salesforce record IDs (`006aj00000dOhJtAAK` and `005aj00000fj5NJAAY`).
- Files: `share_opp.apex`
- Impact: Script will immediately fail when executed against any other org (different sandboxes, scratch orgs, production) because IDs are org-specific.
- Fix approach: Refactor scripts to query records dynamically by name or external ID (`[SELECT Id FROM Opportunity WHERE Name = '...' LIMIT 1]`).

**Temporary Endpoint in Named Credential:**
- Issue: Outbound ERP Named Credential `External_Order_Service` points to a temporary testing URL (`https://webhook.site/5faeabf7-a551-4af5-9ed8-80d767f03c1d`).
- Files: `force-app/main/default/namedCredentials/External_Order_Service.namedCredential-meta.xml`, `force-app/main/default/remoteSiteSettings/WebhookSite.remoteSite-meta.xml`
- Impact: Production transactions or deployments without updated endpoint configurations will send outbound business payloads to an unmonitored temporary test server.
- Fix approach: Update Named Credential URL to point to production/staging ERP endpoint and retire the `WebhookSite` remote site setting.

**Dual UI Frameworks (Aura vs LWC):**
- Issue: Authentication and community login flows utilize legacy Aura components (`force-app/main/default/aura/{loginForm,forgotPassword,selfRegister}`), while internal CRM tools use modern Lightning Web Components (`force-app/main/default/lwc/`).
- Files: `force-app/main/default/aura/`
- Impact: Requires maintaining two distinct frontend tooling pipelines, styling models, and skill sets.
- Fix approach: Migrate legacy Aura authentication components to modern LWC equivalents.

## Known Bugs & Edge Cases

**ERP Sync Re-triggering Logic on Stage Regression:**
- Symptoms: When an Opportunity transitions to `Closed Won`, `OrderNumber__c` is evaluated. If `OrderNumber__c` is already populated from a previous sync and the deal is reopened and won again, outbound ERP sync is skipped.
- Files: `force-app/main/default/classes/OpportunityTriggerHandler.cls:43`
- Trigger: An Opportunity transitions back to `Negotiation/Review` after being `Closed Won`, and is subsequently marked `Closed Won` again.
- Workaround / Fix: Explicitly reset `OrderNumber__c` or track sync status via a dedicated state picklist (e.g. `ERP_Sync_Status__c = 'Pending'`).

## Security Considerations

**Public Inbound REST Webhook Authentication:**
- Risk: Inbound lead capture endpoint `/services/apexrest/v1/webhook/leads/*` (`LeadWebhookRestService.cls`) can be spammed with invalid requests or denial-of-service traffic if external clients do not rotate OAuth tokens.
- Files: `force-app/main/default/classes/LeadWebhookRestService.cls`
- Current mitigation: Enforces `WITH USER_MODE`, performs strict null checks, validates required `name` and `company` fields, rejects negative budgets, and executes email-based duplicate prevention.
- Recommendations: Implement IP range filtering, request rate-limiting, and webhook HMAC signature verification in the header.

**`without sharing` in Analytics and Callout Services:**
- Risk: `Customer360AgentAction.cls` and `ExternalOrderCalloutService.cls` are declared `without sharing`. If exposed indiscriminately to unauthorized user contexts, cross-account financial figures and order details could be visible.
- Files: `force-app/main/default/classes/Customer360AgentAction.cls`, `ExternalOrderCalloutService.cls`
- Current mitigation: `ExternalOrderCalloutService` applies programmatic field stripping via `Security.stripInaccessible(AccessType.READABLE, ...)`.
- Recommendations: Ensure all LWC UI entry points strictly filter accessible accounts and verify caller permissions before passing record IDs into `without sharing` service methods.

## Performance Bottlenecks

**Serial Callout Loop in Trigger Handler:**
- Problem: `ExternalOrderCalloutService.sendOrdersToExternalApi` executes `sendSingleOrderCallout` sequentially within a loop for each won opportunity.
- Files: `force-app/main/default/classes/ExternalOrderCalloutService.cls:57-60`
- Cause: Salesforce strictly limits transactions to a maximum of **100 HTTP callouts**. If a batch or dataloader update marks >100 opportunities as `Closed Won` in a single transaction, the transaction will fail with a `System.CalloutException`.
- Improvement path: Batch outbound callouts into a bulk payload or dispatch individual records via an asynchronous Queueable job (`Database.AllowsCallouts`) with chaining or batch processing.

## Fragile Areas

**Coupled Lifecycle Trigger on Opportunity Closed Won:**
- Files: `force-app/main/default/classes/OpportunityTriggerHandler.cls:63-96`, `force-app/main/default/objects/Customer_Product__c/`
- Why fragile: `createCustomerProducts` executes a synchronous `insert` on `Customer_Product__c`. If any validation rule, required field, or trigger on `Customer_Product__c` fails, the parent Opportunity update to `Closed Won` fails completely, blocking sales reps from closing deals.
- Safe modification: Wrap customer product insertion in `Database.insert(..., false)` (partial success) or decouple creation into an asynchronous Platform Event / Queueable job.
- Test coverage: Covered in `OpportunityTriggerTest.cls`, but needs edge-case testing for custom product validation failures.

## Scaling Limits

**Salesforce Governor Limits:**
- Current capacity:
  - Synchronous Apex SOQL Queries: 100 queries per transaction.
  - SOQL Records Retrieved: 50,000 records.
  - DML Statements: 150 per transaction.
  - HTTP Callouts: 100 per transaction.
- Limit: Large data volume (LDV) batch operations on Opportunities with thousands of line items could approach CPU time (10s synchronous / 60s asynchronous) or query limits.
- Scaling path: Transition heavy calculations to Batchable Apex (`AccountCaseMetricsBatch.cls`) or Queueable Apex.

## Dependencies at Risk

**Jest Dev Dependencies:**
- Risk: `@salesforce/sfdx-lwc-jest` is pinned to `^7.0.2` with `eslint` `^9.29.0`. As Salesforce CLI transitions from `sfdx` to `sf v2`, modern Jest runners need continuous version alignment.
- Impact: Potential version mismatch when running tests against newer Node.js versions (e.g. Node 22+).
- Migration plan: Keep `@salesforce/sfdx-lwc-jest` updated in lockstep with Salesforce CLI releases.

## Missing Critical Features

**Lack of Outbound Retry / Dead-Letter Queue:**
- Problem: If the external ERP endpoint is offline or returns HTTP 500 when an Opportunity is closed, the future callout fails and the order request is dropped.
- Blocks: Automated order fulfillment; requires manual data reconciliation between Salesforce and ERP.
- Solution: Implement a retry mechanism using a custom `Integration_Log__c` object and scheduled batch retry.

## Test Coverage Gaps

**Zero LWC Client-Side Jest Tests:**
- What's not tested: None of the 11 Lightning Web Components have Jest test suites (`customer360Widget`, `aiAssistantWidget`, `dealHealthCard`, `leadScoreBadge`, `opportunityCalculator`, `opportunityPipelineSummary`, `opportunityQuickView`, `quickOpportunityCreator`, `recordAISummaryCard`, `aiEmailDraftModal`).
- Files: `force-app/main/default/lwc/**`
- Risk: Client-side regressions, broken reactive UI bindings, or uncaught JavaScript exceptions can slip into production undetected.
- Priority: **High**. Recommended next step is adding standard Jest tests for high-impact widgets (`customer360Widget`, `quickOpportunityCreator`).

---

*Concerns audit: 2026-10-26*
