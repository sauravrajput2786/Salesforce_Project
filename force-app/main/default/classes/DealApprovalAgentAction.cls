public without sharing class DealApprovalAgentAction {

    public class DealApprovalRequest {
        @InvocableVariable(label='Opportunity ID or Name' description='Salesforce Record ID or Name of the Opportunity' required=false)
        public String opportunityId;

        @InvocableVariable(label='Opportunity Name' description='Name of the Opportunity or Account to apply discount to' required=false)
        public String opportunityName;

        @InvocableVariable(label='Discount Percentage' description='Discount percentage to apply (e.g. 15 for 15% or 25 for 25%)' required=true)
        public Decimal discountPercent;

        @InvocableVariable(label='Discount Reason' description='Business reason for the discount request (Mandatory for discounts over 20%)' required=false)
        public String reason;
    }

    public class DealApprovalResponse {
        @InvocableVariable(label='Is Success' description='True if discount was processed successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Opportunity ID' description='Record ID of the evaluated Opportunity')
        public Id opportunityId;

        @InvocableVariable(label='Opportunity Name' description='Name of the evaluated Opportunity')
        public String opportunityName;

        @InvocableVariable(label='Needs Approval' description='True if discount exceeded 20% threshold and requires approval')
        public Boolean needsApproval;

        @InvocableVariable(label='Approval Status' description='Approval Status e.g. Approved, Pending Approval')
        public String approvalStatus;

        @InvocableVariable(label='Original Amount' description='Deal amount before discount')
        public Decimal originalAmount;

        @InvocableVariable(label='Discounted Amount' description='Calculated deal amount after discount')
        public Decimal discountedAmount;

        @InvocableVariable(label='Message' description='User-facing conversational response with interactive options')
        public String message;
    }

    @InvocableMethod(
        label='Evaluate Deal Discount and Approval'
        description='Applies discount to an Opportunity with enterprise guardrails. Discounts up to 20% auto-approve; discounts > 20% require business reason and route for manager approval.'
        category='Sales Operations'
    )
    public static List<DealApprovalResponse> evaluateDealDiscount(List<DealApprovalRequest> requests) {
        List<DealApprovalResponse> responses = new List<DealApprovalResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (DealApprovalRequest req : requests) {
            DealApprovalResponse res = new DealApprovalResponse();

            if (req == null || (req.opportunityId == null && String.isBlank(req.opportunityName))) {
                res.isSuccess = false;
                res.message = 'Opportunity ID or Name is mandatory to apply a discount. Which deal would you like me to evaluate, or would you like to abort?';
                responses.add(res);
                continue;
            }

            if (req.discountPercent == null || req.discountPercent <= 0 || req.discountPercent > 80) {
                res.isSuccess = false;
                res.message = 'A valid discount percentage (between 1% and 80%) is mandatory. Would you like to specify the discount percentage now, or abort this request?';
                responses.add(res);
                continue;
            }

            try {
                Opportunity targetOpp = findOpportunity(req.opportunityId, req.opportunityName);

                if (targetOpp == null) {
                    res.isSuccess = false;
                    String searchRef = req.opportunityId != null ? String.valueOf(req.opportunityId) : req.opportunityName;
                    res.message = 'Could not find any matching Opportunity for "' + searchRef + '". Would you like to check the spelling or provide another deal name, or abort?';
                    responses.add(res);
                    continue;
                }

                res.opportunityId = targetOpp.Id;
                res.opportunityName = targetOpp.Name;

                if (targetOpp.IsClosed) {
                    res.isSuccess = false;
                    res.message = 'Cannot apply discount: Opportunity "' + targetOpp.Name + '" is already ' + targetOpp.StageName + '. Pricing adjustments are locked on closed deals.';
                    responses.add(res);
                    continue;
                }

                Decimal baseAmount = targetOpp.Amount != null ? targetOpp.Amount : 0;
                if (baseAmount <= 0) {
                    res.isSuccess = false;
                    res.message = 'Opportunity "' + targetOpp.Name + '" currently has no Amount ($0). Please specify the deal amount before applying a discount.';
                    responses.add(res);
                    continue;
                }

                Decimal calculatedDiscountAmount = (baseAmount * (req.discountPercent / 100)).setScale(2);
                Decimal newAmount = (baseAmount - calculatedDiscountAmount).setScale(2);

                res.originalAmount = baseAmount;
                res.discountedAmount = newAmount;

                // Enterprise Compliance Check: Discounts over 20% require business reason
                if (req.discountPercent > 20 && String.isBlank(req.reason)) {
                    res.isSuccess = false;
                    res.needsApproval = true;
                    res.message = 'For discounts exceeding 20% on "' + targetOpp.Name + '", sales compliance requires a business justification before routing to manager approval. What is the business reason for requesting ' + req.discountPercent + '% discount?';
                    responses.add(res);
                    continue;
                }

                if (req.discountPercent <= 20) {
                    targetOpp.Amount = newAmount;
                    targetOpp.Discount_Percentage__c = req.discountPercent;
                    targetOpp.Approval_Status__c = 'Approved';
                    targetOpp.Description = (String.isNotBlank(targetOpp.Description) ? targetOpp.Description + '\n' : '') +
                        'Applied ' + req.discountPercent + '% discount. Reason: ' + (String.isNotBlank(req.reason) ? req.reason : 'Standard rep allowance.');
                    update targetOpp;

                    res.isSuccess = true;
                    res.needsApproval = false;
                    res.approvalStatus = 'Approved';
                    res.message = '✅ ' + req.discountPercent + '% discount applied to "' + targetOpp.Name + '".\n' +
                                  '• Base Amount: $' + baseAmount.format() + '\n' +
                                  '• New Discounted Amount: $' + newAmount.format() + '\n' +
                                  '• Approval Status: Approved (Standard rep allowance up to 20%). Would you like to keep this price or adjust it?';
                } else {
                    List<ProcessInstance> pendingProcesses = [
                        SELECT Id, Status 
                        FROM ProcessInstance 
                        WHERE TargetObjectId = :targetOpp.Id AND Status = 'Pending' 
                        LIMIT 1
                    ];

                    if (!pendingProcesses.isEmpty() || targetOpp.Approval_Status__c == 'Pending') {
                        res.isSuccess = false;
                        res.needsApproval = true;
                        res.approvalStatus = 'Pending Approval';
                        res.message = 'An approval request is already pending for "' + targetOpp.Name + '". Please await manager approval or abort pending requests.';
                        responses.add(res);
                        continue;
                    }

                    targetOpp.Amount = newAmount;
                    targetOpp.Discount_Percentage__c = req.discountPercent;
                    targetOpp.Approval_Status__c = 'Pending';
                    targetOpp.Description = (String.isNotBlank(targetOpp.Description) ? targetOpp.Description + '\n' : '') +
                        'High Discount Request (' + req.discountPercent + '%). Reason: ' + req.reason;
                    update targetOpp;

                    res.isSuccess = true;
                    res.needsApproval = true;
                    res.approvalStatus = 'Pending';

                    try {
                        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
                        submitReq.setComments(req.reason);
                        submitReq.setObjectId(targetOpp.Id);
                        if (targetOpp.OwnerId != null) {
                            submitReq.setSubmitterId(targetOpp.OwnerId);
                        }
                        Approval.process(submitReq);
                        res.message = '⚠️ ' + req.discountPercent + '% discount applied to "' + targetOpp.Name + '".\n' +
                                      '• Base Amount: $' + baseAmount.format() + '\n' +
                                      '• Proposed Amount: $' + newAmount.format() + '\n' +
                                      '• Reason: ' + req.reason + '\n' +
                                      '• Status: Formal Approval Request submitted to Executive Leadership (Saurav Rajput).';
                    } catch (System.DmlException de) {
                        res.message = '⚠️ ' + req.discountPercent + '% discount calculated for "' + targetOpp.Name + '".\n' +
                                      '• Base Amount: $' + baseAmount.format() + '\n' +
                                      '• Proposed Amount: $' + newAmount.format() + '\n' +
                                      '• Reason: ' + req.reason + '\n' +
                                      '• Status: Pending Approval. Discount exceeds 20% policy threshold and has been flagged for Manager Review.';
                    } catch (Exception ex) {
                        res.message = '⚠️ ' + req.discountPercent + '% discount calculated for "' + targetOpp.Name + '".\n' +
                                      '• Base Amount: $' + baseAmount.format() + '\n' +
                                      '• Proposed Amount: $' + newAmount.format() + '\n' +
                                      '• Reason: ' + req.reason + '\n' +
                                      '• Status: Pending Approval. Discount exceeds 20% policy threshold and has been flagged for Manager Review.';
                    }
                }
            } catch (Exception ex) {
                res.isSuccess = false;
                res.message = 'Error processing discount evaluation: ' + ex.getMessage();
            }

            responses.add(res);
        }

        return responses;
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
                    SELECT Id, Name, Amount, StageName, IsClosed, Description, Discount_Percentage__c, Approval_Status__c, OwnerId 
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
            SELECT Id, Name, Amount, StageName, IsClosed, Description, Discount_Percentage__c, Approval_Status__c, OwnerId 
            FROM Opportunity 
            WHERE Name LIKE :wildcard OR Account.Name LIKE :wildcard 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }
}
