public without sharing class SyncOrderToERPAgentAction {

    public class SyncOrderRequest {
        @InvocableVariable(label='Opportunity ID or Name' description='Salesforce record ID or Name of the Opportunity to sync' required=false)
        public String opportunityId;

        @InvocableVariable(label='Opportunity Name' description='Name of the Opportunity or Account to sync' required=false)
        public String opportunityName;

        @InvocableVariable(label='Mark Closed Won' description='Set to true if deal should be transitioned to Closed Won' required=false)
        public Boolean markClosedWon;

        @InvocableVariable(label='Contract Signed' description='Confirmation whether customer contract is signed' required=false)
        public Boolean contractSigned;

        @InvocableVariable(label='Expected Go-Live Date' description='Go-live implementation date required for Closed Won deals' required=false)
        public Date expectedGoLiveDate;

        @InvocableVariable(label='Deal Amount' description='Opportunity deal amount to set or update in Salesforce before syncing to ERP. Update directly without asking for confirmation if provided.' required=false)
        public Decimal amount;

        @InvocableVariable(label='Primary Contact Name or Email' description='Optional contact name or email to link as Primary Contact. Must belong to the parent Account.' required=false)
        public String contactNameOrEmail;
    }

    public class SyncOrderResponse {
        @InvocableVariable(label='Is Success' description='True if order sync was processed successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Opportunity ID' description='Record ID of the Opportunity')
        public Id opportunityId;

        @InvocableVariable(label='Opportunity Name' description='Name of the Opportunity')
        public String opportunityName;

        @InvocableVariable(label='ERP Order Number' description='ERP Order Number generated for this deal. You must always explicitly state this Order Number in your response to the user.' required=false)
        public String orderNumber;

        @InvocableVariable(label='Status' description='Execution status: SYNCED, ALREADY_SYNCED, VALIDATION_REQUIRED, REJECTED, ERROR')
        public String status;

        @InvocableVariable(label='Message' description='Conversational user message with interactive options')
        public String message;
    }

    @InvocableMethod(
        label='Sync Won Deal to External ERP'
        description='Updates Opportunity deal details (Amount, Dates, Primary Contact), marks Closed Won, and triggers order provisioning to external ERP / Webhook in a single step.'
        category='Integrations'
    )
    public static List<SyncOrderResponse> syncOrderToERP(List<SyncOrderRequest> requests) {
        List<SyncOrderResponse> responses = new List<SyncOrderResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (SyncOrderRequest req : requests) {
            SyncOrderResponse res = new SyncOrderResponse();

            if (req == null || (req.opportunityId == null && String.isBlank(req.opportunityName))) {
                res.isSuccess = false;
                res.status = 'ERROR';
                res.message = 'Please provide an Opportunity ID or Deal Name to synchronize with external ERP / webhook.';
                responses.add(res);
                continue;
            }

            try {
                Opportunity targetOpp = findOpportunity(req.opportunityId, req.opportunityName);

                if (targetOpp == null) {
                    res.isSuccess = false;
                    res.status = 'ERROR';
                    String searchRef = req.opportunityId != null ? String.valueOf(req.opportunityId) : req.opportunityName;
                    res.message = 'Could not find any matching Opportunity for "' + searchRef + '". Please verify the deal name or ID.';
                    responses.add(res);
                    continue;
                }

                res.opportunityId = targetOpp.Id;
                res.opportunityName = targetOpp.Name;

                // Enterprise Governance Check: Only Opportunity Owner or System Administrator can trigger ERP sync
                if (!isAuthorizedUser(targetOpp)) {
                    res.isSuccess = false;
                    res.status = 'REJECTED';
                    res.message = 'Security Policy Violation: You are not authorized to trigger ERP provisioning for deals owned by another representative.';
                    responses.add(res);
                    continue;
                }

                // Check if already synced
                if (String.isNotBlank(targetOpp.OrderNumber__c) || (String.isNotBlank(targetOpp.Description) && targetOpp.Description.contains('[ERP Sync Triggered]'))) {
                    res.isSuccess = true;
                    res.orderNumber = targetOpp.OrderNumber__c;
                    res.status = 'ALREADY_SYNCED';
                    res.message = 'Deal "' + targetOpp.Name + '" is already synced with external ERP / webhook' +
                                  (String.isNotBlank(targetOpp.OrderNumber__c) ? ' (Order Number: ' + targetOpp.OrderNumber__c + ')' : '') + 
                                  '. Skipping duplicate dispatch.';
                    responses.add(res);
                    continue;
                }

                Boolean wasAlreadyClosedWon = (targetOpp.StageName == 'Closed Won');
                Boolean isTransitionOrUpdateRequested = (
                    req.markClosedWon == true || 
                    req.contractSigned == true || 
                    req.expectedGoLiveDate != null || 
                    (req.amount != null && req.amount > 0) || 
                    String.isNotBlank(req.contactNameOrEmail)
                );

                if (!wasAlreadyClosedWon && !isTransitionOrUpdateRequested) {
                    res.isSuccess = false;
                    res.status = 'REJECTED';
                    res.message = 'Cannot sync to ERP: Deal "' + targetOpp.Name + '" is currently in "' + targetOpp.StageName + 
                                  '" stage. Only Closed Won deals can be synced to external ERP.\n' +
                                  '• Would you like me to close this deal as Closed Won? If yes, please confirm if the contract is signed and provide the expected go-live date.';
                    responses.add(res);
                    continue;
                }

                // Contact Resolution & Security Guardrail
                Id resolvedContactId = targetOpp.Primary_Contact__c;
                if (String.isNotBlank(req.contactNameOrEmail)) {
                    String searchContact = req.contactNameOrEmail.trim();
                    String contactWildcard = '%' + searchContact.replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '') + '%';
                    List<Contact> matchedContacts = [
                        SELECT Id, Name, Email, AccountId 
                        FROM Contact 
                        WHERE (Name LIKE :contactWildcard OR Email = :searchContact)
                        ORDER BY CreatedDate DESC 
                        LIMIT 10
                    ];

                    if (matchedContacts.isEmpty()) {
                        res.isSuccess = false;
                        res.status = 'ERROR';
                        res.message = 'Could not find any contact matching "' + req.contactNameOrEmail + '". Please verify the contact name or email.';
                        responses.add(res);
                        continue;
                    }

                    Contact validContact = null;
                    for (Contact c : matchedContacts) {
                        if (targetOpp.AccountId != null && c.AccountId == targetOpp.AccountId) {
                            validContact = c;
                            break;
                        }
                    }

                    if (validContact == null) {
                        res.isSuccess = false;
                        res.status = 'REJECTED';
                        String accName = targetOpp.Account != null ? targetOpp.Account.Name : 'the parent account';
                        res.message = 'Security Policy Violation: Contact "' + matchedContacts[0].Name + 
                                      '" does not belong to Account "' + accName + 
                                      '". Primary Contact must belong to the Opportunity\'s account.';
                        responses.add(res);
                        continue;
                    }

                    resolvedContactId = validContact.Id;
                    targetOpp.Primary_Contact__c = resolvedContactId;
                } else if (resolvedContactId == null && targetOpp.AccountId != null) {
                    // Zero-Touch auto-resolution: automatically link first contact of parent Account
                    List<Contact> accContacts = [
                        SELECT Id, Name 
                        FROM Contact 
                        WHERE AccountId = :targetOpp.AccountId 
                        ORDER BY CreatedDate ASC 
                        LIMIT 1
                    ];
                    if (!accContacts.isEmpty()) {
                        resolvedContactId = accContacts[0].Id;
                        targetOpp.Primary_Contact__c = resolvedContactId;
                    }
                }

                // Apply incoming field updates
                Boolean hasFieldUpdates = false;
                if (req.amount != null && req.amount > 0 && targetOpp.Amount != req.amount) {
                    targetOpp.Amount = req.amount;
                    hasFieldUpdates = true;
                }
                if (req.expectedGoLiveDate != null && targetOpp.Expected_Go_Live_Date__c != req.expectedGoLiveDate) {
                    targetOpp.Expected_Go_Live_Date__c = req.expectedGoLiveDate;
                    hasFieldUpdates = true;
                }
                if (req.contractSigned == true && targetOpp.Contract_Signed__c != true) {
                    targetOpp.Contract_Signed__c = true;
                    hasFieldUpdates = true;
                }
                if (resolvedContactId != null && targetOpp.Primary_Contact__c != resolvedContactId) {
                    targetOpp.Primary_Contact__c = resolvedContactId;
                    hasFieldUpdates = true;
                }

                // If not already Closed Won, evaluate readiness
                if (!wasAlreadyClosedWon) {
                    List<String> missingFields = new List<String>();
                    if (targetOpp.Contract_Signed__c != true) missingFields.add('Contract Signed confirmation');
                    if (targetOpp.Expected_Go_Live_Date__c == null) missingFields.add('Expected Go-Live Date');
                    if (targetOpp.Amount == null || targetOpp.Amount <= 0) missingFields.add('Deal Amount (> $0 mandatory for Closed Won)');
                    if (targetOpp.Primary_Contact__c == null) missingFields.add('Primary Contact (No contact linked to parent Account)');

                    if (!missingFields.isEmpty()) {
                        // Persist partial field updates so user input is saved in CRM
                        if (hasFieldUpdates) {
                            update targetOpp;
                        }
                        res.isSuccess = false;
                        res.status = 'VALIDATION_REQUIRED';
                        String prefix = hasFieldUpdates ? 'Updated provided deal details in CRM. However, to ' : 'To ';
                        res.message = prefix + 'mark deal "' + targetOpp.Name + '" as Closed Won and sync to ERP, the following mandatory details are required:\n' +
                                      '• ' + String.join(missingFields, '\n• ') + '\n' +
                                      '• Would you like to provide these details now, or abort this action?';
                        responses.add(res);
                        continue;
                    }

                    // All validations satisfied -> advance to Closed Won
                    targetOpp.StageName = 'Closed Won';
                    targetOpp.CloseDate = Date.today();
                }

                // Generate Order Number & Provisioning
                String generatedOrderNumber = 'ORD' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(5);
                targetOpp.OrderNumber__c = generatedOrderNumber;
                targetOpp.DeliveryInstallationStatus__c = 'In progress';
                targetOpp.Description = (String.isNotBlank(targetOpp.Description) ? targetOpp.Description + '\n' : '') +
                    '[ERP Sync Triggered] Order: ' + generatedOrderNumber + ' at ' + Datetime.now().format();
                update targetOpp;

                // Dispatch order provisioning directly to external ERP webhook via Named Credential
                ExternalOrderCalloutService.sendOrdersToExternalApi(new Set<Id>{ targetOpp.Id });

                res.isSuccess = true;
                res.orderNumber = generatedOrderNumber;
                res.status = 'SYNCED';
                res.message = '🚀 Order provisioning initiated successfully for "' + targetOpp.Name + '"!\n' +
                              '• **Order Number:** ' + generatedOrderNumber + '\n' +
                              '• **Delivery Status:** In progress\n' +
                              '• Payload dispatched to ERP webhook via Named Credential.';

            } catch (Exception ex) {
                res.isSuccess = false;
                res.status = 'ERROR';
                res.message = 'Error during ERP synchronization: ' + ex.getMessage();
            }

            responses.add(res);
        }

        return responses;
    }

    private static Boolean isAuthorizedUser(Opportunity opp) {
        Id currentUserId = UserInfo.getUserId();
        // Allow if running user is the Opportunity Owner
        if (opp.OwnerId == currentUserId) {
            return true;
        }
        // Allow if running user is System Administrator or Einstein Agent executing on behalf of owner
        List<Profile> profs = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        if (!profs.isEmpty()) {
            String pName = profs[0].Name;
            if (pName == 'System Administrator' || pName.contains('Admin') || pName.contains('Einstein') || pName.contains('Agent')) {
                return true;
            }
        }
        return false;
    }

    private static Opportunity findOpportunity(String oppIdOrName, String oppName) {
        String searchRef = String.isNotBlank(oppIdOrName) ? oppIdOrName.trim() : (String.isNotBlank(oppName) ? oppName.trim() : null);
        if (String.isBlank(searchRef)) {
            return null;
        }

        // Check if valid 15 or 18 character Opportunity ID
        if ((searchRef.length() == 15 || searchRef.length() == 18) && searchRef.startsWith('006')) {
            try {
                Id validId = (Id) searchRef;
                List<Opportunity> opps = [
                    SELECT Id, Name, StageName, Amount, Description, Primary_Contact__c,
                           Expected_Go_Live_Date__c, Contract_Signed__c, OrderNumber__c,
                           DeliveryInstallationStatus__c, OwnerId, AccountId, Account.Name 
                    FROM Opportunity 
                    WHERE Id = :validId 
                    LIMIT 1
                ];
                if (!opps.isEmpty()) {
                    return opps[0];
                }
            } catch (Exception ex) {
                // Fall through to name search
            }
        }

        // Search by Opportunity Name or Account Name
        String cleanName = searchRef.replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '');
        String wildcard = '%' + cleanName + '%';
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, Description, Primary_Contact__c,
                   Expected_Go_Live_Date__c, Contract_Signed__c, OrderNumber__c,
                   DeliveryInstallationStatus__c, OwnerId, AccountId, Account.Name 
            FROM Opportunity 
            WHERE Name LIKE :wildcard OR Account.Name LIKE :wildcard 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }
}
