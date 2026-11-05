@isTest
private class Customer360AgentActionTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Alpha Global Enterprise 999',
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '9191112233'
        );
        insert acc;

        Contact testContact = new Contact(
            FirstName = 'Sarah',
            LastName = 'Executive',
            Email = 'sarah.exec@alphaglobal999.com',
            Phone = '9191112233',
            AccountId = acc.Id
        );
        insert testContact;

        Opportunity wonOpp = new Opportunity(
            Name = 'Cloud ERP Deployment',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-10),
            Amount = 120000,
            Contract_Signed__c = true,
            Expected_Go_Live_Date__c = Date.today().addDays(30)
        );
        Opportunity openOpp = new Opportunity(
            Name = 'AI Copilot Add-on',
            AccountId = acc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            Amount = 35000,
            Expected_Go_Live_Date__c = Date.today().addDays(30)
        );
        insert new List<Opportunity>{ wonOpp, openOpp };

        Case supportCase = new Case(
            AccountId = acc.Id,
            Subject = 'SSO Login Configuration',
            Status = 'New',
            Priority = 'High'
        );
        insert supportCase;
    }

    @isTest
    static void testSuccessfulBriefingById() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Alpha Global Enterprise 999' LIMIT 1];

        Customer360AgentAction.Customer360Request req = new Customer360AgentAction.Customer360Request();
        req.accountId = acc.Id;

        Test.startTest();
        List<Customer360AgentAction.Customer360Response> responses = 
            Customer360AgentAction.getExecutiveBriefing(new List<Customer360AgentAction.Customer360Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Alpha Global Enterprise 999', responses[0].accountName);
        Assert.areEqual(120000, responses[0].lifetimeRevenue);
        Assert.areEqual(1, responses[0].openDealsCount);
        Assert.areEqual(1, responses[0].openCasesCount);
        Assert.isTrue(responses[0].executiveBriefing.contains('Platinum Tier'));
    }

    @isTest
    static void testSuccessfulBriefingByName() {
        Customer360AgentAction.Customer360Request req = new Customer360AgentAction.Customer360Request();
        req.accountName = 'Alpha Global Enterprise 999';

        Test.startTest();
        List<Customer360AgentAction.Customer360Response> responses = 
            Customer360AgentAction.getExecutiveBriefing(new List<Customer360AgentAction.Customer360Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Alpha Global Enterprise 999', responses[0].accountName);
    }

    @isTest
    static void testAccountWithZeroRelatedRecords() {
        Account blankAcc = new Account(
            Name = 'Completely Unique Zero Records Startup 777', 
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '9195554433'
        );
        insert blankAcc;

        Customer360AgentAction.Customer360Request req = new Customer360AgentAction.Customer360Request();
        req.accountId = blankAcc.Id;

        Test.startTest();
        List<Customer360AgentAction.Customer360Response> responses = 
            Customer360AgentAction.getExecutiveBriefing(new List<Customer360AgentAction.Customer360Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual(0, responses[0].lifetimeRevenue);
        Assert.areEqual(0, responses[0].openDealsCount);
        Assert.areEqual(0, responses[0].openCasesCount);
    }

    @isTest
    static void testNonExistentAndNullRequests() {
        Customer360AgentAction.Customer360Request req = new Customer360AgentAction.Customer360Request();
        req.accountName = 'Ghost Company Nonexistent 12345';

        Test.startTest();
        List<Customer360AgentAction.Customer360Response> respInvalid = 
            Customer360AgentAction.getExecutiveBriefing(new List<Customer360AgentAction.Customer360Request>{ req });
        List<Customer360AgentAction.Customer360Response> respNull = 
            Customer360AgentAction.getExecutiveBriefing(null);
        Test.stopTest();

        Assert.areEqual(1, respInvalid.size());
        Assert.isFalse(respInvalid[0].isSuccess);
        Assert.areEqual(0, respNull.size());
    }
}
