public with sharing class LeadScoringBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Only score open leads to avoid wasting processing power on converted/closed leads
        return Database.getQueryLocator([
            SELECT Id, Name, Company, Estimated_Budget__c, Industry, LeadSource, Phone, Email, 
                   CreatedDate, AI_Lead_Score__c, Lead_Score__c, Score_Reason__c, Next_Best_Action__c
            FROM Lead 
            WHERE IsConverted = false
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        LeadScoringService.scoreLeads(scope);
        Database.update(scope, false);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'LeadScoringBatch execution completed successfully.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeadScoringBatch(), 200);
    }
}