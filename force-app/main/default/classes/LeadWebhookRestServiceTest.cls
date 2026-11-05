/**
 * @description Unit tests for LeadWebhookRestService Apex REST Inbound Webhook.
 * Tests Lead creation, smart name parsing, duplicate prevention, and exception handling.
 */
@isTest
private class LeadWebhookRestServiceTest {

    @isTest
    static void testSuccessfulLeadCreation() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'name' => 'Rahul Kumar Shah',
            'company' => 'ABC Industries',
            'email' => 'rahul.shah@example.com',
            'phone' => '9999999999',
            'budget' => 75000,
            'region' => 'Asia',
            'message' => 'Interested in B2B enterprise tier deployment'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse response = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual(201, res.statusCode, 'Status code should be 201 Created');
        Assert.areEqual('SUCCESS', response.status, 'Response status should be SUCCESS');
        Assert.areEqual('CREATED', response.action, 'Action should be CREATED');
        Assert.isNotNull(response.leadId, 'Lead ID should not be null');

        Lead insertedLead = [
            SELECT Id, FirstName, LastName, Company, Email, Phone, LeadSource, Status, Estimated_Budget__c, Description, Lead_Region__c 
            FROM Lead 
            WHERE Id = :response.leadId
        ];
        Assert.areEqual('Rahul Kumar', insertedLead.FirstName, 'FirstName should be parsed as Rahul Kumar');
        Assert.areEqual('Shah', insertedLead.LastName, 'LastName should be parsed as Shah');
        Assert.areEqual('ABC Industries', insertedLead.Company, 'Company should match');
        Assert.areEqual('Website', insertedLead.LeadSource, 'LeadSource should be Website');
        Assert.areEqual(75000, insertedLead.Estimated_Budget__c, 'Budget should match');
        Assert.areEqual('Asia', insertedLead.Lead_Region__c, 'Region should match');
    }

    @isTest
    static void testSingleWordNameLeadCreation() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'name' => 'Madonna',
            'company' => 'Single Name Corp',
            'email' => 'madonna@example.com',
            'phone' => '8888888888'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse response = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual(201, res.statusCode, 'Status code should be 201 Created');
        Lead insertedLead = [SELECT FirstName, LastName FROM Lead WHERE Id = :response.leadId];
        Assert.isNull(insertedLead.FirstName, 'FirstName should be null for single name in database');
        Assert.areEqual('Madonna', insertedLead.LastName, 'LastName should hold the single name');
    }

    @isTest
    static void testDuplicateLeadUpdate() {
        // 1. Insert existing lead
        Lead existingLead = new Lead(
            FirstName = 'Existing',
            LastName = 'Lead',
            Company = 'Old Company Corp',
            Email = 'duplicate.test@example.com',
            LeadSource = 'Website',
            Status = 'Open - Not Contacted',
            Estimated_Budget__c = 20000
        );
        insert existingLead;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'name' => 'Existing Lead Updated',
            'company' => 'New Inquiring Company',
            'email' => 'duplicate.test@example.com',
            'budget' => 95000,
            'message' => 'Follow up on second project'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse response = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual(200, res.statusCode, 'Status code should be 200 OK for duplicate update');
        Assert.areEqual('UPDATED', response.action, 'Action should be UPDATED');
        Assert.areEqual(existingLead.Id, response.leadId, 'Lead ID should match existing lead');

        Lead updatedLead = [SELECT Id, Estimated_Budget__c, Description FROM Lead WHERE Id = :existingLead.Id];
        Assert.areEqual(95000, updatedLead.Estimated_Budget__c, 'Budget should be updated to 95000');
        Assert.isTrue(updatedLead.Description.contains('Follow up on second project'), 'Description should contain new note');
    }

    @isTest
    static void testMissingRequiredFields() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'name' => '', // missing name
            'company' => 'No Name Corp'
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse response = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
        Assert.areEqual('ERROR', response.status, 'Status should be ERROR');
        Assert.isTrue(response.message.contains('Validation Failed'), 'Message should indicate validation failure');
    }

    @isTest
    static void testNegativeBudgetValidation() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'name' => 'Bad Budget Lead',
            'company' => 'Negative Budget Corp',
            'email' => 'badbudget@example.com',
            'budget' => -5000
        }));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse response = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual(400, res.statusCode, 'Status code should be 400 Bad Request');
        Assert.areEqual('ERROR', response.status, 'Status should be ERROR');
        Assert.isTrue(response.message.contains('Estimated Budget cannot be negative'), 'Message should flag negative budget');
    }

    @isTest
    static void testEmptyAndMalformedRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/webhook/leads';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('   '); // Empty

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LeadWebhookRestService.LeadWebhookResponse emptyResponse = LeadWebhookRestService.handleInboundLead();

        // Malformed JSON test
        req.requestBody = Blob.valueOf('{ invalid_json: ... ');
        LeadWebhookRestService.LeadWebhookResponse malformedResponse = LeadWebhookRestService.handleInboundLead();
        Test.stopTest();

        Assert.areEqual('ERROR', emptyResponse.status, 'Empty body should return ERROR');
        Assert.areEqual('ERROR', malformedResponse.status, 'Malformed JSON should return ERROR');
    }

    @isTest
    static void testParseFullNameHelper() {
        Map<String, String> single = LeadWebhookRestService.parseFullName('Amit');
        Assert.areEqual('', single.get('FirstName'));
        Assert.areEqual('Amit', single.get('LastName'));

        Map<String, String> doubleName = LeadWebhookRestService.parseFullName('Amit Patel');
        Assert.areEqual('Amit', doubleName.get('FirstName'));
        Assert.areEqual('Patel', doubleName.get('LastName'));

        Map<String, String> tripleName = LeadWebhookRestService.parseFullName('Dr. Amit Kumar Patel');
        Assert.areEqual('Dr. Amit Kumar', tripleName.get('FirstName'));
        Assert.areEqual('Patel', tripleName.get('LastName'));

        Map<String, String> emptyName = LeadWebhookRestService.parseFullName('');
        Assert.areEqual('Unknown', emptyName.get('LastName'));
    }
}
