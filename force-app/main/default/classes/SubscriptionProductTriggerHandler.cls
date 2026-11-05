/**
 * @description Handler for SubscriptionProductTrigger following One-Trigger-Per-Object pattern.
 * Automatically recalculates and synchronizes Annual_Contract_Value__c on parent Customer_Subscription__c
 * whenever Subscription_Product__c records are inserted, updated, deleted, or undeleted.
 */
public with sharing class SubscriptionProductTriggerHandler {

    /**
     * @description Dispatches after-insert operations.
     * @param newProducts Trigger.new list of Subscription_Product__c
     */
    public static void handleAfterInsert(List<Subscription_Product__c> newProducts) {
        recalculateSubscriptionTotals(extractSubscriptionIds(newProducts, null));
    }

    /**
     * @description Dispatches after-update operations.
     * Only triggers recalculation if Quantity, Unit_Price, or Customer_Subscription parent changed.
     * @param newProducts Trigger.new list of Subscription_Product__c
     * @param oldProductsMap Trigger.oldMap map of Subscription_Product__c
     */
    public static void handleAfterUpdate(List<Subscription_Product__c> newProducts, Map<Id, Subscription_Product__c> oldProductsMap) {
        Set<Id> targetSubscriptionIds = new Set<Id>();

        for (Subscription_Product__c prod : newProducts) {
            Subscription_Product__c oldProd = oldProductsMap != null ? oldProductsMap.get(prod.Id) : null;
            if (oldProd == null || 
                prod.Quantity__c != oldProd.Quantity__c || 
                prod.Unit_Price__c != oldProd.Unit_Price__c || 
                prod.Customer_Subscription__c != oldProd.Customer_Subscription__c) {
                
                if (prod.Customer_Subscription__c != null) {
                    targetSubscriptionIds.add(prod.Customer_Subscription__c);
                }
                if (oldProd != null && oldProd.Customer_Subscription__c != null && oldProd.Customer_Subscription__c != prod.Customer_Subscription__c) {
                    targetSubscriptionIds.add(oldProd.Customer_Subscription__c);
                }
            }
        }

        recalculateSubscriptionTotals(targetSubscriptionIds);
    }

    /**
     * @description Dispatches after-delete operations.
     * @param oldProducts Trigger.old list of Subscription_Product__c
     */
    public static void handleAfterDelete(List<Subscription_Product__c> oldProducts) {
        recalculateSubscriptionTotals(extractSubscriptionIds(oldProducts, null));
    }

    /**
     * @description Dispatches after-undelete operations.
     * @param newProducts Trigger.new list of Subscription_Product__c
     */
    public static void handleAfterUndelete(List<Subscription_Product__c> newProducts) {
        recalculateSubscriptionTotals(extractSubscriptionIds(newProducts, null));
    }

    /**
     * @description Aggregates Total_Price__c from child Subscription_Product__c records
     * and updates Annual_Contract_Value__c on the corresponding Customer_Subscription__c parents.
     * @param subscriptionIds Set of parent Customer_Subscription__c IDs to roll up
     */
    public static void recalculateSubscriptionTotals(Set<Id> subscriptionIds) {
        if (subscriptionIds == null || subscriptionIds.isEmpty()) {
            return;
        }

        // Initialize rollup map with 0 to safely handle scenarios where all child products are deleted
        Map<Id, Decimal> subToTotalMap = new Map<Id, Decimal>();
        for (Id subId : subscriptionIds) {
            if (subId != null) {
                subToTotalMap.put(subId, 0);
            }
        }

        if (subToTotalMap.isEmpty()) {
            return;
        }

        for (AggregateResult ar : [
            SELECT Customer_Subscription__c subId, SUM(Total_Price__c) totalVal
            FROM Subscription_Product__c
            WHERE Customer_Subscription__c IN :subToTotalMap.keySet()
            GROUP BY Customer_Subscription__c
        ]) {
            Id sId = (Id)ar.get('subId');
            Decimal sumVal = (Decimal)ar.get('totalVal');
            subToTotalMap.put(sId, sumVal != null ? sumVal : 0);
        }

        List<Customer_Subscription__c> subsToUpdate = new List<Customer_Subscription__c>();
        for (Id sId : subToTotalMap.keySet()) {
            subsToUpdate.add(new Customer_Subscription__c(
                Id = sId,
                Annual_Contract_Value__c = subToTotalMap.get(sId)
            ));
        }

        if (!subsToUpdate.isEmpty()) {
            update subsToUpdate;
        }
    }

    /**
     * @description Helper to extract Customer_Subscription__c IDs from product list.
     */
    private static Set<Id> extractSubscriptionIds(List<Subscription_Product__c> products, Set<Id> existingIds) {
        Set<Id> result = (existingIds != null) ? existingIds : new Set<Id>();
        if (products != null) {
            for (Subscription_Product__c sp : products) {
                if (sp.Customer_Subscription__c != null) {
                    result.add(sp.Customer_Subscription__c);
                }
            }
        }
        return result;
    }
}

