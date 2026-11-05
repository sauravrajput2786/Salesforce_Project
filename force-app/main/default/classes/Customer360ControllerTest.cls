@isTest
private class Customer360ControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test Account with valid Picklist values
        Account testAccount = new Account(
            Name = 'Test Customer Corp',
            Industry = 'Technology',
            Type = 'Prospect',
            Phone = '1234567890',
            BillingCity = 'San Francisco',
            BillingCountry = 'United States'
        );
        insert testAccount;

        // Create test Contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'John', LastName = 'Doe', Title = 'CTO', Email = 'john@test.com', AccountId = testAccount.Id),
            new Contact(FirstName = 'Jane', LastName = 'Smith', Title = 'VP Sales', Email = 'jane@test.com', AccountId = testAccount.Id)
        };
        insert contacts;

        // Create test Product
        Product2 testProduct = new Product2(Name = 'Test SaaS Plan', IsActive = true);
        insert testProduct;

        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = testProduct.Id,
            UnitPrice = 1000.00,
            IsActive = true
        );
        insert pbe;

        // Create Closed Won Opportunity with product
        Opportunity closedWonOpp = new Opportunity(
            Name = 'Test Closed Won Deal',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-30),
            Amount = 5000.00,
            Pricebook2Id = standardPbId
        );
        insert closedWonOpp;

        OpportunityLineItem lineItem = new OpportunityLineItem(
            OpportunityId = closedWonOpp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000.00
        );
        insert lineItem;

        // Create Open Opportunity
        Opportunity openOpp = new Opportunity(
            Name = 'Test Open Deal',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 2000.00
        );
        insert openOpp;
    }

    @isTest
    static void testGetCustomer360Data() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Customer Corp' LIMIT 1];

        Test.startTest();
        Customer360Wrapper result = Customer360Controller.getCustomer360Data(acc.Id);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.accountInfo, 'Account info should not be null');
        Assert.areEqual('Test Customer Corp', result.accountInfo.Name, 'Account name should match');

        Assert.areNotEqual(null, result.contacts, 'Contacts should not be null');
        Assert.areEqual(2, result.contacts.size(), 'Should return 2 contacts');

        Assert.areNotEqual(null, result.openOpportunities, 'Open opportunities should not be null');
        Assert.areEqual(1, result.openOpportunities.size(), 'Should return 1 open opportunity');

        Assert.areNotEqual(null, result.closedWonRevenue, 'Closed Won revenue should not be null');
        Assert.areEqual(5000.00, result.closedWonRevenue, 'Closed Won revenue should be 5000');

        Assert.areNotEqual(null, result.purchasedProducts, 'Purchased products should not be null');
        Assert.areEqual(1, result.purchasedProducts.size(), 'Should return 1 purchased product');
        Assert.areEqual('Test SaaS Plan', result.purchasedProducts[0], 'Product name should match');
    }

    @isTest
    static void testGetCustomer360DataWithNullId() {
        Test.startTest();
        Customer360Wrapper result = Customer360Controller.getCustomer360Data(null);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Should return empty wrapper, not null');
        Assert.areEqual(null, result.accountInfo, 'Account info should be null for null input');
        Assert.isTrue(result.contacts.isEmpty(), 'Contacts should be empty');
        Assert.isTrue(result.openOpportunities.isEmpty(), 'Open opportunities should be empty');
    }
}