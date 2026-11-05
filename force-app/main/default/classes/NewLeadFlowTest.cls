@isTest
private class NewLeadFlowTest {

    @isTest
    static void testNewLeadCreatesFollowUpTask() {
        Lead testLead = new Lead(
            FirstName = 'Rohan',
            LastName = 'Sharma',
            Company = 'Sharma Tech Solutions',
            Status = 'Open - Not Contacted'
        );

        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Query the inserted Lead to get database-assigned fields (OwnerId)
        testLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :testLead.Id];

        // Verify the Flow created the follow-up task
        List<Task> tasks = [
            SELECT Id, Subject, WhoId, OwnerId, Status, Priority, ActivityDate 
            FROM Task 
            WHERE WhoId = :testLead.Id
        ];

        Assert.areEqual(1, tasks.size(), 'Exactly one follow-up task should be auto-created by the Flow');
        Assert.isTrue(tasks[0].Subject.contains('Rohan Sharma'), 'Task subject should include Lead name');
        Assert.areEqual(testLead.OwnerId, tasks[0].OwnerId, 'Task should be assigned to the Lead Owner');
        Assert.areEqual('Not Started', tasks[0].Status, 'Task status should be Not Started');
        Assert.areEqual(Date.today().addDays(1), tasks[0].ActivityDate, 'Task due date should be tomorrow');
    }
}
