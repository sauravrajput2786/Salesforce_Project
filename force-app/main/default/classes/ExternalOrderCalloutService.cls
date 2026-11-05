/**
 * @description Outbound Callout Service that handles sending Closed Won Opportunity
 * data (Account, Primary Contact, Opportunity, Line Items) to an external API endpoint.
 * Uses Salesforce Named Credential (callout:External_Order_Service) to avoid hardcoding URLs.
 * Executes asynchronously via @future(callout=true) to prevent blocking the DML transaction.
 */
public without sharing class ExternalOrderCalloutService {

    // Named Credential endpoint (No hardcoded domain URLs)
    public static final String NAMED_CREDENTIAL_ENDPOINT = 'callout:External_Order_Service';

    /**
     * @description Asynchronous callout method invoked from OpportunityTriggerHandler
     * when one or more Opportunities transition to 'Closed Won'.
     * @param opportunityIds Set of Opportunity IDs that reached Closed Won
     */
    @future(callout=true)
    public static void sendOrdersToExternalApi(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }

        List<Opportunity> rawWonOpportunities = [
            SELECT Id, Name, Amount, CloseDate, StageName,
                   AccountId, Account.Name, Account.AccountNumber, Account.BillingCity, Account.BillingCountry,
                   Primary_Contact__c, Primary_Contact__r.Name, Primary_Contact__r.Email, Primary_Contact__r.Phone
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        // Programmatic FLS Enforcement: Strip any fields not accessible to ensure zero FLS breach
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.READABLE,
            rawWonOpportunities
        );
        List<Opportunity> wonOpportunities = (List<Opportunity>) decision.getRecords();

        Map<Id, List<OpportunityLineItem>> oppToLineItems = new Map<Id, List<OpportunityLineItem>>();
        if (Schema.sObjectType.OpportunityLineItem.isAccessible()) {
            List<OpportunityLineItem> rawLineItems = [
                SELECT Id, OpportunityId, Product2Id, Product2.Name, ProductCode, Quantity, UnitPrice, TotalPrice 
                FROM OpportunityLineItem 
                WHERE OpportunityId IN :opportunityIds
            ];
            SObjectAccessDecision oliDecision = Security.stripInaccessible(
                AccessType.READABLE,
                rawLineItems
            );
            for (OpportunityLineItem oli : (List<OpportunityLineItem>) oliDecision.getRecords()) {
                if (!oppToLineItems.containsKey(oli.OpportunityId)) {
                    oppToLineItems.put(oli.OpportunityId, new List<OpportunityLineItem>());
                }
                oppToLineItems.get(oli.OpportunityId).add(oli);
            }
        }

        for (Opportunity opp : wonOpportunities) {
            List<OpportunityLineItem> items = oppToLineItems.get(opp.Id);
            sendSingleOrderCallout(opp, items);
        }
    }

    /**
     * @description Builds the DTO payload and sends HTTP POST request via Named Credential.
     * @param opp Opportunity record with related Account and Contact queried
     * @return HttpResponse The received HTTP response from the external server
     */
    public static HttpResponse sendSingleOrderCallout(Opportunity opp) {
        return sendSingleOrderCallout(opp, null);
    }

    public static HttpResponse sendSingleOrderCallout(Opportunity opp, List<OpportunityLineItem> lineItems) {
        ExternalOrderPayloadDTO payload = buildPayload(opp, lineItems);
        String jsonBody = JSON.serializePretty(payload);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(NAMED_CREDENTIAL_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setBody(jsonBody);
        request.setTimeout(20000); // 20 seconds timeout

        Http http = new Http();
        HttpResponse response;

        try {
            response = http.send(request);
            System.debug(LoggingLevel.INFO, 'External Order Callout Response [' + response.getStatusCode() + ']: ' + response.getBody());
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'External Order Callout Failed for Opportunity ' + opp.Id + ': ' + ex.getMessage());
            throw ex;
        }

        return response;
    }

    /**
     * @description Constructs the ExternalOrderPayloadDTO from queried Opportunity data.
     * @param opp Opportunity record with parent and child relationships
     * @return ExternalOrderPayloadDTO structured payload
     */
    public static ExternalOrderPayloadDTO buildPayload(Opportunity opp) {
        return buildPayload(opp, null);
    }

    public static ExternalOrderPayloadDTO buildPayload(Opportunity opp, List<OpportunityLineItem> lineItems) {
        ExternalOrderPayloadDTO dto = new ExternalOrderPayloadDTO();
        dto.opportunityId = opp.Id;
        dto.opportunityName = opp.Name;
        dto.amount = opp.Amount;
        dto.closeDate = opp.CloseDate;
        dto.stage = opp.StageName;

        // Customer details
        if (opp.AccountId != null) {
            ExternalOrderPayloadDTO.CustomerDTO cust = new ExternalOrderPayloadDTO.CustomerDTO();
            cust.accountId = opp.AccountId;
            cust.accountName = opp.Account.Name;
            cust.accountNumber = opp.Account.AccountNumber;
            cust.billingCity = opp.Account.BillingCity;
            cust.billingCountry = opp.Account.BillingCountry;
            dto.customer = cust;
        }

        // Contact details
        if (opp.Primary_Contact__c != null) {
            ExternalOrderPayloadDTO.ContactDTO cont = new ExternalOrderPayloadDTO.ContactDTO();
            cont.contactId = opp.Primary_Contact__c;
            cont.fullName = opp.Primary_Contact__r.Name;
            cont.email = opp.Primary_Contact__r.Email;
            cont.phone = opp.Primary_Contact__r.Phone;
            dto.contact = cont;
        }

        // Product Line Items
        dto.products = new List<ExternalOrderPayloadDTO.ProductDTO>();
        List<OpportunityLineItem> itemsToProcess = lineItems;
        if (itemsToProcess == null) {
            try {
                itemsToProcess = opp.OpportunityLineItems;
            } catch (Exception ex) {
                itemsToProcess = null;
            }
        }

        if (itemsToProcess != null && !itemsToProcess.isEmpty()) {
            for (OpportunityLineItem oli : itemsToProcess) {
                ExternalOrderPayloadDTO.ProductDTO prod = new ExternalOrderPayloadDTO.ProductDTO();
                prod.productId = oli.Product2Id;
                prod.productName = oli.Product2 != null ? oli.Product2.Name : null;
                prod.productCode = oli.ProductCode;
                prod.quantity = oli.Quantity;
                prod.unitPrice = oli.UnitPrice;
                prod.totalPrice = oli.TotalPrice;
                dto.products.add(prod);
            }
        }

        return dto;
    }
}
