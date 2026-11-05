import { LightningElement, api, wire } from 'lwc';
import getCustomer360Data from '@salesforce/apex/Customer360Controller.getCustomer360Data';
import { refreshApex } from '@salesforce/apex';

export default class Customer360Widget extends LightningElement {
    @api recordId;

    customer360 = null;
    isLoading = true;
    errorMessage = null;
    wiredCustomer360Result;

    @wire(getCustomer360Data, { accountId: '$recordId' })
    wiredCustomer360(result) {
        this.wiredCustomer360Result = result;
        this.isLoading = false;
        if (result.data) {
            this.customer360 = result.data;
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = 'Unable to load Customer 360 data. Please refresh the page.';
            this.customer360 = null;
        }
    }

    // Manual / Event-driven real-time refresh (Method 1)
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredCustomer360Result)
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Account Info Getters
    get hasData() {
        return !!this.customer360;
    }

    get accountName() {
        return this.customer360?.accountInfo?.Name || '';
    }

    get accountIndustry() {
        return this.customer360?.accountInfo?.Industry || 'N/A';
    }

    get accountType() {
        return this.customer360?.accountInfo?.Type || 'N/A';
    }

    get accountPhone() {
        return this.customer360?.accountInfo?.Phone || null;
    }

    get accountWebsite() {
        return this.customer360?.accountInfo?.Website || null;
    }

    get accountLocation() {
        const city = this.customer360?.accountInfo?.BillingCity;
        const country = this.customer360?.accountInfo?.BillingCountry;
        if (city && country) return `${city}, ${country}`;
        return city || country || 'N/A';
    }

    // Revenue Getters
    get formattedRevenue() {
        const revenue = this.customer360?.closedWonRevenue || 0;
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(revenue);
    }

    get hasRevenue() {
        return (this.customer360?.closedWonRevenue || 0) > 0;
    }

    // Contacts Getters
    get contacts() {
        return this.customer360?.contacts || [];
    }

    get hasContacts() {
        return this.contacts.length > 0;
    }

    // Open Opportunities Getters
    get openOpportunities() {
        return this.customer360?.openOpportunities || [];
    }

    get hasOpenOpportunities() {
        return this.openOpportunities.length > 0;
    }

    get openOpportunitiesCount() {
        return this.openOpportunities.length;
    }

    // Purchased Products Getters
    get purchasedProducts() {
        return this.customer360?.purchasedProducts || [];
    }

    get hasPurchasedProducts() {
        return this.purchasedProducts.length > 0;
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount || 0);
    }
}
