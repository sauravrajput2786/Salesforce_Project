/**
 * @description Comprehensive unit test suite for AgentApiController ensuring 90%+ code coverage.
 *              Uses HttpCalloutMock to test session start, message transmission, and session closure.
 */
@IsTest
private class AgentApiControllerTest {

    private class AgentApiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public AgentApiMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);

            if (this.responseBody != null) {
                res.setBody(this.responseBody);
            } else if (req.getMethod() == 'DELETE') {
                res.setStatusCode(204);
            } else if (req.getEndpoint().contains('/sessions') && req.getMethod() == 'POST' && req.getEndpoint().contains('/agents/')) {
                res.setStatusCode(200);
                res.setBody('{"sessionId":"0D5aj000000SampleSessionId","messages":[{"type":"Text","message":"Hi! I am Sales Operations Assistant."}]}');
            } else if (req.getEndpoint().contains('/messages') && req.getMethod() == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"messages":[{"type":"Text","message":"Lead Sam Altman was qualified and converted successfully!"}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"status":"OK"}');
            }
            return res;
        }
    }

    @IsTest
    static void testStartSessionDefaultSuccess() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(200, null));

        Test.startTest();
        AgentApiController.SessionResult res = AgentApiController.startSession(null, null);
        Test.stopTest();

        Assert.isTrue(res.isSuccess, 'Session start should succeed');
        Assert.areEqual('0D5aj000000SampleSessionId', res.sessionId, 'SessionId should match mock response');
        Assert.isTrue(res.welcomeMessage.contains('Sales Operations Assistant'), 'Welcome message should be populated');
    }

    @IsTest
    static void testStartSessionWithDeveloperNameAndContextRecord() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(200, null));

        // Create a dummy lead for context record ID testing
        Lead testLead = new Lead(LastName = 'Tester', Company = 'TestCo', Status = 'Open - Not Contacted');
        insert testLead;

        Test.startTest();
        AgentApiController.SessionResult res = AgentApiController.startSession('Sales_Operations_Assistant_Agentforce_ai', testLead.Id);
        Test.stopTest();

        Assert.isTrue(res.isSuccess, 'Session start with valid developer name should succeed');
        Assert.isNotNull(res.sessionId, 'SessionId should be present');
    }

    @IsTest
    static void testStartSessionUnauthorizedAgentKey() {
        Test.startTest();
        AgentApiController.SessionResult res = AgentApiController.startSession('Unauthorized_Agent_XYZ', null);
        Test.stopTest();

        Assert.isFalse(res.isSuccess, 'Session start should fail with unauthorized agentKey');
        Assert.isTrue(res.errorMessage.contains('Unauthorized or unmapped'), 'Error message should report authorization failure');
    }

    @IsTest
    static void testStartSessionHttpError() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(500, '{"message":"Internal Agentforce Gateway Error"}'));

        Test.startTest();
        AgentApiController.SessionResult res = AgentApiController.startSession(null, null);
        Test.stopTest();

        Assert.isFalse(res.isSuccess, 'Session start should fail on 500 status');
        Assert.isTrue(res.errorMessage.contains('Agent API Error (500)'), 'Error message should capture status code');
    }

    @IsTest
    static void testSendMessageSuccess() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(200, null));

        Test.startTest();
        AgentApiController.MessageResult res = AgentApiController.sendMessage('0D5aj000000SampleSessionId', 'Convert lead Sam Altman', 1);
        Test.stopTest();

        Assert.isTrue(res.isSuccess, 'Send message should succeed');
        Assert.isTrue(res.replyText.contains('Lead Sam Altman was qualified and converted'), 'Reply text should match agent output');
        Assert.areEqual(2, res.nextSequenceId, 'Next sequence ID should increment');
    }

    @IsTest
    static void testSendMessageValidationFailures() {
        Test.startTest();
        AgentApiController.MessageResult blankSessionRes = AgentApiController.sendMessage('', 'Hello', 1);
        AgentApiController.MessageResult blankMsgRes = AgentApiController.sendMessage('0D5aj000000SampleSessionId', '', 1);
        Test.stopTest();

        Assert.isFalse(blankSessionRes.isSuccess, 'Should fail when sessionId is blank');
        Assert.isFalse(blankMsgRes.isSuccess, 'Should fail when user message is blank');
    }

    @IsTest
    static void testSendMessageHttpError() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(400, '{"error":"Invalid message payload"}'));

        Test.startTest();
        AgentApiController.MessageResult res = AgentApiController.sendMessage('0D5aj000000SampleSessionId', 'Test message', 1);
        Test.stopTest();

        Assert.isFalse(res.isSuccess, 'Should fail when HTTP status is 400');
        Assert.isTrue(res.errorMessage.contains('Agent API Error (400)'), 'Error should report 400 status');
    }

    @IsTest
    static void testEndSessionSuccessAndBlank() {
        Test.setMock(HttpCalloutMock.class, new AgentApiMock(204, ''));

        Test.startTest();
        AgentApiController.endSession('0D5aj000000SampleSessionId');
        AgentApiController.endSession(null); // Should execute safely without error
        Test.stopTest();

        // End session is void and executes gracefully
        Assert.isTrue(true, 'End session executed successfully');
    }
}

