public with sharing class Customer360Wrapper {
    @AuraEnabled public Account accountInfo { get; set; }
    @AuraEnabled public Decimal closedWonRevenue { get; set; }
    @AuraEnabled public List<Contact> contacts { get; set; }
    @AuraEnabled public List<Opportunity> openOpportunities { get; set; }
    @AuraEnabled public List<String> purchasedProducts { get; set; }

    public Customer360Wrapper() {
        this.closedWonRevenue = 0;
        this.contacts = new List<Contact>();
        this.openOpportunities = new List<Opportunity>();
        this.purchasedProducts = new List<String>();
    }
}