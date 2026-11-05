/**
 * @description Opportunity Trigger following One-Trigger-Per-Object pattern.
 * Delegates all business logic to OpportunityTriggerHandler.
 */
trigger OpportunityTrigger on Opportunity (before insert, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        OpportunityTriggerHandler.handleBeforeInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}