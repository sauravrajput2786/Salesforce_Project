@isTest
private class ScheduleFollowUpAgentActionTest {

    @testSetup
    static void setupTestData() {
        Account testAcc = new Account(
            Name = 'Agentforce Test Account',
            BillingCountry = 'United States',
            Industry = 'Agriculture',
            Phone = '1234567890'
        );
        insert testAcc;

        Opportunity testOpp = new Opportunity(
            Name = 'Cloud Migration Deal',
            AccountId = testAcc.Id,
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(30),
            Amount = 50000
        );
        insert testOpp;
    }

    @isTest
    static void testSuccessfulTaskWithOpportunity() {
        Opportunity opp = [SELECT Id, OwnerId FROM Opportunity WHERE Name = 'Cloud Migration Deal' LIMIT 1];

        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.opportunityId = opp.Id;
        req.subject = 'Contract Terms Discussion';
        req.dueDate = Date.today().addDays(5);
        req.notes = 'Client agreed to proceed if discount is under 15%';
        req.priority = 'High';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size(), 'Should return exactly 1 response matching request');
        Assert.isTrue(responses[0].isSuccess, 'Task creation should be successful');
        Assert.isNotNull(responses[0].taskId, 'Task ID should be populated');
        Assert.isTrue(responses[0].message.contains('Contract Terms Discussion'), 'Message should contain subject');

        Task createdTask = [SELECT Id, Subject, WhatId, OwnerId, Priority, ActivityDate, Description 
                            FROM Task WHERE Id = :responses[0].taskId];
        Assert.areEqual('Contract Terms Discussion', createdTask.Subject);
        Assert.areEqual(opp.Id, createdTask.WhatId);
        Assert.areEqual(opp.OwnerId, createdTask.OwnerId, 'Task must be assigned to Opportunity Owner');
        Assert.areEqual('High', createdTask.Priority);
        Assert.areEqual(Date.today().addDays(5), createdTask.ActivityDate);
    }

    @isTest
    static void testSuccessfulTaskWithoutOpportunityDefaults() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordName = 'Agentforce Test Account';
        req.subject = 'Initial Discovery Call';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.isNotNull(responses[0].taskId);
        Assert.isFalse(responses[0].message.contains(responses[0].taskId), 'Confirmation card must never expose internal Task ID');

        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Agentforce Test Account' LIMIT 1];
        Task createdTask = [SELECT Id, Subject, WhatId, Priority, ActivityDate FROM Task WHERE Id = :responses[0].taskId];
        Assert.areEqual('Initial Discovery Call', createdTask.Subject);
        Assert.areEqual(testAcc.Id, createdTask.WhatId, 'WhatId should match Account');
        Assert.areEqual('Normal', createdTask.Priority, 'Priority should default to Normal');
        Assert.areEqual(Date.today().addDays(2), createdTask.ActivityDate, 'Due date should default to +2 days');
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> emptyResp = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>());
        List<ScheduleFollowUpAgentAction.ScheduleResponse> nullResp = 
            ScheduleFollowUpAgentAction.scheduleTask(null);
        List<ScheduleFollowUpAgentAction.ScheduleResponse> nullEntryResp = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ null });
        Test.stopTest();

        Assert.areEqual(0, emptyResp.size(), 'Empty request list should return empty response list');
        Assert.areEqual(0, nullResp.size(), 'Null request should return empty response list');
        Assert.areEqual(1, nullEntryResp.size(), 'Null entry should return 1 aligned failure response');
        Assert.isFalse(nullEntryResp[0].isSuccess, 'Null entry should fail gracefully');
    }

    @isTest
    static void testTaskWithAccountRecordName() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordName = 'Agentforce Test Account';
        req.subject = 'Executive Check-in';
        req.dueDate = Date.today().addDays(7);
        req.priority = 'High';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Account', responses[0].linkedRecordType);
        Assert.areEqual('Agentforce Test Account', responses[0].linkedRecordName);

        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Agentforce Test Account' LIMIT 1];
        Task createdTask = [SELECT Id, WhatId, WhoId, Subject, Priority FROM Task WHERE Id = :responses[0].taskId];
        Assert.areEqual(testAcc.Id, createdTask.WhatId);
        Assert.isNull(createdTask.WhoId);
    }

    @isTest
    static void testTaskWithLead() {
        Lead testLead = new Lead(
            FirstName = 'Vikram',
            LastName = 'Sharma',
            Company = 'Apex Innovations',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordName = 'Vikram Sharma';
        req.subject = 'Product Demo Call';
        req.priority = 'Normal';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Lead', responses[0].linkedRecordType);

        testLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :testLead.Id];
        Task createdTask = [SELECT Id, WhatId, WhoId, OwnerId, Subject FROM Task WHERE Id = :responses[0].taskId];
        Assert.areEqual(testLead.Id, createdTask.WhoId);
        Assert.isNull(createdTask.WhatId);
        Assert.areEqual(testLead.OwnerId, createdTask.OwnerId, 'Task must be assigned to Lead Owner');
    }

    @isTest
    static void testMissingMandatoryDetailsValidation() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        // Neither subject nor record provided

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('the following details are required'));
    }

    @isTest
    static void testRecordNameNotFound() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordName = 'NonExistentCompanyXYZ999';
        req.subject = 'Follow up';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('Could not find any matching Account, Opportunity, Lead, or Contact'));
    }

    @isTest
    static void testGenericSubjectValidation() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Agentforce Test Account' LIMIT 1];
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordId = testAcc.Id;
        req.subject = 'Follow-up with Agentforce Test Account';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('please specify the discussion topic or purpose'));
    }

    @isTest
    static void testMissingTargetRecordValidation() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.subject = 'Discuss Contract Terms';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('please specify which record it should be linked to'));
    }

    @isTest
    static void testPastDueDateValidation() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Agentforce Test Account' LIMIT 1];
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.recordId = testAcc.Id;
        req.subject = 'Discuss Contract Terms';
        req.dueDate = Date.today().addDays(-2);

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].isSuccess);
        Assert.isTrue(responses[0].message.contains('cannot be in the past'));
    }

    @isTest
    static void testTaskWithOpportunityNamePassedAsOpportunityId() {
        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();
        req.opportunityId = 'Cloud Migration Deal';
        req.subject = 'Pricing Review';
        req.priority = 'High';

        Test.startTest();
        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].isSuccess);
        Assert.areEqual('Opportunity', responses[0].linkedRecordType);
        Assert.areEqual('Cloud Migration Deal', responses[0].linkedRecordName);
    }
}
