@IsTest
private class DealHealthServiceTest {

    @IsTest
    static void testDealHealthHealthy() {
        Account acc = new Account(Name = 'Enterprise Acc', Type = 'Customer', BillingCountry = 'India', Industry = 'Technology', Phone = '+91 9876543210');
        insert acc;

        Contact con = new Contact(LastName = 'Kapoor', AccountId = acc.Id, Email = 'kapoor@enterprise.com');
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Healthy Enterprise Deal',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1500000,
            Primary_Contact__c = con.Id
        );
        insert opp;

        // Log task
        Task t = new Task(
            Subject = 'Follow up',
            WhatId = opp.Id,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;

        Test.startTest();
        DealHealthBatch batch = new DealHealthBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Id, Deal_Health_Score__c, Deal_Risk_Reason__c 
            FROM Opportunity 
            WHERE Id = :opp.Id
        ];

        Assert.isNotNull(updatedOpp.Deal_Health_Score__c, 'Health score should be populated');
        Assert.isTrue(updatedOpp.Deal_Health_Score__c >= 80, 'Deal with recent activity, primary contact, future close date should be healthy');
    }

    @IsTest
    static void testDealHealthAtRisk() {
        Account acc = new Account(Name = 'Stale Acc', Type = 'Customer', BillingCountry = 'India', Industry = 'Banking');
        insert acc;

        Opportunity staleOpp = new Opportunity(
            Name = 'Stale Risky Deal',
            AccountId = acc.Id,
            StageName = 'Proposal/Price Quote',
            CloseDate = Date.today().addDays(-5), // Overdue! (-25)
            Amount = 800000,
            Discount_Percentage__c = 25,          // High discount (-10)
            Competitor__c = 'Competitor Corp'     // Competitor (-10)
        );
        insert staleOpp;

        Test.startTest();
        DealHealthService.assessOpportunities(new List<Opportunity>{ staleOpp });
        Test.stopTest();

        Assert.isTrue(staleOpp.Deal_Health_Score__c < 50, 'Overdue deal with high discount and competitor should have low health score');
        Assert.isTrue(String.isNotBlank(staleOpp.Deal_Risk_Reason__c), 'Risk reasons should be logged');
    }

    @IsTest
    static void testDealHealthSchedulable() {
        Test.startTest();
        String cron = '0 0 2 * * ?';
        System.schedule('TestDealHealthBatchJob', cron, new DealHealthBatch());
        Test.stopTest();
    }
}