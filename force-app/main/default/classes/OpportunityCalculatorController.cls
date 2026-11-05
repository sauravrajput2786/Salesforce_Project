public with sharing class OpportunityCalculatorController {
    
    public class ProductOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        
        public ProductOption(String id, String name, Decimal unitPrice) {
            this.id = id;
            this.name = name;
            this.unitPrice = unitPrice;
        }
    }

    /**
     * @description Fetches active products and their standard unit prices.
     * Enforces user permissions, sharing rules, and field-level security using WITH USER_MODE.
     * @return List of ProductOption wrappers representing active products.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getActiveProducts() {
        List<ProductOption> options = new List<ProductOption>();
        
        List<PricebookEntry> entries = [
            SELECT Id, Product2.Id, Product2.Name, UnitPrice 
            FROM PricebookEntry 
            WHERE IsActive = true 
              AND Product2.IsActive = true 
            WITH USER_MODE 
            ORDER BY Product2.Name ASC 
            LIMIT 100
        ];
        
        for (PricebookEntry pbe : entries) {
            options.add(new ProductOption(
                pbe.Id,
                pbe.Product2.Name,
                pbe.UnitPrice != null ? pbe.UnitPrice : 0.00
            ));
        }
        
        return options;
    }
}