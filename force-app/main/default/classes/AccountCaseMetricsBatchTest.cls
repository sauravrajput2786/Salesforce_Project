/**
 * @description Test class for AccountCaseMetricsBatch verifying bulk execution,
 * open case counting, closed case exclusion, and latest date synchronization.
 */
@IsTest
private class AccountCaseMetricsBatchTest {

    @TestSetup
    static void setupTestData() {
        // Create test Accounts with required enterprise fields
        List<Account> testAccounts = new List<Account>{
            new Account(
                Name = 'Batch Test Account Alpha',
                BillingCountry = 'United States',
                Industry = 'Technology',
                Phone = '1112223333'
            ),
            new Account(
                Name = 'Batch Test Account Beta',
                BillingCountry = 'United States',
                Industry = 'Banking',
                Phone = '4445556666'
            )
        };
        insert testAccounts;

        // Account Alpha gets 2 open cases and 1 closed case
        List<Case> cases = new List<Case>{
            new Case(
                AccountId = testAccounts[0].Id,
                Subject = 'Alpha Case 1 (Open)',
                Status = 'New',
                Priority = 'High',
                Origin = 'Web'
            ),
            new Case(
                AccountId = testAccounts[0].Id,
                Subject = 'Alpha Case 2 (Open)',
                Status = 'Working',
                Priority = 'Medium',
                Origin = 'Email'
            ),
            new Case(
                AccountId = testAccounts[0].Id,
                Subject = 'Alpha Case 3 (Closed)',
                Status = 'Closed',
                Priority = 'Low',
                Origin = 'Phone'
            ),
            // Account Beta gets 1 open case
            new Case(
                AccountId = testAccounts[1].Id,
                Subject = 'Beta Case 1 (Open)',
                Status = 'New',
                Priority = 'Critical',
                Origin = 'Web'
            )
        };
        insert cases;
    }

    @IsTest
    static void testBatchExecutionAggregatesMetrics() {
        Test.startTest();
        AccountCaseMetricsBatch batchJob = new AccountCaseMetricsBatch();
        Id batchProcessId = Database.executeBatch(batchJob, 200);
        Test.stopTest();

        System.assertNotEquals(null, batchProcessId, 'Batch job should be enqueued successfully.');

        Account alphaAcc = [
            SELECT Id, Open_Case_Count__c, Last_Case_Date__c
            FROM Account
            WHERE Name = 'Batch Test Account Alpha'
            LIMIT 1
        ];
        System.assertEquals(2, alphaAcc.Open_Case_Count__c, 'Account Alpha should have exactly 2 open cases.');
        System.assertEquals(Date.today(), alphaAcc.Last_Case_Date__c, 'Account Alpha latest case date should be today.');

        Account betaAcc = [
            SELECT Id, Open_Case_Count__c, Last_Case_Date__c
            FROM Account
            WHERE Name = 'Batch Test Account Beta'
            LIMIT 1
        ];
        System.assertEquals(1, betaAcc.Open_Case_Count__c, 'Account Beta should have exactly 1 open case.');
        System.assertEquals(Date.today(), betaAcc.Last_Case_Date__c, 'Account Beta latest case date should be today.');
    }
}
