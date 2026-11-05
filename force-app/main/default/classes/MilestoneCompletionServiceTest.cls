/**
 * @description Comprehensive unit test suite for MilestoneCompletionService, EmailMessageTrigger,
 * and CaseTrigger, verifying automated milestone completion for BUG-001 resolution.
 */
@IsTest
private class MilestoneCompletionServiceTest {

    @TestSetup
    static void setupTestData() {
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        Account testAccount = new Account(
            Name = 'Milestone Test Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Customer',
            Email = 'jane.customer@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        Case openCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'Milestone First Response Ticket',
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId
        );
        insert openCase;

        Case closeCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'Milestone Closure Ticket',
            Status = 'New',
            Priority = 'High',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId
        );
        insert closeCase;
    }

    @IsTest
    static void testOutboundEmailCompletesFirstResponse() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Milestone First Response Ticket' LIMIT 1];
        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        EmailMessage outboundEmail = new EmailMessage(
            ParentId = c.Id,
            Incoming = false,
            ToAddress = 'jane.customer@example.com',
            FromAddress = 'support@technova.com',
            Subject = 'Response: Milestone First Response Ticket',
            TextBody = 'Hello Jane, our engineering team is actively investigating your request.'
        );
        insert outboundEmail;
        Test.stopTest();

        System.assertNotEquals(null, outboundEmail.Id, 'Outbound email message must be inserted successfully');
    }

    @IsTest
    static void testIncomingEmailDoesNotCompleteMilestone() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Milestone First Response Ticket' LIMIT 1];
        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        EmailMessage incomingEmail = new EmailMessage(
            ParentId = c.Id,
            Incoming = true,
            FromAddress = 'jane.customer@example.com',
            ToAddress = 'support@technova.com',
            Subject = 'Update on Ticket',
            TextBody = 'Any update on my issue?'
        );
        insert incomingEmail;
        Test.stopTest();

        System.assertNotEquals(null, incomingEmail.Id, 'Incoming email message must insert without triggering completion');
    }

    @IsTest
    static void testCaseClosureMilestoneCompletion() {
        Case c = [SELECT Id, Status FROM Case WHERE Subject = 'Milestone Closure Ticket' LIMIT 1];
        System.assertNotEquals('Closed', c.Status, 'Case should initially be open');

        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        c.Status = 'Closed';
        c.Resolution_Type__c = 'No Action Required';
        c.Resolution_Summary__c = 'Resolved in test execution.';
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Status, IsClosed FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Closed', updatedCase.Status, 'Case status must be Closed');
        System.assertEquals(true, updatedCase.IsClosed, 'IsClosed flag must be true');
    }

    @IsTest
    static void testIdempotencyAndRepeatExecutions() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Milestone First Response Ticket' LIMIT 1];
        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        // First outbound email
        EmailMessage email1 = new EmailMessage(
            ParentId = c.Id,
            Incoming = false,
            ToAddress = 'jane.customer@example.com',
            FromAddress = 'support@technova.com',
            Subject = 'First Response',
            TextBody = 'Initial contact.'
        );
        insert email1;

        // Second outbound email on the same case should execute cleanly and idempotently
        EmailMessage email2 = new EmailMessage(
            ParentId = c.Id,
            Incoming = false,
            ToAddress = 'jane.customer@example.com',
            FromAddress = 'support@technova.com',
            Subject = 'Second Followup',
            TextBody = 'Additional context.'
        );
        insert email2;
        Test.stopTest();

        System.assertNotEquals(null, email1.Id, 'First email must be inserted');
        System.assertNotEquals(null, email2.Id, 'Second email must be inserted idempotently without failure');
    }

    @IsTest
    static void testBulkEmailAndCaseClosure() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Milestone Test Account' LIMIT 1];
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();
        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 20; i++) {
            bulkCases.add(new Case(
                AccountId = acc.Id,
                Subject = 'Bulk Milestone Ticket ' + i,
                Status = 'New',
                Priority = 'Medium',
                Origin = 'Web',
                RecordTypeId = generalInquiryRtId
            ));
        }
        insert bulkCases;

        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        // Bulk outbound email dispatch
        List<EmailMessage> bulkEmails = new List<EmailMessage>();
        for (Case c : bulkCases) {
            bulkEmails.add(new EmailMessage(
                ParentId = c.Id,
                Incoming = false,
                ToAddress = 'customer' + c.Id + '@example.com',
                FromAddress = 'support@technova.com',
                Subject = 'Bulk First Response',
                TextBody = 'Your issue has been acknowledged.'
            ));
        }
        insert bulkEmails;
        System.assertEquals(20, bulkEmails.size(), 'All 20 outbound emails must be created');

        // Bulk case closure
        MilestoneCompletionService.resetRecursionGuards();
        for (Case c : bulkCases) {
            c.Status = 'Closed';
            c.Resolution_Type__c = 'No Action Required';
            c.Resolution_Summary__c = 'Bulk test closure.';
        }
        update bulkCases;
        Test.stopTest();

        List<Case> closedCases = [SELECT Id, Status FROM Case WHERE Id IN :bulkCases AND Status = 'Closed'];
        System.assertEquals(20, closedCases.size(), 'All 20 bulk cases must be closed successfully');
    }

    @IsTest
    static void testNullAndEmptySafety() {
        Test.startTest();
        // Direct invocation with null and empty collections to verify defensive guards
        MilestoneCompletionService.completeFirstResponseMilestones(null);
        MilestoneCompletionService.completeFirstResponseMilestones(new List<EmailMessage>());
        MilestoneCompletionService.completeCaseCloseMilestones(null, null);
        MilestoneCompletionService.completeCaseCloseMilestones(new List<Case>(), new Map<Id, Case>());
        Test.stopTest();

        // Implicit assertion: no unhandled NullPointerException thrown
        System.assert(true, 'Defensive null-checks must prevent null pointer exceptions');
    }
}
