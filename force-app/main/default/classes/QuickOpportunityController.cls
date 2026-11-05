/**
 * @description Controller for Quick Opportunity Creator LWC widget.
 * Enforces strict role hierarchy and sharing rules using 'with sharing' and USER_MODE.
 * Maintains transactional integrity using Savepoints.
 */
public with sharing class QuickOpportunityController {

    /**
     * @description Fetches active products and their standard PricebookEntry records.
     * @return List of ProductOption wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<QuickOpportunityWrapper.ProductOption> getActiveProducts() {
        List<QuickOpportunityWrapper.ProductOption> options = new List<QuickOpportunityWrapper.ProductOption>();

        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Product2.Name, UnitPrice, Pricebook2Id
            FROM PricebookEntry
            WHERE IsActive = true
              AND Product2.IsActive = true
            WITH USER_MODE
            ORDER BY Product2.Name ASC
            LIMIT 100
        ];

        for (PricebookEntry pbe : entries) {
            options.add(new QuickOpportunityWrapper.ProductOption(
                pbe.Id,
                pbe.Product2Id,
                pbe.Product2.Name,
                pbe.UnitPrice != null ? pbe.UnitPrice : 0.00
            ));
        }

        return options;
    }

    /**
     * @description Fetches contacts belonging to the selected Account.
     * @param accountId Id of the selected Account
     * @return List of ContactOption wrappers
     */
    @AuraEnabled(cacheable=true)
    public static List<QuickOpportunityWrapper.ContactOption> getContactsByAccount(Id accountId) {
        List<QuickOpportunityWrapper.ContactOption> contacts = new List<QuickOpportunityWrapper.ContactOption>();

        if (accountId == null) {
            return contacts;
        }

        List<Contact> contactList = [
            SELECT Id, Name, Title, Email
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 100
        ];

        for (Contact c : contactList) {
            contacts.add(new QuickOpportunityWrapper.ContactOption(
                c.Id,
                c.Name,
                c.Title,
                c.Email
            ));
        }

        return contacts;
    }

    /**
     * @description Creates an Opportunity with its Product Line Item and Contact Role in a single atomic transaction.
     * @param request QuickOpportunityWrapper.CreateRequest containing user input fields
     * @return Id of the created Opportunity
     */
    @AuraEnabled
    public static Id createQuickOpportunity(QuickOpportunityWrapper.CreateRequest request) {
        if (request == null) {
            throw new AuraHandledException('Invalid request payload.');
        }
        if (request.accountId == null) {
            throw new AuraHandledException('Account is required.');
        }
        if (request.productEntryId == null) {
            throw new AuraHandledException('Product is required.');
        }
        if (request.quantity == null || request.quantity <= 0) {
            throw new AuraHandledException('Quantity must be greater than 0.');
        }
        if (request.closeDate == null) {
            throw new AuraHandledException('Close Date is required.');
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Fetch PricebookEntry and Account details in User Mode
            PricebookEntry pbe = [
                SELECT Id, Product2Id, Product2.Name, Pricebook2Id, UnitPrice
                FROM PricebookEntry
                WHERE Id = :request.productEntryId
                WITH USER_MODE
                LIMIT 1
            ];

            Account acc = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :request.accountId
                WITH USER_MODE
                LIMIT 1
            ];

            // Determine Opportunity Name
            String oppName = String.isNotBlank(request.opportunityName) 
                ? request.opportunityName 
                : acc.Name + ' - ' + pbe.Product2.Name;

            String stage = String.isNotBlank(request.stageName) 
                ? request.stageName 
                : 'Prospecting';

            Decimal unitPrice = (request.unitPrice != null) ? request.unitPrice : (pbe.UnitPrice != null ? pbe.UnitPrice : 0.00);
            Decimal totalAmount = request.quantity * unitPrice;

            // 1. Create and Insert Opportunity
            Opportunity newOpp = new Opportunity(
                Name = oppName,
                AccountId = acc.Id,
                CloseDate = request.closeDate,
                StageName = stage,
                Amount = totalAmount,
                Pricebook2Id = pbe.Pricebook2Id
            );
            Database.insert(newOpp, AccessLevel.USER_MODE);

            // 2. Create and Insert OpportunityContactRole if contact provided
            if (request.contactId != null) {
                OpportunityContactRole ocr = new OpportunityContactRole(
                    OpportunityId = newOpp.Id,
                    ContactId = request.contactId,
                    IsPrimary = true,
                    Role = 'Decision Maker'
                );
                Database.insert(ocr, AccessLevel.USER_MODE);
            }

            // 3. Create and Insert OpportunityLineItem
            OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId = newOpp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = request.quantity,
                UnitPrice = unitPrice
            );
            Database.insert(oli, AccessLevel.USER_MODE);

            return newOpp.Id;

        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException(ex.getMessage());
        }
    }
}

