@isTest
private class DealApprovalAgentActionTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Discount Testing Corp', 
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '1234567890'
        );
        insert acc;

        Contact testContact = new Contact(
            FirstName = 'Alex',
            LastName = 'Buyer',
            Email = 'alex.buyer@discountcorp.com',
            Phone = '1234567890',
            AccountId = acc.Id
        );
        insert testContact;

        Opportunity opp = new Opportunity(
            Name = 'Enterprise Analytics Solution',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(20),
            Amount = 100000,
            Expected_Go_Live_Date__c = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testStandardDiscountUnder20Percent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Enterprise Analytics Solution' LIMIT 1];

        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityId = opp.Id;
        req.discountPercent = 15;
        req.reason = 'Quarter end incentive';

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess, 'Discount should succeed: ' + responses[0].message);
        Assert.isFalse(responses[0].needsApproval, 'Discounts <= 20% should not require approval');
        Assert.areEqual(100000, responses[0].originalAmount);
        Assert.areEqual(85000, responses[0].discountedAmount);

        Opportunity updatedOpp = [SELECT Id, Amount FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual(85000, updatedOpp.Amount);
    }

    @isTest
    static void testHighDiscountOver20Percent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Enterprise Analytics Solution' LIMIT 1];

        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityId = opp.Id;
        req.discountPercent = 30;
        req.reason = 'Large strategic volume deal';

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess, 'High discount should succeed: ' + responses[0].message);
        Assert.isTrue(responses[0].needsApproval, 'Discounts > 20% must trigger approval workflow');
        Assert.areEqual(70000, responses[0].discountedAmount);
    }

    @isTest
    static void testClosedOpportunityRejection() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Contact c = [SELECT Id FROM Contact WHERE Email = 'alex.buyer@discountcorp.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Enterprise Analytics Solution' LIMIT 1];
        opp.Primary_Contact__c = c.Id;
        opp.Contract_Signed__c = true;
        opp.Expected_Go_Live_Date__c = Date.today().addDays(30);
        opp.Amount = 100000;
        opp.CloseDate = Date.today();
        opp.StageName = 'Closed Won';
        update opp;

        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityId = opp.Id;
        req.discountPercent = 10;

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('already Closed Won'));
    }

    @isTest
    static void testInvalidDiscountAndNullRequests() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Enterprise Analytics Solution' LIMIT 1];

        DealApprovalAgentAction.DealApprovalRequest reqInvalid = new DealApprovalAgentAction.DealApprovalRequest();
        reqInvalid.opportunityId = opp.Id;
        reqInvalid.discountPercent = 95;

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> respInvalid = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ reqInvalid });
        List<DealApprovalAgentAction.DealApprovalResponse> respNull = 
            DealApprovalAgentAction.evaluateDealDiscount(null);
        Test.stopTest();

        Assert.areEqual(1, respInvalid.size());
        Assert.isFalse(respInvalid[0].isSuccess);
        Assert.areEqual(0, respNull.size());
    }

    @isTest
    static void testDiscountByName() {
        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityName = 'Enterprise Analytics Solution';
        req.discountPercent = 10;
        req.reason = 'Standard incentive';

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Approved', responses[0].approvalStatus);
        Assert.areEqual(90000, responses[0].discountedAmount);
    }

    @isTest
    static void testMissingReasonForHighDiscountPrompt() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Enterprise Analytics Solution' LIMIT 1];

        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityId = opp.Id;
        req.discountPercent = 25;
        // reason is omitted

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('requires a business justification'));
    }

    @isTest
    static void testOpportunityNotFound() {
        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.opportunityName = 'NonExistentDeal999';
        req.discountPercent = 10;

        Test.startTest();
        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('Could not find any matching Opportunity'));
    }
}
