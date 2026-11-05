/**
 * @description Test class for Case priority guard ensuring Critical priority is preserved
 * against automated downgrades to High, while allowing standard priority adjustments.
 */
@IsTest
private class CasePriorityGuardTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'SLA Guard Test Account',
            BillingCountry = 'United States',
            Industry = 'Technology',
            Phone = '5551234567'
        );
        insert testAccount;

        Case criticalCase = new Case(
            AccountId = testAccount.Id,
            Subject = 'Critical Severity System Outage',
            Status = 'New',
            Priority = 'Critical',
            Origin = 'Web'
        );
        insert criticalCase;

        Case standardCase = new Case(
            AccountId = testAccount.Id,
            Subject = 'Standard Inquiry Ticket',
            Status = 'New',
            Priority = 'Low',
            Origin = 'Web'
        );
        insert standardCase;
    }

    @IsTest
    static void testCriticalPriorityImmuneToDowngrade() {
        Case c = [SELECT Id, Priority FROM Case WHERE Subject = 'Critical Severity System Outage' LIMIT 1];
        System.assertEquals('Critical', c.Priority, 'Case should initially be Critical');

        Test.startTest();
        // Simulate automated SLA violation or field update attempting to set Priority to High
        c.Priority = 'High';
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Priority FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Critical', updatedCase.Priority, 'Critical priority must be preserved and immune to downgrade');
    }

    @IsTest
    static void testNormalPriorityUpdateAllowed() {
        Case c = [SELECT Id, Priority FROM Case WHERE Subject = 'Standard Inquiry Ticket' LIMIT 1];
        System.assertEquals('Low', c.Priority, 'Case should initially be Low');

        Test.startTest();
        c.Priority = 'Medium';
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Priority FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('Medium', updatedCase.Priority, 'Standard priority progression from Low to Medium must be permitted');
    }
}
