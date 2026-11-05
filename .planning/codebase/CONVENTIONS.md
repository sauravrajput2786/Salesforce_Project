# Coding Conventions

**Analysis Date:** 2026-10-26

## Naming Patterns

**Files:**
- Apex Classes: PascalCase with functional suffix (`OpportunityTriggerHandler.cls`, `ExternalOrderCalloutService.cls`, `AIAssistantController.cls`).
- Apex Tests: PascalCase with `Test` suffix (`OpportunityTriggerTest.cls`, `DealHealthServiceTest.cls`).
- Apex Mocks: PascalCase with `Mock` suffix (`ExternalOrderCalloutMock.cls`).
- Apex Triggers: PascalCase named after SObject (`OpportunityTrigger.trigger`).
- LWC Bundles & Files: camelCase matching folder name (`customer360Widget.js`, `customer360Widget.html`).
- Metadata XML files: Matching component filename plus specific metadata extension (`.cls-meta.xml`, `.js-meta.xml`, `.flow-meta.xml`).

**Methods / Functions:**
- Apex Methods: camelCase starting with action verbs (`handleBeforeInsert`, `sendOrdersToExternalApi`, `createCustomerProducts`, `getRecordDetails`).
- LWC Functions / Handlers: camelCase with `handle` prefix for events (`handleRefresh`, `handleInputChange`, `handleQuickActionClick`).
- LWC Getters: camelCase starting with `has` or describing the value (`hasData`, `formattedRevenue`, `accountLocation`).

**Variables:**
- Apex Local Variables: camelCase with clear nouns (`newOpportunities`, `customerProductsToInsert`, `rawWonOpportunities`).
- Apex Collections: Plural nouns or descriptive collection names (`wonOpportunityIds`, `lineItems`, `oppToLineItems`).
- Apex Constants: UPPER_SNAKE_CASE (`NAMED_CREDENTIAL_ENDPOINT`).
- LWC Properties: camelCase (`isLoading`, `errorMessage`, `customer360`).

**Types & Classes:**
- Apex Classes / Interfaces: PascalCase (`Customer360Wrapper`, `OpportunityPipelineDTO`).
- Inner Request / Response DTOs: PascalCase (`Customer360Request`, `AssistantResponse`, `LeadInboundPayload`).

## Code Style

**Formatting:**
- **Tool:** Prettier (^3.5.3) configured in `.prettierrc`.
- **Plugins:** `prettier-plugin-apex` (^2.2.6) for Apex formatting; `@prettier/plugin-xml` (^3.4.1) for Salesforce metadata XML files.
- **Rules:**
  - Trailing commas: `none`.
  - Indentation: 4 spaces for Apex and LWC JS/HTML.
  - Bracket spacing and line wraps automatically normalized on pre-commit via Husky and lint-staged.

**Linting:**
- **Tool:** ESLint (^9.29.0) using Flat Config format in `eslint.config.js`.
- **Rulesets:**
  - `@salesforce/eslint-config-lwc/recommended` for LWC components.
  - `@salesforce/eslint-plugin-aura` (recommended and locker rules) for Aura components.
  - Wire adapter security and DOM interaction rules strictly enforced.

## Import Organization

**Order (LWC JavaScript):**
1. Core LWC standard primitives (`import { LightningElement, api, wire, track } from 'lwc';`).
2. Salesforce Apex controller methods (`import getCustomer360Data from '@salesforce/apex/Customer360Controller.getCustomer360Data';`).
3. Salesforce platform modules (`import { refreshApex } from '@salesforce/apex';`, `@salesforce/schema/...`, `@salesforce/label/...`).
4. Toast / Navigation / Modal utilities (`import { ShowToastEvent } from 'lightning/platformShowToastEvent';`).
5. Local helper files or sibling components.

**Path Aliases:**
- Salesforce DX namespace aliases (`@salesforce/apex/*`, `@salesforce/schema/*`, `@salesforce/user/*`) resolved automatically via generated TypeScript typings in `.sfdx/typings/lwc/`.

## Error Handling

**Patterns:**
- **Guard Clauses:** Defensive checks for `null` and empty collections at the beginning of methods (`if (newOpportunities == null || newOpportunities.isEmpty()) return;`).
- **User-Facing Responses:** Never leak raw stack traces or database errors to the client. Wrap responses in structured status objects containing `isSuccess` (Boolean) and user-friendly `message` strings (see `AIAssistantController.AssistantResponse` and `LeadWebhookRestService.LeadWebhookResponse`).
- **HTTP Webhook Errors:** Set explicit HTTP status codes on `RestContext.response` (`res.statusCode = 400;` on validation failure, `200` on success).
- **Transactional Safety:** Wrap external HTTP callouts in try-catch blocks and log diagnostic information using `System.debug(LoggingLevel.ERROR, ...)` before throwing or handling errors.

## Logging

**Framework:** Native Salesforce `System.debug` using explicit `LoggingLevel`.

**Patterns:**
- Errors: `System.debug(LoggingLevel.ERROR, 'External Order Callout Failed for Opportunity ' + opp.Id + ': ' + ex.getMessage());`
- Info / Integration Payloads: `System.debug(LoggingLevel.INFO, 'External Order Callout Response [' + response.getStatusCode() + ']: ' + response.getBody());`
- Anonymous Apex Verification: Structured log prefixes (`TEST_RESULT: ...`, `SHARE_CREATED: ...`) to enable automated test log parsing.

## Comments

**When to Comment:**
- Use comments to explain non-obvious business rules, transaction boundaries, or multi-step logic.
- Avoid obvious comments that merely repeat code keywords.

**ApexDoc / JSDoc:**
- Top of classes and public methods decorated with `@description`, `@param`, and `@return` tags.
- Example pattern:
  ```apex
  /**
   * @description Handles after update logic on Opportunity.
   * Identifies Opportunities transitioning to 'Closed Won' and triggers
   * the outbound asynchronous integration callout to external ERP/REST API.
   * @param newOpportunities List of updated Opportunity records (Trigger.new)
   * @param oldOpportunitiesMap Map of pre-update Opportunity records (Trigger.oldMap)
   */
  ```

## Function & Method Design

**Size:**
- Single Responsibility: Methods target a discrete business operation (e.g. `createCustomerProducts` separated from trigger routing logic).
- Long methods refactored into smaller private helper methods.

**Parameters:**
- Maximum 3-4 parameters for public methods; larger parameter lists are encapsulated in typed DTOs or Request wrapper classes (e.g. `Customer360Request`).

**Return Values:**
- Trigger handler methods return `void`.
- Inbound API and LWC controller methods return typed DTOs or collections rather than generic `Object` maps.

## Module Design

**Apex Visibility:**
- Classes default to `public with sharing` for CRM boundary code.
- Inbound webhooks use `global with sharing`.
- Integration callout services use `public without sharing` only when executing automated background sync across system-owned records.

**LWC Exports:**
- Standard default export extending `LightningElement` (`export default class Customer360Widget extends LightningElement`).

---

*Convention analysis: 2026-10-26*
