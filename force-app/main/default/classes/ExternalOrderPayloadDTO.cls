/**
 * @description Data Transfer Object (DTO) for sending Closed Won Opportunity
 * and related Customer, Contact, and Product details to an external REST API / ERP.
 */
public with sharing class ExternalOrderPayloadDTO {

    public String opportunityId;
    public String opportunityName;
    public Decimal amount;
    public Date closeDate;
    public String stage;

    public CustomerDTO customer;
    public ContactDTO contact;
    public List<ProductDTO> products;

    public class CustomerDTO {
        public String accountId;
        public String accountName;
        public String accountNumber;
        public String billingCity;
        public String billingCountry;
    }

    public class ContactDTO {
        public String contactId;
        public String fullName;
        public String email;
        public String phone;
    }

    public class ProductDTO {
        public String productId;
        public String productName;
        public String productCode;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal totalPrice;
    }
}

