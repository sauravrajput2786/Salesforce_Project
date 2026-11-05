@isTest
private class OpportunityCalculatorControllerTest {

    @testSetup
    static void setupTestData() {
        Id standardPbId = Test.getStandardPricebookId();

        Product2 activeProd = new Product2(
            Name = 'Test SaaS Plan',
            IsActive = true
        );
        insert activeProd;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = activeProd.Id,
            UnitPrice = 250.00,
            IsActive = true
        );
        insert pbe;
    }

    @isTest
    static void testGetActiveProducts() {
        Test.startTest();
        List<OpportunityCalculatorController.ProductOption> options = 
            OpportunityCalculatorController.getActiveProducts();
        Test.stopTest();

        Assert.areNotEqual(null, options, 'Options list should not be null');
        Assert.isTrue(options.size() > 0, 'Should return at least one active product');
        
        OpportunityCalculatorController.ProductOption opt = options[0];
        Assert.areEqual('Test SaaS Plan', opt.name, 'Product name should match test record');
        Assert.areEqual(250.00, opt.unitPrice, 'Unit price should match test record');
    }
}