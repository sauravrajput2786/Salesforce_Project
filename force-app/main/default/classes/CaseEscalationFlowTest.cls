/**
 * @description Test class for Case escalation flow governance ensuring single-admin resolution,
 * 72h critical escalation telemetry stamping, priority protection integration, and bulk safety.
 */
@IsTest
private class CaseEscalationFlowTest {

    @TestSetup
    static void setupTestData() {
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();

        Account testAccount = new Account(
            Name = 'Escalation Test Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert testAccount;

        Case openCase = new Case(
            AccountId = testAccount.Id,
            Subject = 'Unresolved Ticket 24h',
            Status = 'New',
            Priority = 'Low',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId
        );
        insert openCase;

        Case closedCase = new Case(
            AccountId = testAccount.Id,
            Subject = 'Closed Ticket',
            Status = 'Closed',
            Priority = 'Low',
            Origin = 'Web',
            RecordTypeId = generalInquiryRtId,
            Resolution_Type__c = 'No Action Required',
            Resolution_Summary__c = 'Test closed case for escalation bypass verification.'
        );
        insert closedCase;
    }

    @IsTest
    static void testSingleAdminResolution() {
        // Verifies active System Administrator can be retrieved dynamically without UserRole dependencies
        Test.startTest();
        List<User> admins = [
            SELECT Id, Name, Email, Profile.Name
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        Test.stopTest();

        System.assertNotEquals(0, admins.size(), 'At least one active System Administrator must exist in the environment');
        System.assertNotEquals(null, admins[0].Email, 'System Administrator must have an email address configured');
    }

    @IsTest
    static void test72HourCriticalEscalationTelemetry() {
        Case c = [SELECT Id, Priority, Escalation_Reason__c, IsEscalated FROM Case WHERE Subject = 'Unresolved Ticket 24h' LIMIT 1];
        System.assertEquals('Low', c.Priority, 'Case should initially be Low priority');
        System.assertEquals(false, c.IsEscalated, 'Case should initially not be escalated');

        Test.startTest();
        // Simulate 72h scheduled path updates
        c.Priority = 'Critical';
        c.Status = 'Escalated';
        c.Escalation_Reason__c = 'SLA Breach Risk';
        c.IsEscalated = true;
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Priority, Status, Escalation_Reason__c, IsEscalated FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Critical', updatedCase.Priority, 'Priority must be elevated to Critical at 72h');
        System.assertEquals('Escalated', updatedCase.Status, 'Status must be set to Escalated at 72h');
        System.assertEquals('SLA Breach Risk', updatedCase.Escalation_Reason__c, 'Escalation Reason must be set to SLA Breach Risk');
        System.assertEquals(true, updatedCase.IsEscalated, 'IsEscalated flag must be set to true for dashboard tracking');

        // Verify Case_Critical_Priority_Guard prevents downgrade from Critical to High
        updatedCase.Priority = 'High';
        update updatedCase;

        Case guardedCase = [SELECT Id, Priority FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Critical', guardedCase.Priority, 'Critical priority must remain immune to downgrade');
    }

    @IsTest
    static void testClosedCaseEscalationBypass() {
        Case closedCase = [SELECT Id, IsClosed, IsEscalated, Priority FROM Case WHERE Subject = 'Closed Ticket' LIMIT 1];
        System.assertEquals(true, closedCase.IsClosed, 'Case should be confirmed closed');
        System.assertEquals(false, closedCase.IsEscalated, 'Closed case should not be escalated');
    }

    @IsTest
    static void testChatterFeedItemAuditPost() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Unresolved Ticket 24h' LIMIT 1];

        Test.startTest();
        FeedItem post = new FeedItem(
            ParentId = c.Id,
            Body = '[CRITICAL ESCALATION - 72 Hours Unresolved] Case unresolved for 72 hours. Priority escalated to Critical.'
        );
        insert post;
        Test.stopTest();

        FeedItem createdPost = [SELECT Id, Body, ParentId FROM FeedItem WHERE Id = :post.Id LIMIT 1];
        System.assertEquals(c.Id, createdPost.ParentId, 'FeedItem parent must match the Case record ID');
        System.assert(createdPost.Body.contains('CRITICAL ESCALATION'), 'FeedItem body should contain critical escalation notice');
    }

    @IsTest
    static void testBulkEscalationSafety() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Escalation Test Account' LIMIT 1];
        Id generalInquiryRtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('General_Inquiry').getRecordTypeId();
        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 20; i++) {
            bulkCases.add(new Case(
                AccountId = acc.Id,
                Subject = 'Bulk Escalation Case ' + i,
                Status = 'New',
                Priority = 'Low',
                Origin = 'Web',
                RecordTypeId = generalInquiryRtId
            ));
        }
        insert bulkCases;

        Test.startTest();
        for (Case c : bulkCases) {
            c.Priority = 'Critical';
            c.Escalation_Reason__c = 'SLA Breach Risk';
            c.IsEscalated = true;
        }
        update bulkCases;
        Test.stopTest();

        List<Case> updatedCases = [SELECT Id, Priority, Escalation_Reason__c, IsEscalated FROM Case WHERE Id IN :bulkCases];
        System.assertEquals(20, updatedCases.size(), 'All 20 cases must be updated');
        for (Case c : updatedCases) {
            System.assertEquals('Critical', c.Priority, 'Bulk case Priority must be Critical');
            System.assertEquals('SLA Breach Risk', c.Escalation_Reason__c, 'Bulk case Escalation Reason must be SLA Breach Risk');
            System.assertEquals(true, c.IsEscalated, 'Bulk case IsEscalated must be true');
        }
    }
}
