public with sharing class OpportunityTriggerHandler {
    
    /**
     * @description Handles before insert logic on Opportunity.
     * Evaluates deal size and sets standard business classification in Description.
     * Fully bulkified - performs 0 SOQL and 0 DML statements.
     * @param newOpportunities List of newly inserted Opportunity records (Trigger.new)
     */
    public static void handleBeforeInsert(List<Opportunity> newOpportunities) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        for (Opportunity opp : newOpportunities) {
            if (opp.Amount != null && opp.Amount >= 50000) {
                opp.Description = 'Hot Opportunity - Requires Fast Follow-up';
            } else {
                opp.Description = 'Standard Opportunity';
            }
        }
    }

    /**
     * @description Handles after update logic on Opportunity.
     * Identifies Opportunities transitioning to 'Closed Won' and triggers
     * the outbound asynchronous integration callout to external ERP/REST API.
     * @param newOpportunities List of updated Opportunity records (Trigger.new)
     * @param oldOpportunitiesMap Map of pre-update Opportunity records (Trigger.oldMap)
     */
    public static void handleAfterUpdate(List<Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunitiesMap) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        Set<Id> erpWonOpportunityIds = new Set<Id>();
        Set<Id> allWonOpportunityIds = new Set<Id>();

        for (Opportunity opp : newOpportunities) {
            Opportunity oldOpp = oldOpportunitiesMap != null ? oldOpportunitiesMap.get(opp.Id) : null;
            // Check if Stage transitioned to 'Closed Won'
            if (opp.StageName == 'Closed Won' && (oldOpp == null || oldOpp.StageName != 'Closed Won')) {
                allWonOpportunityIds.add(opp.Id);
                if (String.isBlank(opp.OrderNumber__c)) {
                    erpWonOpportunityIds.add(opp.Id);
                }
            }
        }

        if (!allWonOpportunityIds.isEmpty()) {
            createCustomerProducts(allWonOpportunityIds);
        }

        if (!erpWonOpportunityIds.isEmpty()) {
            ExternalOrderCalloutService.sendOrdersToExternalApi(erpWonOpportunityIds);
        }
    }

    /**
     * @description Automatically creates Customer_Product__c records for all line items
     * on Opportunities that transition to 'Closed Won'. Safely skips if no line items exist.
     * @param wonOpportunityIds Set of Opportunity IDs that changed to Closed Won
     */
    public static void createCustomerProducts(Set<Id> wonOpportunityIds) {
        if (wonOpportunityIds == null || wonOpportunityIds.isEmpty()) {
            return;
        }

        List<OpportunityLineItem> lineItems = [
            SELECT Id, OpportunityId, Opportunity.AccountId, Opportunity.CloseDate,
                   Product2Id, Quantity
            FROM OpportunityLineItem
            WHERE OpportunityId IN :wonOpportunityIds
              AND Product2Id != null
              AND Opportunity.AccountId != null
        ];

        if (lineItems.isEmpty()) {
            return; // Safely skip opportunities that have no products attached
        }

        List<Customer_Product__c> customerProductsToInsert = new List<Customer_Product__c>();
        for (OpportunityLineItem oli : lineItems) {
            Date purchaseDate = oli.Opportunity.CloseDate != null ? oli.Opportunity.CloseDate : Date.today();
            customerProductsToInsert.add(new Customer_Product__c(
                Account__c = oli.Opportunity.AccountId,
                Product__c = oli.Product2Id,
                Quantity__c = oli.Quantity != null ? oli.Quantity : 1,
                Purchase_Date__c = purchaseDate,
                Renewal_Date__c = purchaseDate.addYears(1),
                Status__c = 'Active'
            ));
        }

        if (!customerProductsToInsert.isEmpty()) {
            insert customerProductsToInsert;
        }
    }
}