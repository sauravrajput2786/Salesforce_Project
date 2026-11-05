/**
 * @description Inbound Webhook REST Service that receives external website form submissions
 * and converts them into Salesforce Lead records.
 * Endpoint URL: /services/apexrest/v1/webhook/leads
 */
@RestResource(urlMapping='/v1/webhook/leads/*')
global with sharing class LeadWebhookRestService {

    /**
     * @description Inbound Payload DTO representing data sent by the external website form.
     */
    global class LeadInboundPayload {
        public String name;
        public String company;
        public String email;
        public String phone;
        public Decimal budget;
        public String region;
        public String message;
    }

    /**
     * @description Outbound Response DTO sent back to the external website.
     */
    global class LeadWebhookResponse {
        public String status;
        public String message;
        public String leadId;
        public String action;

        public LeadWebhookResponse(String status, String message, String leadId, String action) {
            this.status = status;
            this.message = message;
            this.leadId = leadId;
            this.action = action;
        }
    }

    /**
     * @description HTTP POST endpoint to process inbound website form submission.
     * @return LeadWebhookResponse JSON response containing result and Lead ID
     */
    @HttpPost
    global static LeadWebhookResponse handleInboundLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }

        if (req == null || req.requestBody == null || String.isBlank(req.requestBody.toString())) {
            res.statusCode = 400;
            return new LeadWebhookResponse('ERROR', 'Request body cannot be empty.', null, null);
        }

        LeadInboundPayload payload;
        try {
            payload = (LeadInboundPayload) JSON.deserialize(req.requestBody.toString(), LeadInboundPayload.class);
        } catch (Exception ex) {
            res.statusCode = 400;
            return new LeadWebhookResponse('ERROR', 'Malformed JSON payload: ' + ex.getMessage(), null, null);
        }

        // 1. Mandatory Field Validation
        if (payload == null || String.isBlank(payload.name) || String.isBlank(payload.company)) {
            res.statusCode = 400;
            return new LeadWebhookResponse('ERROR', 'Validation Failed: "name" and "company" are mandatory fields.', null, null);
        }

        // 2. Budget Validation Rule (Estimated_Budget__c cannot be negative)
        if (payload.budget != null && payload.budget < 0) {
            res.statusCode = 400;
            return new LeadWebhookResponse('ERROR', 'Validation Failed: Estimated Budget cannot be negative.', null, null);
        }

        try {
            // 3. Pre-emptive Duplicate Prevention by Email
            List<Lead> existingLeads = new List<Lead>();
            if (String.isNotBlank(payload.email)) {
                existingLeads = [
                    SELECT Id, FirstName, LastName, Company, Email, Phone, Description, Estimated_Budget__c 
                    FROM Lead 
                    WHERE Email = :payload.email 
                    WITH USER_MODE 
                    LIMIT 1
                ];
            }

            if (!existingLeads.isEmpty()) {
                // Update existing lead with latest message/budget instead of creating duplicate
                Lead existingLead = existingLeads[0];
                if (String.isNotBlank(payload.message)) {
                    existingLead.Description = (existingLead.Description != null ? existingLead.Description + '\n---\n' : '') + 
                                               'Latest Web Form Submission: ' + payload.message;
                }
                if (payload.budget != null) {
                    existingLead.Estimated_Budget__c = payload.budget;
                }
                if (String.isNotBlank(payload.phone)) {
                    existingLead.Phone = payload.phone;
                }
                update as user existingLead;

                res.statusCode = 200;
                return new LeadWebhookResponse('SUCCESS', 'Existing lead updated with new inquiry.', existingLead.Id, 'UPDATED');
            }

            // 4. Parse Name into FirstName and LastName
            Map<String, String> nameParts = parseFullName(payload.name);

            // 5. Create new Lead record satisfying all validation rules
            Lead newLead = new Lead();
            newLead.FirstName = nameParts.get('FirstName');
            newLead.LastName = nameParts.get('LastName');
            newLead.Company = payload.company;
            newLead.Email = payload.email;
            newLead.Phone = payload.phone;
            newLead.LeadSource = 'Website';
            newLead.Status = 'Open - Not Contacted';
            newLead.Description = payload.message;

            if (payload.budget != null) {
                newLead.Estimated_Budget__c = payload.budget;
            }
            if (String.isNotBlank(payload.region)) {
                newLead.Lead_Region__c = payload.region;
            }

            insert as user newLead;

            res.statusCode = 201;
            return new LeadWebhookResponse('SUCCESS', 'Lead created successfully from website webhook.', newLead.Id, 'CREATED');

        } catch (DmlException dmlEx) {
            res.statusCode = 400;
            return new LeadWebhookResponse('ERROR', 'DML Error: ' + dmlEx.getDmlMessage(0), null, null);
        } catch (Exception ex) {
            res.statusCode = 500;
            return new LeadWebhookResponse('ERROR', 'Internal Server Error: ' + ex.getMessage(), null, null);
        }
    }

    /**
     * @description Smart name parsing helper that splits full names into FirstName and LastName.
     * Handles single-word names (e.g. "Rahul") and multi-word names (e.g. "Rahul Kumar Shah").
     * @param fullName Full name string sent from website
     * @return Map<String, String> with keys 'FirstName' and 'LastName'
     */
    public static Map<String, String> parseFullName(String fullName) {
        Map<String, String> result = new Map<String, String>{
            'FirstName' => '',
            'LastName' => 'Unknown'
        };

        if (String.isBlank(fullName)) {
            return result;
        }

        String trimmedName = fullName.trim();
        List<String> parts = trimmedName.split('\\s+');

        if (parts.size() == 1) {
            result.put('FirstName', '');
            result.put('LastName', parts[0]);
        } else {
            result.put('LastName', parts[parts.size() - 1]);
            parts.remove(parts.size() - 1);
            result.put('FirstName', String.join(parts, ' '));
        }

        return result;
    }
}
