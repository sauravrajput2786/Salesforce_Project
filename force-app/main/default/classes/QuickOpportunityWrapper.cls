public with sharing class QuickOpportunityWrapper {

    public class CreateRequest {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public Id productEntryId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Date closeDate { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
    }

    public class ProductOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }

        public ProductOption(String id, String productId, String name, Decimal unitPrice) {
            this.id = id;
            this.productId = productId;
            this.name = name;
            this.unitPrice = unitPrice;
        }
    }

    public class ContactOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String email { get; set; }

        public ContactOption(String id, String name, String title, String email) {
            this.id = id;
            this.name = name;
            this.title = title;
            this.email = email;
        }
    }
}

