@isTest
private class CRMRecordDetailsAgentActionTest {

    @testSetup
    static void setupTestData() {
        Account testAcc = new Account(
            Name = 'TechNova Cloud Corp',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Type = 'Customer - Direct',
            Phone = '1234567890',
            AnnualRevenue = 5000000
        );
        insert testAcc;

        Contact testCon = new Contact(
            FirstName = 'Mohit',
            LastName = 'Shopify',
            AccountId = testAcc.Id,
            Email = 'mohit.shopify@technova.com',
            Phone = '9876543210',
            Title = 'VP of Engineering',
            Department = 'Technology'
        );
        insert testCon;

        Opportunity testOpp = new Opportunity(
            Name = 'CloudTech Services Deal',
            AccountId = testAcc.Id,
            Primary_Contact__c = testCon.Id,
            StageName = 'Proposal',
            Amount = 85000,
            CloseDate = Date.today().addDays(30),
            Expected_Go_Live_Date__c = Date.today().addDays(60),
            Contract_Signed__c = true
        );
        insert testOpp;

        Lead testLead = new Lead(
            FirstName = 'Vikram',
            LastName = 'Sharma',
            Company = 'Apex Innovations',
            Status = 'Open - Not Contacted',
            Email = 'vikram.sharma@apexinnovations.com',
            Phone = '5551234567',
            Industry = 'Technology',
            Estimated_Budget__c = 120000
        );
        insert testLead;
    }

    @isTest
    static void testOpportunityByName() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'CloudTech Services Deal';
        req.recordType = 'Opportunity';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Opportunity', responses[0].recordType);
        Assert.areEqual('CloudTech Services Deal', responses[0].recordName);
        Assert.areEqual('Proposal', responses[0].stageOrStatus);
        Assert.areEqual(85000, responses[0].amountOrBudget);
        Assert.areEqual('TechNova Cloud Corp', responses[0].parentAccountName);
        Assert.areEqual('Mohit Shopify', responses[0].primaryContactName);
        Assert.isTrue(responses[0].detailsSummary.contains('Proposal'));
        Assert.isTrue(responses[0].detailsSummary.contains('$85,000'));
    }

    @isTest
    static void testOpportunityAutoType() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'CloudTech Services Deal';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Opportunity', responses[0].recordType);
        Assert.areEqual('Proposal', responses[0].stageOrStatus);
    }

    @isTest
    static void testAccountByName() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'TechNova Cloud Corp';
        req.recordType = 'Account';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Account', responses[0].recordType);
        Assert.areEqual('TechNova Cloud Corp', responses[0].recordName);
        Assert.areEqual('Technology', responses[0].titleOrIndustry);
        Assert.areEqual('1234567890', responses[0].phone);
        Assert.isTrue(responses[0].detailsSummary.contains('TechNova Cloud Corp'));
    }

    @isTest
    static void testLeadByName() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'Vikram Sharma';
        req.recordType = 'Lead';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Lead', responses[0].recordType);
        Assert.areEqual('Open - Not Contacted', responses[0].stageOrStatus);
        Assert.areEqual(120000, responses[0].amountOrBudget);
        Assert.areEqual('vikram.sharma@apexinnovations.com', responses[0].email);
        Assert.isTrue(responses[0].detailsSummary.contains('Apex Innovations'));
    }

    @isTest
    static void testContactByName() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'Mohit Shopify';
        req.recordType = 'Contact';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Contact', responses[0].recordType);
        Assert.areEqual('Mohit Shopify', responses[0].recordName);
        Assert.areEqual('TechNova Cloud Corp', responses[0].parentAccountName);
        Assert.areEqual('VP of Engineering', responses[0].titleOrIndustry);
        Assert.areEqual('mohit.shopify@technova.com', responses[0].email);
    }

    @isTest
    static void testDirectIdLookup() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'CloudTech Services Deal' LIMIT 1];

        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = String.valueOf(opp.Id);

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Opportunity', responses[0].recordType);
        Assert.areEqual(opp.Id, responses[0].recordId);
    }

    @isTest
    static void testRecordNotFound() {
        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();
        req.recordName = 'NonExistentCompanyXYZ999';

        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].detailsSummary.contains('Could not find any Opportunity, Account, Lead, or Contact'));
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> emptyResp = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>());
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> nullResp = 
            CRMRecordDetailsAgentAction.getRecordDetails(null);
        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> nullEntryResp = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ null });
        Test.stopTest();

        Assert.areEqual(0, emptyResp.size());
        Assert.areEqual(0, nullResp.size());
        Assert.areEqual(1, nullEntryResp.size());
        Assert.isFalse(nullEntryResp[0].isSuccess);
    }
}

