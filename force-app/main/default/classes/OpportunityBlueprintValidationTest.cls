@isTest
private class OpportunityBlueprintValidationTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Blueprint Test Account',
            Type = 'Prospect',
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '555-123-4567'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Blueprint Test Deal',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 15000
        );
        insert opp;
    }

    @isTest
    static void testProposalRequiresProposalDate() {
        Opportunity opp = [SELECT Id, StageName, Proposal_Date__c FROM Opportunity WHERE Name = 'Blueprint Test Deal' LIMIT 1];

        // 1. Try to advance to Proposal without Proposal Date -> Expect validation failure
        opp.StageName = 'Proposal';
        opp.Proposal_Date__c = null;
        try {
            update opp;
            Assert.fail('Should have failed validation: Proposal requires Proposal Date');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Proposal Date is required'), 'Expected error message regarding Proposal Date');
        }

        // 2. Advance to Proposal with Proposal Date -> Should succeed
        opp.Proposal_Date__c = Date.today();
        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, StageName, Proposal_Date__c FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Proposal', updatedOpp.StageName, 'Opportunity should successfully advance to Proposal with Proposal Date populated');
    }

    @isTest
    static void testNegotiationRequiresCompetitor() {
        Opportunity opp = [SELECT Id, StageName, Competitor_Count__c FROM Opportunity WHERE Name = 'Blueprint Test Deal' LIMIT 1];

        // 1. Try to advance to Negotiation without Competitor -> Expect validation failure
        opp.StageName = 'Negotiation';
        try {
            update opp;
            Assert.fail('Should have failed validation: Negotiation requires at least one Competitor');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Competitor must be identified'), 'Expected error message regarding Competitor requirement');
        }

        // 2. Add a competitor under this Opportunity
        Competitor__c comp = new Competitor__c(Name = 'Competitor X', Is_Active__c = true);
        insert comp;

        Opportunity_Competitor__c oc = new Opportunity_Competitor__c(
            Opportunity__c = opp.Id,
            Competitor_Master__c = comp.Id,
            Competitor_Unit_Price__c = 1000,
            Quantity__c = 1
        );
        insert oc;

        // 3. Now advance to Negotiation -> Should succeed
        Test.startTest();
        opp.StageName = 'Negotiation';
        update opp;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, StageName, Competitor_Count__c FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Negotiation', updatedOpp.StageName, 'Opportunity should successfully advance to Negotiation with Competitor present');
        Assert.areEqual(1, updatedOpp.Competitor_Count__c, 'Competitor Count should be 1');
    }

    @isTest
    static void testClosedLostRequiresLossReason() {
        Opportunity opp = [SELECT Id, StageName, Loss_Reason__c FROM Opportunity WHERE Name = 'Blueprint Test Deal' LIMIT 1];

        // 1. Try to mark Closed Lost without Loss Reason -> Expect validation failure
        opp.StageName = 'Closed Lost';
        opp.Loss_Reason__c = null;
        try {
            update opp;
            Assert.fail('Should have failed validation: Closed Lost requires Loss Reason');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Loss Reason is required'), 'Expected error message regarding Loss Reason');
        }

        // 2. Mark Closed Lost with Loss Reason -> Should succeed
        opp.Loss_Reason__c = 'Lost on Price to Competitor X';
        Test.startTest();
        update opp;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, StageName, Loss_Reason__c FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Closed Lost', updatedOpp.StageName, 'Opportunity should successfully move to Closed Lost with Loss Reason');
    }
}

