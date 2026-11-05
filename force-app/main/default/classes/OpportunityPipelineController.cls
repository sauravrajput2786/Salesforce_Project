/**
 * @description Controller for Opportunity Pipeline Summary LWC widget (Day 25).
 * Enforces role hierarchy and sharing rules using 'with sharing' and USER_MODE.
 * Aggregates open opportunity pipeline by stage without N+1 queries.
 */
public with sharing class OpportunityPipelineController {

    /**
     * @description Fetches aggregated pipeline data for all open opportunities grouped by Stage.
     * @return OpportunityPipelineDTO.PipelineResult containing stage breakdown and grand totals.
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityPipelineDTO.PipelineResult getPipelineSummary() {
        OpportunityPipelineDTO.PipelineResult result = new OpportunityPipelineDTO.PipelineResult();

        try {
            // Aggregate query for open opportunities in USER_MODE
            List<AggregateResult> aggResults = [
                SELECT StageName stage, SUM(Amount) totalAmt, COUNT(Id) cnt
                FROM Opportunity
                WHERE IsClosed = false
                WITH USER_MODE
                GROUP BY StageName
                ORDER BY SUM(Amount) DESC
            ];

            Decimal grandTotal = 0.00;
            Integer totalDeals = 0;

            // First pass: compute grand totals
            for (AggregateResult ar : aggResults) {
                Decimal stageAmount = (Decimal) ar.get('totalAmt');
                Integer dealCount = (Integer) ar.get('cnt');

                if (stageAmount != null) {
                    grandTotal += stageAmount;
                }
                if (dealCount != null) {
                    totalDeals += dealCount;
                }
            }

            result.grandTotalAmount = grandTotal;
            result.totalDeals = totalDeals;

            // Second pass: compute percentage and populate stages
            for (AggregateResult ar : aggResults) {
                String stage = (String) ar.get('stage');
                Decimal stageAmount = (Decimal) ar.get('totalAmt');
                Integer dealCount = (Integer) ar.get('cnt');

                Decimal actualAmount = stageAmount != null ? stageAmount : 0.00;
                Integer actualCount = dealCount != null ? dealCount : 0;

                Decimal percentage = 0.0;
                if (grandTotal > 0) {
                    percentage = ((actualAmount / grandTotal) * 100).setScale(1);
                }

                result.stages.add(new OpportunityPipelineDTO.StageSummary(
                    stage,
                    actualAmount,
                    actualCount,
                    percentage
                ));
            }

            return result;

        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load pipeline summary: ' + ex.getMessage());
        }
    }
}

