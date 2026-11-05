public with sharing class RecordAISummaryService {

    public class SummaryRequest {
        @InvocableVariable(label='Record ID' description='Salesforce ID for Account or Opportunity' required=true)
        @AuraEnabled
        public String recordId;
    }

    public class SummaryResponse {
        @InvocableVariable(label='Is Success' description='True if summary generated successfully')
        @AuraEnabled
        public Boolean isSuccess;

        @InvocableVariable(label='Record Name' description='Name of the record summarized')
        @AuraEnabled
        public String recordName;

        @InvocableVariable(label='Record Type' description='Account or Opportunity')
        @AuraEnabled
        public String recordType;

        @InvocableVariable(label='AI Summary' description='Executive catch-me-up summary')
        @AuraEnabled
        public String aiSummary;

        @InvocableVariable(label='Risk Level' description='Low, Medium, or High')
        @AuraEnabled
        public String riskLevel;

        @InvocableVariable(label='Next Best Action' description='Recommended next action')
        @AuraEnabled
        public String nextAction;
    }

    @InvocableMethod(
        label='Get AI Catch-Me-Up Summary'
        description='Generates a concise 30-second executive summary for an Account or Opportunity.'
        category='Customer Intelligence'
    )
    public static List<SummaryResponse> getSummaries(List<SummaryRequest> requests) {
        List<SummaryResponse> responses = new List<SummaryResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (SummaryRequest req : requests) {
            responses.add(generateSummary(req.recordId));
        }
        return responses;
    }

    @AuraEnabled(cacheable=true)
    public static SummaryResponse generateSummary(String recordId) {
        SummaryResponse res = new SummaryResponse();
        if (String.isBlank(recordId)) {
            res.isSuccess = false;
            res.aiSummary = 'Error: RecordId is required.';
            return res;
        }

        Id recId;
        try {
            recId = (Id)recordId.trim();
        } catch (Exception ex) {
            res.isSuccess = false;
            res.aiSummary = 'Error: Invalid Record ID format.';
            return res;
        }

        String sObjType = recId.getSObjectType().getDescribe().getName();
        if (sObjType == 'Account') {
            return generateAccountSummary(recId);
        } else if (sObjType == 'Opportunity') {
            return generateOpportunitySummary(recId);
        } else {
            res.isSuccess = false;
            res.aiSummary = 'Error: Only Account and Opportunity are supported.';
            return res;
        }
    }

    private static SummaryResponse generateAccountSummary(Id accountId) {
        SummaryResponse res = new SummaryResponse();
        Account acc = [
            SELECT Id, Name, Industry, Type, AnnualRevenue,
                   (SELECT Id, Name, Amount, StageName, IsClosed, IsWon, CloseDate, Deal_Health_Score__c, Deal_Risk_Reason__c 
                    FROM Opportunities),
            (SELECT Id, CaseNumber, Priority, Status, IsClosed FROM Cases WHERE IsClosed = false),
            (SELECT Id, Subject, ActivityDate, CreatedDate FROM Tasks ORDER BY CreatedDate DESC LIMIT 1)
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        res.isSuccess = true;
        res.recordName = acc.Name;
        res.recordType = 'Account';

        Decimal totalWon = 0;
        Decimal openPipeline = 0;
        Integer openDeals = 0;
        Integer highRiskDeals = 0;

        if (acc.Opportunities != null) {
            for (Opportunity opp : acc.Opportunities) {
                if (opp.IsWon) {
                    totalWon += (opp.Amount != null ? opp.Amount : 0);
                } else if (!opp.IsClosed) {
                    openDeals++;
                    openPipeline += (opp.Amount != null ? opp.Amount : 0);
                    if (opp.Deal_Health_Score__c != null && opp.Deal_Health_Score__c < 50) {
                        highRiskDeals++;
                    }
                }
            }
        }

        Integer openCases = (acc.Cases != null) ? acc.Cases.size() : 0;
        Integer criticalCases = 0;
        if (acc.Cases != null) {
            for (Case c : acc.Cases) {
                if (c.Priority == 'High' || c.Priority == 'Critical') {
                    criticalCases++;
                }
            }
        }

        String lastActivityText = 'No logged activities.';
        if (acc.Tasks != null && !acc.Tasks.isEmpty()) {
            Task t = acc.Tasks[0];
            lastActivityText = t.Subject + ' (' + (t.ActivityDate != null ? String.valueOf(t.ActivityDate) : 'recently') + ')';
        }

        if (criticalCases > 0 || highRiskDeals > 0) {
            res.riskLevel = 'High';
            res.nextAction = criticalCases > 0 ? 'Resolve critical support cases before engaging sales.' : 'Review deal risk factors on open pipeline.';
        } else if (openDeals > 0) {
            res.riskLevel = 'Medium';
            res.nextAction = 'Follow up on active pipeline to progress stages.';
        } else {
            res.riskLevel = 'Low';
            res.nextAction = 'Schedule quarterly executive check-in.';
        }

        String summary = '📋 **Executive Catch-Me-Up — ' + acc.Name + '**\n' +
                         '• **Industry & Type:** ' + (String.isNotBlank(acc.Industry) ? acc.Industry : 'General') + ' | ' + (String.isNotBlank(acc.Type) ? acc.Type : 'Prospect') + '\n' +
                         '• **Pipeline Health:** ' + openDeals + ' active deal(s) worth ₹' + openPipeline.setScale(0) + ' (Won Lifetime: ₹' + totalWon.setScale(0) + ')\n' +
                         '• **Deal Risks:** ' + (highRiskDeals > 0 ? ('⚠️ ' + highRiskDeals + ' deal(s) below health threshold') : '✅ No immediate deal risks') + '\n' +
                         '• **Support Status:** ' + openCases + ' open case(s) (' + criticalCases + ' high priority)\n' +
                         '• **Last Activity:** ' + lastActivityText + '\n' +
                         '• **Recommended Action:** ' + res.nextAction;

        res.aiSummary = summary;
        return res;
    }

    private static SummaryResponse generateOpportunitySummary(Id oppId) {
        SummaryResponse res = new SummaryResponse();
        Opportunity opp = [
            SELECT Id, Name, StageName, Amount, CloseDate, Deal_Health_Score__c, Deal_Risk_Reason__c,
                   Account.Name, Account.Industry, Primary_Contact__r.Name,
                   (SELECT Id, Subject, ActivityDate, CreatedDate FROM Tasks ORDER BY CreatedDate DESC LIMIT 1)
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        res.isSuccess = true;
        res.recordName = opp.Name;
        res.recordType = 'Opportunity';

        Decimal health = opp.Deal_Health_Score__c != null ? opp.Deal_Health_Score__c : 70;
        if (health < 40) {
            res.riskLevel = 'High';
            res.nextAction = 'Engage leadership immediately. Address risks: ' + (String.isNotBlank(opp.Deal_Risk_Reason__c) ? opp.Deal_Risk_Reason__c : 'Stalled progress');
        } else if (health < 70) {
            res.riskLevel = 'Medium';
            res.nextAction = 'Log customer touchpoint and reaffirm milestone target by ' + opp.CloseDate.format();
        } else {
            res.riskLevel = 'Low';
            res.nextAction = 'Proceed with formal closing / contracting stage.';
        }

        String lastAct = (opp.Tasks != null && !opp.Tasks.isEmpty()) 
            ? opp.Tasks[0].Subject + ' (' + (opp.Tasks[0].ActivityDate != null ? String.valueOf(opp.Tasks[0].ActivityDate) : 'recently') + ')' 
            : 'No logged activity';

        String summary = '📋 **Executive Catch-Me-Up — ' + opp.Name + '**\n' +
                         '• **Account:** ' + (opp.Account != null ? opp.Account.Name : 'Not Assigned') + '\n' +
                         '• **Value & Stage:** ₹' + (opp.Amount != null ? String.valueOf(opp.Amount.setScale(0)) : '0') + ' | ' + opp.StageName + '\n' +
                         '• **Target Close Date:** ' + opp.CloseDate.format() + '\n' +
                         '• **Health Score:** ' + health + '/100 (Risk: ' + res.riskLevel + ')\n' +
                         '• **Primary Contact:** ' + (opp.Primary_Contact__r != null ? opp.Primary_Contact__r.Name : 'None') + '\n' +
                         '• **Last Interaction:** ' + lastAct + '\n' +
                         '• **Recommended Action:** ' + res.nextAction;

        res.aiSummary = summary;
        return res;
    }
}

