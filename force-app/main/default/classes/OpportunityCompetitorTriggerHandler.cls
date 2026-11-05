public with sharing class OpportunityCompetitorTriggerHandler {
    
    /**
     * @description Handles before insert and before update on Opportunity_Competitor__c.
     * Automatically sets Account__c from parent Opportunity when Opportunity__c is present.
     * Fully bulkified - executes max 1 SOQL, 0 DML.
     * @param newCompetitors Trigger.new records
     */
    public static void handleBefore(List<Opportunity_Competitor__c> newCompetitors) {
        if (newCompetitors == null || newCompetitors.isEmpty()) {
            return;
        }

        Set<Id> oppIdsToQuery = new Set<Id>();
        for (Opportunity_Competitor__c oc : newCompetitors) {
            if (oc.Opportunity__c != null && oc.Account__c == null) {
                oppIdsToQuery.add(oc.Opportunity__c);
            }
        }

        if (oppIdsToQuery.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, AccountId 
            FROM Opportunity 
            WHERE Id IN :oppIdsToQuery
        ]);

        for (Opportunity_Competitor__c oc : newCompetitors) {
            if (oc.Opportunity__c != null && oc.Account__c == null) {
                Opportunity parentOpp = oppMap.get(oc.Opportunity__c);
                if (parentOpp != null && parentOpp.AccountId != null) {
                    oc.Account__c = parentOpp.AccountId;
                }
            }
        }
    }
}

