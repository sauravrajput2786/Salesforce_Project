@IsTest
private class SubscriptionProductTriggerTest {

    @TestSetup
    static void setupTestData() {
        Account testAcc = new Account(
            Name = 'Cloud Enterprise Corp',
            Industry = 'Technology',
            Type = 'Customer',
            BillingCountry = 'India',
            BillingCity = 'Mumbai',
            BillingStreet = '123 Tech Park',
            Phone = '+91 9988776655'
        );
        insert testAcc;

        Product2 testProd1 = new Product2(
            Name = 'Enterprise SaaS Suite',
            IsActive = true
        );
        Product2 testProd2 = new Product2(
            Name = 'Analytics Add-On',
            IsActive = true
        );
        insert new List<Product2>{ testProd1, testProd2 };

        Customer_Subscription__c sub1 = new Customer_Subscription__c(
            Account__c = testAcc.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1),
            Subscription_Status__c = 'Active',
            Annual_Contract_Value__c = 0
        );
        Customer_Subscription__c sub2 = new Customer_Subscription__c(
            Account__c = testAcc.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1),
            Subscription_Status__c = 'Active',
            Annual_Contract_Value__c = 0
        );
        insert new List<Customer_Subscription__c>{ sub1, sub2 };
    }

    @IsTest
    static void testInsertProductsCalculatesRollup() {
        Customer_Subscription__c sub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        Subscription_Product__c p1 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 2,
            Unit_Price__c = 1500
        );
        Subscription_Product__c p2 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 1,
            Unit_Price__c = 500
        );
        insert new List<Subscription_Product__c>{ p1, p2 };
        Test.stopTest();

        Customer_Subscription__c updatedSub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c WHERE Id = :sub.Id];
        // 2*1500 + 1*500 = 3500
        Assert.areEqual(3500, updatedSub.Annual_Contract_Value__c, 'Annual Contract Value should equal the sum of product total prices.');
    }

    @IsTest
    static void testUpdateProductRecalculatesRollup() {
        Customer_Subscription__c sub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Subscription_Product__c p1 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 1,
            Unit_Price__c = 1000
        );
        insert p1;

        Test.startTest();
        // Update quantity from 1 to 4
        p1.Quantity__c = 4;
        p1.Unit_Price__c = 1250;
        update p1;
        Test.stopTest();

        Customer_Subscription__c updatedSub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c WHERE Id = :sub.Id];
        // 4 * 1250 = 5000
        Assert.areEqual(5000, updatedSub.Annual_Contract_Value__c, 'Annual Contract Value should update after product price/quantity change.');
    }

    @IsTest
    static void testDeleteAndUndeleteRecalculatesRollup() {
        Customer_Subscription__c sub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Subscription_Product__c p1 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 2,
            Unit_Price__c = 1000
        );
        Subscription_Product__c p2 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 1,
            Unit_Price__c = 1000
        );
        insert new List<Subscription_Product__c>{ p1, p2 };

        Test.startTest();
        // Delete p2 (1000)
        delete p2;
        Customer_Subscription__c subAfterDelete = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c WHERE Id = :sub.Id];
        Assert.areEqual(2000, subAfterDelete.Annual_Contract_Value__c, 'Total should decrease to 2000 after deleting p2.');

        // Undelete p2
        undelete p2;
        Customer_Subscription__c subAfterUndelete = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c WHERE Id = :sub.Id];
        Assert.areEqual(3000, subAfterUndelete.Annual_Contract_Value__c, 'Total should restore to 3000 after undeleting p2.');
        Test.stopTest();
    }

    @IsTest
    static void testDeleteAllProductsSetsZero() {
        Customer_Subscription__c sub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        Subscription_Product__c p1 = new Subscription_Product__c(
            Customer_Subscription__c = sub.Id,
            Product__c = prod.Id,
            Quantity__c = 1,
            Unit_Price__c = 2000
        );
        insert p1;

        Test.startTest();
        delete p1;
        Test.stopTest();

        Customer_Subscription__c updatedSub = [SELECT Id, Annual_Contract_Value__c FROM Customer_Subscription__c WHERE Id = :sub.Id];
        Assert.areEqual(0, updatedSub.Annual_Contract_Value__c, 'Annual Contract Value should be 0 when all products are deleted.');
    }
}

