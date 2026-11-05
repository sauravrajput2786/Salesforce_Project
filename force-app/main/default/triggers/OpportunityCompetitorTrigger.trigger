/**
 * @description Trigger on Opportunity_Competitor__c.
 * Auto-populates Account__c from parent Opportunity.
 */
trigger OpportunityCompetitorTrigger on Opportunity_Competitor__c (before insert, before update) {
    if (Trigger.isBefore) {
        OpportunityCompetitorTriggerHandler.handleBefore(Trigger.new);
    }
}

