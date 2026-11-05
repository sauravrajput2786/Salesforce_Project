public with sharing class DealHealthService {

    public class DealHealthResult {
        @AuraEnabled public Integer healthScore;
        @AuraEnabled public String riskReason;
        @AuraEnabled public Boolean shouldAlertManager;
    }

    @AuraEnabled
    public static DealHealthResult recalculateSingleDeal(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, Amount, CloseDate, IsClosed, LastActivityDate, LastModifiedDate,
                   Discount_Percentage__c, Competitor__c, Deal_Health_Score__c, Previous_Health_Score__c,
                   Deal_Risk_Reason__c, Primary_Contact__c
            FROM Opportunity 
            WHERE Id = :oppId
            LIMIT 1
        ];
        assessOpportunities(new List<Opportunity>{ opp });
        
        Opportunity toUpdate = new Opportunity(
            Id = opp.Id,
            Deal_Health_Score__c = opp.Deal_Health_Score__c,
            Previous_Health_Score__c = opp.Previous_Health_Score__c,
            Deal_Risk_Reason__c = opp.Deal_Risk_Reason__c
        );
        update toUpdate;

        DealHealthResult res = new DealHealthResult();
        res.healthScore = (Integer)opp.Deal_Health_Score__c;
        res.riskReason = opp.Deal_Risk_Reason__c;
        res.shouldAlertManager = false;
        return res;
    }

    public static DealHealthResult calculateHealth(Opportunity opp, Integer contactRoleCount, Integer daysInStage) {
        DealHealthResult result = new DealHealthResult();
        Integer health = 100;
        List<String> riskReasons = new List<String>();

        // 1. Inactivity Risk: LastActivityDate > 10 days
        Integer daysSinceActivity = opp.LastActivityDate != null ? opp.LastActivityDate.daysBetween(Date.today()) : 999;
        if (daysSinceActivity > 10) {
            health -= 20;
            String daysText = daysSinceActivity == 999 ? 'No logged activities' : daysSinceActivity + ' days without logged activity';
            riskReasons.add('Inactivity: ' + daysText + ' (-20)');
        }

        // 2. Stage Stagnation: Stuck in stage > 15 days
        if (daysInStage > 15) {
            health -= 20;
            riskReasons.add('Stagnant Stage: ' + opp.StageName + ' for ' + daysInStage + ' days (-20)');
        }

        // 3. Missing Key Decision Maker
        Boolean hasDecisionMaker = (contactRoleCount > 0 || opp.Primary_Contact__c != null);
        if (!hasDecisionMaker) {
            health -= 15;
            riskReasons.add('Missing Contact Role: No Key Decision Maker identified (-15)');
        }

        // 4. Excessive Discount Risk (> 20%)
        if (opp.Discount_Percentage__c != null && opp.Discount_Percentage__c > 20) {
            health -= 10;
            riskReasons.add('Margin Risk: High discount of ' + opp.Discount_Percentage__c + '% applied (-10)');
        }

        // 5. Active Competitor Pressure
        if (String.isNotBlank(opp.Competitor__c)) {
            health -= 10;
            riskReasons.add('Competitor Threat: ' + opp.Competitor__c + ' actively engaged (-10)');
        }

        // 6. Overdue Deal (Past CloseDate while still Open)
        if (opp.CloseDate < Date.today() && !opp.IsClosed) {
            health -= 25;
            riskReasons.add('Overdue Close Date: Target was ' + opp.CloseDate.format() + ' (-25)');
        }

        // Health floor at 0
        result.healthScore = Math.max(health, 0);
        result.riskReason = riskReasons.isEmpty() ? '🟢 Healthy Deal — all pipeline velocity metrics on track.' : String.join(riskReasons, '\n');

        // Delta check for alert to avoid notification spam
        Decimal prev = opp.Previous_Health_Score__c != null ? opp.Previous_Health_Score__c : 100;
        result.shouldAlertManager = (result.healthScore < 40 && prev >= 40);

        return result;
    }

    public static void assessOpportunities(List<Opportunity> opps) {
        if (opps == null || opps.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : opps) {
            if (o.Id != null) {
                oppIds.add(o.Id);
            }
        }

        // Count OpportunityContactRoles in bulk
        Map<Id, Integer> contactRoleCountMap = new Map<Id, Integer>();
        if (!oppIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT OpportunityId oppId, COUNT(Id) cnt 
                FROM OpportunityContactRole 
                WHERE OpportunityId IN :oppIds 
                GROUP BY OpportunityId
            ]) {
                contactRoleCountMap.put((Id)ar.get('oppId'), (Integer)ar.get('cnt'));
            }
        }

        for (Opportunity opp : opps) {
            Integer crCount = contactRoleCountMap.containsKey(opp.Id) ? contactRoleCountMap.get(opp.Id) : 0;
            
            // Calculate days in stage based on LastModifiedDate or LastStageChangeDate
            Integer daysInStage = 0;
            if (opp.LastModifiedDate != null) {
                daysInStage = Date.valueOf(opp.LastModifiedDate).daysBetween(Date.today());
            }

            DealHealthResult res = calculateHealth(opp, crCount, daysInStage);
            opp.Previous_Health_Score__c = opp.Deal_Health_Score__c != null ? opp.Deal_Health_Score__c : 100;
            opp.Deal_Health_Score__c = res.healthScore;
            opp.Deal_Risk_Reason__c = res.riskReason;
        }
    }
}