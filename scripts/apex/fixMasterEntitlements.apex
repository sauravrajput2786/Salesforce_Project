// Delete B2B-specific entitlement
delete [SELECT Id FROM Entitlement WHERE Name LIKE 'B2B%'];

// Get SLA Process IDs dynamically
Map<String, Id> slaProcessMap = new Map<String, Id>();
for (SlaProcess sp : [SELECT Id, Name FROM SlaProcess WHERE IsActive = true]) {
    slaProcessMap.put(sp.Name, sp.Id);
}

// Use existing valid Account in org to hold the Master Entitlements (Zero Account creation/validation issues)
Account masterAcc = [SELECT Id FROM Account WHERE BillingCountry != null LIMIT 1];

// 1. Ensure clean Master 'Gold'
List<Entitlement> goldCards = [SELECT Id, Name FROM Entitlement WHERE Name LIKE '%Gold%' LIMIT 1];
if (!goldCards.isEmpty()) {
    goldCards[0].Name = 'Gold';
    goldCards[0].AccountId = masterAcc.Id;
    goldCards[0].SlaProcessId = slaProcessMap.get('Gold_Tier_SLA_Process');
    update goldCards;
} else {
    insert new Entitlement(
        Name = 'Gold',
        AccountId = masterAcc.Id,
        SlaProcessId = slaProcessMap.get('Gold_Tier_SLA_Process'),
        StartDate = Date.today().addYears(-1),
        EndDate = Date.today().addYears(10)
    );
}

// 2. Ensure clean Master 'Silver'
List<Entitlement> silverCards = [SELECT Id, Name FROM Entitlement WHERE Name = 'Silver' LIMIT 1];
if (silverCards.isEmpty()) {
    insert new Entitlement(
        Name = 'Silver',
        AccountId = masterAcc.Id,
        SlaProcessId = slaProcessMap.get('Silver_Tier_SLA_Process'),
        StartDate = Date.today().addYears(-1),
        EndDate = Date.today().addYears(10)
    );
}

// 3. Ensure clean Master 'Platinum'
List<Entitlement> platCards = [SELECT Id, Name FROM Entitlement WHERE Name = 'Platinum' LIMIT 1];
if (platCards.isEmpty()) {
    insert new Entitlement(
        Name = 'Platinum',
        AccountId = masterAcc.Id,
        SlaProcessId = slaProcessMap.get('Platinum_Tier_SLA_Process'),
        StartDate = Date.today().addYears(-1),
        EndDate = Date.today().addYears(10)
    );
}

System.debug('Master Entitlements successfully verified and established: Gold, Silver, Platinum.');
