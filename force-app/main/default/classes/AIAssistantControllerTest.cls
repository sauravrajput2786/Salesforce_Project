@IsTest
private class AIAssistantControllerTest {

    @TestSetup
    static void setupTestData() {
        Account testAcc = new Account(
            Name = 'Assistant Test Corp',
            Type = 'Customer',
            Industry = 'Technology'
        );
        insert testAcc;

        Contact testCon = new Contact(
            FirstName = 'Assistant',
            LastName = 'LeadUser',
            Email = 'leaduser@assistant.test',
            AccountId = testAcc.Id
        );
        insert testCon;

        Opportunity testOpp = new Opportunity(
            Name = 'Assistant Test Deal',
            AccountId = testAcc.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        );
        insert testOpp;

        Lead testLead = new Lead(
            FirstName = 'Sam',
            LastName = 'Altman',
            Company = 'OpenAI Ventures',
            Email = 'sam@openaiventures.test',
            Status = 'Open - Not Contacted'
        );
        insert testLead;
    }

    @IsTest
    static void testGeneralHelpCommand() {
        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('hello assistant', null);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('GENERAL', res.actionType, 'Action type should be GENERAL');
        System.assert(res.quickOptions.size() > 0, 'Quick options should be populated');
    }

    @IsTest
    static void testOffTopicGuardrail() {
        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('what is the weather today?', null);
        Test.stopTest();

        System.assertEquals(false, res.isSuccess, 'Should trigger guardrail');
        System.assertEquals('GUARDRAIL', res.actionType, 'Action type should be GUARDRAIL');
    }

    @IsTest
    static void testLeadConversionIntent() {
        Lead l = [SELECT Id FROM Lead WHERE LastName = 'Altman' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('convert this lead', l.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('LEAD_CONVERT', res.actionType, 'Action type should be LEAD_CONVERT');
    }

    @IsTest
    static void testDiscountApprovalIntent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Assistant Test Deal' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('evaluate 15% discount', opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('DISCOUNT_APPROVAL', res.actionType, 'Action type should be DISCOUNT_APPROVAL');
    }

    @IsTest
    static void testERPSyncIntent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Assistant Test Deal' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('sync won deal to erp amount 500', opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('ERP_SYNC', res.actionType, 'Action type should be ERP_SYNC');
    }

    @IsTest
    static void testCustomer360Intent() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Assistant Test Corp' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('get Customer 360 briefing', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('CUSTOMER_360', res.actionType, 'Action type should be CUSTOMER_360');
    }

    @IsTest
    static void testRecordDetailsIntent() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Assistant Test Deal' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('get details for record', opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('RECORD_DETAILS', res.actionType, 'Action type should be RECORD_DETAILS');
    }

    @IsTest
    static void testScheduleTaskIntent() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Assistant Test Corp' LIMIT 1];

        Test.startTest();
        AIAssistantController.AssistantResponse res = AIAssistantController.executeAssistantCommand('schedule a follow-up task', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
        System.assertEquals('SCHEDULE_TASK', res.actionType, 'Action type should be SCHEDULE_TASK');
    }
}
