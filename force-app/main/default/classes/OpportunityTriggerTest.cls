@isTest
private class OpportunityTriggerTest {

    @testSetup
    static void setupTestData() {
        // Create 1 parent Account for testing
        Account testAcc = new Account(
            Name = 'Day 20 Test Account',
            Type = 'Prospect',
            BillingCountry = 'United States',
            Industry = 'Agriculture'
        );
        insert testAcc;
    }

    @isTest
    static void testSingleHighValueOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Day 20 Test Account' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Single High Value Deal',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 75000
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity insertedOpp = [SELECT Id, Description FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual(
            'Hot Opportunity - Requires Fast Follow-up',
            insertedOpp.Description,
            'Description should be flagged as Hot Opportunity for Amount >= 50000'
        );
    }

    @isTest
    static void testSingleStandardOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Day 20 Test Account' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Single Standard Deal',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 25000
        );

        Test.startTest();
        insert opp;
        Test.stopTest();

        Opportunity insertedOpp = [SELECT Id, Description FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual(
            'Standard Opportunity',
            insertedOpp.Description,
            'Description should be Standard Opportunity for Amount < 50000'
        );
    }

    @isTest
    static void testBulk200Opportunities() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Day 20 Test Account' LIMIT 1];

        // Assessment Requirement: Process 200 Opportunities in a single bulk operation
        List<Opportunity> oppList = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            oppList.add(new Opportunity(
                Name = 'Bulk Test Opp ' + i,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                // First 100 are high value (>= 50k), next 100 are standard (< 50k)
                Amount = (i < 100) ? 60000 : 20000
            ));
        }

        Test.startTest();
        // Insert all 200 records in a single bulk DML statement
        insert oppList;
        Test.stopTest();

        // Verify all 200 records processed without hitting governor limits
        List<Opportunity> insertedOpps = [
            SELECT Id, Amount, Description 
            FROM Opportunity 
            WHERE AccountId = :acc.Id 
            ORDER BY Name ASC
        ];

        Assert.areEqual(200, insertedOpps.size(), 'All 200 Opportunities should be inserted successfully');

        Integer hotCount = 0;
        Integer standardCount = 0;
        for (Opportunity opp : insertedOpps) {
            if (opp.Description == 'Hot Opportunity - Requires Fast Follow-up') {
                hotCount++;
            } else if (opp.Description == 'Standard Opportunity') {
                standardCount++;
            }
        }

        Assert.areEqual(100, hotCount, 'Exactly 100 high-value opportunities should be tagged as Hot');
        Assert.areEqual(100, standardCount, 'Exactly 100 standard opportunities should be tagged as Standard');
    }

    @isTest
    static void testClosedWonCreatesCustomerProducts() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Day 20 Test Account' LIMIT 1];

        Contact testContact = new Contact(LastName = 'Test Primary', AccountId = acc.Id);
        insert testContact;

        Product2 prod = new Product2(Name = 'Test Cloud Plan', IsActive = true);
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Deal with Products',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Pricebook2Id = standardPricebookId,
            Amount = 4000,
            Primary_Contact__c = testContact.Id
        );
        insert opp;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 4,
            UnitPrice = 1000
        );
        insert oli;

        Test.startTest();
        opp.StageName = 'Closed Won';
        opp.Amount = 4000;
        opp.Contract_Signed__c = true;
        opp.Primary_Contact__c = testContact.Id;
        opp.OrderNumber__c = 'ORD-1234';
        opp.Expected_Go_Live_Date__c = Date.today().addDays(30);
        update opp;
        Test.stopTest();

        List<Customer_Product__c> customerProducts = [
            SELECT Id, Account__c, Product__c, Quantity__c, Status__c, Purchase_Date__c, Renewal_Date__c
            FROM Customer_Product__c
            WHERE Account__c = :acc.Id AND Product__c = :prod.Id
        ];

        Assert.areEqual(1, customerProducts.size(), 'One Customer_Product__c should be auto-created on Closed Won');
        Assert.areEqual(4, customerProducts[0].Quantity__c, 'Quantity should match line item quantity');
        Assert.areEqual('Active', customerProducts[0].Status__c, 'Status should be Active');
    }

    @isTest
    static void testClosedWonWithoutProductsSkipsSafely() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Day 20 Test Account' LIMIT 1];

        Contact testContact = new Contact(LastName = 'Test Primary 2', AccountId = acc.Id);
        insert testContact;

        Opportunity opp = new Opportunity(
            Name = 'Deal without Products',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Amount = 5000,
            Primary_Contact__c = testContact.Id
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        opp.Amount = 5000;
        opp.Contract_Signed__c = true;
        opp.Primary_Contact__c = testContact.Id;
        opp.OrderNumber__c = 'ORD-5678';
        opp.Expected_Go_Live_Date__c = Date.today().addDays(30);
        update opp;
        Test.stopTest();

        List<Customer_Product__c> customerProducts = [
            SELECT Id
            FROM Customer_Product__c
            WHERE Account__c = :acc.Id
        ];

        Assert.areEqual(0, customerProducts.size(), 'Zero Customer_Product__c should be created when deal has no products');
    }
}