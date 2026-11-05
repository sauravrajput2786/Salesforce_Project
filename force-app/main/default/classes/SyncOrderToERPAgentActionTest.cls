@isTest
private class SyncOrderToERPAgentActionTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Global Manufacturing Corp 999', 
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '9194443322'
        );
        insert acc;

        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Manufacturer',
            Email = 'john@globalmfg999.com',
            Phone = '9194443322',
            AccountId = acc.Id
        );
        insert testContact;

        Opportunity wonOpp = new Opportunity(
            Name = 'Heavy Machinery Deal',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 150000,
            Contract_Signed__c = true,
            Expected_Go_Live_Date__c = Date.today().addDays(30)
        );

        Opportunity openOpp = new Opportunity(
            Name = 'Spare Parts Supply',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(15),
            Amount = 45000
        );

        insert new List<Opportunity>{ wonOpp, openOpp };
    }

    @isTest
    static void testSuccessfulSyncAlreadyClosedWon() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Opportunity wonOpp = [SELECT Id FROM Opportunity WHERE Name = 'Heavy Machinery Deal' LIMIT 1];

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = wonOpp.Id;

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);
        Assert.isTrue(responses[0].message.contains('dispatched to ERP'));
    }

    @isTest
    static void testValidationRequiredWhenContractAndDateMissing() {
        Opportunity openOpp = [SELECT Id FROM Opportunity WHERE Name = 'Spare Parts Supply' LIMIT 1];

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = openOpp.Id;
        req.markClosedWon = true;

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.areEqual('VALIDATION_REQUIRED', responses[0].status);
        Assert.isTrue(responses[0].message.contains('Contract Signed confirmation'));
        Assert.isTrue(responses[0].message.contains('Expected Go-Live Date'));
    }

    @isTest
    static void testSyncWithExplicitContractAndDateConfirmation() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Opportunity openOpp = [SELECT Id FROM Opportunity WHERE Name = 'Spare Parts Supply' LIMIT 1];

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = openOpp.Id;
        req.markClosedWon = true;
        req.contractSigned = true;
        req.expectedGoLiveDate = Date.today().addDays(45);

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);

        Opportunity updated = [SELECT Id, StageName, Contract_Signed__c, Expected_Go_Live_Date__c FROM Opportunity WHERE Id = :openOpp.Id];
        Assert.areEqual('Closed Won', updated.StageName);
        Assert.isTrue(updated.Contract_Signed__c);
        Assert.areEqual(Date.today().addDays(45), updated.Expected_Go_Live_Date__c);
    }

    @isTest
    static void testRejectionIfNotClosedWon() {
        Opportunity openOpp = [SELECT Id FROM Opportunity WHERE Name = 'Spare Parts Supply' LIMIT 1];

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = openOpp.Id;
        req.markClosedWon = false;

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.areEqual('REJECTED', responses[0].status);
    }

    @isTest
    static void testIdempotencyDuplicateSync() {
        Opportunity wonOpp = [SELECT Id, Description FROM Opportunity WHERE Name = 'Heavy Machinery Deal' LIMIT 1];
        wonOpp.Description = '[ERP Sync Triggered] Already processed';
        update wonOpp;

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = wonOpp.Id;

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('ALREADY_SYNCED', responses[0].status);
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> respEmpty = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>());
        List<SyncOrderToERPAgentAction.SyncOrderResponse> respNull = 
            SyncOrderToERPAgentAction.syncOrderToERP(null);
        Test.stopTest();

        Assert.areEqual(0, respEmpty.size());
        Assert.areEqual(0, respNull.size());
    }

    @isTest
    static void testSyncByOpportunityName() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityName = 'Heavy Machinery Deal';

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);
        Assert.isNotNull(responses[0].orderNumber);
    }

    @isTest
    static void testNotFoundSync() {
        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityName = 'NonExistentDeal999';

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.areEqual('ERROR', responses[0].status);
    }

    @isTest
    static void testAutoResolvePrimaryContactFromParentAccount() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Account acc = [SELECT Id FROM Account WHERE Name = 'Global Manufacturing Corp 999' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

        Opportunity oppNoContact = new Opportunity(
            Name = 'Deal Without Contact',
            AccountId = acc.Id,
            Primary_Contact__c = null,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30),
            Amount = 80000
        );
        insert oppNoContact;

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = oppNoContact.Id;
        req.markClosedWon = true;
        req.contractSigned = true;
        req.expectedGoLiveDate = Date.today().addDays(20);

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);

        Opportunity updated = [SELECT Id, StageName, Primary_Contact__c FROM Opportunity WHERE Id = :oppNoContact.Id];
        Assert.areEqual('Closed Won', updated.StageName);
        Assert.areEqual(testContact.Id, updated.Primary_Contact__c);
    }

    @isTest
    static void testExplicitPrimaryContactSuccess() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Account acc = [SELECT Id FROM Account WHERE Name = 'Global Manufacturing Corp 999' LIMIT 1];
        Contact testContact = [SELECT Id, Email FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

        Opportunity oppNoContact = new Opportunity(
            Name = 'Deal With Explicit Contact',
            AccountId = acc.Id,
            Primary_Contact__c = null,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30),
            Amount = 50000
        );
        insert oppNoContact;

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = oppNoContact.Id;
        req.contactNameOrEmail = testContact.Email;
        req.markClosedWon = true;
        req.contractSigned = true;
        req.expectedGoLiveDate = Date.today().addDays(25);

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);

        Opportunity updated = [SELECT Id, Primary_Contact__c FROM Opportunity WHERE Id = :oppNoContact.Id];
        Assert.areEqual(testContact.Id, updated.Primary_Contact__c);
    }

    @isTest
    static void testExplicitPrimaryContactSecurityRejection() {
        Account otherAcc = new Account(
            Name = 'External Competitor Corp', 
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '9998887777'
        );
        insert otherAcc;

        Contact otherContact = new Contact(
            FirstName = 'Unauthorized',
            LastName = 'Person',
            Email = 'unauth@othercorp.com',
            AccountId = otherAcc.Id
        );
        insert otherContact;

        Opportunity openOpp = [SELECT Id FROM Opportunity WHERE Name = 'Spare Parts Supply' LIMIT 1];

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = openOpp.Id;
        req.contactNameOrEmail = 'Unauthorized Person';

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.areEqual('REJECTED', responses[0].status);
        Assert.isTrue(responses[0].message.contains('Security Policy Violation'));
    }

    @isTest
    static void testDynamicAmountUpdateOnSync() {
        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status":"SUCCESS"}'));

        Account acc = [SELECT Id FROM Account WHERE Name = 'Global Manufacturing Corp 999' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

        Opportunity zeroAmountOpp = new Opportunity(
            Name = 'Zero Amount Deal',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30),
            Amount = 0
        );
        insert zeroAmountOpp;

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.opportunityId = zeroAmountOpp.Id;
        req.amount = 555;
        req.markClosedWon = true;
        req.contractSigned = true;
        req.expectedGoLiveDate = Date.today().addDays(10);

        Test.startTest();
        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('SYNCED', responses[0].status);

        Opportunity updated = [SELECT Id, Amount, StageName FROM Opportunity WHERE Id = :zeroAmountOpp.Id];
        Assert.areEqual(555, updated.Amount);
        Assert.areEqual('Closed Won', updated.StageName);
    }
}
