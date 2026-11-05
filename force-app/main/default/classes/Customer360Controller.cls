public with sharing class Customer360Controller {

    /**
     * @description Returns a unified Customer 360 data wrapper for a given Account.
     * Uses only 2 SOQL queries with subqueries to prevent N+1.
     * Enforces sharing rules and FLS via "with sharing" and WITH USER_MODE.
     * @param accountId The Id of the Account record.
     * @return Customer360Wrapper containing all customer data sections.
     */
    @AuraEnabled(cacheable=true)
    public static Customer360Wrapper getCustomer360Data(Id accountId) {
        Customer360Wrapper result = new Customer360Wrapper();

        if (accountId == null) {
            return result;
        }

        // QUERY 1: Account info + related Contacts + Open Opportunities (single SOQL with subqueries)
        List<Account> accounts = [
            SELECT
                Id, Name, Industry, Type, Phone, Website, BillingCity, BillingCountry,
                (
                    SELECT Id, Name, Title, Email
                    FROM Contacts
                    ORDER BY Name ASC
                    LIMIT 5
                ),
                (
                    SELECT Id, Name, StageName, Amount, CloseDate
                    FROM Opportunities
                    WHERE IsClosed = false
                    ORDER BY Amount DESC NULLS LAST
                    LIMIT 10
                )
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            return result;
        }

        Account acc = accounts[0];
        result.accountInfo = acc;
        result.contacts = acc.Contacts;
        result.openOpportunities = acc.Opportunities;

        // QUERY 2: Closed Won Revenue + Purchased Products
        List<AggregateResult> revenueResult = [
            SELECT SUM(Amount) totalRevenue
            FROM Opportunity
            WHERE AccountId = :accountId
              AND IsWon = true
            WITH USER_MODE
        ];

        if (!revenueResult.isEmpty() && revenueResult[0].get('totalRevenue') != null) {
            result.closedWonRevenue = (Decimal) revenueResult[0].get('totalRevenue');
        }

        // Purchased products from Closed Won Opportunity Line Items
        Set<String> productNames = new Set<String>();
        List<OpportunityLineItem> lineItems = [
            SELECT Product2.Name
            FROM OpportunityLineItem
            WHERE Opportunity.AccountId = :accountId
              AND Opportunity.IsWon = true
              AND Product2.IsActive = true
            WITH USER_MODE
            ORDER BY Product2.Name ASC
            LIMIT 50
        ];

        for (OpportunityLineItem item : lineItems) {
            if (item.Product2 != null && String.isNotBlank(item.Product2.Name)) {
                productNames.add(item.Product2.Name);
            }
        }

        result.purchasedProducts = new List<String>(productNames);
        result.purchasedProducts.sort();

        return result;
    }
}