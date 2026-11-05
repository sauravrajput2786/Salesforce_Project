/**
 * @description Enterprise Milestone Completion Service addressing BUG-001.
 * Automatically marks CaseMilestones as completed upon outbound customer communications
 * (EmailMessage with Incoming=false) and Case closure (Status='Closed').
 * Incorporates multi-layer idempotency guards and static recursion protection.
 */
public without sharing class MilestoneCompletionService {

    // Static recursion guards to prevent multiple executions within the same transaction
    private static Set<Id> processedFirstResponseCases = new Set<Id>();
    private static Set<Id> processedClosedCases = new Set<Id>();

    /**
     * @description Automatically completes the 'First Response to Customer' CaseMilestone
     * when an outbound email is sent to the customer.
     * @param emails List of EmailMessage records from Trigger.new
     */
    public static void completeFirstResponseMilestones(List<EmailMessage> emails) {
        if (emails == null || emails.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        for (EmailMessage email : emails) {
            // Outbound emails only: Incoming == false and ParentId must be a Case
            if (!email.Incoming && email.ParentId != null && email.ParentId.getSObjectType() == Case.sObjectType) {
                if (!processedFirstResponseCases.contains(email.ParentId)) {
                    caseIds.add(email.ParentId);
                }
            }
        }

        if (caseIds.isEmpty()) {
            return;
        }

        // Add to recursion set before DML to prevent re-entrant loops
        processedFirstResponseCases.addAll(caseIds);

        try {
            // Query open First Response and legacy/residual milestones linked to the affected cases
            List<CaseMilestone> milestonesToComplete = [
                SELECT Id, CaseId, CompletionDate
                FROM CaseMilestone
                WHERE CaseId IN :caseIds
                  AND MilestoneType.Name IN ('First Response to Customer', 'Escalate Case')
                  AND CompletionDate = null
            ];

            if (milestonesToComplete.isEmpty()) {
                return;
            }

            DateTime nowTime = System.now();
            for (CaseMilestone cm : milestonesToComplete) {
                cm.CompletionDate = nowTime;
            }

            update milestonesToComplete;

            // Touch the Case records so Salesforce's Lightning Data Service (LDS) detects a Case record update
            List<Case> casesToTouch = new List<Case>();
            for (Id cId : caseIds) {
                casesToTouch.add(new Case(Id = cId));
            }
            update casesToTouch;

            // Publish real-time client-side UI refresh event
            List<Milestone_Refresh_Event__e> refreshEvents = new List<Milestone_Refresh_Event__e>();
            for (Id cId : caseIds) {
                refreshEvents.add(new Milestone_Refresh_Event__e(Case_Id__c = cId));
            }
            EventBus.publish(refreshEvents);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'MilestoneCompletionService.completeFirstResponseMilestones failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Automatically completes all remaining open CaseMilestones on a Case
     * when its Status transitions to 'Closed'.
     * @param cases List of Case records from Trigger.new
     * @param oldCaseMap Map of prior Case state from Trigger.oldMap
     */
    public static void completeCaseCloseMilestones(List<Case> cases, Map<Id, Case> oldCaseMap) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Set<Id> closedCaseIds = new Set<Id>();
        for (Case c : cases) {
            // Status changed to Closed
            Boolean wasClosed = (oldCaseMap != null && oldCaseMap.containsKey(c.Id) && oldCaseMap.get(c.Id).Status == 'Closed');
            if (c.Status == 'Closed' && !wasClosed) {
                if (!processedClosedCases.contains(c.Id)) {
                    closedCaseIds.add(c.Id);
                }
            }
        }

        if (closedCaseIds.isEmpty()) {
            return;
        }

        // Add to recursion set
        processedClosedCases.addAll(closedCaseIds);

        try {
            // Complete ALL open milestones remaining on the closed tickets
            List<CaseMilestone> openMilestones = [
                SELECT Id, CaseId, CompletionDate
                FROM CaseMilestone
                WHERE CaseId IN :closedCaseIds
                  AND CompletionDate = null
            ];

            if (openMilestones.isEmpty()) {
                return;
            }

            DateTime nowTime = System.now();
            for (CaseMilestone cm : openMilestones) {
                cm.CompletionDate = nowTime;
            }

            update openMilestones;

            // Publish real-time client-side UI refresh event (0 DML on Case)
            List<Milestone_Refresh_Event__e> refreshEvents = new List<Milestone_Refresh_Event__e>();
            for (Id cId : closedCaseIds) {
                refreshEvents.add(new Milestone_Refresh_Event__e(Case_Id__c = cId));
            }
            EventBus.publish(refreshEvents);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'MilestoneCompletionService.completeCaseCloseMilestones failed: ' + ex.getMessage());
        }
    }

    /**
     * @description Resets static recursion guards for isolated unit test verification.
     */
    @TestVisible
    public static void resetRecursionGuards() {
        processedFirstResponseCases.clear();
        processedClosedCases.clear();
    }
}
