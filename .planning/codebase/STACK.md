# Technology Stack

**Analysis Date:** 2026-10-26

## Languages

**Primary:**
- **Apex (API v67.0 / Winter '27):** Backend business logic, trigger handlers, asynchronous batches, REST webhooks, and Agentforce invocable actions located in `force-app/main/default/classes/` and `force-app/main/default/triggers/`.
- **JavaScript (ES2021+ / LWC):** Frontend presentation components and reactive UI controllers located in `force-app/main/default/lwc/`.

**Secondary:**
- **HTML (LWC Templates):** Shadow DOM templates for Lightning Web Components in `force-app/main/default/lwc/`.
- **CSS:** Scoped styling rules for LWC components in `force-app/main/default/lwc/`.
- **XML:** Salesforce metadata representations (custom fields, objects, layouts, flows, named credentials) across `force-app/main/default/` and manifest files in `manifest/package.xml`.
- **SOQL / SOSL:** Salesforce Object Query Language embedded within Apex queries and utility scripts in `scripts/soql/`.

## Runtime

**Environment:**
- **Salesforce Lightning Platform (Core Runtime):** Multi-tenant cloud engine executing Apex, Lightning Web Components, Flow orchestrations, and data transactions at API version 67.0.
- **Node.js (Local Tooling):** Local development and CI runtime running developer tooling, linting, code formatting, and unit testing via npm scripts.

**Package Manager:**
- **npm (v10+):** Manages local linting and testing tooling via `package.json`.
- Lockfile: `package-lock.json` (present).
- **Salesforce DX CLI (`sf`):** Source tracking and deployment engine configured via `sfdx-project.json`.

## Frameworks

**Core:**
- **Salesforce Lightning Web Components (LWC):** Modern web-standards component architecture for responsive CRM UI (`@wire`, `@api`, track, custom events).
- **Salesforce Apex Enterprise Patterns:** Service layer, Domain trigger handlers, Invocable Actions, DTOs, and asynchronous batch jobs.
- **Salesforce Aura (Legacy Experience):** Authentication and community portal self-registration components in `force-app/main/default/aura/`.

**Testing:**
- **Apex Test Framework:** Standard on-platform test harness using modern `Assert` methods, `@testSetup`, and `HttpCalloutMock` located in `force-app/main/default/classes/*Test.cls`.
- **sfdx-lwc-jest (^7.0.2):** Jest-based unit test runner for Lightning Web Components configured via `jest.config.js`.

**Build/Dev:**
- **ESLint (^9.29.0):** Static code analysis configured via `eslint.config.js` with plugins `@salesforce/eslint-config-lwc` and `@salesforce/eslint-plugin-aura`.
- **Prettier (^3.5.3):** Code formatting engine configured via `.prettierrc` with `prettier-plugin-apex` (^2.2.6) and `@prettier/plugin-xml` (^3.4.1).
- **Husky (^9.1.7) & lint-staged (^16.1.2):** Git pre-commit hooks executing automated Prettier formatting and ESLint checks on staged files.

## Key Dependencies

**Critical:**
- `@salesforce/sfdx-lwc-jest` (^7.0.2): Executes headless client-side unit tests for LWC.
- `prettier-plugin-apex` (^2.2.6): Formats Apex classes, triggers, and anonymous scripts uniformly.
- `@salesforce/eslint-config-lwc` (^4.0.0): Enforces Salesforce security and best-practice rules on LWC client code.

**Infrastructure:**
- `husky` (^9.1.7): Pre-commit hook management.
- `lint-staged` (^16.1.2): Scopes automated verification strictly to staged files.

## Configuration

**Environment:**
- Configured via Salesforce DX workspace settings (`sfdx-project.json`) specifying `sourceApiVersion: "67.0"` and target package directory `force-app`.
- Default org alias and authorization stored in `.sf/` and `.sfdx/` (never committed to repository).
- Target scratch org definition in `config/project-scratch-def.json` using `Developer` edition with `EnableSetPasswordInApi` feature flag.

**Build:**
- Prettier: `.prettierrc` (parsers for Apex, XML, and LWC HTML).
- Linter: `eslint.config.js` (enforces Locker Service and LWC rules).
- Jest: `jest.config.js` (delegates to `@salesforce/sfdx-lwc-jest/config`).
- Packaging Manifests: `manifest/package.xml` and granular manifests in `manifest/`.

## Platform Requirements

**Development:**
- Node.js >= 20.x, npm >= 10.x.
- Salesforce CLI (`sf`).
- VS Code with Salesforce Extension Pack (`.vscode/extensions.json`).
- Local Scratch Org or Developer Edition sandbox authorized via OAuth web login.

**Production:**
- Salesforce Enterprise, Unlimited, or Developer Edition Org (API v67.0).
- Standard CRM Objects: Account, Contact, Opportunity, OpportunityLineItem, Product2, Case, Lead.
- Custom Objects enabled: `Customer_Product__c`, `Customer_Subscription__c`, `Case_Known_Issue__c`, etc.

---

*Stack analysis: 2026-10-26*
