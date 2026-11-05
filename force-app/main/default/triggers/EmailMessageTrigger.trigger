/**
 * @description Trigger on EmailMessage to automatically complete the active
 * 'First Response to Customer' milestone when an outbound email is dispatched.
 */
trigger EmailMessageTrigger on EmailMessage (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        MilestoneCompletionService.completeFirstResponseMilestones(Trigger.new);
    }
}
