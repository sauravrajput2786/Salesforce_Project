List<Customer_Product__c> cpList = [SELECT Id, Product__r.Name, Product_Name_Text__c FROM Customer_Product__c];
for (Customer_Product__c cp : cpList) {
    if (cp.Product__r != null && String.isNotBlank(cp.Product__r.Name)) {
        cp.Product_Name_Text__c = cp.Product__r.Name;
    }
}
update cpList;
System.debug('Updated ' + cpList.size() + ' Customer Products with Product_Name_Text__c.');
