public with sharing class OpportunityPipelineDTO {

    public class StageSummary {
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Integer dealCount { get; set; }
        @AuraEnabled public Decimal percentageOfTotal { get; set; }

        public StageSummary(String stageName, Decimal totalAmount, Integer dealCount, Decimal percentageOfTotal) {
            this.stageName = stageName;
            this.totalAmount = totalAmount != null ? totalAmount : 0.00;
            this.dealCount = dealCount != null ? dealCount : 0;
            this.percentageOfTotal = percentageOfTotal != null ? percentageOfTotal : 0.00;
        }
    }

    public class PipelineResult {
        @AuraEnabled public List<StageSummary> stages { get; set; }
        @AuraEnabled public Decimal grandTotalAmount { get; set; }
        @AuraEnabled public Integer totalDeals { get; set; }

        public PipelineResult() {
            this.stages = new List<StageSummary>();
            this.grandTotalAmount = 0.00;
            this.totalDeals = 0;
        }
    }
}

