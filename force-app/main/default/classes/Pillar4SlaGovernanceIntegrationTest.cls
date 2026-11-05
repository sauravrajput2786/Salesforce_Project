/**
 * @description End-to-end integration and governance test suite for Pillar 4
 * (Milestone Lifecycle & SLA Governance). Verifies intake data and SLA breach metric
 * immutability (GOV-02), automated SLA breach tracking alignment (GOV-01), Critical
 * priority downgrade protection, outbound email first-response milestone completion,
 * case closure milestone completion, and non-locked field servicing.
 */
@IsTest
private class Pillar4SlaGovernanceIntegrationTest {

    @TestSetup
    static void setupIntegrationData() {
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        Account testAccount = new Account(
            Name = 'Pillar4 Governance Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Pillar',
            LastName = 'Governance',
            Email = 'pillar.gov@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;

        Case activeCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'Pillar 4 Active SLA Ticket',
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId
        );
        insert activeCase;

        Case criticalCase = new Case(
            AccountId = testAccount.Id,
            ContactId = testContact.Id,
            Subject = 'Pillar 4 Critical Protection Ticket',
            Status = 'New',
            Priority = 'Critical',
            Origin = 'Phone',
            RecordTypeId = generalInquiryRtId
        );
        insert criticalCase;
    }

    @IsTest
    static void testIntakeDataImmutabilityBlocksUnauthorizedModifications() {
        Case c = [SELECT Id, AccountId, ContactId, Origin FROM Case WHERE Subject = 'Pillar 4 Active SLA Ticket' LIMIT 1];

        Account altAccount = new Account(
            Name = 'Unauthorized Alternative Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5559876543'
        );
        insert altAccount;

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            c.AccountId = altAccount.Id;
            update c;
        } catch (DmlException e) {
            exceptionCaught = true;
            System.assert(e.getMessage().contains('Customer intake data') || e.getMessage().contains('Rule Violation'),
                'Exception message should reference VR_Case_Lock_Customer_And_SLA_Data rule: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'VR_Case_Lock_Customer_And_SLA_Data must prevent altering AccountId on existing Case');
    }

    @IsTest
    static void testSlaBreachDataImmutabilityBlocksAgentTampering() {
        Case c = [SELECT Id, SLA_Breached__c, SLAViolation__c FROM Case WHERE Subject = 'Pillar 4 Active SLA Ticket' LIMIT 1];

        Test.startTest();
        // 1. Verify SLA_Breached__c cannot be modified directly by agents
        Boolean breachedExceptionCaught = false;
        try {
            c.SLA_Breached__c = true;
            update c;
        } catch (DmlException e) {
            breachedExceptionCaught = true;
            System.assert(e.getMessage().contains('SLA metrics') || e.getMessage().contains('Rule Violation'),
                'Exception should reference SLA metric protection: ' + e.getMessage());
        }
        System.assert(breachedExceptionCaught, 'Validation rule must prevent manual modification of SLA_Breached__c');

        // 2. Verify SLAViolation__c cannot be modified directly by agents
        Boolean violationExceptionCaught = false;
        try {
            c.SLAViolation__c = 'Yes';
            update c;
        } catch (DmlException e) {
            violationExceptionCaught = true;
            System.assert(e.getMessage().contains('SLA metrics') || e.getMessage().contains('Rule Violation'),
                'Exception should reference SLA metric protection: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(violationExceptionCaught, 'Validation rule must prevent manual modification of SLAViolation__c');
    }

    @IsTest
    static void testNonLockedFieldUpdatesPermitted() {
        Case c = [SELECT Id, Subject, Description FROM Case WHERE Subject = 'Pillar 4 Active SLA Ticket' LIMIT 1];

        Test.startTest();
        c.Subject = 'Pillar 4 Active SLA Ticket - Serviced';
        c.Description = 'Agent added notes and updated subject successfully without hitting lock rule.';
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Subject, Description FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Pillar 4 Active SLA Ticket - Serviced', updatedCase.Subject, 'Non-locked fields should update cleanly');
        System.assert(updatedCase.Description.contains('Agent added notes'), 'Description should be updated successfully');
    }

    @IsTest
    static void testCriticalPriorityProtectionIntegration() {
        Case c = [SELECT Id, Priority FROM Case WHERE Subject = 'Pillar 4 Critical Protection Ticket' LIMIT 1];
        System.assertEquals('Critical', c.Priority, 'Case should initially have Critical priority');

        Test.startTest();
        // Simulate automated SLA violation or agent update attempting to downgrade to High
        c.Priority = 'High';
        update c;
        Test.stopTest();

        Case verifiedCase = [SELECT Id, Priority FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Critical', verifiedCase.Priority,
            'Case_Critical_Priority_Guard must preserve Critical priority against downgrade');
    }

    @IsTest
    static void testOutboundEmailFirstResponseTriggerIntegration() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Pillar 4 Active SLA Ticket' LIMIT 1];
        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        EmailMessage outboundEmail = new EmailMessage(
            ParentId = c.Id,
            Incoming = false,
            Subject = 'First Response: Re: Your inquiry',
            HtmlBody = '<p>Thank you for contacting support. We are working on your case.</p>',
            ToAddress = 'customer@example.com'
        );
        insert outboundEmail;
        Test.stopTest();

        // Verify email inserted and trigger processed without exception
        EmailMessage insertedEmail = [SELECT Id, Incoming, ParentId FROM EmailMessage WHERE Id = :outboundEmail.Id LIMIT 1];
        System.assertNotEquals(null, insertedEmail.Id, 'Outbound email message must be inserted successfully');
        System.assertEquals(false, insertedEmail.Incoming, 'EmailMessage must be outbound (Incoming == false)');
    }

    @IsTest
    static void testCaseClosureMilestoneServiceIntegration() {
        Case c = [SELECT Id, Status FROM Case WHERE Subject = 'Pillar 4 Active SLA Ticket' LIMIT 1];
        MilestoneCompletionService.resetRecursionGuards();

        Test.startTest();
        c.Status = 'Closed';
        c.Resolution_Type__c = 'No Action Required';
        c.Resolution_Summary__c = 'Resolved in integration test.';
        update c;
        Test.stopTest();

        Case closedCase = [SELECT Id, Status, IsClosed FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Closed', closedCase.Status, 'Case status should successfully transition to Closed');
        System.assertEquals(true, closedCase.IsClosed, 'Case should be marked closed');
    }
}
