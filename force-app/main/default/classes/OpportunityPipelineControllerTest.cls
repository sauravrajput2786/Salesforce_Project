@isTest
private class OpportunityPipelineControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test Account
        Account acc = new Account(
            Name = 'Pipeline Test Corp',
            Industry = 'Banking',
            Type = 'Prospect',
            BillingCity = 'New York',
            BillingCountry = 'United States'
        );
        insert acc;

        // Create opportunities across various stages
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Opp Qual', AccountId = acc.Id, StageName = 'Qualification', Amount = 100000.00, CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Opp Disc', AccountId = acc.Id, StageName = 'Discovery', Amount = 150000.00, CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Opp Prop', AccountId = acc.Id, StageName = 'Proposal/Price Quote', Amount = 250000.00, CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Opp Nego', AccountId = acc.Id, StageName = 'Negotiation/Review', Amount = 200000.00, CloseDate = Date.today().addDays(30))
        };
        insert opps;
    }

    @isTest
    static void testGetPipelineSummarySuccess() {
        Test.startTest();
        OpportunityPipelineDTO.PipelineResult result = OpportunityPipelineController.getPipelineSummary();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(700000.00, result.grandTotalAmount, 'Grand total open pipeline should equal 700,000');
        Assert.areEqual(4, result.totalDeals, 'Total open deals count should be 4 (excluding Closed deals)');
        Assert.areEqual(4, result.stages.size(), 'Should return 4 distinct open stages');

        // Verify percentages
        Decimal totalPercent = 0.0;
        for (OpportunityPipelineDTO.StageSummary stage : result.stages) {
            Assert.isTrue(stage.totalAmount > 0, 'Stage amount should be > 0');
            Assert.areEqual(1, stage.dealCount, 'Each test stage has 1 deal');
            totalPercent += stage.percentageOfTotal;
        }
        Assert.isTrue(totalPercent >= 99.0 && totalPercent <= 101.0, 'Percentages should sum approximately to 100%');
    }

    @isTest
    static void testGetPipelineSummaryEmpty() {
        // Delete all open opportunities
        delete [SELECT Id FROM Opportunity WHERE IsClosed = false];

        Test.startTest();
        OpportunityPipelineDTO.PipelineResult result = OpportunityPipelineController.getPipelineSummary();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null even when empty');
        Assert.areEqual(0.00, result.grandTotalAmount, 'Grand total should be 0');
        Assert.areEqual(0, result.totalDeals, 'Total deals should be 0');
        Assert.isTrue(result.stages.isEmpty(), 'Stages should be empty');
    }
}

