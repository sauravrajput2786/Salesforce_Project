public without sharing class LeadConversionAgentAction {

    public class LeadConversionRequest {
        @InvocableVariable(label='Lead ID or Name' description='Salesforce ID, Full Name, or Company of the Lead to convert' required=false)
        public String leadId;

        @InvocableVariable(label='Lead Name' description='Full name or company of the Lead to convert' required=false)
        public String leadName;

        @InvocableVariable(label='Company Name' description='Company or organization name of the Lead to convert' required=false)
        public String company;

        @InvocableVariable(label='Lead Email' description='Email of the Lead to convert if ID is not known' required=false)
        public String email;

        @InvocableVariable(label='Opportunity Name' description='Custom name for the newly created Opportunity' required=false)
        public String opportunityName;

        @InvocableVariable(label='Estimated Budget' description='Deal budget or amount to assign to the Opportunity' required=false)
        public Decimal amount;

        @InvocableVariable(label='Opportunity Stage' description='Stage for the created Opportunity. Defaults to Discovery. If Closed Won is selected, Expected Go-Live Date, Amount, and Contract Signed are validated.' required=false)
        public String stageName;

        @InvocableVariable(label='Expected Go-Live Date' description='Required if Opportunity Stage is Closed Won' required=false)
        public Date expectedGoLiveDate;

        @InvocableVariable(label='Contract Signed' description='True if contract has been executed (required for Closed Won)' required=false)
        public Boolean contractSigned;

        @InvocableVariable(label='Account Type' description='Account Type (e.g. Prospect, Customer). Required by Account validation rule. Defaults to Prospect.' required=false)
        public String accountType;

        @InvocableVariable(label='Billing Country' description='Country for the Account to satisfy validation rules' required=false)
        public String billingCountry;

        @InvocableVariable(label='Industry' description='Industry for the Account to satisfy validation rules' required=false)
        public String industry;

        @InvocableVariable(label='Phone' description='Phone number for the Account and Contact to satisfy validation rules' required=false)
        public String phone;

        @InvocableVariable(label='Website' description='Website URL for the Account (required if Account Type is Enterprise)' required=false)
        public String website;
    }

    public class LeadConversionResponse {
        @InvocableVariable(label='Is Success' description='True if lead was converted successfully, false otherwise')
        public Boolean isSuccess;

        @InvocableVariable(label='Account ID' description='ID of the newly created or linked Account')
        public Id accountId;

        @InvocableVariable(label='Contact ID' description='ID of the newly created Contact')
        public Id contactId;

        @InvocableVariable(label='Opportunity ID' description='ID of the newly created Opportunity')
        public Id opportunityId;

        @InvocableVariable(label='Account Name' description='Name of the linked or created Account')
        public String accountName;

        @InvocableVariable(label='Contact Name' description='Name of the linked or created Contact')
        public String contactName;

        @InvocableVariable(label='Opportunity Name' description='Name of the linked or created Opportunity')
        public String opportunityName;

        @InvocableVariable(label='Message' description='Conversational confirmation or interactive option prompt')
        public String message;
    }

    @InvocableMethod(
        label='Qualify and Convert Lead'
        description='Converts a Lead into an Account, Contact, and Opportunity with full pre-flight validation, duplicate prevention, and closed-won guardrails.'
        category='Sales Operations'
    )
    public static List<LeadConversionResponse> convertLead(List<LeadConversionRequest> requests) {
        List<LeadConversionResponse> responses = new List<LeadConversionResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (LeadConversionRequest req : requests) {
            LeadConversionResponse res = new LeadConversionResponse();

            if (req == null || (String.isBlank(req.leadId) && String.isBlank(req.email) && String.isBlank(req.leadName) && String.isBlank(req.company))) {
                res.isSuccess = false;
                res.message = 'Please provide the Lead name, company, or email address to qualify and convert this lead. Would you like to provide these details now, or abort?';
                responses.add(res);
                continue;
            }

            try {
                Lead targetLead = findLead(req.leadId, req.email, req.leadName, req.company);
                if (targetLead == null) {
                    res.isSuccess = false;
                    String searchRef = String.isNotBlank(req.leadName) ? req.leadName : (String.isNotBlank(req.company) ? req.company : (String.isNotBlank(req.leadId) ? req.leadId : req.email));
                    res.message = 'Could not find any open Lead matching "' + searchRef + '". Would you like to check the spelling or provide another name or company, or abort?';
                    responses.add(res);
                    continue;
                }

                if (targetLead.IsConverted) {
                    res.isSuccess = false;
                    res.accountId = targetLead.ConvertedAccountId;
                    res.contactId = targetLead.ConvertedContactId;
                    res.opportunityId = targetLead.ConvertedOpportunityId;

                    String linkedAccountName = targetLead.Company;
                    String linkedOppName = 'None';
                    String linkedContactName = targetLead.Name;

                    if (targetLead.ConvertedAccountId != null) {
                        List<Account> linkedAccs = [SELECT Id, Name FROM Account WHERE Id = :targetLead.ConvertedAccountId LIMIT 1];
                        if (!linkedAccs.isEmpty()) {
                            linkedAccountName = linkedAccs[0].Name;
                        }
                    }
                    if (targetLead.ConvertedOpportunityId != null) {
                        List<Opportunity> linkedOpps = [SELECT Id, Name FROM Opportunity WHERE Id = :targetLead.ConvertedOpportunityId LIMIT 1];
                        if (!linkedOpps.isEmpty()) {
                            linkedOppName = linkedOpps[0].Name;
                        }
                    }
                    if (targetLead.ConvertedContactId != null) {
                        List<Contact> linkedCons = [SELECT Id, Name FROM Contact WHERE Id = :targetLead.ConvertedContactId LIMIT 1];
                        if (!linkedCons.isEmpty()) {
                            linkedContactName = linkedCons[0].Name;
                        }
                    }

                    res.accountName = linkedAccountName;
                    res.opportunityName = linkedOppName;
                    res.contactName = linkedContactName;

                    res.message = 'The lead "' + targetLead.Name + '" has already been converted. Here are the linked records:\n' +
                                  '• Account: ' + linkedAccountName + '\n' +
                                  '• Opportunity: ' + linkedOppName + '\n' +
                                  '• Contact: ' + linkedContactName + '\n\n' +
                                  'Would you like to review or update any details for these records, or perform another action?';
                    responses.add(res);
                    continue;
                }

                // 1. Resolve Effective Field Values
                String effectiveCountry = String.isNotBlank(req.billingCountry) ? req.billingCountry.trim() : targetLead.Country;
                String effectiveIndustry = String.isNotBlank(req.industry) ? req.industry.trim() : targetLead.Industry;
                String effectivePhone = String.isNotBlank(req.phone) ? req.phone.trim() : targetLead.Phone;
                String effectiveWebsite = String.isNotBlank(req.website) ? req.website.trim() : targetLead.Website;
                String effectiveAccountType = String.isNotBlank(req.accountType) ? req.accountType.trim() : 'Prospect';
                String effectiveStage = String.isNotBlank(req.stageName) ? req.stageName.trim() : 'Discovery';
                Decimal effectiveAmount = (req.amount != null && req.amount > 0) ? req.amount : targetLead.Estimated_Budget__c;

                // 2. Pre-Flight Validation Checks
                List<String> missingFields = new List<String>();
                if (String.isBlank(effectiveCountry)) missingFields.add('Billing Country');
                if (String.isBlank(effectiveIndustry)) missingFields.add('Industry');
                if (effectiveIndustry == 'Technology' && String.isBlank(effectivePhone)) missingFields.add('Phone (Mandatory for Technology Industry)');
                if (String.isBlank(effectiveAccountType)) missingFields.add('Account Type');
                if (effectiveAccountType == 'Enterprise' && String.isBlank(effectiveWebsite)) missingFields.add('Website (Mandatory for Enterprise Accounts)');

                if (effectiveStage == 'Closed Won') {
                    if (effectiveAmount == null || effectiveAmount <= 0) missingFields.add('Amount (> $0 mandatory for Closed Won)');
                    if (req.expectedGoLiveDate == null) missingFields.add('Expected Go-Live Date (Mandatory for Closed Won)');
                    if (req.contractSigned != true) missingFields.add('Contract Signed = True (Mandatory for Closed Won)');
                }

                if (!missingFields.isEmpty()) {
                    res.isSuccess = false;
                    res.message = 'To qualify and convert Lead "' + targetLead.Name + '", the following mandatory details are required:\n' +
                                  '• ' + String.join(missingFields, '\n• ') + '\n' +
                                  'Would you like to provide these details now, or abort this conversion?';
                    responses.add(res);
                    continue;
                }

                // 3. Update Lead if necessary
                Boolean leadNeedsUpdate = false;
                if (targetLead.Country != effectiveCountry) { targetLead.Country = effectiveCountry; leadNeedsUpdate = true; }
                if (targetLead.Industry != effectiveIndustry) { targetLead.Industry = effectiveIndustry; leadNeedsUpdate = true; }
                if (targetLead.Phone != effectivePhone) { targetLead.Phone = effectivePhone; leadNeedsUpdate = true; }
                if (leadNeedsUpdate) { update targetLead; }

                // 4. Duplicate Check & Smart Account Linking
                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(targetLead.Id);
                lc.setConvertedStatus('Closed - Converted');

                Boolean isLinkedToExistingAccount = false;
                List<Account> existingAccounts = [
                    SELECT Id, Name FROM Account 
                    WHERE Name = :targetLead.Company 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];

                if (!existingAccounts.isEmpty()) {
                    lc.setAccountId(existingAccounts[0].Id);
                    isLinkedToExistingAccount = true;
                } else {
                    // Pre-create Account to satisfy all Account validation rules cleanly
                    Account newAcc = new Account(
                        Name = targetLead.Company,
                        BillingCountry = effectiveCountry,
                        Industry = effectiveIndustry,
                        Type = effectiveAccountType,
                        Phone = effectivePhone,
                        Website = effectiveWebsite
                    );
                    Database.DMLOptions dml = new Database.DMLOptions();
                    dml.DuplicateRuleHeader.AllowSave = true;
                    dml.DuplicateRuleHeader.runAsCurrentUser = true;
                    Database.SaveResult sr = Database.insert(newAcc, dml);
                    if (sr.isSuccess()) {
                        lc.setAccountId(sr.getId());
                    } else {
                        res.isSuccess = false;
                        res.message = 'Account creation failed: ' + sr.getErrors()[0].getMessage();
                        responses.add(res);
                        continue;
                    }
                }

                String oppName = String.isNotBlank(req.opportunityName) ? req.opportunityName.trim() : targetLead.Company + ' - Core Deal';
                lc.setOpportunityName(oppName);

                // 5. Execute Lead Conversion
                Database.LeadConvertResult lcr = Database.convertLead(lc, false);

                if (lcr.isSuccess()) {
                    res.isSuccess = true;
                    res.accountId = lcr.getAccountId();
                    res.contactId = lcr.getContactId();
                    res.opportunityId = lcr.getOpportunityId();

                    // 6. Enrich newly created Opportunity
                    if (lcr.getOpportunityId() != null) {
                        Opportunity oppToUpdate = new Opportunity(
                            Id = lcr.getOpportunityId(),
                            StageName = effectiveStage,
                            CloseDate = Date.today().addDays(30),
                            Primary_Contact__c = lcr.getContactId()
                        );

                        if (effectiveAmount != null && effectiveAmount > 0) {
                            oppToUpdate.Amount = effectiveAmount;
                        }
                        if (req.expectedGoLiveDate != null) {
                            oppToUpdate.Expected_Go_Live_Date__c = req.expectedGoLiveDate;
                        }
                        if (req.contractSigned != null) {
                            oppToUpdate.Contract_Signed__c = req.contractSigned;
                        }

                        update oppToUpdate;
                    }

                    String accountNote = isLinkedToExistingAccount ? ' [Linked to existing Account]' : ' [New Account created]';
                    String amountNote = effectiveAmount != null ? ', Amount: $' + effectiveAmount.format() : '';
                    res.accountName = targetLead.Company;
                    res.opportunityName = oppName;
                    res.contactName = targetLead.Name;
                    res.message = '🎉 Lead "' + targetLead.Name + '" qualified and converted successfully!\n' +
                                  '• **Account:** ' + targetLead.Company + accountNote + '\n' +
                                  '• **Contact:** ' + targetLead.Name + '\n' +
                                  '• **Opportunity:** ' + oppName + ' (Stage: ' + effectiveStage + amountNote + ').';
                } else {
                    res.isSuccess = false;
                    String errorText = '';
                    for (Database.Error err : lcr.getErrors()) {
                        errorText += err.getMessage() + ' ';
                    }
                    res.message = 'Cannot convert Lead due to validation failure: ' + errorText.trim() + 
                                  '. Would you like to provide the missing information, or abort?';
                }
            } catch (DmlException de) {
                res.isSuccess = false;
                res.message = 'Validation Error during lead conversion: ' + de.getDmlMessage(0) + 
                              '. Would you like to provide the required details, or abort?';
            } catch (Exception ex) {
                res.isSuccess = false;
                res.message = 'Error processing lead conversion: ' + ex.getMessage();
            }

            responses.add(res);
        }

        return responses;
    }

    private static Lead findLead(String leadRef, String email, String leadName, String company) {
        // 1. Direct 15/18-character Lead ID check (if valid ID format)
        if (String.isNotBlank(leadRef)) {
            String cleanRef = leadRef.trim();
            if ((cleanRef.length() == 15 || cleanRef.length() == 18) && cleanRef.startsWith('00Q')) {
                try {
                    Id validId = (Id) cleanRef;
                    List<Lead> leads = [
                        SELECT Id, Name, Company, Country, Industry, Phone, Website, Estimated_Budget__c, 
                               IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId 
                        FROM Lead 
                        WHERE Id = :validId 
                        LIMIT 1
                    ];
                    if (!leads.isEmpty()) {
                        return leads[0];
                    }
                } catch (Exception ex) {
                    // Fall through to name/company search
                }
            }
        }

        // 2. Email lookup
        if (String.isNotBlank(email)) {
            String sanitizedEmail = email.trim();
            List<Lead> leads = [
                SELECT Id, Name, Company, Country, Industry, Phone, Website, Estimated_Budget__c, 
                       IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId 
                FROM Lead 
                WHERE Email = :sanitizedEmail 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!leads.isEmpty()) {
                return leads[0];
            }
        }

        // 3. Name or Company lookup (supports leadName, company, or leadRef holding the text)
        String searchTarget = String.isNotBlank(leadName) ? leadName : (String.isNotBlank(company) ? company : leadRef);
        if (String.isNotBlank(searchTarget)) {
            String cleanName = searchTarget.trim().replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '');
            String wildcard = '%' + cleanName + '%';
            String firstWord = cleanName.contains(' ') ? cleanName.substringBefore(' ').trim() : cleanName;
            String firstWordWildcard = '%' + firstWord + '%';

            List<Lead> leads = [
                SELECT Id, Name, Company, Country, Industry, Phone, Website, Estimated_Budget__c, 
                       IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId 
                FROM Lead 
                WHERE (Name LIKE :wildcard OR Company LIKE :wildcard OR Name LIKE :firstWordWildcard OR Company LIKE :firstWordWildcard) 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!leads.isEmpty()) {
                return leads[0];
            }
        }
        return null;
    }
}
