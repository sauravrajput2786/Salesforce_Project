# Testing Patterns

**Analysis Date:** 2026-10-26

## Test Framework

**Runner:**
- **Apex Backend:** Native Salesforce Apex Test Execution Engine (API v67.0).
- **LWC Frontend:** `@salesforce/sfdx-lwc-jest` (^7.0.2) running Jest 28 in Node.js environment.
- Config: `jest.config.js` and `package.json`.

**Assertion Library:**
- Modern Apex `Assert` class (`Assert.areEqual`, `Assert.areNotEqual`, `Assert.isTrue`, `Assert.isFalse`).
- Jest standard assertions (`expect(...).toBe(...)`, `expect(...).toEqual(...)`) for LWC.

**Run Commands:**
```bash
# Apex unit test execution via Salesforce CLI
sf apex test run --code-coverage --result-format human           # Run all Apex tests in default org
sf apex test run --class-names OpportunityTriggerTest --result-format human  # Run single test class

# LWC Jest unit tests via npm scripts
npm run test:unit             # Run all LWC Jest unit tests
npm run test:unit:watch       # Run LWC tests in interactive watch mode
npm run test:unit:coverage    # Generate LWC code coverage report
```

## Test File Organization

**Location:**
- Apex Tests: Co-located in `force-app/main/default/classes/` alongside implementation files.
- LWC Tests (Standard Pattern): Co-located inside `__tests__/` subdirectory within each component bundle (e.g. `force-app/main/default/lwc/customer360Widget/__tests__/customer360Widget.test.js`).

**Naming:**
- Apex Test Classes: Matches target class name with `Test` suffix (`OpportunityPipelineControllerTest.cls` tests `OpportunityPipelineController.cls`).
- Apex Mock Classes: Matches target service with `Mock` suffix (`ExternalOrderCalloutMock.cls`).
- LWC Test Files: `<componentName>.test.js`.

**Structure:**
```
force-app/main/default/classes/
├── OpportunityPipelineController.cls
├── OpportunityPipelineController.cls-meta.xml
├── OpportunityPipelineControllerTest.cls
└── OpportunityPipelineControllerTest.cls-meta.xml
```

## Test Structure

**Suite Organization (Apex):**
```apex
@isTest
private class OpportunityPipelineControllerTest {

    @testSetup
    static void setupTestData() {
        // 1. Create prerequisite test account
        Account acc = new Account(
            Name = 'Pipeline Test Corp',
            Industry = 'Banking',
            Type = 'Prospect'
        );
        insert acc;

        // 2. Create test opportunities
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp Qual', AccountId = acc.Id, StageName = 'Qualification', Amount = 100000.00, CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Opp Disc', AccountId = acc.Id, StageName = 'Discovery', Amount = 150000.00, CloseDate = Date.today().addDays(30))
        };
        insert opps;
    }

    @isTest
    static void testGetPipelineSummarySuccess() {
        Test.startTest();
        OpportunityPipelineDTO.PipelineResult result = OpportunityPipelineController.getPipelineSummary();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(250000.00, result.grandTotalAmount, 'Grand total should equal sum of open amounts');
        Assert.areEqual(2, result.totalDeals, 'Total deals count should match inserted records');
    }
}
```

**Patterns:**
- **Setup Pattern:** Always use `@testSetup static void setupTestData()` to insert baseline records once per test class execution. Tests execute against isolated rollbacks.
- **Governor Limit Reset:** Wrap core execution block in `Test.startTest()` and `Test.stopTest()` to provide a fresh set of governor limits and force asynchronous tasks (`@future`, batch) to complete synchronously before assertion.
- **Assertion Pattern:** Use modern `Assert` methods with descriptive error messages explaining what went wrong if the assertion fails.

## Mocking

**Framework:**
- Native `HttpCalloutMock` interface implementation.

**Patterns (HTTP Callout Mocking):**
```apex
public class ExternalOrderCalloutMock implements HttpCalloutMock {
    protected Integer statusCode;
    protected String status;
    protected String bodyAsString;

    public ExternalOrderCalloutMock(Integer statusCode, String bodyAsString) {
        this.statusCode = statusCode;
        this.bodyAsString = bodyAsString;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        response.setBody(this.bodyAsString);
        response.setStatusCode(this.statusCode);
        return response;
    }
}

// In test class:
Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status": "SUCCESS", "orderId": "ORD-123"}'));
```

**What to Mock:**
- Outbound HTTP callouts to external web endpoints (e.g. `ExternalOrderCalloutService`).
- Simulated external error codes (e.g. HTTP 400, 500 responses) to verify exception and retry pathways.

**What NOT to Mock:**
- Internal database operations (SOQL/DML): Apex tests run in a test-isolated database sandbox; test records must be created and inserted using real SObjects to trigger validation rules, workflows, and triggers.

## Fixtures and Factories

**Test Data Strategy:**
- Programmatic record creation inside `@testSetup` methods.
- Satisfies all org Validation Rules (e.g. required Phone, Country, Type on Account; required line items and Go-Live dates on Closed Won Opportunities).
- Uses `Test.getStandardPricebookId()` when setting up PricebookEntries and Products.

**Location:**
- Declared inline within `@testSetup` in each test class (`force-app/main/default/classes/*Test.cls`).

## Coverage

**Requirements:**
- Salesforce deployment gate strictly requires a minimum of **75% overall Apex code coverage**, with 0 trigger failures.
- Recommended target for core business services is **>85%**.

**View Coverage:**
```bash
sf apex test run --code-coverage --result-format human
```

## Test Types

**Unit Tests (Apex):**
- Test individual controller methods, service calculations, and DTO mappings in isolation using `@isTest`.
- Cover positive scenarios, negative/empty inputs, and boundary limits.

**Integration Tests (Trigger to External Callout):**
- Verify end-to-end trigger invocation, asynchronous dispatch, and callout generation (e.g. `OpportunityTrigger` -> `OpportunityTriggerHandler` -> `ExternalOrderCalloutService`).

**LWC Unit Tests:**
- Test component DOM rendering, `@wire` reactive data propagation, and user click handlers in Node.js via `sfdx-lwc-jest`.

## Common Patterns

**Async Testing (Future & Batch):**
```apex
Test.startTest();
Database.executeBatch(new AccountCaseMetricsBatch(), 200);
Test.stopTest(); // Forces asynchronous batch execution to complete before assertions
```

**Error & Validation Testing:**
```apex
@isTest
static void testNegativeBudgetValidation() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/v1/webhook/leads';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{"name":"Jane Doe","company":"Acme","budget":-500}');
    RestContext.request = req;

    Test.startTest();
    LeadWebhookRestService.LeadWebhookResponse res = LeadWebhookRestService.handleInboundLead();
    Test.stopTest();

    Assert.areEqual('ERROR', res.status, 'Negative budget must fail validation');
    Assert.areEqual(400, RestContext.response.statusCode, 'Status code must be 400');
}
```

---

*Testing analysis: 2026-10-26*
