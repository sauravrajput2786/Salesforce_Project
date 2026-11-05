@IsTest
private class LeadScoringServiceTest {

    @IsTest
    static void testLeadScoringCalculation() {
        Lead testLead = new Lead(
            FirstName = 'Rohan',
            LastName = 'Gupta',
            Company = 'TechCorp',
            Industry = 'Technology',
            LeadSource = 'Web',
            Email = 'rohan@techcorp.com',
            Phone = '+91 9876543210',
            Estimated_Budget__c = 80000
        );
        insert testLead;

        // Log a test task
        Task t = new Task(
            Subject = 'Discovery Call',
            WhoId = testLead.Id,
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today()
        );
        insert t;

        Test.startTest();
        LeadScoringBatch batchJob = new LeadScoringBatch();
        Database.executeBatch(batchJob, 10);
        Test.stopTest();

        Lead updatedLead = [
            SELECT Id, AI_Lead_Score__c, Lead_Score__c, Score_Reason__c, Next_Best_Action__c 
            FROM Lead 
            WHERE Id = :testLead.Id
        ];

        Assert.isNotNull(updatedLead.AI_Lead_Score__c, 'AI Lead Score should be computed');
        Assert.isTrue(updatedLead.AI_Lead_Score__c >= 50, 'Actual score was: ' + updatedLead.AI_Lead_Score__c);
        Assert.isTrue(String.isNotBlank(updatedLead.Score_Reason__c), 'Score reason should be populated');
        Assert.isTrue(String.isNotBlank(updatedLead.Next_Best_Action__c), 'Next best action should be populated');
    }

    @IsTest
    static void testColdLeadScoring() {
        Lead coldLead = new Lead(
            LastName = 'Sharma',
            Company = 'SmallCo'
        );
        insert coldLead;

        Test.startTest();
        LeadScoringService.scoreLeads(new List<Lead>{ coldLead });
        Test.stopTest();

        Assert.isTrue(coldLead.AI_Lead_Score__c <= 40, 'Lead without details should have cold score');
        Assert.isTrue(coldLead.Next_Best_Action__c.contains('Contact details missing') || coldLead.Next_Best_Action__c.contains('Cold Lead'));
    }

    @IsTest
    static void testBatchSchedulable() {
        Test.startTest();
        String cron = '0 0 1 * * ?';
        System.schedule('TestLeadScoringBatchJob', cron, new LeadScoringBatch());
        Test.stopTest();
    }
}