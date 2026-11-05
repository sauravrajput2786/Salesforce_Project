public without sharing class Customer360AgentAction {

    public class Customer360Request {
        @InvocableVariable(label='Account ID' description='Salesforce record ID of the Account' required=false)
        public Id accountId;

        @InvocableVariable(label='Account Name' description='Company or Account Name to search for' required=false)
        public String accountName;
    }

    public class Customer360Response {
        @InvocableVariable(label='Is Success' description='True if Account summary was generated successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Account ID' description='Record ID of the summarized Account')
        public Id accountId;

        @InvocableVariable(label='Account Name' description='Name of the Account')
        public String accountName;

        @InvocableVariable(label='Account Owner' description='Name of the Account Owner')
        public String accountOwner;

        @InvocableVariable(label='Account Type' description='Account Type e.g. Prospect, Customer')
        public String accountType;

        @InvocableVariable(label='Industry' description='Account Industry')
        public String industry;

        @InvocableVariable(label='Rating' description='Account Rating e.g. Hot, Warm, Cold')
        public String rating;

        @InvocableVariable(label='Annual Revenue' description='Account Annual Revenue')
        public Decimal annualRevenue;

        @InvocableVariable(label='Employees' description='Number of employees')
        public Integer numberOfEmployees;

        @InvocableVariable(label='Phone' description='Phone number of the Account')
        public String phone;

        @InvocableVariable(label='Fax' description='Fax number of the Account')
        public String fax;

        @InvocableVariable(label='Website' description='Website URL of the Account')
        public String website;

        @InvocableVariable(label='Billing Address' description='Full Billing Address of the Account')
        public String billingAddress;

        @InvocableVariable(label='Shipping Address' description='Full Shipping Address of the Account')
        public String shippingAddress;

        @InvocableVariable(label='Customer Priority' description='Customer Priority e.g. High, Medium, Low')
        public String customerPriority;

        @InvocableVariable(label='Active Status' description='Account Active status e.g. Yes, No')
        public String activeStatus;

        @InvocableVariable(label='Account Description' description='Description and notes on the Account')
        public String accountDescription;

        @InvocableVariable(label='Lifetime Revenue' description='Total revenue from all Closed Won Opportunities')
        public Decimal lifetimeRevenue;

        @InvocableVariable(label='Open Deals Count' description='Count of active pipeline Opportunities')
        public Integer openDealsCount;

        @InvocableVariable(label='Open Cases Count' description='Count of open customer support cases')
        public Integer openCasesCount;

        @InvocableVariable(label='Total Contacts Count' description='Total number of contacts associated with this Account')
        public Integer totalContactsCount;

        @InvocableVariable(label='Contacts Detail' description='Detailed listing of all contacts including Name, Title, Email, Phone, Mobile, Department, Mailing Address, Lead Source, Owner')
        public String contactsDetail;

        @InvocableVariable(label='Opportunities Detail' description='Detailed listing of related opportunities with Stage, Amount, Expected Revenue, Close Date, Go-Live, Order Number, Delivery Status, and Approval Status')
        public String opportunitiesDetail;

        @InvocableVariable(label='Executive Briefing' description='Formatted 30-second conversational summary')
        public String executiveBriefing;
    }

    @InvocableMethod(
        label='Get Customer 360 Executive Briefing'
        description='Fetches Account-level executive briefing for Accounts: Lifetime Revenue and Support Cases. Do not use for Opportunity stage lookups or deal inquiries.'
        category='Customer Intelligence'
    )
    public static List<Customer360Response> getExecutiveBriefing(List<Customer360Request> requests) {
        List<Customer360Response> responses = new List<Customer360Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Customer360Request req : requests) {
            Customer360Response res = new Customer360Response();

            if (req == null || (req.accountId == null && String.isBlank(req.accountName))) {
                res.isSuccess = false;
                res.executiveBriefing = 'Account Name or ID is mandatory to generate a Customer 360 briefing. Which company would you like me to summarize, or would you like to abort?';
                responses.add(res);
                continue;
            }

            try {
                Account acc = findAccountWithDetails(req.accountId, req.accountName);

                if (acc == null) {
                    res.isSuccess = false;
                    res.executiveBriefing = 'No matching Account found. Would you like to check the spelling or provide another company name, or abort?';
                    responses.add(res);
                    continue;
                }

                Decimal totalWonAmount = 0;
                Integer openDeals = 0;
                Decimal openDealsAmount = 0;

                if (acc.Opportunities != null) {
                    for (Opportunity opp : acc.Opportunities) {
                        if (opp.IsWon) {
                            totalWonAmount += (opp.Amount != null ? opp.Amount : 0);
                        } else if (!opp.IsClosed) {
                            openDeals++;
                            openDealsAmount += (opp.Amount != null ? opp.Amount : 0);
                        }
                    }
                }

                Integer openCases = 0;
                Integer criticalCases = 0;

                if (acc.Cases != null) {
                    for (Case c : acc.Cases) {
                        if (!c.IsClosed) {
                            openCases++;
                            if (c.Priority == 'High' || c.Priority == 'Critical') {
                                criticalCases++;
                            }
                        }
                    }
                }

                res.isSuccess = true;
                res.accountId = acc.Id;
                res.accountName = acc.Name;
                res.lifetimeRevenue = totalWonAmount;
                res.openDealsCount = openDeals;
                res.openCasesCount = openCases;
                res.phone = acc.Phone;
                res.fax = acc.Fax;
                res.website = acc.Website;
                res.accountOwner = acc.Owner != null ? acc.Owner.Name : '';
                res.accountType = acc.Type;
                res.industry = acc.Industry;
                res.rating = acc.Rating;
                res.annualRevenue = acc.AnnualRevenue;
                res.numberOfEmployees = acc.NumberOfEmployees;
                res.customerPriority = acc.CustomerPriority__c;
                res.activeStatus = acc.Active__c;
                res.accountDescription = acc.Description;

                String fullBillingAddress = '';
                if (String.isNotBlank(acc.BillingStreet)) fullBillingAddress += acc.BillingStreet + ', ';
                if (String.isNotBlank(acc.BillingCity)) fullBillingAddress += acc.BillingCity + ', ';
                if (String.isNotBlank(acc.BillingState)) fullBillingAddress += acc.BillingState + ' ';
                if (String.isNotBlank(acc.BillingPostalCode)) fullBillingAddress += acc.BillingPostalCode + ', ';
                if (String.isNotBlank(acc.BillingCountry)) fullBillingAddress += acc.BillingCountry;
                fullBillingAddress = fullBillingAddress.removeEnd(', ').trim();
                if (String.isBlank(fullBillingAddress)) fullBillingAddress = 'Not Provided';
                res.billingAddress = fullBillingAddress;

                String fullShippingAddress = '';
                if (String.isNotBlank(acc.ShippingStreet)) fullShippingAddress += acc.ShippingStreet + ', ';
                if (String.isNotBlank(acc.ShippingCity)) fullShippingAddress += acc.ShippingCity + ', ';
                if (String.isNotBlank(acc.ShippingState)) fullShippingAddress += acc.ShippingState + ' ';
                if (String.isNotBlank(acc.ShippingPostalCode)) fullShippingAddress += acc.ShippingPostalCode + ', ';
                if (String.isNotBlank(acc.ShippingCountry)) fullShippingAddress += acc.ShippingCountry;
                fullShippingAddress = fullShippingAddress.removeEnd(', ').trim();
                if (String.isBlank(fullShippingAddress)) fullShippingAddress = 'Not Provided';
                res.shippingAddress = fullShippingAddress;

                Integer contactsCount = (acc.Contacts != null) ? acc.Contacts.size() : 0;
                res.totalContactsCount = contactsCount;

                String contactsInfo = '';
                if (acc.Contacts != null && !acc.Contacts.isEmpty()) {
                    for (Contact ct : acc.Contacts) {
                        String contactMailing = '';
                        if (String.isNotBlank(ct.MailingStreet)) contactMailing += ct.MailingStreet + ', ';
                        if (String.isNotBlank(ct.MailingCity)) contactMailing += ct.MailingCity + ', ';
                        if (String.isNotBlank(ct.MailingState)) contactMailing += ct.MailingState + ' ';
                        if (String.isNotBlank(ct.MailingPostalCode)) contactMailing += ct.MailingPostalCode + ', ';
                        if (String.isNotBlank(ct.MailingCountry)) contactMailing += ct.MailingCountry;
                        contactMailing = contactMailing.removeEnd(', ').trim();
                        if (String.isBlank(contactMailing)) contactMailing = 'N/A';

                        contactsInfo += '• Contact: ' + ct.Name + '\n' +
                                        '  - Title: ' + (String.isNotBlank(ct.Title) ? ct.Title : 'N/A') + '\n' +
                                        '  - Department: ' + (String.isNotBlank(ct.Department) ? ct.Department : 'N/A') + '\n' +
                                        '  - Email: ' + (String.isNotBlank(ct.Email) ? ct.Email : 'N/A') + '\n' +
                                        '  - Phone: ' + (String.isNotBlank(ct.Phone) ? ct.Phone : 'N/A') + '\n' +
                                        '  - Mobile: ' + (String.isNotBlank(ct.MobilePhone) ? ct.MobilePhone : 'N/A') + '\n' +
                                        '  - Home Phone: ' + (String.isNotBlank(ct.HomePhone) ? ct.HomePhone : 'N/A') + '\n' +
                                        '  - Other Phone: ' + (String.isNotBlank(ct.OtherPhone) ? ct.OtherPhone : 'N/A') + '\n' +
                                        '  - Fax: ' + (String.isNotBlank(ct.Fax) ? ct.Fax : 'N/A') + '\n' +
                                        '  - Lead Source: ' + (String.isNotBlank(ct.LeadSource) ? ct.LeadSource : 'N/A') + '\n' +
                                        '  - Mailing Address: ' + contactMailing + '\n' +
                                        '  - Languages: ' + (String.isNotBlank(ct.Languages__c) ? ct.Languages__c : 'N/A') + '\n' +
                                        '  - Level: ' + (String.isNotBlank(ct.Level__c) ? ct.Level__c : 'N/A') + '\n' +
                                        '  - Reports To: ' + (ct.ReportsTo != null ? ct.ReportsTo.Name : 'N/A') + '\n' +
                                        '  - Assistant: ' + (String.isNotBlank(ct.AssistantName) ? ct.AssistantName + (String.isNotBlank(ct.AssistantPhone) ? ' (' + ct.AssistantPhone + ')' : '') : 'N/A') + '\n' +
                                        '  - Contact Owner: ' + (ct.Owner != null ? ct.Owner.Name : 'N/A') + '\n';
                    }
                } else {
                    contactsInfo = 'No contacts associated with this Account.';
                }
                res.contactsDetail = contactsInfo.trim();

                String oppsInfo = '';
                if (acc.Opportunities != null && !acc.Opportunities.isEmpty()) {
                    for (Opportunity opp : acc.Opportunities) {
                        String stageLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Opportunity.SObjectType, Opportunity.StageName, opp.StageName);
                        String leadSourceLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Opportunity.SObjectType, Opportunity.LeadSource, opp.LeadSource);
                        String dealTypeLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Opportunity.SObjectType, Opportunity.Type, opp.Type);
                        String approvalLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Opportunity.SObjectType, Opportunity.Approval_Status__c, opp.Approval_Status__c);
                        String deliveryLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Opportunity.SObjectType, Opportunity.DeliveryInstallationStatus__c, opp.DeliveryInstallationStatus__c);

                        oppsInfo += '• Opportunity: ' + opp.Name + '\n' +
                                    '  - Owner: ' + (opp.Owner != null ? opp.Owner.Name : 'N/A') + '\n' +
                                    '  - Stage: ' + stageLabel + ' | Probability: ' + (opp.Probability != null ? opp.Probability + '%' : 'N/A') + '\n' +
                                    '  - Amount: $' + (opp.Amount != null ? opp.Amount.format() : '0') + '\n' +
                                    '  - Expected Revenue: $' + (opp.ExpectedRevenue != null ? opp.ExpectedRevenue.format() : '0') + '\n' +
                                    '  - Close Date: ' + (opp.CloseDate != null ? String.valueOf(opp.CloseDate) : 'N/A') + '\n' +
                                    '  - Expected Go-Live Date: ' + (opp.Expected_Go_Live_Date__c != null ? String.valueOf(opp.Expected_Go_Live_Date__c) : 'N/A') + '\n' +
                                    '  - Lead Source: ' + (String.isNotBlank(leadSourceLabel) ? leadSourceLabel : 'N/A') + '\n' +
                                    '  - Deal Type: ' + (String.isNotBlank(dealTypeLabel) ? dealTypeLabel : 'N/A') + '\n' +
                                    '  - Contract Signed: ' + (opp.Contract_Signed__c == true ? 'True' : 'False') + '\n' +
                                    '  - Discount Percentage: ' + (opp.Discount_Percentage__c != null ? opp.Discount_Percentage__c + '%' : 'None') + '\n' +
                                    '  - Approval Status: ' + (String.isNotBlank(approvalLabel) ? approvalLabel : 'Not Submitted') + '\n' +
                                    '  - Order Number: ' + (String.isNotBlank(opp.OrderNumber__c) ? opp.OrderNumber__c : 'N/A') + '\n' +
                                    '  - Delivery / Installation Status: ' + (String.isNotBlank(deliveryLabel) ? deliveryLabel : 'N/A') + '\n' +
                                    '  - Tracking Number: ' + (String.isNotBlank(opp.TrackingNumber__c) ? opp.TrackingNumber__c : 'N/A') + '\n' +
                                    '  - Primary Contact: ' + (opp.Primary_Contact__r != null ? opp.Primary_Contact__r.Name : 'None') + '\n' +
                                    '  - Next Step: ' + (String.isNotBlank(opp.NextStep) ? opp.NextStep : 'N/A') + '\n' +
                                    '  - Description: ' + (String.isNotBlank(opp.Description) ? opp.Description : 'None') + '\n';
                    }
                } else {
                    oppsInfo = 'No opportunities found for this Account.';
                }
                res.opportunitiesDetail = oppsInfo.trim();

                String accountTier = totalWonAmount >= 100000 ? 'Platinum Tier' : (totalWonAmount >= 25000 ? 'Gold Tier' : 'Standard Tier');
                String accTypeLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Account.SObjectType, Account.Type, acc.Type);
                String accIndustryLabel = CRMRecordDetailsAgentAction.getPicklistLabel(Account.SObjectType, Account.Industry, acc.Industry);

                String summary = '📊 **Customer 360 Comprehensive Briefing: ' + acc.Name + '** (' + accountTier + ')\n' +
                                 '• **Lifetime Value:** $' + totalWonAmount.format() + '\n' +
                                 '• **Active Pipeline:** ' + openDeals + ' open deal(s) totalling $' + openDealsAmount.format() + '\n' +
                                 '• **Support Health:** ' + openCases + ' open case(s) (' + criticalCases + ' high/critical priority)\n' +
                                 '• **Account Owner:** ' + (acc.Owner != null ? acc.Owner.Name : 'Not Assigned') + '\n' +
                                 '• **Phone:** ' + (acc.Phone != null ? acc.Phone : 'Not Provided') + '\n' +
                                 '• **Website:** ' + (acc.Website != null ? acc.Website : 'Not Provided') + '\n' +
                                 '• **Type / Industry:** ' + (String.isNotBlank(accTypeLabel) ? accTypeLabel : 'Prospect') + ' | ' + (String.isNotBlank(accIndustryLabel) ? accIndustryLabel : 'General') + '\n' +
                                 '• **Billing Address:** ' + fullBillingAddress + '\n' +
                                 '• **Contacts:** ' + contactsCount + ' associated contact(s)';

                res.executiveBriefing = summary;

            } catch (Exception ex) {
                res.isSuccess = false;
                res.executiveBriefing = 'Error generating Customer 360 briefing: ' + ex.getMessage();
            }

            responses.add(res);
        }

        return responses;
    }

    private static Account findAccountWithDetails(Id accountId, String accountName) {
        if (accountId != null) {
            List<Account> accounts = [
                SELECT Id, Name, Phone, Fax, Website, Industry, Type, Rating, Ownership, AccountNumber,
                       AnnualRevenue, NumberOfEmployees, Description, CustomerPriority__c, Active__c,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                       Owner.Name,
                       (SELECT Id, Name, Amount, ExpectedRevenue, StageName, Probability, CloseDate,
                               LeadSource, Type, NextStep, Description, Expected_Go_Live_Date__c,
                               Discount_Percentage__c, Contract_Signed__c, Approval_Status__c,
                               OrderNumber__c, DeliveryInstallationStatus__c, TrackingNumber__c,
                               Owner.Name, Primary_Contact__r.Name, IsWon, IsClosed FROM Opportunities),
                       (SELECT Id, CaseNumber, Status, Priority, IsClosed FROM Cases),
                       (SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, HomePhone,
                               OtherPhone, Fax, LeadSource, MailingStreet, MailingCity, MailingState,
                               MailingPostalCode, MailingCountry, Languages__c, Level__c,
                               ReportsTo.Name, AssistantName, AssistantPhone, Title, Department, Owner.Name FROM Contacts)
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            return accounts.isEmpty() ? null : accounts[0];
        } else if (String.isNotBlank(accountName)) {
            String cleanName = accountName.trim().replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '');
            String wildcardQuery = '%' + cleanName + '%';
            List<Account> accounts = [
                SELECT Id, Name, Phone, Fax, Website, Industry, Type, Rating, Ownership, AccountNumber,
                       AnnualRevenue, NumberOfEmployees, Description, CustomerPriority__c, Active__c,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                       ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                       Owner.Name,
                       (SELECT Id, Name, Amount, ExpectedRevenue, StageName, Probability, CloseDate,
                               LeadSource, Type, NextStep, Description, Expected_Go_Live_Date__c,
                               Discount_Percentage__c, Contract_Signed__c, Approval_Status__c,
                               OrderNumber__c, DeliveryInstallationStatus__c, TrackingNumber__c,
                               Owner.Name, Primary_Contact__r.Name, IsWon, IsClosed FROM Opportunities),
                       (SELECT Id, CaseNumber, Status, Priority, IsClosed FROM Cases),
                       (SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, HomePhone,
                               OtherPhone, Fax, LeadSource, MailingStreet, MailingCity, MailingState,
                               MailingPostalCode, MailingCountry, Languages__c, Level__c,
                               ReportsTo.Name, AssistantName, AssistantPhone, Title, Department, Owner.Name FROM Contacts)
                FROM Account
                WHERE Name LIKE :wildcardQuery
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                return accounts[0];
            }

            if (cleanName.contains(' ')) {
                String firstWord = cleanName.substringBefore(' ').trim();
                if (firstWord.length() >= 3) {
                    accounts = [
                        SELECT Id, Name, Phone, Fax, Website, Industry, Type, Rating, Ownership, AccountNumber,
                               AnnualRevenue, NumberOfEmployees, Description, CustomerPriority__c, Active__c,
                               BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                               ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                               Owner.Name,
                               (SELECT Id, Name, Amount, ExpectedRevenue, StageName, Probability, CloseDate,
                                       LeadSource, Type, NextStep, Description, Expected_Go_Live_Date__c,
                                       Discount_Percentage__c, Contract_Signed__c, Approval_Status__c,
                                       OrderNumber__c, DeliveryInstallationStatus__c, TrackingNumber__c,
                                       Owner.Name, Primary_Contact__r.Name, IsWon, IsClosed FROM Opportunities),
                               (SELECT Id, CaseNumber, Status, Priority, IsClosed FROM Cases),
                               (SELECT Id, Name, FirstName, LastName, Email, Phone, MobilePhone, HomePhone,
                                       OtherPhone, Fax, LeadSource, MailingStreet, MailingCity, MailingState,
                                       MailingPostalCode, MailingCountry, Languages__c, Level__c,
                                       ReportsTo.Name, AssistantName, AssistantPhone, Title, Department, Owner.Name FROM Contacts)
                        FROM Account
                        WHERE Name LIKE :('%' + firstWord + '%')
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!accounts.isEmpty()) {
                        return accounts[0];
                    }
                }
            }
        }
        return null;
    }
}
