public with sharing class AIAssistantController {

    public class AssistantResponse {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String actionType { get; set; } // LEAD_CONVERT, DISCOUNT_APPROVAL, ERP_SYNC, CUSTOMER_360, RECORD_DETAILS, SCHEDULE_TASK, GENERAL, GUARDRAIL
        @AuraEnabled public Map<String, Object> details { get; set; }
        @AuraEnabled public List<QuickActionOption> quickOptions { get; set; }

        public AssistantResponse() {
            this.isSuccess = true;
            this.details = new Map<String, Object>();
            this.quickOptions = new List<QuickActionOption>();
        }
    }

    public class QuickActionOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String prompt { get; set; }

        public QuickActionOption(String label, String prompt) {
            this.label = label;
            this.prompt = prompt;
        }
    }

    @AuraEnabled
    public static AssistantResponse executeAssistantCommand(String userPrompt, Id contextRecordId) {
        AssistantResponse response = new AssistantResponse();

        if (String.isBlank(userPrompt)) {
            response.isSuccess = false;
            response.message = 'Please enter a message or command.';
            return response;
        }

        String lowerPrompt = userPrompt.toLowerCase().trim();

        try {
            // Guardrail: Off-Topic Detection (Weather, Sports, Jokes, Non-CRM)
            if (isOffTopic(lowerPrompt)) {
                response.isSuccess = false;
                response.actionType = 'GUARDRAIL';
                response.message = '🛡️ **Off-Topic Guardrail:** I am the enterprise Sales & Operations AI Assistant. I can only assist with Salesforce CRM operations including Lead Qualification, Discount Governance, ERP Sync, Customer 360, Record Details, and Task Scheduling.';
                populateStandardQuickOptions(response);
                return response;
            }

            // 1. Lead Conversion Intent
            if (lowerPrompt.contains('convert') || lowerPrompt.contains('qualif')) {
                return handleLeadConversion(lowerPrompt, contextRecordId);
            }

            // 2. Deal Discount Approval Intent
            if (lowerPrompt.contains('discount') || lowerPrompt.contains('approval') || lowerPrompt.contains('approve')) {
                return handleDiscountApproval(lowerPrompt, contextRecordId);
            }

            // 3. ERP Outbound Sync Intent
            if (lowerPrompt.contains('sync') || lowerPrompt.contains('erp') || lowerPrompt.contains('outbound') || (lowerPrompt.contains('order') && (lowerPrompt.contains('provision') || lowerPrompt.contains('won')))) {
                return handleERPSync(lowerPrompt, contextRecordId);
            }

            // 4. Customer 360 Executive Briefing Intent
            if (lowerPrompt.contains('360') || (lowerPrompt.contains('briefing') && lowerPrompt.contains('customer')) || (lowerPrompt.contains('executive') && lowerPrompt.contains('account'))) {
                return handleCustomer360(lowerPrompt, contextRecordId);
            }

            // 5. Schedule Follow-Up Task Intent
            if (lowerPrompt.contains('schedule') || lowerPrompt.contains('follow-up') || lowerPrompt.contains('follow up') || (lowerPrompt.contains('task') && !lowerPrompt.contains('detail'))) {
                return handleScheduleTask(lowerPrompt, contextRecordId);
            }

            // 6. Universal CRM Record Lookups (Industry, Phone, Stage, Amount, etc.)
            AssistantResponse recordLookup = handleRecordDetails(lowerPrompt, contextRecordId);
            if (recordLookup.isSuccess) {
                return recordLookup;
            }

            // 7. Greetings & Help Menu
            if (isGreeting(lowerPrompt)) {
                response.message = '👋 **Hello! All 6 AI Agents & Guardrails are Active:**\n\n'
                    + '• 🎯 **Lead Conversion:** *"Convert lead Sam Altman"*\n'
                    + '• 💰 **Discount Governance:** *"Evaluate 15% discount for deal"*\n'
                    + '• 🚀 **ERP Outbound Sync:** *"Sync won deal to ERP with amount 750"*\n'
                    + '• 📊 **Customer 360:** *"Get Customer 360 executive briefing for Acme"*\n'
                    + '• 🔍 **Record Inquiries:** *"Give me industry of Agentforce Account"* or *"Stage of CloudTech deal"*\n'
                    + '• 📅 **Schedule Follow-Up:** *"Schedule a follow-up task for next week"*';

                response.actionType = 'GENERAL';
                populateStandardQuickOptions(response);
                return response;
            }

            // Fallback message with suggestions
            response.message = '🔍 I could not locate a record matching your request.\n\n'
                + 'Try asking:\n'
                + '• *"Give me industry of Agentforce Account"*\n'
                + '• *"Show details of Opportunity CloudTech Services"*\n'
                + '• *"Convert lead Agent Test"*\n'
                + '• *"Sync won deal fresh ERP testing fourth with amount 555"*';
            response.actionType = 'GENERAL';
            populateStandardQuickOptions(response);

        } catch (Exception ex) {
            response.isSuccess = false;
            response.message = '⚠️ Error executing request: ' + ex.getMessage();
        }

        return response;
    }

    private static Boolean isGreeting(String prompt) {
        List<String> greetings = new List<String>{ 'hi', 'hello', 'hey', 'hy', 'help', 'start', 'test' };
        return greetings.contains(prompt);
    }

    private static Boolean isOffTopic(String prompt) {
        List<String> offTopicKeywords = new List<String>{
            'weather', 'cricket', 'football', 'movie', 'song', 'joke', 'capital of', 'who is prime minister', 'who won the match'
        };
        for (String k : offTopicKeywords) {
            if (prompt.contains(k)) return true;
        }
        return false;
    }

    private static void populateStandardQuickOptions(AssistantResponse res) {
        res.quickOptions.add(new QuickActionOption('🎯 Convert Lead', 'Convert this lead'));
        res.quickOptions.add(new QuickActionOption('💰 Evaluate 15% Discount', 'Evaluate 15% discount'));
        res.quickOptions.add(new QuickActionOption('🚀 Sync to ERP', 'Sync won deal to ERP'));
        res.quickOptions.add(new QuickActionOption('📊 Customer 360', 'Get Customer 360 briefing'));
        res.quickOptions.add(new QuickActionOption('🔍 Record Details', 'Give me industry of Agentforce Account'));
        res.quickOptions.add(new QuickActionOption('📅 Schedule Task', 'Schedule a follow-up task'));
    }

    // 1. Agent 1: Lead Conversion
    private static AssistantResponse handleLeadConversion(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'LEAD_CONVERT';

        LeadConversionAgentAction.LeadConversionRequest req = new LeadConversionAgentAction.LeadConversionRequest();

        if (contextRecordId != null && contextRecordId.getSobjectType() == Lead.SObjectType) {
            req.leadId = String.valueOf(contextRecordId);
        } else {
            String leadQuery = extractTargetName(prompt, new List<String>{'convert', 'qualify', 'lead', 'this'});
            if (String.isNotBlank(leadQuery)) {
                req.leadName = leadQuery;
            } else {
                List<Lead> recentLeads = [
                    SELECT Id, Name, Company FROM Lead WHERE IsConverted = false WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 3
                ];
                if (!recentLeads.isEmpty()) {
                    res.isSuccess = false;
                    res.message = 'Which Lead would you like to qualify and convert?';
                    for (Lead l : recentLeads) {
                        res.quickOptions.add(new QuickActionOption('Convert ' + l.Name, 'Convert lead ' + l.Name));
                    }
                    return res;
                }
            }
        }

        List<LeadConversionAgentAction.LeadConversionResponse> actionResponses = 
            LeadConversionAgentAction.convertLead(new List<LeadConversionAgentAction.LeadConversionRequest>{ req });

        if (!actionResponses.isEmpty()) {
            LeadConversionAgentAction.LeadConversionResponse actionRes = actionResponses[0];
            res.isSuccess = actionRes.isSuccess;
            res.message = actionRes.message;
            if (actionRes.isSuccess) {
                res.details.put('accountId', actionRes.accountId);
                res.details.put('contactId', actionRes.contactId);
                res.details.put('opportunityId', actionRes.opportunityId);
            }
        }
        return res;
    }

    // 2. Agent 2: Discount Governance
    private static AssistantResponse handleDiscountApproval(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'DISCOUNT_APPROVAL';

        DealApprovalAgentAction.DealApprovalRequest req = new DealApprovalAgentAction.DealApprovalRequest();
        req.discountPercent = extractPercentage(prompt);
        if (req.discountPercent == null) {
            req.discountPercent = 15;
        }

        if (contextRecordId != null && contextRecordId.getSobjectType() == Opportunity.SObjectType) {
            req.opportunityId = String.valueOf(contextRecordId);
        } else {
            String oppName = extractTargetName(prompt, new List<String>{'discount', 'approval', 'approve', 'deal', 'opportunity', 'evaluate'});
            if (String.isNotBlank(oppName)) {
                req.opportunityName = oppName;
            } else {
                List<Opportunity> recentOpps = [
                    SELECT Id, Name FROM Opportunity WHERE IsClosed = false WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 3
                ];
                if (!recentOpps.isEmpty()) {
                    res.isSuccess = false;
                    res.message = 'Which Opportunity would you like to evaluate for discount?';
                    for (Opportunity o : recentOpps) {
                        res.quickOptions.add(new QuickActionOption('Evaluate ' + o.Name, 'Evaluate 15% discount for ' + o.Name));
                    }
                    return res;
                }
            }
        }

        if (req.discountPercent > 20) {
            req.reason = 'Strategic deal discount evaluated via AI Assistant';
        }

        List<DealApprovalAgentAction.DealApprovalResponse> responses = 
            DealApprovalAgentAction.evaluateDealDiscount(new List<DealApprovalAgentAction.DealApprovalRequest>{ req });

        if (!responses.isEmpty()) {
            DealApprovalAgentAction.DealApprovalResponse actionRes = responses[0];
            res.isSuccess = actionRes.isSuccess;
            res.message = actionRes.message;
            res.details.put('approvalStatus', actionRes.approvalStatus);
            res.details.put('originalAmount', actionRes.originalAmount);
            res.details.put('discountedAmount', actionRes.discountedAmount);
        }
        return res;
    }

    // 3. Agent 3: ERP Outbound Sync
    private static AssistantResponse handleERPSync(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'ERP_SYNC';

        SyncOrderToERPAgentAction.SyncOrderRequest req = new SyncOrderToERPAgentAction.SyncOrderRequest();
        req.amount = extractAmount(prompt);
        req.markClosedWon = true;

        if (contextRecordId != null && contextRecordId.getSobjectType() == Opportunity.SObjectType) {
            req.opportunityId = String.valueOf(contextRecordId);
        } else {
            String oppName = extractTargetName(prompt, new List<String>{'sync', 'erp', 'deal', 'order', 'won', 'outbound'});
            if (String.isNotBlank(oppName)) {
                req.opportunityName = oppName;
            } else {
                List<Opportunity> recentOpps = [
                    SELECT Id, Name FROM Opportunity WHERE IsClosed = false WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 3
                ];
                if (!recentOpps.isEmpty()) {
                    res.isSuccess = false;
                    res.message = 'Which Opportunity would you like to sync to ERP?';
                    for (Opportunity o : recentOpps) {
                        res.quickOptions.add(new QuickActionOption('Sync ' + o.Name, 'Sync won deal to ERP for ' + o.Name));
                    }
                    return res;
                }
            }
        }

        List<SyncOrderToERPAgentAction.SyncOrderResponse> responses = 
            SyncOrderToERPAgentAction.syncOrderToERP(new List<SyncOrderToERPAgentAction.SyncOrderRequest>{ req });

        if (!responses.isEmpty()) {
            SyncOrderToERPAgentAction.SyncOrderResponse actionRes = responses[0];
            res.isSuccess = actionRes.isSuccess;
            res.message = actionRes.message;
            res.details.put('orderNumber', actionRes.orderNumber);
            res.details.put('status', actionRes.status);
        }
        return res;
    }

    // 4. Agent 4: Customer 360 Executive Briefing
    private static AssistantResponse handleCustomer360(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'CUSTOMER_360';

        Customer360AgentAction.Customer360Request req = new Customer360AgentAction.Customer360Request();

        if (contextRecordId != null && contextRecordId.getSobjectType() == Account.SObjectType) {
            req.accountId = contextRecordId;
        } else {
            String accName = extractTargetName(prompt, new List<String>{'360', 'customer', 'briefing', 'executive', 'account', 'for'});
            if (String.isNotBlank(accName)) {
                req.accountName = accName;
            } else {
                List<Account> recentAccs = [
                    SELECT Id, Name FROM Account WITH USER_MODE ORDER BY LastModifiedDate DESC LIMIT 3
                ];
                if (!recentAccs.isEmpty()) {
                    res.isSuccess = false;
                    res.message = 'Which Account would you like a Customer 360 executive briefing for?';
                    for (Account a : recentAccs) {
                        res.quickOptions.add(new QuickActionOption('360 ' + a.Name, 'Get Customer 360 briefing for ' + a.Name));
                    }
                    return res;
                }
            }
        }

        List<Customer360AgentAction.Customer360Response> responses = 
            Customer360AgentAction.getExecutiveBriefing(new List<Customer360AgentAction.Customer360Request>{ req });

        if (!responses.isEmpty()) {
            Customer360AgentAction.Customer360Response actionRes = responses[0];
            res.isSuccess = actionRes.isSuccess;
            res.message = actionRes.executiveBriefing;
            res.details.put('accountId', actionRes.accountId);
            res.details.put('accountName', actionRes.accountName);
            res.details.put('lifetimeRevenue', actionRes.lifetimeRevenue);
        }
        return res;
    }

    // 5. Agent 5: CRM Record Details (Accurate Slot & Entity Extraction)
    private static AssistantResponse handleRecordDetails(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'RECORD_DETAILS';

        CRMRecordDetailsAgentAction.RecordDetailsRequest req = new CRMRecordDetailsAgentAction.RecordDetailsRequest();

        // 1. Explicit Record Type Detection
        if (prompt.contains('account') || prompt.contains('company')) {
            req.recordType = 'Account';
        } else if (prompt.contains('deal') || prompt.contains('opp') || prompt.contains('stage')) {
            req.recordType = 'Opportunity';
        } else if (prompt.contains('lead') || prompt.contains('prospect')) {
            req.recordType = 'Lead';
        } else if (prompt.contains('contact') || prompt.contains('person')) {
            req.recordType = 'Contact';
        } else {
            req.recordType = 'Auto';
        }

        if (contextRecordId != null) {
            req.recordName = String.valueOf(contextRecordId);
        } else {
            List<String> stopWords = new List<String>{
                'give', 'me', 'industry', 'phone', 'email', 'revenue', 'website', 'stage', 'amount', 'owner',
                'what', 'is', 'the', 'of', 'for', 'about', 'tell', 'show', 'view', 'detail', 'details', 'status',
                'account', 'company', 'opportunity', 'deal', 'lead', 'contact', 'look', 'up', 'lookup', 'find', 'get'
            };
            String recName = extractTargetName(prompt, stopWords);
            if (String.isNotBlank(recName)) {
                req.recordName = recName;
            } else {
                res.isSuccess = false;
                res.message = 'Please specify the Record Name or ID you would like details for.';
                return res;
            }
        }

        List<CRMRecordDetailsAgentAction.RecordDetailsResponse> responses = 
            CRMRecordDetailsAgentAction.getRecordDetails(new List<CRMRecordDetailsAgentAction.RecordDetailsRequest>{ req });

        if (!responses.isEmpty()) {
            CRMRecordDetailsAgentAction.RecordDetailsResponse actionRes = responses[0];
            res.isSuccess = actionRes.isSuccess;

            if (actionRes.isSuccess) {
                // If user specifically asked for an attribute, highlight it prominently
                if (prompt.contains('industry') && String.isNotBlank(actionRes.titleOrIndustry)) {
                    res.message = '🏢 **Industry for ' + actionRes.recordName + ':** `' + actionRes.titleOrIndustry + '`\n\n' + actionRes.detailsSummary;
                } else if (prompt.contains('phone') && String.isNotBlank(actionRes.phone)) {
                    res.message = '📞 **Phone for ' + actionRes.recordName + ':** `' + actionRes.phone + '`\n\n' + actionRes.detailsSummary;
                } else if (prompt.contains('stage') && String.isNotBlank(actionRes.stageOrStatus)) {
                    res.message = '📌 **Stage/Status for ' + actionRes.recordName + ':** `' + actionRes.stageOrStatus + '`\n\n' + actionRes.detailsSummary;
                } else {
                    res.message = actionRes.detailsSummary;
                }

                res.details.put('recordId', actionRes.recordId);
                res.details.put('recordName', actionRes.recordName);
                res.details.put('stageOrStatus', actionRes.stageOrStatus);
                res.details.put('amountOrBudget', actionRes.amountOrBudget);
            } else {
                res.message = actionRes.detailsSummary;
            }
        }
        return res;
    }

    // 6. Agent 6: Schedule Follow-Up Task
    private static AssistantResponse handleScheduleTask(String prompt, Id contextRecordId) {
        AssistantResponse res = new AssistantResponse();
        res.actionType = 'SCHEDULE_TASK';

        ScheduleFollowUpAgentAction.ScheduleRequest req = new ScheduleFollowUpAgentAction.ScheduleRequest();

        if (contextRecordId != null) {
            req.recordId = String.valueOf(contextRecordId);
        } else {
            String recName = extractTargetName(prompt, new List<String>{'schedule', 'task', 'follow-up', 'follow up', 'for', 'with'});
            if (String.isNotBlank(recName)) {
                req.recordName = recName;
            }
        }

        req.subject = 'Follow-up Scheduled via AI Assistant';
        req.dueDate = Date.today().addDays(3);
        req.priority = 'Normal';
        req.status = 'Not Started';

        List<ScheduleFollowUpAgentAction.ScheduleResponse> responses = 
            ScheduleFollowUpAgentAction.scheduleTask(new List<ScheduleFollowUpAgentAction.ScheduleRequest>{ req });

        if (!responses.isEmpty()) {
            ScheduleFollowUpAgentAction.ScheduleResponse actionRes = responses[0];
            res.isSuccess = actionRes.isSuccess;
            res.message = actionRes.message;
            res.details.put('taskId', actionRes.taskId);
            res.details.put('dueDate', actionRes.dueDate);
        }
        return res;
    }

    private static Decimal extractPercentage(String text) {
        Pattern p = Pattern.compile('(\\d{1,2})\\s*%');
        Matcher m = p.matcher(text);
        if (m.find()) {
            return Decimal.valueOf(m.group(1));
        }
        return null;
    }

    private static Decimal extractAmount(String text) {
        Pattern p = Pattern.compile('(?:\\$|amount\\s+|budget\\s+)(\\d+(?:\\.\\d{1,2})?)');
        Matcher m = p.matcher(text);
        if (m.find()) {
            return Decimal.valueOf(m.group(1));
        }
        return null;
    }

    private static String extractTargetName(String text, List<String> stopWords) {
        String clean = text;
        for (String w : stopWords) {
            clean = clean.replaceAll('(?i)\\b' + w + '\\b', ' ');
        }
        clean = clean.replaceAll('[^a-zA-Z0-9\\s]', ' ').trim();
        List<String> tokens = clean.split('\\s+');
        List<String> validTokens = new List<String>();
        for (String t : tokens) {
            if (t.length() > 2 && !t.equalsIgnoreCase('for') && !t.equalsIgnoreCase('the') && !t.equalsIgnoreCase('this') && !t.equalsIgnoreCase('get') && !t.equalsIgnoreCase('and')) {
                validTokens.add(t);
            }
        }
        return String.join(validTokens, ' ');
    }
}
