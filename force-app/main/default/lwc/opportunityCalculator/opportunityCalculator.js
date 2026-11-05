import { LightningElement, api, wire, track } from 'lwc';
import getActiveProducts from '@salesforce/apex/OpportunityCalculatorController.getActiveProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OpportunityCalculator extends LightningElement {
    @api recordId;

    selectedProductId = '';
    selectedProductName = '';
    quantity = 1;
    unitPrice = 0;
    discountPercent = 0;

    @track productOptions = [];
    productList = [];
    isLoading = true;

    // Fetch active products dynamically respecting user permissions and FLS
    @wire(getActiveProducts)
    wiredProducts({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.productList = data;
            this.productOptions = data.map(item => ({
                label: `${item.name} ($${item.unitPrice})`,
                value: item.id
            }));

            // Pre-select the first active product if available
            if (data.length > 0 && !this.selectedProductId) {
                this.applyProductSelection(data[0].id);
            }
        } else if (error) {
            this.productOptions = [];
            this.showToast('Error', 'Could not load active products from org.', 'error');
        }
    }

    applyProductSelection(productId) {
        this.selectedProductId = productId;
        const matched = this.productList.find(p => p.id === productId);
        if (matched) {
            this.selectedProductName = matched.name;
            this.unitPrice = Number(matched.unitPrice) || 0;
        }
    }

    // Input change handlers
    handleProductChange(event) {
        this.applyProductSelection(event.detail.value);
    }

    handleQuantityChange(event) {
        const val = Number(event.detail.value);
        this.quantity = isNaN(val) || val < 1 ? 1 : val;
    }

    handleUnitPriceChange(event) {
        const val = Number(event.detail.value);
        this.unitPrice = isNaN(val) || val < 0 ? 0 : val;
    }

    handleDiscountChange(event) {
        const val = Number(event.detail.value);
        if (isNaN(val) || val < 0) {
            this.discountPercent = 0;
        } else if (val > 100) {
            this.discountPercent = 100;
        } else {
            this.discountPercent = val;
        }
    }

    // Reset back to initial catalog defaults
    handleReset() {
        this.quantity = 1;
        this.discountPercent = 0;
        if (this.selectedProductId) {
            this.applyProductSelection(this.selectedProductId);
        }
        this.showToast('Reset Complete', 'Calculator reset to default values.', 'info');
    }

    // Mathematical Getters (Real-time reactivity)
    get subtotal() {
        return (this.quantity || 0) * (this.unitPrice || 0);
    }

    get discountAmount() {
        return this.subtotal * ((this.discountPercent || 0) / 100);
    }

    get total() {
        return Math.max(0, this.subtotal - this.discountAmount);
    }

    // Formatted Currency Getters
    get formattedSubtotal() {
        return this.formatCurrency(this.subtotal);
    }

    get formattedDiscountAmount() {
        return this.formatCurrency(this.discountAmount);
    }

    get formattedTotal() {
        return this.formatCurrency(this.total);
    }

    get hasProducts() {
        return this.productOptions.length > 0;
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount || 0);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
