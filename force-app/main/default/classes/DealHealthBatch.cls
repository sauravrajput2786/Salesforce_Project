public with sharing class DealHealthBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Only evaluate open opportunities
        return Database.getQueryLocator([
            SELECT Id, Name, StageName, Amount, CloseDate, IsClosed, LastActivityDate, LastModifiedDate,
                   Discount_Percentage__c, Competitor__c, Primary_Contact__c, 
                   Deal_Health_Score__c, Previous_Health_Score__c, Deal_Risk_Reason__c
            FROM Opportunity 
            WHERE IsClosed = false
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        DealHealthService.assessOpportunities(scope);
        Database.update(scope, false);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'DealHealthBatch execution completed successfully.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DealHealthBatch(), 200);
    }
}