public without sharing class CRMRecordDetailsAgentAction {

    public class RecordDetailsRequest {
        @InvocableVariable(label='Record Name or ID' description='Name or Salesforce ID of the Opportunity, Account, Lead, or Contact' required=false)
        public String recordName;

        @InvocableVariable(label='Record Type' description='Optional object type: Opportunity, Account, Lead, Contact, or Auto' required=false)
        public String recordType;
    }

    public class RecordDetailsResponse {
        @InvocableVariable(label='Is Success' description='True if record was found and details retrieved successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Record ID' description='Salesforce ID of the record')
        public Id recordId;

        @InvocableVariable(label='Record Name' description='Name of the record')
        public String recordName;

        @InvocableVariable(label='Record Type' description='Type of record: Opportunity, Account, Lead, or Contact')
        public String recordType;

        @InvocableVariable(label='Stage or Status' description='StageName for Opportunity or Status for Lead')
        public String stageOrStatus;

        @InvocableVariable(label='Amount or Budget' description='Amount for Opportunity, Estimated Budget for Lead, or Annual Revenue for Account')
        public Decimal amountOrBudget;

        @InvocableVariable(label='Close or Go-Live Date' description='Close Date or Expected Go-Live Date for Opportunity')
        public Date closeOrGoLiveDate;

        @InvocableVariable(label='Owner Name' description='Name of the Record Owner')
        public String ownerName;

        @InvocableVariable(label='Parent Account Name' description='Associated Account Name for Opportunity or Contact')
        public String parentAccountName;

        @InvocableVariable(label='Primary Contact Name' description='Primary Contact for Opportunity or Decision Maker')
        public String primaryContactName;

        @InvocableVariable(label='Phone' description='Phone number')
        public String phone;

        @InvocableVariable(label='Email' description='Email address')
        public String email;

        @InvocableVariable(label='Title or Industry' description='Title for Lead/Contact or Industry for Account/Lead')
        public String titleOrIndustry;

        @InvocableVariable(label='Details Summary' description='Comprehensive formatted breakdown of all fields and details')
        public String detailsSummary;
    }

    @InvocableMethod(
        label='Get CRM Record Details'
        description='Retrieves complete details such as Stage, Amount, Close Date, Status, Owner for any Opportunity, Deal, Account, Lead, or Contact by name or ID. Use this for all Opportunity and deal stage inquiries.'
        category='CRM Intelligence'
    )
    public static List<RecordDetailsResponse> getRecordDetails(List<RecordDetailsRequest> requests) {
        List<RecordDetailsResponse> responses = new List<RecordDetailsResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (RecordDetailsRequest req : requests) {
            RecordDetailsResponse res = new RecordDetailsResponse();

            if (req == null || String.isBlank(req.recordName)) {
                res.isSuccess = false;
                res.detailsSummary = 'Record Name or ID is mandatory to retrieve details. Which record would you like me to look up, or would you like to abort?';
                responses.add(res);
                continue;
            }

            String searchRef = req.recordName.trim();
            String cleanName = searchRef.replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '');
            String wildcard = '%' + cleanName + '%';
            String targetType = String.isNotBlank(req.recordType) ? req.recordType.trim().toLowerCase() : 'auto';

            // Check if input is a direct 15 or 18 character Salesforce ID
            Boolean isDirectId = (cleanName.length() == 15 || cleanName.length() == 18) &&
                (cleanName.startsWith('006') || cleanName.startsWith('001') || cleanName.startsWith('00Q') || cleanName.startsWith('003'));

            Boolean handled = false;

            // 1. Direct ID evaluation
            if (isDirectId) {
                try {
                    Id parsedId = (Id) cleanName;
                    if (cleanName.startsWith('006')) {
                        handled = inspectOpportunityById(parsedId, res);
                    } else if (cleanName.startsWith('001')) {
                        handled = inspectAccountById(parsedId, res);
                    } else if (cleanName.startsWith('00Q')) {
                        handled = inspectLeadById(parsedId, res);
                    } else if (cleanName.startsWith('003')) {
                        handled = inspectContactById(parsedId, res);
                    }
                } catch (Exception ex) {
                    // Fall through to name search
                }
            }

            // 2. Explicit or Inferred Type Search
            if (!handled) {
                if (targetType.contains('opp') || targetType.contains('deal')) {
                    handled = searchOpportunity(wildcard, res);
                } else if (targetType.contains('acc') || targetType.contains('company')) {
                    handled = searchAccount(wildcard, res);
                } else if (targetType.contains('lead') || targetType.contains('prospect')) {
                    handled = searchLead(wildcard, res);
                } else if (targetType.contains('contact') || targetType.contains('person')) {
                    handled = searchContact(wildcard, res);
                }
            }

            // 3. Auto / Fallback Search Across Objects
            if (!handled) {
                // Priority 1: Opportunity (Most common for stage/deal lookups)
                handled = searchOpportunity(wildcard, res);

                // Priority 2: Account
                if (!handled) {
                    handled = searchAccount(wildcard, res);
                }

                // Priority 3: Lead
                if (!handled) {
                    handled = searchLead(wildcard, res);
                }

                // Priority 4: Contact
                if (!handled) {
                    handled = searchContact(wildcard, res);
                }
            }

            if (!handled) {
                res.isSuccess = false;
                res.detailsSummary = 'Could not find any Opportunity, Account, Lead, or Contact matching "' + cleanName + '". Please check the spelling or provide another name.';
            }

            responses.add(res);
        }

        return responses;
    }

    private static Boolean inspectOpportunityById(Id oppId, RecordDetailsResponse res) {
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, ExpectedRevenue, Probability, CloseDate, Type,
                   LeadSource, NextStep, Description, Expected_Go_Live_Date__c, Discount_Percentage__c,
                   Contract_Signed__c, Approval_Status__c, OrderNumber__c, DeliveryInstallationStatus__c,
                   TrackingNumber__c, Loss_Reason__c, Implementation_Type__c, Competitor__c,
                   Account.Name, Account.Id, Primary_Contact__r.Name, Owner.Name, IsWon, IsClosed
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        if (!opps.isEmpty()) {
            populateOpportunityResponse(opps[0], res);
            return true;
        }
        return false;
    }

    private static Boolean searchOpportunity(String wildcard, RecordDetailsResponse res) {
        String cleanTerm = wildcard.replace('%', '').trim();
        String firstWord = cleanTerm.contains(' ') ? cleanTerm.substringBefore(' ').trim() : cleanTerm;
        String firstWordWildcard = '%' + firstWord + '%';

        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, ExpectedRevenue, Probability, CloseDate, Type,
                   LeadSource, NextStep, Description, Expected_Go_Live_Date__c, Discount_Percentage__c,
                   Contract_Signed__c, Approval_Status__c, OrderNumber__c, DeliveryInstallationStatus__c,
                   TrackingNumber__c, Loss_Reason__c, Implementation_Type__c, Competitor__c,
                   Account.Name, Account.Id, Primary_Contact__r.Name, Owner.Name, IsWon, IsClosed
            FROM Opportunity
            WHERE Name LIKE :wildcard OR Name LIKE :firstWordWildcard
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!opps.isEmpty()) {
            populateOpportunityResponse(opps[0], res);
            return true;
        }
        return false;
    }

    private static void populateOpportunityResponse(Opportunity opp, RecordDetailsResponse res) {
        res.isSuccess = true;
        res.recordId = opp.Id;
        res.recordName = opp.Name;
        res.recordType = 'Opportunity';
        String stageLabel = getPicklistLabel(Opportunity.SObjectType, Opportunity.StageName, opp.StageName);
        res.stageOrStatus = stageLabel;
        res.amountOrBudget = opp.Amount;
        res.closeOrGoLiveDate = opp.CloseDate;
        res.ownerName = opp.Owner != null ? opp.Owner.Name : 'Unassigned';
        res.parentAccountName = opp.Account != null ? opp.Account.Name : 'None';
        res.primaryContactName = opp.Primary_Contact__r != null ? opp.Primary_Contact__r.Name : 'None';

        String amountStr = opp.Amount != null ? '$' + opp.Amount.format() : '$0';
        String expRevStr = opp.ExpectedRevenue != null ? '$' + opp.ExpectedRevenue.format() : '$0';
        String probStr = opp.Probability != null ? String.valueOf(opp.Probability) + '%' : 'N/A';
        String contractSignedStr = opp.Contract_Signed__c == true ? 'Yes' : 'No';
        String goLiveStr = opp.Expected_Go_Live_Date__c != null ? String.valueOf(opp.Expected_Go_Live_Date__c) : 'Not specified';
        String discountStr = opp.Discount_Percentage__c != null ? String.valueOf(opp.Discount_Percentage__c) + '%' : '0%';
        String approvalLabel = getPicklistLabel(Opportunity.SObjectType, Opportunity.Approval_Status__c, opp.Approval_Status__c);
        String approvalStr = String.isNotBlank(approvalLabel) ? approvalLabel : 'None';
        String orderNumStr = String.isNotBlank(opp.OrderNumber__c) ? opp.OrderNumber__c : 'Not Generated';
        String deliveryLabel = getPicklistLabel(Opportunity.SObjectType, Opportunity.DeliveryInstallationStatus__c, opp.DeliveryInstallationStatus__c);
        String deliveryStr = String.isNotBlank(deliveryLabel) ? deliveryLabel : 'Not Started';

        res.detailsSummary = 'Opportunity Details for "' + opp.Name + '":\n' +
                             '• **Stage:** ' + stageLabel + '\n' +
                             '• **Amount:** ' + amountStr + '\n' +
                             '• **Probability:** ' + probStr + '\n' +
                             '• **Expected Revenue:** ' + expRevStr + '\n' +
                             '• **Close Date:** ' + opp.CloseDate + '\n' +
                             '• **Expected Go-Live:** ' + goLiveStr + '\n' +
                             '• **Contract Signed:** ' + contractSignedStr + '\n' +
                             '• **Discount:** ' + discountStr + ' (Approval: ' + approvalStr + ')\n' +
                             '• **Order Number:** ' + orderNumStr + ' (Delivery: ' + deliveryStr + ')\n' +
                             '• **Account:** ' + res.parentAccountName + '\n' +
                             '• **Primary Contact:** ' + res.primaryContactName + '\n' +
                             '• **Owner:** ' + res.ownerName + '\n' +
                             (String.isNotBlank(opp.Description) ? '• **Notes:** ' + opp.Description : '');
    }

    private static Boolean inspectAccountById(Id accId, RecordDetailsResponse res) {
        List<Account> accs = [
            SELECT Id, Name, Phone, Fax, Website, Industry, Type, Rating, Ownership, AccountNumber,
                   AnnualRevenue, NumberOfEmployees, Description, CustomerPriority__c, Active__c,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Owner.Name
            FROM Account
            WHERE Id = :accId
            LIMIT 1
        ];
        if (!accs.isEmpty()) {
            populateAccountResponse(accs[0], res);
            return true;
        }
        return false;
    }

    private static Boolean searchAccount(String wildcard, RecordDetailsResponse res) {
        List<Account> accs = [
            SELECT Id, Name, Phone, Fax, Website, Industry, Type, Rating, Ownership, AccountNumber,
                   AnnualRevenue, NumberOfEmployees, Description, CustomerPriority__c, Active__c,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Owner.Name
            FROM Account
            WHERE Name LIKE :wildcard
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!accs.isEmpty()) {
            populateAccountResponse(accs[0], res);
            return true;
        }
        return false;
    }

    private static void populateAccountResponse(Account acc, RecordDetailsResponse res) {
        res.isSuccess = true;
        res.recordId = acc.Id;
        res.recordName = acc.Name;
        res.recordType = 'Account';
        String typeLabel = getPicklistLabel(Account.SObjectType, Account.Type, acc.Type);
        String industryLabel = getPicklistLabel(Account.SObjectType, Account.Industry, acc.Industry);
        String ratingLabel = getPicklistLabel(Account.SObjectType, Account.Rating, acc.Rating);
        String priorityLabel = getPicklistLabel(Account.SObjectType, Account.CustomerPriority__c, acc.CustomerPriority__c);

        res.stageOrStatus = String.isNotBlank(typeLabel) ? typeLabel : 'Prospect';
        res.amountOrBudget = acc.AnnualRevenue;
        res.ownerName = acc.Owner != null ? acc.Owner.Name : 'Unassigned';
        res.phone = acc.Phone;
        res.titleOrIndustry = industryLabel;

        String revStr = acc.AnnualRevenue != null ? '$' + acc.AnnualRevenue.format() : 'N/A';
        String priorityStr = String.isNotBlank(priorityLabel) ? priorityLabel : 'Standard';
        String activeStr = String.isNotBlank(acc.Active__c) ? acc.Active__c : 'Yes';

        res.detailsSummary = 'Account Details for "' + acc.Name + '":\n' +
                             '• **Type / Industry:** ' + (String.isNotBlank(typeLabel) ? typeLabel : 'Prospect') + ' | ' + (String.isNotBlank(industryLabel) ? industryLabel : 'General') + '\n' +
                             '• **Rating:** ' + (String.isNotBlank(ratingLabel) ? ratingLabel : 'Standard') + '\n' +
                             '• **Customer Priority:** ' + priorityStr + '\n' +
                             '• **Annual Revenue:** ' + revStr + '\n' +
                             '• **Phone:** ' + (acc.Phone != null ? acc.Phone : 'N/A') + '\n' +
                             '• **Website:** ' + (acc.Website != null ? acc.Website : 'N/A') + '\n' +
                             '• **Billing Country:** ' + (acc.BillingCountry != null ? acc.BillingCountry : 'N/A') + '\n' +
                             '• **Owner:** ' + res.ownerName;
    }

    private static Boolean inspectLeadById(Id leadId, RecordDetailsResponse res) {
        List<Lead> leads = [
            SELECT Id, Name, FirstName, LastName, Title, Company, Status, Email, Phone, MobilePhone,
                   Website, Industry, LeadSource, Rating, AnnualRevenue, NumberOfEmployees,
                   City, State, Country, Estimated_Budget__c, IsConverted, Owner.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (!leads.isEmpty()) {
            populateLeadResponse(leads[0], res);
            return true;
        }
        return false;
    }

    private static Boolean searchLead(String wildcard, RecordDetailsResponse res) {
        List<Lead> leads = [
            SELECT Id, Name, FirstName, LastName, Title, Company, Status, Email, Phone, MobilePhone,
                   Website, Industry, LeadSource, Rating, AnnualRevenue, NumberOfEmployees,
                   City, State, Country, Estimated_Budget__c, IsConverted, Owner.Name
            FROM Lead
            WHERE (Name LIKE :wildcard OR Company LIKE :wildcard) AND IsConverted = false
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!leads.isEmpty()) {
            populateLeadResponse(leads[0], res);
            return true;
        }
        return false;
    }

    private static void populateLeadResponse(Lead ld, RecordDetailsResponse res) {
        res.isSuccess = true;
        res.recordId = ld.Id;
        res.recordName = ld.Name;
        res.recordType = 'Lead';
        String statusLabel = getPicklistLabel(Lead.SObjectType, Lead.Status, ld.Status);
        res.stageOrStatus = statusLabel;
        res.amountOrBudget = ld.Estimated_Budget__c;
        res.ownerName = ld.Owner != null ? ld.Owner.Name : 'Unassigned';
        res.phone = ld.Phone;
        res.email = ld.Email;
        String industryLabel = getPicklistLabel(Lead.SObjectType, Lead.Industry, ld.Industry);
        res.titleOrIndustry = ld.Title != null ? ld.Title : industryLabel;

        String budgetStr = ld.Estimated_Budget__c != null ? '$' + ld.Estimated_Budget__c.format() : 'N/A';
        String leadSourceLabel = getPicklistLabel(Lead.SObjectType, Lead.LeadSource, ld.LeadSource);
        String ratingLabel = getPicklistLabel(Lead.SObjectType, Lead.Rating, ld.Rating);

        res.detailsSummary = 'Lead Details for "' + ld.Name + '":\n' +
                             '• **Company:** ' + ld.Company + '\n' +
                             '• **Status:** ' + statusLabel + '\n' +
                             '• **Title:** ' + (ld.Title != null ? ld.Title : 'N/A') + '\n' +
                             '• **Estimated Budget:** ' + budgetStr + '\n' +
                             '• **Email:** ' + (ld.Email != null ? ld.Email : 'N/A') + '\n' +
                             '• **Phone:** ' + (ld.Phone != null ? ld.Phone : 'N/A') + '\n' +
                             '• **Industry:** ' + (industryLabel != null ? industryLabel : 'N/A') + '\n' +
                             '• **Lead Source:** ' + (leadSourceLabel != null ? leadSourceLabel : 'N/A') + '\n' +
                             '• **Rating:** ' + (ratingLabel != null ? ratingLabel : 'N/A') + '\n' +
                             '• **Owner:** ' + res.ownerName;
    }

    private static Boolean inspectContactById(Id contactId, RecordDetailsResponse res) {
        List<Contact> contacts = [
            SELECT Id, Name, FirstName, LastName, Title, Department, Email, Phone, MobilePhone,
                   LeadSource, Account.Name, Account.Id, ReportsTo.Name, Owner.Name
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            populateContactResponse(contacts[0], res);
            return true;
        }
        return false;
    }

    private static Boolean searchContact(String wildcard, RecordDetailsResponse res) {
        List<Contact> contacts = [
            SELECT Id, Name, FirstName, LastName, Title, Department, Email, Phone, MobilePhone,
                   LeadSource, Account.Name, Account.Id, ReportsTo.Name, Owner.Name
            FROM Contact
            WHERE Name LIKE :wildcard
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            populateContactResponse(contacts[0], res);
            return true;
        }
        return false;
    }

    private static void populateContactResponse(Contact con, RecordDetailsResponse res) {
        res.isSuccess = true;
        res.recordId = con.Id;
        res.recordName = con.Name;
        res.recordType = 'Contact';
        res.ownerName = con.Owner != null ? con.Owner.Name : 'Unassigned';
        res.parentAccountName = con.Account != null ? con.Account.Name : 'None';
        res.phone = con.Phone;
        res.email = con.Email;
        res.titleOrIndustry = con.Title;
        String leadSourceLabel = getPicklistLabel(Contact.SObjectType, Contact.LeadSource, con.LeadSource);

        res.detailsSummary = 'Contact Details for "' + con.Name + '":\n' +
                             '• **Account:** ' + res.parentAccountName + '\n' +
                             '• **Title / Role:** ' + (con.Title != null ? con.Title : 'N/A') + '\n' +
                             '• **Department:** ' + (con.Department != null ? con.Department : 'N/A') + '\n' +
                             '• **Email:** ' + (con.Email != null ? con.Email : 'N/A') + '\n' +
                             '• **Phone:** ' + (con.Phone != null ? con.Phone : 'N/A') + '\n' +
                             '• **Mobile:** ' + (con.MobilePhone != null ? con.MobilePhone : 'N/A') + '\n' +
                             '• **Lead Source:** ' + (leadSourceLabel != null ? leadSourceLabel : 'N/A') + '\n' +
                             '• **Reports To:** ' + (con.ReportsTo != null ? con.ReportsTo.Name : 'N/A') + '\n' +
                             '• **Owner:** ' + res.ownerName;
    }

    private static Map<String, Map<String, String>> picklistLabelCache = new Map<String, Map<String, String>>();

    public static String getPicklistLabel(SObjectType objType, SObjectField field, String apiValue) {
        if (String.isBlank(apiValue) || objType == null || field == null) {
            return apiValue;
        }
        String cacheKey = objType.getDescribe().getName() + '.' + field.getDescribe().getName();
        if (!picklistLabelCache.containsKey(cacheKey)) {
            Map<String, String> valueToLabel = new Map<String, String>();
            if (objType == Lead.SObjectType && field == Lead.Status) {
                for (LeadStatus ls : [SELECT MasterLabel, ApiName FROM LeadStatus]) {
                    valueToLabel.put(ls.ApiName.toLowerCase(), ls.MasterLabel);
                }
            } else {
                for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
                    valueToLabel.put(pe.getValue().toLowerCase(), pe.getLabel());
                }
            }
            picklistLabelCache.put(cacheKey, valueToLabel);
        }
        Map<String, String> labels = picklistLabelCache.get(cacheKey);
        String lowerVal = apiValue.toLowerCase();
        return labels.containsKey(lowerVal) ? labels.get(lowerVal) : apiValue;
    }
}

