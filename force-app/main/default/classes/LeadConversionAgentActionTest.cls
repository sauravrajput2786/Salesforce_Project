@isTest
private class LeadConversionAgentActionTest {

    @testSetup
    static void setupTestData() {
        Lead testLead = new Lead(
            FirstName = 'Sarah',
            LastName = 'Jenkins',
            Company = 'Sarah Enterprise Tech 999',
            Email = 'sarah.jenkins@jenkinscloud999.com',
            Country = 'United States',
            Industry = 'Agriculture',
            Phone = '9199887711',
            Status = 'New'
        );
        insert testLead;
    }

    @isTest
    static void testSuccessfulLeadConversionById() {
        Lead target = [SELECT Id FROM Lead WHERE Email = 'sarah.jenkins@jenkinscloud999.com' LIMIT 1];

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = target.Id;
        req.opportunityName = 'Jenkins Cloud - Enterprise Tier';
        req.amount = 75000;

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size(), 'Should return 1 response');
        Assert.isTrue(responses[0].isSuccess, 'Conversion should succeed: ' + responses[0].message);
        Assert.isNotNull(responses[0].accountId, 'Account ID must be created');
        Assert.isNotNull(responses[0].contactId, 'Contact ID must be created');
        Assert.isNotNull(responses[0].opportunityId, 'Opportunity ID must be created');

        Opportunity opp = [SELECT Id, Amount, Name FROM Opportunity WHERE Id = :responses[0].opportunityId];
        Assert.areEqual(75000, opp.Amount);
        Assert.areEqual('Jenkins Cloud - Enterprise Tier', opp.Name);
    }

    @isTest
    static void testSuccessfulLeadConversionByEmailAndCountry() {
        Lead testLead2 = new Lead(
            FirstName = 'Arun',
            LastName = 'Verma',
            Company = 'Arun Global Logistics 888',
            Email = 'arun.verma@vermalogistics888.com',
            Country = 'United States',
            Industry = 'Agriculture',
            Phone = '9199887722',
            Status = 'New'
        );
        insert testLead2;

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.email = 'arun.verma@vermalogistics888.com';
        req.billingCountry = 'United States';
        req.industry = 'Agriculture';
        req.phone = '9199887722';

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess, 'Conversion by email should succeed: ' + responses[0].message);
        Assert.isNotNull(responses[0].accountId);
    }

    @isTest
    static void testAlreadyConvertedLeadHandling() {
        Lead target = [SELECT Id FROM Lead WHERE Email = 'sarah.jenkins@jenkinscloud999.com' LIMIT 1];

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = target.Id;

        LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> secondRun = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, secondRun.size());
        Assert.isFalse(secondRun[0].isSuccess);
        Assert.isTrue(secondRun[0].message.contains('already converted'));
    }

    @isTest
    static void testNonExistentAndNullRequests() {
        LeadConversionAgentAction.LeadConversionRequest invalidReq = new LeadConversionAgentAction.LeadConversionRequest();
        invalidReq.email = 'nobody@nonexistentdomain.com';

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> respInvalid = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ invalidReq });
        List<LeadConversionAgentAction.LeadConversionResponse> respEmpty = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>());
        List<LeadConversionAgentAction.LeadConversionResponse> respNull = 
            LeadConversionAgentAction.convertLead(null);
        Test.stopTest();

        Assert.areEqual(1, respInvalid.size());
        Assert.isFalse(respInvalid[0].isSuccess);
        Assert.areEqual(0, respEmpty.size());
        Assert.areEqual(0, respNull.size());
    }

    @isTest
    static void testSuccessfulLeadConversionByName() {
        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadName = 'Sarah Jenkins';
        req.opportunityName = 'Jenkins Cloud Global';
        req.amount = 50000;

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.isNotNull(responses[0].accountId);
        Assert.isNotNull(responses[0].opportunityId);
    }

    @isTest
    static void testLeadConversionWithExistingAccountLink() {
        Account existingAcc = new Account(
            Name = 'Existing Corporate Client',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Type = 'Customer',
            Phone = '9998887777'
        );
        insert existingAcc;

        Lead leadForExisting = new Lead(
            FirstName = 'Rohan',
            LastName = 'Kapoor',
            Company = 'Existing Corporate Client',
            Email = 'rohan.kapoor@existingcorp.com',
            Country = 'United States',
            Industry = 'Technology',
            Phone = '9998887777',
            Status = 'New'
        );
        insert leadForExisting;

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = leadForExisting.Id;

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual(existingAcc.Id, responses[0].accountId, 'Should link to the existing account rather than duplicating');
    }

    @isTest
    static void testMissingMandatoryValidationPrompt() {
        Lead incompleteLead = new Lead(
            FirstName = 'Incomplete',
            LastName = 'Candidate',
            Company = 'Incomplete Corp',
            Email = 'incomplete@example.com',
            Status = 'New'
        );
        insert incompleteLead;

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = incompleteLead.Id;

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('the following mandatory details are required'));
    }

    @isTest
    static void testClosedWonRequirementsPrompt() {
        Lead target = [SELECT Id FROM Lead WHERE Email = 'sarah.jenkins@jenkinscloud999.com' LIMIT 1];

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = target.Id;
        req.stageName = 'Closed Won';

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('Expected Go-Live Date'));
    }

    @isTest
    static void testLeadNamePassedIntoLeadIdField() {
        Lead testLead3 = new Lead(
            FirstName = 'Kavita',
            LastName = 'Patel',
            Company = 'Patel Global Analytics',
            Email = 'kavita.patel@patelanalytics77.com',
            Country = 'United States',
            Industry = 'Agriculture',
            Phone = '9199887733',
            Status = 'New'
        );
        insert testLead3;

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.leadId = 'Kavita Patel'; // Natural language string passed into leadId slot
        req.opportunityName = 'Patel Analytics Deal';
        req.amount = 45000;

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess, 'Should convert successfully with lead name in leadId: ' + responses[0].message);
        Assert.isNotNull(responses[0].accountId);
        Assert.isNotNull(responses[0].opportunityId);
    }

    @isTest
    static void testSuccessfulLeadConversionByCompany() {
        Lead testLead4 = new Lead(
            FirstName = 'Vikram',
            LastName = 'Malhotra',
            Company = 'Malhotra Cloud Systems',
            Email = 'vikram@malhotracloud.com',
            Country = 'United States',
            Industry = 'Agriculture',
            Phone = '9199887744',
            Status = 'New'
        );
        insert testLead4;

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();
        req.company = 'Malhotra Cloud Systems';
        req.opportunityName = 'Malhotra Cloud Deal';

        Test.startTest();
        List<LeadConversionAgentAction.LeadConversionResponse> responses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess, 'Should convert successfully with company name: ' + responses[0].message);
        Assert.isNotNull(responses[0].accountId);
    }
}
