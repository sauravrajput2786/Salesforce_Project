/**
 * @description Comprehensive unit and integration test suite for CSATSurveyService,
 * Case_CSAT_Survey_Trigger flow, and VR_Case_Lock_Customer_And_SLA_Data hybrid immutability validation.
 */
@IsTest
private class CSATSurveyServiceTest {

    @TestSetup
    static void setupTestData() {
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        Account testAccount = new Account(
            Name = 'CSAT Test Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Alice',
            LastName = 'Customer',
            Email = 'alice.customer@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        Case closedCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'CSAT Survey Test Ticket',
            Status = 'Closed',
            Priority = 'Medium',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId,
            Resolution_Type__c = 'No Action Required',
            Resolution_Summary__c = 'Closed in setup test data.'
        );
        insert closedCase;

        Case openCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'CSAT Open Ticket',
            Status = 'New',
            Priority = 'High',
            Origin = 'Phone',
            RecordTypeId = generalInquiryRtId
        );
        insert openCase;
    }

    @IsTest
    static void testInitialSurveyResponseSubmission() {
        Case c = [SELECT Id, Customer_Rating__c, Feedback_Comments__c, CSAT_Sent__c FROM Case WHERE Subject = 'CSAT Survey Test Ticket' LIMIT 1];
        System.assertEquals(null, c.Customer_Rating__c, 'Initial rating should be blank');

        Test.startTest();
        Boolean success = CSATSurveyService.recordResponse(c.Id, 5, 'Outstanding support experience!');
        Test.stopTest();

        System.assert(success, 'Survey submission should succeed');

        Case updatedCase = [SELECT Id, Customer_Rating__c, Feedback_Comments__c, CSAT_Sent__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('5 - Excellent', updatedCase.Customer_Rating__c, 'Rating should map to 5 - Excellent');
        System.assertEquals('Outstanding support experience!', updatedCase.Feedback_Comments__c, 'Feedback comments should match');
        System.assertEquals(true, updatedCase.CSAT_Sent__c, 'CSAT_Sent__c flag should be stamped true');
    }

    @IsTest
    static void testRatingTamperingBlockedByValidationRule() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'CSAT Survey Test Ticket' LIMIT 1];
        Boolean initialRecorded = CSATSurveyService.recordResponse(c.Id, 4, 'Good support');
        System.assert(initialRecorded, 'Initial recording should succeed');

        Test.startTest();
        // An agent attempts to tamper with the existing customer rating
        Case caseToTamper = [SELECT Id, Customer_Rating__c FROM Case WHERE Id = :c.Id LIMIT 1];
        Boolean exceptionCaught = false;
        try {
            caseToTamper.Customer_Rating__c = '1 - Very Poor';
            update caseToTamper;
        } catch (DmlException e) {
            exceptionCaught = true;
            System.assert(e.getMessage().contains('CSAT ratings/feedback') || e.getMessage().contains('Rule Violation'),
                'Validation rule must block tampering with existing rating: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'VR_Case_Lock_Customer_And_SLA_Data must prevent altering an existing customer rating');
    }

    @IsTest
    static void testFeedbackTamperingBlockedByValidationRule() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'CSAT Survey Test Ticket' LIMIT 1];
        Boolean initialRecorded = CSATSurveyService.recordResponse(c.Id, 3, 'Average resolution speed');
        System.assert(initialRecorded, 'Initial recording should succeed');

        Test.startTest();
        // An agent attempts to alter customer feedback comments
        Case caseToTamper = [SELECT Id, Feedback_Comments__c FROM Case WHERE Id = :c.Id LIMIT 1];
        Boolean exceptionCaught = false;
        try {
            caseToTamper.Feedback_Comments__c = 'Tampered comment trying to overwrite customer voice.';
            update caseToTamper;
        } catch (DmlException e) {
            exceptionCaught = true;
            System.assert(e.getMessage().contains('CSAT ratings/feedback') || e.getMessage().contains('Rule Violation'),
                'Validation rule must block tampering with feedback comments: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'VR_Case_Lock_Customer_And_SLA_Data must prevent altering existing feedback comments');
    }

    @IsTest
    static void testBulkSurveyResponseProcessing() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'CSAT Test Account' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'alice.customer@example.com' LIMIT 1];

        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 20; i++) {
            bulkCases.add(new Case(
                AccountId = acc.Id,
                ContactId = con.Id,
                Subject = 'Bulk CSAT Case ' + i,
                Status = 'Closed',
                Priority = 'Medium',
                Origin = 'Web',
                RecordTypeId = generalInquiryRtId,
                Resolution_Type__c = 'No Action Required',
                Resolution_Summary__c = 'Bulk test case closed.'
            ));
        }
        insert bulkCases;

        List<CSATSurveyService.SurveySubmissionRequest> requests = new List<CSATSurveyService.SurveySubmissionRequest>();
        for (Integer i = 0; i < bulkCases.size(); i++) {
            String ratingVal = String.valueOf(Math.mod(i, 5) + 1);
            requests.add(new CSATSurveyService.SurveySubmissionRequest(
                bulkCases[i].Id,
                ratingVal,
                'Bulk feedback review ' + i
            ));
        }

        Test.startTest();
        List<CSATSurveyService.SurveySubmissionResult> results = CSATSurveyService.processSurveyResponses(requests);
        Test.stopTest();

        System.assertEquals(20, results.size(), 'All 20 requests should return results');
        for (CSATSurveyService.SurveySubmissionResult res : results) {
            System.assertEquals(true, res.isSuccess, 'Every request should succeed: ' + res.errorMessage);
        }

        List<Case> updatedCases = [SELECT Id, Customer_Rating__c, CSAT_Sent__c FROM Case WHERE Id IN :bulkCases];
        for (Case c : updatedCases) {
            System.assertNotEquals(null, c.Customer_Rating__c, 'Customer rating should be populated');
            System.assertEquals(true, c.CSAT_Sent__c, 'CSAT_Sent__c must be true');
        }
    }

    @IsTest
    static void testInvalidRatingDefensiveHandling() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'CSAT Survey Test Ticket' LIMIT 1];

        Test.startTest();
        CSATSurveyService.SurveySubmissionRequest invalidReq = new CSATSurveyService.SurveySubmissionRequest(c.Id, '99', 'Invalid test');
        List<CSATSurveyService.SurveySubmissionResult> results = CSATSurveyService.processSurveyResponses(
            new List<CSATSurveyService.SurveySubmissionRequest>{ invalidReq }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Result list should have 1 item');
        System.assertEquals(false, results[0].isSuccess, 'Submission should fail for invalid rating');
        System.assert(results[0].errorMessage.contains('Invalid rating value'), 'Error message should explain invalid rating');
    }

    @IsTest
    static void testNonExistentCaseHandling() {
        Test.startTest();
        // Fake Case Id with standard 500 prefix
        Id fakeCaseId = '500000000000000AAA';
        CSATSurveyService.SurveySubmissionRequest nonExistentReq = new CSATSurveyService.SurveySubmissionRequest(fakeCaseId, '5', 'Fake case test');
        List<CSATSurveyService.SurveySubmissionResult> results = CSATSurveyService.processSurveyResponses(
            new List<CSATSurveyService.SurveySubmissionRequest>{ nonExistentReq }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Result list should have 1 item');
        System.assertEquals(false, results[0].isSuccess, 'Submission should fail for non-existent case');
    }
}
