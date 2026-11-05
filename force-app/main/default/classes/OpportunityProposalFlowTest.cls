@isTest
private class OpportunityProposalFlowTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Proposal Flow Account',
            Type = 'Prospect',
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '555-987-6543'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Proposal Flow Deal',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 20000
        );
        insert opp;
    }

    @isTest
    static void testTransitionToProposalCreatesTaskAndPreventsDuplicates() {
        Opportunity opp = [SELECT Id, OwnerId, StageName, Proposal_Date__c FROM Opportunity WHERE Name = 'Proposal Flow Deal' LIMIT 1];

        // 1. Transition to Proposal stage with Proposal Date populated (satisfying Day 10 validation)
        Test.startTest();
        opp.Proposal_Date__c = Date.today();
        opp.StageName = 'Proposal';
        update opp;
        Test.stopTest();

        // 2. Verify Follow-up Task is created
        List<Task> tasks = [
            SELECT Id, Subject, WhatId, OwnerId, Priority, Status, ActivityDate 
            FROM Task 
            WHERE WhatId = :opp.Id
        ];

        Assert.areEqual(1, tasks.size(), 'Exactly one follow-up Task should be created upon reaching Proposal stage');
        Assert.isTrue(tasks[0].Subject.contains('Proposal Flow Deal'), 'Task subject should reference Opportunity Name');
        Assert.areEqual(opp.OwnerId, tasks[0].OwnerId, 'Task should be assigned to the Opportunity Owner');
        Assert.areEqual('High', tasks[0].Priority, 'Proposal task should be High priority');
        Assert.areEqual('Not Started', tasks[0].Status, 'Task status should be Not Started');
        Assert.areEqual(Date.today().addDays(3), tasks[0].ActivityDate, 'Task should be due in 3 days');

        // 3. Architectural Idempotency Check: Subsequent edits without stage change must NOT create duplicate tasks
        opp.Amount = 25000;
        update opp;

        List<Task> tasksAfterEdit = [SELECT Id FROM Task WHERE WhatId = :opp.Id];
        Assert.areEqual(1, tasksAfterEdit.size(), 'Editing the record in the same stage must NOT create duplicate tasks');
    }
}

