/**
 * @description Trigger on Case to automatically complete all remaining open milestones
 * when a Case is resolved and transitioned to Closed status.
 */
trigger CaseTrigger on Case (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        MilestoneCompletionService.completeCaseCloseMilestones(Trigger.new, Trigger.oldMap);
    }
}
