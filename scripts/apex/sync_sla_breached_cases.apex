List<CaseMilestone> violated = [SELECT CaseId FROM CaseMilestone WHERE IsViolated = true];
Set<Id> caseIds = new Set<Id>();
for (CaseMilestone cm : violated) {
    if (cm.CaseId != null) {
        caseIds.add(cm.CaseId);
    }
}
List<Case> toUpdate = [SELECT Id, SLA_Breached__c, SLAViolation__c FROM Case WHERE Id IN :caseIds];
for (Case c : toUpdate) {
    c.SLA_Breached__c = true;
    c.SLAViolation__c = 'Yes';
}
update toUpdate;
System.debug('SUCCESS: Synchronized ' + toUpdate.size() + ' cases to SLA Breached');

