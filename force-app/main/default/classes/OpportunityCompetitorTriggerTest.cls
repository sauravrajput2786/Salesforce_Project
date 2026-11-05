@isTest
private class OpportunityCompetitorTriggerTest {
    
    @testSetup
    static void setupTestData() {
        // Create parent Account satisfying all validation rules (BillingCountry, Industry, Type)
        Account acc = new Account(
            Name = 'Test Account for Competitor',
            Type = 'Prospect',
            BillingCountry = 'United States',
            Industry = 'Agriculture'
        );
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp with Account',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        );
        insert opp;

        // Create Competitor Master
        Competitor__c comp = new Competitor__c(
            Name = 'Competitor ABC',
            Is_Active__c = true
        );
        insert comp;
    }

    @isTest
    static void testAutoPopulateAccountOnInsert() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opp with Account' LIMIT 1];
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor ABC' LIMIT 1];

        Test.startTest();
        Opportunity_Competitor__c oc = new Opportunity_Competitor__c(
            Opportunity__c = opp.Id,
            Competitor_Master__c = comp.Id,
            Competitor_Unit_Price__c = 500,
            Quantity__c = 2
        );
        insert oc;
        Test.stopTest();

        // Verify Account__c was automatically populated by trigger
        Opportunity_Competitor__c insertedOC = [
            SELECT Id, Account__c, Opportunity__c 
            FROM Opportunity_Competitor__c 
            WHERE Id = :oc.Id
        ];
        Assert.areEqual(opp.AccountId, insertedOC.Account__c, 'Account__c should be auto-populated from parent Opportunity');
    }

    @isTest
    static void testAutoPopulateAccountOnUpdate() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opp with Account' LIMIT 1];
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor ABC' LIMIT 1];

        Opportunity_Competitor__c oc = new Opportunity_Competitor__c(
            Opportunity__c = opp.Id,
            Competitor_Master__c = comp.Id,
            Competitor_Unit_Price__c = 300,
            Quantity__c = 1
        );
        insert oc;

        Test.startTest();
        oc.Account__c = null;
        update oc;
        Test.stopTest();

        Opportunity_Competitor__c updatedOC = [
            SELECT Id, Account__c 
            FROM Opportunity_Competitor__c 
            WHERE Id = :oc.Id
        ];
        Assert.areEqual(opp.AccountId, updatedOC.Account__c, 'Account__c should be repopulated from Opportunity on update if cleared');
    }

    @isTest
    static void testBulkOpportunityCompetitors() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opp with Account' LIMIT 1];
        Competitor__c comp = [SELECT Id FROM Competitor__c WHERE Name = 'Competitor ABC' LIMIT 1];

        List<Opportunity_Competitor__c> ocList = new List<Opportunity_Competitor__c>();
        for (Integer i = 0; i < 50; i++) {
            ocList.add(new Opportunity_Competitor__c(
                Opportunity__c = opp.Id,
                Competitor_Master__c = comp.Id,
                Competitor_Unit_Price__c = 100 + i,
                Quantity__c = 1
            ));
        }

        Test.startTest();
        insert ocList;
        Test.stopTest();

        List<Opportunity_Competitor__c> insertedList = [
            SELECT Id, Account__c 
            FROM Opportunity_Competitor__c 
            WHERE Opportunity__c = :opp.Id
        ];
        Assert.areEqual(50, insertedList.size(), 'All 50 records should be inserted');
        for (Opportunity_Competitor__c item : insertedList) {
            Assert.areEqual(opp.AccountId, item.Account__c, 'Every record must have Account__c populated');
        }
    }
}
