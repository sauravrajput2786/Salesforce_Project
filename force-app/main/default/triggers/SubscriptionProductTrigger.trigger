/**
 * @description SubscriptionProductTrigger following One-Trigger-Per-Object pattern.
 * Delegates all calculation and rollup business logic to SubscriptionProductTriggerHandler.
 */
trigger SubscriptionProductTrigger on Subscription_Product__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SubscriptionProductTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            SubscriptionProductTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            SubscriptionProductTriggerHandler.handleAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            SubscriptionProductTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}

