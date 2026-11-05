/**
 * @description Enterprise Batch Apex to aggregate open case metrics and last case activity
 * onto parent Account records. Designed for high-volume enterprise scalability (100K+ records)
 * avoiding governor limits through standard chunked execution and partial-success tolerance.
 * 
 * Implements: Database.Batchable<sObject>, Database.Stateful
 */
public with sharing class AccountCaseMetricsBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    @TestVisible
    private Integer totalAccountsProcessed = 0;
    @TestVisible
    private Integer totalAccountsUpdated = 0;
    @TestVisible
    private Integer totalErrors = 0;

    /**
     * @description Collects all Accounts that have related Cases or existing open case counts.
     * Uses QueryLocator for optimal scalability up to 50M records.
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Open_Case_Count__c, Last_Case_Date__c
            FROM Account
        ]);
    }

    /**
     * @description Processes a 200-record batch chunk of Accounts, aggregating
     * open case counts and latest case creation dates with partial success enabled.
     * @param bc BatchableContext
     * @param scope List of Account records in current batch chunk
     */
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Map<Id, Account>(scope).keySet();

        // Aggregate open cases count per Account
        Map<Id, Integer> openCountMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) openTotal
            FROM Case
            WHERE AccountId IN :accountIds AND IsClosed = false
            GROUP BY AccountId
        ]) {
            Id accId = (Id) ar.get('AccountId');
            Integer count = (Integer) ar.get('openTotal');
            openCountMap.put(accId, count);
        }

        // Aggregate latest case date per Account
        Map<Id, Date> latestDateMap = new Map<Id, Date>();
        for (AggregateResult ar : [
            SELECT AccountId, MAX(CreatedDate) maxDate
            FROM Case
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            Id accId = (Id) ar.get('AccountId');
            DateTime dt = (DateTime) ar.get('maxDate');
            if (dt != null) {
                latestDateMap.put(accId, dt.date());
            }
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : scope) {
            Integer calculatedOpen = openCountMap.containsKey(acc.Id) ? openCountMap.get(acc.Id) : 0;
            Date calculatedLatestDate = latestDateMap.containsKey(acc.Id) ? latestDateMap.get(acc.Id) : null;

            Boolean needsUpdate = false;
            if (acc.Open_Case_Count__c != calculatedOpen) {
                acc.Open_Case_Count__c = calculatedOpen;
                needsUpdate = true;
            }
            if (acc.Last_Case_Date__c != calculatedLatestDate) {
                acc.Last_Case_Date__c = calculatedLatestDate;
                needsUpdate = true;
            }

            if (needsUpdate) {
                accountsToUpdate.add(acc);
            }
            totalAccountsProcessed++;
        }

        if (!accountsToUpdate.isEmpty()) {
            // Enterprise standard: allOrNone = false prevents single dirty record from blocking whole batch
            Database.SaveResult[] results = Database.update(accountsToUpdate, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    totalAccountsUpdated++;
                } else {
                    totalErrors++;
                }
            }
        }
    }

    /**
     * @description Final completion log for audit and enterprise monitoring.
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('AccountCaseMetricsBatch COMPLETED. Processed: ' + totalAccountsProcessed + ', Updated: ' + totalAccountsUpdated + ', Errors: ' + totalErrors);
    }
}
