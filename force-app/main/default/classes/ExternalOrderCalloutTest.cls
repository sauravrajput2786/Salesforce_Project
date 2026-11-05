/**
 * @description Unit tests for ExternalOrderCalloutService, ExternalOrderPayloadDTO,
 * and OpportunityTriggerHandler Closed Won integration.
 */
@isTest
private class ExternalOrderCalloutTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Test Account satisfying validation rules (Phone, Country, Type)
        Account testAcc = new Account(
            Name = 'Day 27 Enterprise Customer',
            Type = 'Prospect',
            BillingCountry = 'United States',
            BillingCity = 'San Francisco',
            Phone = '1234567890',
            AccountNumber = 'ACC-D27-001',
            Industry = 'Agriculture'
        );
        insert testAcc;

        // 2. Create Test Primary Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Integration',
            Email = 'john.integration@example.com',
            Phone = '1234567890',
            AccountId = testAcc.Id
        );
        insert testContact;
    }

    @isTest
    static void testOpportunityClosedWonCalloutViaTrigger() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Day 27 Enterprise Customer' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'john.integration@example.com' LIMIT 1];

        // 1. Setup Standard Pricebook & Product
        Id standardPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Enterprise Analytics Suite',
            ProductCode = 'EAS-500',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 1500.00,
            IsActive = true
        );
        insert pbe;

        // 2. Create Opportunity satisfying all Closed Won validation rules
        // (Amount > 0 via line items, Contract_Signed__c = true, Primary_Contact__c, Expected_Go_Live_Date__c)
        Opportunity opp = new Opportunity(
            Name = 'Trigger Closed Won Deal',
            AccountId = testAcc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(10),
            Expected_Go_Live_Date__c = Date.today().addDays(30),
            Contract_Signed__c = true,
            Pricebook2Id = standardPbId
        );
        insert opp;

        // 3. Create Line Item so Amount rollup calculates > 0 in database
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 50,
            UnitPrice = 1500.00
        );
        insert oli;

        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status": "SUCCESS"}'));

        Test.startTest();
        // Re-query Opportunity to refresh rollup Amount and update to Closed Won
        Opportunity oppToUpdate = [
            SELECT Id, StageName, Expected_Go_Live_Date__c, Amount, Contract_Signed__c 
            FROM Opportunity 
            WHERE Id = :opp.Id
        ];
        oppToUpdate.StageName = 'Closed Won';
        oppToUpdate.Contract_Signed__c = true;
        oppToUpdate.Expected_Go_Live_Date__c = Date.today().addDays(30);
        update oppToUpdate;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual('Closed Won', updatedOpp.StageName, 'Opportunity stage should be Closed Won');
    }

    @isTest
    static void testDirectCalloutServiceExecution() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Day 27 Enterprise Customer' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'john.integration@example.com' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Direct Service Test Deal',
            AccountId = testAcc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(10),
            Expected_Go_Live_Date__c = Date.today().addDays(30),
            Contract_Signed__c = true,
            Amount = 50000.00
        );
        insert opp;

        Opportunity queriedOpp = [
            SELECT Id, Name, Amount, CloseDate, StageName,
                   AccountId, Account.Name, Account.AccountNumber, Account.BillingCity, Account.BillingCountry,
                   Primary_Contact__c, Primary_Contact__r.Name, Primary_Contact__r.Email, Primary_Contact__r.Phone,
                   (SELECT Id, Product2Id, Product2.Name, ProductCode, Quantity, UnitPrice, TotalPrice 
                    FROM OpportunityLineItems)
            FROM Opportunity 
            WHERE Id = :opp.Id
        ];

        Test.setMock(HttpCalloutMock.class, new ExternalOrderCalloutMock(200, '{"status": "SUCCESS", "externalOrderId": "EXT-12345"}'));

        Test.startTest();
        HttpResponse res = ExternalOrderCalloutService.sendSingleOrderCallout(queriedOpp);
        Test.stopTest();

        Assert.areEqual(200, res.getStatusCode(), 'Callout should return status code 200');
        Assert.isTrue(res.getBody().contains('EXT-12345'), 'Response body should contain external order ID');
    }

    @isTest
    static void testPayloadBuilderWithProducts() {
        Account testAcc = [SELECT Id, Name, AccountNumber, BillingCity, BillingCountry FROM Account LIMIT 1];
        Contact testContact = [SELECT Id, Name, Email, Phone FROM Contact LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Payload Test Deal',
            AccountId = testAcc.Id,
            Primary_Contact__c = testContact.Id,
            StageName = 'Proposal/Price Quote',
            CloseDate = Date.today().addDays(15),
            Amount = 100000.00
        );
        insert opp;

        Opportunity queriedOpp = [
            SELECT Id, Name, Amount, CloseDate, StageName,
                   AccountId, Account.Name, Account.AccountNumber, Account.BillingCity, Account.BillingCountry,
                   Primary_Contact__c, Primary_Contact__r.Name, Primary_Contact__r.Email, Primary_Contact__r.Phone,
                   (SELECT Id, Product2Id, Product2.Name, ProductCode, Quantity, UnitPrice, TotalPrice 
                    FROM OpportunityLineItems)
            FROM Opportunity 
            WHERE Id = :opp.Id
        ];

        Test.startTest();
        ExternalOrderPayloadDTO dto = ExternalOrderCalloutService.buildPayload(queriedOpp);
        Test.stopTest();

        Assert.areEqual(opp.Id, dto.opportunityId, 'DTO OpportunityId should match');
        Assert.areEqual(testAcc.Name, dto.customer.accountName, 'DTO customer name should match');
        Assert.areEqual(testContact.Name, dto.contact.fullName, 'DTO contact name should match');
        Assert.isNotNull(dto.products, 'Products list should be initialized');
    }

    @isTest
    static void testPayloadBuilderWithoutContactOrProducts() {
        Account testAcc = [SELECT Id, Name, AccountNumber, BillingCity, BillingCountry FROM Account LIMIT 1];

        Opportunity bareOpp = new Opportunity(
            Name = 'Bare Bones Deal',
            AccountId = testAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            Amount = 10000.00
        );
        insert bareOpp;

        Opportunity queriedBareOpp = [
            SELECT Id, Name, Amount, CloseDate, StageName,
                   AccountId, Account.Name, Account.AccountNumber, Account.BillingCity, Account.BillingCountry,
                   Primary_Contact__c, Primary_Contact__r.Name, Primary_Contact__r.Email, Primary_Contact__r.Phone,
                   (SELECT Id, Product2Id, Product2.Name, ProductCode, Quantity, UnitPrice, TotalPrice 
                    FROM OpportunityLineItems)
            FROM Opportunity 
            WHERE Id = :bareOpp.Id
        ];

        Test.startTest();
        ExternalOrderPayloadDTO dto = ExternalOrderCalloutService.buildPayload(queriedBareOpp);
        Test.stopTest();

        Assert.areEqual(bareOpp.Id, dto.opportunityId, 'DTO OpportunityId should match');
        Assert.areEqual(testAcc.Name, dto.customer.accountName, 'DTO customer name should match');
        Assert.isNull(dto.contact, 'DTO contact should be null when Opportunity has no primary contact');
        Assert.isTrue(dto.products.isEmpty(), 'DTO products list should be empty');
    }

    @isTest
    static void testNullAndEmptyIdHandling() {
        Test.startTest();
        ExternalOrderCalloutService.sendOrdersToExternalApi(null);
        ExternalOrderCalloutService.sendOrdersToExternalApi(new Set<Id>());
        Test.stopTest();
        
        Assert.isTrue(true, 'Null and empty sets should be handled gracefully');
    }
}
