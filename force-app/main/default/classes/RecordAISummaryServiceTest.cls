@IsTest
private class RecordAISummaryServiceTest {

    @IsTest
    static void testAccountSummary() {
        Account acc = new Account(
            Name = 'Omega Solutions',
            Industry = 'Technology',
            Type = 'Customer',
            BillingCountry = 'India',
            Phone = '+91 9999888877'
        );
        insert acc;

        Contact con = new Contact(FirstName = 'Rohan', LastName = 'Sharma', AccountId = acc.Id, Email = 'rohan@omega.com');
        insert con;

        Opportunity wonOpp = new Opportunity(
            Name = 'Omega FY25 Won',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-10),
            Expected_Go_Live_Date__c = Date.today().addDays(30),
            Contract_Signed__c = true,
            Primary_Contact__c = con.Id,
            Amount = 500000
        );
        Opportunity openOpp = new Opportunity(
            Name = 'Omega FY26 Upgrade',
            AccountId = acc.Id,
            StageName = 'Proposal/Price Quote',
            CloseDate = Date.today().addDays(30),
            Amount = 750000,
            Deal_Health_Score__c = 35,
            Deal_Risk_Reason__c = 'No activity in 15 days'
        );
        insert new List<Opportunity>{ wonOpp, openOpp };

        Case c = new Case(
            AccountId = acc.Id,
            Subject = 'System latency issue',
            Priority = 'High',
            Status = 'New'
        );
        insert c;

        Task t = new Task(
            Subject = 'Technical Discovery Call',
            WhatId = acc.Id,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;

        Test.startTest();
        RecordAISummaryService.SummaryRequest req = new RecordAISummaryService.SummaryRequest();
        req.recordId = acc.Id;
        List<RecordAISummaryService.SummaryResponse> resList = RecordAISummaryService.getSummaries(new List<RecordAISummaryService.SummaryRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, resList.size());
        Assert.isTrue(resList[0].isSuccess);
        Assert.areEqual('Account', resList[0].recordType);
        Assert.areEqual('Omega Solutions', resList[0].recordName);
        Assert.areEqual('High', resList[0].riskLevel);
        Assert.isTrue(resList[0].aiSummary.contains('Omega Solutions'));
        Assert.isTrue(resList[0].aiSummary.contains('Technical Discovery Call'));
    }

    @IsTest
    static void testOpportunitySummary() {
        Account acc = new Account(
            Name = 'Alpha Global',
            Industry = 'Technology',
            Type = 'Customer',
            BillingCountry = 'India',
            Phone = '+91 9876500000'
        );
        insert acc;

        Contact con = new Contact(FirstName = 'Priya', LastName = 'Nair', AccountId = acc.Id, Email = 'priya@alpha.com');
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Enterprise Cloud Rollout',
            AccountId = acc.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(20),
            Amount = 1800000,
            Primary_Contact__c = con.Id,
            Deal_Health_Score__c = 85
        );
        insert opp;

        Task t = new Task(
            Subject = 'Security Compliance Review',
            WhatId = opp.Id,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;

        Test.startTest();
        RecordAISummaryService.SummaryResponse res = RecordAISummaryService.generateSummary(opp.Id);
        Test.stopTest();

        Assert.isTrue(res.isSuccess);
        Assert.areEqual('Opportunity', res.recordType);
        Assert.areEqual('Enterprise Cloud Rollout', res.recordName);
        Assert.areEqual('Low', res.riskLevel);
        Assert.isTrue(res.aiSummary.contains('Enterprise Cloud Rollout'));
        Assert.isTrue(res.aiSummary.contains('Alpha Global'));
    }

    @IsTest
    static void testInvalidAndEdgeCases() {
        Test.startTest();
        RecordAISummaryService.SummaryResponse res1 = RecordAISummaryService.generateSummary('');
        RecordAISummaryService.SummaryResponse res2 = RecordAISummaryService.generateSummary('invalid_id');
        List<RecordAISummaryService.SummaryResponse> res3 = RecordAISummaryService.getSummaries(new List<RecordAISummaryService.SummaryRequest>());
        Test.stopTest();

        Assert.isFalse(res1.isSuccess);
        Assert.isFalse(res2.isSuccess);
        Assert.areEqual(0, res3.size());
    }
}

