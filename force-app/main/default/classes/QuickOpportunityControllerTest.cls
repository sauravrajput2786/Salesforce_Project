@isTest
private class QuickOpportunityControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test Account with valid Picklist values
        Account acc = new Account(
            Name = 'Quick Opp Test Corp',
            Industry = 'Technology',
            Type = 'Prospect',
            Phone = '1122334455',
            BillingCity = 'Chicago',
            BillingCountry = 'United States'
        );
        insert acc;

        // Create test Contact
        Contact con = new Contact(
            FirstName = 'Alice',
            LastName = 'Johnson',
            Title = 'VP Procurement',
            Email = 'alice.johnson@quickopptest.com',
            Phone = '1122334455',
            AccountId = acc.Id
        );
        insert con;

        // Create test Product & Standard PricebookEntry
        Product2 prod = new Product2(
            Name = 'Enterprise Analytics Suite',
            IsActive = true
        );
        insert prod;

        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 25000.00,
            IsActive = true
        );
        insert pbe;
    }

    @isTest
    static void testGetActiveProducts() {
        Test.startTest();
        List<QuickOpportunityWrapper.ProductOption> options = QuickOpportunityController.getActiveProducts();
        Test.stopTest();

        Assert.areNotEqual(null, options, 'Product options should not be null');
        Assert.isTrue(options.size() >= 1, 'Should return at least 1 active product option');
        Assert.areEqual('Enterprise Analytics Suite', options[0].name, 'Product name should match');
        Assert.areEqual(25000.00, options[0].unitPrice, 'Unit price should match');
    }

    @isTest
    static void testGetContactsByAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Quick Opp Test Corp' LIMIT 1];

        Test.startTest();
        List<QuickOpportunityWrapper.ContactOption> contacts = QuickOpportunityController.getContactsByAccount(acc.Id);
        List<QuickOpportunityWrapper.ContactOption> emptyContacts = QuickOpportunityController.getContactsByAccount(null);
        Test.stopTest();

        Assert.areEqual(1, contacts.size(), 'Should return 1 contact for test account');
        Assert.areEqual('Alice Johnson', contacts[0].name, 'Contact name should match');
        Assert.isTrue(emptyContacts.isEmpty(), 'Null account should return empty list');
    }

    @isTest
    static void testCreateQuickOpportunitySuccess() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Quick Opp Test Corp' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'alice.johnson@quickopptest.com' LIMIT 1];
        PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2.Name = 'Enterprise Analytics Suite' LIMIT 1];

        QuickOpportunityWrapper.CreateRequest req = new QuickOpportunityWrapper.CreateRequest();
        req.accountId = acc.Id;
        req.contactId = con.Id;
        req.productEntryId = pbe.Id;
        req.quantity = 2;
        req.unitPrice = 25000.00; // Total 50,000 -> triggers 'Hot Opportunity' logic
        req.closeDate = Date.today().addDays(15);
        req.stageName = 'Qualification';
        req.opportunityName = 'Custom Quick Deal';

        Test.startTest();
        Id oppId = QuickOpportunityController.createQuickOpportunity(req);
        Test.stopTest();

        Assert.areNotEqual(null, oppId, 'Created Opportunity Id should not be null');

        // Verify Opportunity
        Opportunity createdOpp = [
            SELECT Id, Name, AccountId, StageName, Amount, CloseDate, Description 
            FROM Opportunity 
            WHERE Id = :oppId
        ];
        Assert.areEqual('Custom Quick Deal', createdOpp.Name, 'Opp Name should match request');
        Assert.areEqual(50000.00, createdOpp.Amount, 'Amount should be 50,000');
        Assert.areEqual('Qualification', createdOpp.StageName, 'Stage should match request');
        Assert.areEqual('Hot Opportunity - Requires Fast Follow-up', createdOpp.Description, 'Trigger automation should set hot description for >= 50k');

        // Verify OpportunityContactRole
        List<OpportunityContactRole> ocrs = [
            SELECT Id, ContactId, IsPrimary, Role 
            FROM OpportunityContactRole 
            WHERE OpportunityId = :oppId
        ];
        Assert.areEqual(1, ocrs.size(), 'Should create 1 OpportunityContactRole');
        Assert.areEqual(con.Id, ocrs[0].ContactId, 'Contact Id should match');
        Assert.isTrue(ocrs[0].IsPrimary, 'Should be primary contact role');

        // Verify OpportunityLineItem
        List<OpportunityLineItem> lineItems = [
            SELECT Id, PricebookEntryId, Quantity, UnitPrice, TotalPrice 
            FROM OpportunityLineItem 
            WHERE OpportunityId = :oppId
        ];
        Assert.areEqual(1, lineItems.size(), 'Should create 1 OpportunityLineItem');
        Assert.areEqual(2, lineItems[0].Quantity, 'Quantity should be 2');
        Assert.areEqual(25000.00, lineItems[0].UnitPrice, 'Unit price should match');
    }

    @isTest
    static void testCreateQuickOpportunityValidationFailures() {
        QuickOpportunityWrapper.CreateRequest nullReq = null;
        try {
            QuickOpportunityController.createQuickOpportunity(nullReq);
            Assert.fail('Expected exception for null request');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'Exception caught as expected');
        }

        QuickOpportunityWrapper.CreateRequest missingAccReq = new QuickOpportunityWrapper.CreateRequest();
        missingAccReq.quantity = 1;
        try {
            QuickOpportunityController.createQuickOpportunity(missingAccReq);
            Assert.fail('Expected exception for missing account');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'Exception caught as expected');
        }
    }
}

