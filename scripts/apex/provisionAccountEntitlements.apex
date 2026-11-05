Id b2bId = [SELECT Id FROM Account WHERE Name = 'B2B' LIMIT 1].Id;
Id platSlaId = [SELECT Id FROM SlaProcess WHERE Name = 'Platinum_Tier_SLA_Process' AND IsActive = true LIMIT 1].Id;

update new Account(
    Id = b2bId,
    Customer__c = 'Platinum',
    Annual_Contract_Value__c = 2000
);

List<Entitlement> existing = [SELECT Id FROM Entitlement WHERE AccountId = :b2bId AND Status = 'Active'];
if (existing.isEmpty()) {
    insert new Entitlement(
        Name = 'B2B Platinum Enterprise SLA',
        AccountId = b2bId,
        SlaProcessId = platSlaId,
        StartDate = Date.today(),
        EndDate = Date.today().addDays(365)
    );
    System.debug('Created B2B Platinum Enterprise SLA successfully.');
} else {
    System.debug('B2B Entitlement already exists.');
}
