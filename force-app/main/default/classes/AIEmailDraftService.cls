public with sharing class AIEmailDraftService {

    public class DraftRequest {
        @InvocableVariable(label='Record ID' description='Lead or Opportunity ID' required=true)
        public String recordId;

        @InvocableVariable(label='Draft Type' description='Follow-up, Proposal, or Discovery' required=false)
        public String draftType;
    }

    public class DraftResponse {
        @InvocableVariable(label='Subject' description='Generated Email Subject')
        @AuraEnabled public String subject;

        @InvocableVariable(label='Email Body' description='Generated Email Body')
        @AuraEnabled public String body;

        @InvocableVariable(label='Status' description='Success or Error')
        @AuraEnabled public String status;

        @AuraEnabled public String recipientEmail;
        @AuraEnabled public String recipientName;
    }

    @InvocableMethod(label='Draft AI Email' description='Generates personalized, context-aware email draft from Lead or Opportunity data.')
    public static List<DraftResponse> generateDrafts(List<DraftRequest> requests) {
        List<DraftResponse> responses = new List<DraftResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (DraftRequest req : requests) {
            responses.add(generateSingleDraft(req.recordId, req.draftType));
        }
        return responses;
    }

    @AuraEnabled(cacheable=false)
    public static DraftResponse generateSingleDraft(String recordId, String draftType) {
        DraftResponse res = new DraftResponse();
        if (String.isBlank(recordId)) {
            res.status = 'Error: RecordId cannot be empty.';
            return res;
        }

        Id recId;
        try {
            recId = (Id)recordId.trim();
        } catch (Exception ex) {
            res.status = 'Error: Invalid Record ID format.';
            return res;
        }

        String sObjType = recId.getSObjectType().getDescribe().getName();
        String effectiveType = String.isNotBlank(draftType) ? draftType.trim() : 'Follow-up';

        if (sObjType == 'Lead') {
            return generateLeadDraft(recId, effectiveType);
        } else if (sObjType == 'Opportunity') {
            return generateOpportunityDraft(recId, effectiveType);
        } else {
            res.status = 'Error: Unsupported Object Type. Supported: Lead, Opportunity.';
            return res;
        }
    }

    private static DraftResponse generateLeadDraft(Id leadId, String draftType) {
        DraftResponse res = new DraftResponse();
        Lead ld = [
            SELECT Id, FirstName, LastName, Company, Industry, LeadSource, Estimated_Budget__c, 
                   AI_Lead_Score__c, Next_Best_Action__c, Email,
                   (SELECT Subject, ActivityDate, CreatedDate FROM Tasks ORDER BY CreatedDate DESC LIMIT 1)
            FROM Lead 
            WHERE Id = :leadId 
            LIMIT 1
        ];

        String recipientName = String.isNotBlank(ld.FirstName) ? ld.FirstName : ld.LastName;
        String companyName = String.isNotBlank(ld.Company) ? ld.Company : 'your team';
        String lastActivityInfo = '';
        if (ld.Tasks != null && !ld.Tasks.isEmpty()) {
            lastActivityInfo = 'Following up on our recent interaction regarding ' + ld.Tasks[0].Subject + '. ';
        }

        res.recipientEmail = ld.Email;
        res.recipientName = recipientName;
        res.subject = draftType + ': Next Steps with ' + companyName;

        String body = 'Hi ' + recipientName + ',\n\n';
        if (String.isNotBlank(lastActivityInfo)) {
            body += lastActivityInfo;
        } else {
            body += 'I hope you are doing well. Reaching out regarding your interest in our solutions for ' + companyName + '.\n\n';
        }

        if (String.isNotBlank(ld.Industry)) {
            body += 'Given your focus in the ' + ld.Industry + ' sector, we have helped similar enterprises streamline their sales operations and accelerate business velocity.\n\n';
        }

        if (ld.Estimated_Budget__c != null && ld.Estimated_Budget__c > 0) {
            body += 'Based on our preliminary budget alignment (approx ₹' + String.valueOf(ld.Estimated_Budget__c.setScale(0)) + '), we would love to share a tailored solution architecture.\n\n';
        }

        body += 'Would you be open for a brief 15-minute sync this week to explore this further?\n\nBest regards,\nSales Operations Team';
        res.body = body;
        res.status = 'Success';
        return res;
    }

    private static DraftResponse generateOpportunityDraft(Id oppId, String draftType) {
        DraftResponse res = new DraftResponse();
        Opportunity opp = [
            SELECT Id, Name, StageName, Amount, CloseDate, Primary_Contact__r.FirstName, Primary_Contact__r.LastName, Primary_Contact__r.Email,
                   Account.Name, Competitor__c, Deal_Health_Score__c,
                   (SELECT Subject, ActivityDate, CreatedDate FROM Tasks ORDER BY CreatedDate DESC LIMIT 1)
            FROM Opportunity 
            WHERE Id = :oppId 
            LIMIT 1
        ];

        String recipientName = (opp.Primary_Contact__r != null && String.isNotBlank(opp.Primary_Contact__r.FirstName))
            ? opp.Primary_Contact__r.FirstName 
            : (opp.Account != null ? opp.Account.Name : 'Partner');
        String oppName = opp.Name;
        String amountStr = opp.Amount != null ? '₹' + String.valueOf(opp.Amount.setScale(0)) : '';

        res.recipientEmail = (opp.Primary_Contact__r != null) ? opp.Primary_Contact__r.Email : '';
        res.recipientName = recipientName;
        res.subject = draftType + ': ' + oppName + ' — Progression & Next Steps';

        String body = 'Hi ' + recipientName + ',\n\n';
        if (draftType.equalsIgnoreCase('Proposal')) {
            body += 'I am pleased to share our formal proposal framework for ' + oppName + '.\n\n';
            if (String.isNotBlank(amountStr)) {
                body += 'Proposed Engagement Value: ' + amountStr + '\n';
            }
            body += 'Target Delivery & Implementation Target: ' + opp.CloseDate.format() + '\n\n';
            body += 'Please review the scope and let us know if you have any questions or require adjustments.\n\n';
        } else {
            body += 'Following up on our discussions regarding ' + oppName + ' (current stage: ' + opp.StageName + ').\n\n';
            body += 'We are on track towards our projected timeline of ' + opp.CloseDate.format() + ' and wanted to confirm if there are any remaining technical or commercial validations needed from our side.\n\n';
        }

        body += 'Looking forward to your thoughts.\n\nBest regards,\nSales Operations Team';
        res.body = body;
        res.status = 'Success';
        return res;
    }

    @AuraEnabled
    public static String sendDraftEmail(String recordId, String recipientEmail, String subject, String body) {
        if (String.isBlank(recipientEmail)) {
            return 'Error: Recipient email address is missing.';
        }
        if (String.isBlank(subject) || String.isBlank(body)) {
            return 'Error: Subject and email body cannot be empty.';
        }

        Id recId;
        try {
            recId = (Id)recordId.trim();
        } catch (Exception ex) {
            return 'Error: Invalid record ID.';
        }

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{ recipientEmail.trim() });
            mail.setSubject(subject);
            mail.setPlainTextBody(body);

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
            if (results != null && !results.isEmpty() && results[0].isSuccess()) {
                try {
                    Task t = new Task();
                    t.Subject = 'Email: ' + subject;
                    t.Description = 'To: ' + recipientEmail.trim() + '\n\n' + body;
                    t.Status = 'Completed';
                    t.TaskSubtype = 'Email';
                    t.ActivityDate = Date.today();

                    String sObj = recId.getSObjectType().getDescribe().getName();
                    if (sObj == 'Lead') {
                        t.WhoId = recId;
                    } else if (sObj == 'Opportunity') {
                        t.WhatId = recId;
                    }
                    insert t;
                } catch (Exception logEx) {
                    System.debug(LoggingLevel.WARN, 'Email sent but activity logging skipped: ' + logEx.getMessage());
                }
                return 'Success';
            } else {
                return 'Error: ' + (results != null && !results.isEmpty() ? results[0].getErrors()[0].getMessage() : 'Unable to dispatch email.');
            }
        } catch (Exception ex) {
            return 'Error sending email: ' + ex.getMessage();
        }
    }
}

