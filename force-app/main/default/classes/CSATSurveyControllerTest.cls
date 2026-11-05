/**
 * @description Comprehensive unit test suite for CSATSurveyController.
 * Validates positive submissions, rating validations, token obfuscation security,
 * non-closed case rejection, and idempotency guards against duplicate submissions.
 */
@IsTest
private class CSATSurveyControllerTest {

    @TestSetup
    static void setupTestData() {
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        Account acc = new Account(
            Name = 'TechNova Test Customer',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'Rony',
            LastName = 'Thakkar',
            Email = 'rony.thakkar.test@example.com',
            Phone = '5551234567',
            AccountId = acc.Id
        );
        insert con;

        // Create a Closed Case with token and CSAT_Sent__c true
        Case closedCase = new Case(
            Subject = 'Issue with Batch Processing',
            Status = 'Closed',
            Priority = 'Medium',
            AccountId = acc.Id,
            ContactId = con.Id,
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId,
            Resolution_Type__c = 'No Action Required',
            Resolution_Summary__c = 'Closed in setup test data.',
            CSAT_Sent__c = true,
            Survey_Token__c = 'token-uuid-1111-2222-3333-4444'
        );
        insert closedCase;

        // Create an Open Case with token
        Case openCase = new Case(
            Subject = 'Open Inquiry on API Integration',
            Status = 'New',
            Priority = 'High',
            AccountId = acc.Id,
            ContactId = con.Id,
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId,
            CSAT_Sent__c = true,
            Survey_Token__c = 'token-uuid-open-case-9999'
        );
        insert openCase;
    }

    @IsTest
    static void testValidSubmission_RatingAndComments() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-1111-2222-3333-4444' LIMIT 1];

        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', c.Survey_Token__c);
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();

        System.assertEquals(true, controller.isValidToken, 'Token should be valid for closed case');
        System.assertEquals(false, controller.isAlreadySubmitted, 'Should not be marked already submitted');

        controller.selectedRating = '5';
        controller.feedbackComments = 'Exceptional support from TechNova engineering!';
        controller.submitSurvey();
        Test.stopTest();

        System.assertEquals(true, controller.isSuccess, 'Submission should succeed');

        Case updatedCase = [SELECT Id, Customer_Rating__c, Feedback_Comments__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('5 - Excellent', updatedCase.Customer_Rating__c, 'Rating should normalize to 5 - Excellent');
        System.assertEquals('Exceptional support from TechNova engineering!', updatedCase.Feedback_Comments__c, 'Feedback comments should be saved');
    }

    @IsTest
    static void testValidSubmission_RatingOnlyWithoutComments() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-1111-2222-3333-4444' LIMIT 1];

        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', c.Survey_Token__c);
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();

        controller.selectedRating = '4';
        controller.feedbackComments = null; // Optional feedback left blank
        controller.submitSurvey();
        Test.stopTest();

        System.assertEquals(true, controller.isSuccess, 'Submission should succeed without optional comments');

        Case updatedCase = [SELECT Id, Customer_Rating__c, Feedback_Comments__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('4 - Good', updatedCase.Customer_Rating__c, 'Rating should normalize to 4 - Good');
        System.assertEquals(null, updatedCase.Feedback_Comments__c, 'Feedback comments should remain null');
    }

    @IsTest
    static void testInvalidToken_FailsGracefully() {
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', 'fake-nonexistent-token');
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();
        Test.stopTest();

        System.assertEquals(false, controller.isValidToken, 'Invalid token should not be accepted');
        System.assert(controller.pageMessage.contains('Invalid or expired'), 'Error message should indicate invalid token');
    }

    @IsTest
    static void testMissingToken_FailsGracefully() {
        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();
        Test.stopTest();

        System.assertEquals(false, controller.isValidToken, 'Empty token should not be accepted');
        System.assert(controller.pageMessage.contains('No access token provided'), 'Should prompt for valid token');
    }

    @IsTest
    static void testOpenCase_Rejected() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-open-case-9999' LIMIT 1];

        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', c.Survey_Token__c);
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();
        Test.stopTest();

        System.assertEquals(false, controller.isValidToken, 'Open case should not allow survey submission');
        System.assert(controller.pageMessage.contains('not currently active'), 'Should indicate survey is inactive');
    }

    @IsTest
    static void testAlreadySubmitted_BlocksDuplicate() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-1111-2222-3333-4444' LIMIT 1];
        c.Customer_Rating__c = '5 - Excellent';
        update c;

        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', c.Survey_Token__c);
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();
        Test.stopTest();

        System.assertEquals(false, controller.isValidToken, 'Already submitted case should not present form');
        System.assertEquals(true, controller.isAlreadySubmitted, 'Should flag as already submitted');
    }

    @IsTest
    static void testMissingRating_ThrowsValidationError() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-1111-2222-3333-4444' LIMIT 1];

        Test.startTest();
        PageReference pageRef = new PageReference('/apex/CSATSurvey');
        pageRef.getParameters().put('token', c.Survey_Token__c);
        Test.setCurrentPage(pageRef);

        CSATSurveyController controller = new CSATSurveyController();
        controller.init();

        controller.selectedRating = null; // Customer forgot to select stars
        controller.submitSurvey();
        Test.stopTest();

        System.assertEquals(false, controller.isSuccess, 'Submission should fail if rating is missing');
        System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR), 'Page should display validation error');
    }

    @IsTest
    static void testRemoteAction_Success() {
        Case c = [SELECT Id, Survey_Token__c FROM Case WHERE Survey_Token__c = 'token-uuid-1111-2222-3333-4444' LIMIT 1];

        Test.startTest();
        Map<String, Object> res = CSATSurveyController.submitSurveyRemote(c.Survey_Token__c, '5', 'High-performance response!');
        Test.stopTest();

        System.assertEquals(true, (Boolean)res.get('success'), 'RemoteAction should succeed');

        Case updatedCase = [SELECT Id, Customer_Rating__c, Feedback_Comments__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('5 - Excellent', updatedCase.Customer_Rating__c);
        System.assertEquals('High-performance response!', updatedCase.Feedback_Comments__c);
    }

    @IsTest
    static void testRemoteAction_InvalidToken() {
        Test.startTest();
        Map<String, Object> res = CSATSurveyController.submitSurveyRemote('invalid-token-xyz', '4', 'test');
        Test.stopTest();

        System.assertEquals(false, (Boolean)res.get('success'));
    }
}

