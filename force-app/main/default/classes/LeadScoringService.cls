public with sharing class LeadScoringService {

    private static Map<String, Integer> cachedIndustryScores;

    public static Map<String, Integer> getIndustryScoreMap() {
        if (cachedIndustryScores == null) {
            cachedIndustryScores = new Map<String, Integer>();
            try {
                for (Lead_Industry_Score__mdt config : [SELECT MasterLabel, DeveloperName, Score__c FROM Lead_Industry_Score__mdt]) {
                    if (config.Score__c != null) {
                        if (String.isNotBlank(config.MasterLabel)) {
                            cachedIndustryScores.put(config.MasterLabel.toLowerCase(), (Integer)config.Score__c);
                        }
                        if (String.isNotBlank(config.DeveloperName)) {
                            cachedIndustryScores.put(config.DeveloperName.toLowerCase(), (Integer)config.Score__c);
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Unable to load Lead_Industry_Score__mdt: ' + ex.getMessage());
            }

            // Fallback safety for any test isolation or initial org deployment latency
            if (cachedIndustryScores.isEmpty()) {
                cachedIndustryScores.put('technology', 20);
                cachedIndustryScores.put('finance', 20);
                cachedIndustryScores.put('banking', 20);
                cachedIndustryScores.put('healthcare', 20);
                cachedIndustryScores.put('manufacturing', 12);
                cachedIndustryScores.put('retail', 12);
            }
        }
        return cachedIndustryScores;
    }

    public class LeadScoreResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String scoreReason;
        @AuraEnabled public String nextBestAction;
    }

    @AuraEnabled
    public static LeadScoreResult recalculateSingleLead(Id leadId) {
        Lead ld = [
            SELECT Id, Name, Company, Estimated_Budget__c, Industry, LeadSource, Phone, Email, 
                   CreatedDate, AI_Lead_Score__c, Lead_Score__c, Score_Reason__c, Next_Best_Action__c
            FROM Lead 
            WHERE Id = :leadId
            LIMIT 1
        ];
        scoreLeads(new List<Lead>{ ld });
        
        Lead toUpdate = new Lead(
            Id = ld.Id,
            AI_Lead_Score__c = ld.AI_Lead_Score__c,
            Lead_Score__c = ld.Lead_Score__c,
            Score_Reason__c = ld.Score_Reason__c,
            Next_Best_Action__c = ld.Next_Best_Action__c
        );
        update toUpdate;

        LeadScoreResult res = new LeadScoreResult();
        res.score = (Integer)ld.AI_Lead_Score__c;
        res.scoreReason = ld.Score_Reason__c;
        res.nextBestAction = ld.Next_Best_Action__c;
        return res;
    }

    public static LeadScoreResult calculateScore(Lead ld, Integer activityCount, Boolean respondedWithin24Hr, Date lastActivityDate) {
        LeadScoreResult result = new LeadScoreResult();
        Integer totalScore = 0;
        List<String> reasons = new List<String>();

        // 1. Budget Weightage (Max 25 pts)
        Decimal budget = ld.Estimated_Budget__c;
        if (budget != null && budget >= 50000) {
            totalScore += 25;
            reasons.add('Budget >= ₹50,000 (+25)');
        } else if (budget != null && budget >= 20000) {
            totalScore += 15;
            reasons.add('Budget >= ₹20,000 (+15)');
        } else if (budget != null && budget > 0) {
            totalScore += 5;
            reasons.add('Budget Specified (+5)');
        }

        // 2. Industry Tier Weightage (Max 20 pts from Custom Metadata)
        Map<String, Integer> industryMap = getIndustryScoreMap();
        String indKey = String.isNotBlank(ld.Industry) ? ld.Industry.toLowerCase() : '';
        Integer industryScore = industryMap.containsKey(indKey) ? industryMap.get(indKey) : 0;
        if (industryScore > 0) {
            totalScore += industryScore;
            reasons.add(ld.Industry + ' Industry Tier (+' + industryScore + ')');
        }

        // 3. Lead Source Weightage (Max 15 pts)
        if (ld.LeadSource == 'Web' || ld.LeadSource == 'Referral') {
            totalScore += 15;
            reasons.add('High Intent Source: ' + ld.LeadSource + ' (+15)');
        } else if (String.isNotBlank(ld.LeadSource)) {
            totalScore += 5;
            reasons.add('Lead Source: ' + ld.LeadSource + ' (+5)');
        }

        // 4. Contact Data Completeness (Max 10 pts)
        Boolean hasPhone = String.isNotBlank(ld.Phone);
        Boolean hasEmail = String.isNotBlank(ld.Email);
        if (hasPhone && hasEmail) {
            totalScore += 10;
            reasons.add('Complete Contact Info (Phone & Email) (+10)');
        } else if (hasPhone || hasEmail) {
            totalScore += 5;
            reasons.add('Partial Contact Info (+5)');
        }

        // 5. Engagement Count (Max 15 pts)
        if (activityCount >= 3) {
            totalScore += 15;
            reasons.add('High Activity Count >= 3 (+15)');
        } else if (activityCount >= 1) {
            totalScore += 5;
            reasons.add('Logged Interactions (+5)');
        }

        // 6. Response Velocity (Max 15 pts)
        if (respondedWithin24Hr) {
            totalScore += 15;
            reasons.add('First Response within 24 Hours (+15)');
        }

        // Final score capped at 100
        result.score = Math.min(totalScore, 100);
        result.scoreReason = String.join(reasons, '\n');

        // Dynamic Next Best Action
        result.nextBestAction = determineNextBestAction(result.score, ld, activityCount, lastActivityDate);

        return result;
    }

    public static String determineNextBestAction(Integer score, Lead ld, Integer activityCount, Date lastActivityDate) {
        Integer daysSinceActivity = lastActivityDate != null ? lastActivityDate.daysBetween(Date.today()) : 999;

        if (String.isBlank(ld.Email) && String.isBlank(ld.Phone)) {
            return '⚠️ Contact details missing. Prompt user for Phone & Email before proceeding.';
        }
        if (score >= 70) {
            if (daysSinceActivity >= 5) {
                return '🔥 Hot Lead (Score ' + score + ') has had no interaction for ' + daysSinceActivity + ' days. Schedule immediate follow-up call today.';
            } else {
                return '🔥 Hot Lead (Score ' + score + '). Ready for qualification or demo presentation.';
            }
        } else if (score >= 40) {
            if (activityCount == 0) {
                return '⚡ Warm Lead (Score ' + score + '). Log initial discovery call or send intro email.';
            } else {
                return '⚡ Warm Lead (Score ' + score + '). Share product case studies and schedule technical discussion.';
            }
        } else {
            return '❄️ Cold Lead (Score ' + score + '). Enroll in marketing nurture email sequence.';
        }
    }

    public static void scoreLeads(List<Lead> leadsToScore) {
        if (leadsToScore == null || leadsToScore.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Lead ld : leadsToScore) {
            if (ld.Id != null) {
                leadIds.add(ld.Id);
            }
        }

        // Fetch activity metrics in bulk
        Map<Id, Integer> activityCountMap = new Map<Id, Integer>();
        Map<Id, Date> lastActivityMap = new Map<Id, Date>();
        Map<Id, Boolean> firstResponseMap = new Map<Id, Boolean>();

        if (!leadIds.isEmpty()) {
            for (Task t : [SELECT Id, WhoId, CreatedDate, ActivityDate FROM Task WHERE WhoId IN :leadIds ORDER BY CreatedDate ASC]) {
                Integer currentCount = activityCountMap.containsKey(t.WhoId) ? activityCountMap.get(t.WhoId) : 0;
                activityCountMap.put(t.WhoId, currentCount + 1);

                Date actDate = t.ActivityDate != null ? t.ActivityDate : Date.valueOf(t.CreatedDate);
                if (!lastActivityMap.containsKey(t.WhoId) || lastActivityMap.get(t.WhoId) < actDate) {
                    lastActivityMap.put(t.WhoId, actDate);
                }
            }
        }

        for (Lead ld : leadsToScore) {
            Integer actCount = activityCountMap.containsKey(ld.Id) ? activityCountMap.get(ld.Id) : 0;
            Date lastActDate = lastActivityMap.containsKey(ld.Id) ? lastActivityMap.get(ld.Id) : null;
            Boolean resp24 = false;
            if (ld.CreatedDate != null && lastActDate != null) {
                // If first activity within 1 day of lead creation
                resp24 = (Date.valueOf(ld.CreatedDate).daysBetween(lastActDate) <= 1);
            }

            LeadScoreResult res = calculateScore(ld, actCount, resp24, lastActDate);
            ld.AI_Lead_Score__c = res.score;
            ld.Lead_Score__c = res.score;
            ld.Score_Reason__c = res.scoreReason;
            ld.Next_Best_Action__c = res.nextBestAction;
        }
    }
}