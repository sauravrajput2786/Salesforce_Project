import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getActiveProducts from '@salesforce/apex/QuickOpportunityController.getActiveProducts';
import getContactsByAccount from '@salesforce/apex/QuickOpportunityController.getContactsByAccount';
import createQuickOpportunity from '@salesforce/apex/QuickOpportunityController.createQuickOpportunity';

export default class QuickOpportunityCreator extends NavigationMixin(LightningElement) {
    @api recordId; // Auto-populated if placed on Account record page

    selectedAccountId = null;
    selectedContactId = null;
    selectedProductEntryId = null;
    quantity = 1;
    unitPrice = 0;
    calculatedAmount = 0;
    closeDate = null;
    isLoading = false;

    rawProducts = [];
    productOptions = [];
    contactOptions = [];

    connectedCallback() {
        // Set default Close Date to 30 days from today
        const defaultDate = new Date();
        defaultDate.setDate(defaultDate.getDate() + 30);
        this.closeDate = defaultDate.toISOString().split('T')[0];

        // If placed on an Account record page, pre-select the Account
        if (this.recordId && this.recordId.startsWith('001')) {
            this.selectedAccountId = this.recordId;
            this.loadContacts(this.selectedAccountId);
        }
    }

    // Fetch active products via wire
    @wire(getActiveProducts)
    wiredProducts({ data, error }) {
        if (data) {
            this.rawProducts = data;
            this.productOptions = data.map(prod => ({
                label: `${prod.name} ($${prod.unitPrice})`,
                value: prod.id
            }));
        } else if (error) {
            this.showToast('Error', 'Unable to load products.', 'error');
        }
    }

    // Load contacts when Account changes
    loadContacts(accountId) {
        if (!accountId) {
            this.contactOptions = [];
            this.selectedContactId = null;
            return;
        }

        getContactsByAccount({ accountId })
            .then(result => {
                this.contactOptions = result.map(c => ({
                    label: c.title ? `${c.name} (${c.title})` : c.name,
                    value: c.id
                }));
            })
            .catch(error => {
                this.contactOptions = [];
            });
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.recordId || event.target.value;
        this.selectedContactId = null;
        this.loadContacts(this.selectedAccountId);
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.value;
    }

    handleProductChange(event) {
        this.selectedProductEntryId = event.detail.value;
        const selectedProd = this.rawProducts.find(p => p.id === this.selectedProductEntryId);
        if (selectedProd) {
            this.unitPrice = selectedProd.unitPrice || 0;
            this.recalculateAmount();
        }
    }

    handleQuantityChange(event) {
        const val = parseFloat(event.target.value);
        this.quantity = isNaN(val) ? 1 : val;
        this.recalculateAmount();
    }

    handleAmountChange(event) {
        const val = parseFloat(event.target.value);
        this.calculatedAmount = isNaN(val) ? 0 : val;
        if (this.quantity > 0) {
            this.unitPrice = this.calculatedAmount / this.quantity;
        }
    }

    handleCloseDateChange(event) {
        this.closeDate = event.target.value;
    }

    recalculateAmount() {
        this.calculatedAmount = (this.quantity * this.unitPrice);
    }

    get isContactDisabled() {
        return !this.selectedAccountId || this.contactOptions.length === 0;
    }

    get contactPlaceholder() {
        if (!this.selectedAccountId) {
            return 'Select an Account first...';
        }
        return this.contactOptions.length > 0 ? 'Select a Contact...' : 'No contacts found for Account';
    }

    get formattedUnitPrice() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(this.unitPrice || 0);
    }

    validateInputs() {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker')
        ].reduce((validSoFar, inputCmp) => {
            if (inputCmp.reportValidity) {
                return validSoFar && inputCmp.reportValidity();
            }
            return validSoFar && (inputCmp.value != null && inputCmp.value !== '');
        }, true);

        if (!this.selectedAccountId) {
            this.showToast('Validation Error', 'Please select an Account.', 'warning');
            return false;
        }
        if (!this.selectedProductEntryId) {
            this.showToast('Validation Error', 'Please select a Product.', 'warning');
            return false;
        }
        if (!this.quantity || this.quantity <= 0) {
            this.showToast('Validation Error', 'Quantity must be at least 1.', 'warning');
            return false;
        }
        if (!this.closeDate) {
            this.showToast('Validation Error', 'Please select a Close Date.', 'warning');
            return false;
        }

        return allValid;
    }

    handleCreateOpportunity() {
        if (!this.validateInputs()) {
            return;
        }

        this.isLoading = true;

        const requestPayload = {
            accountId: this.selectedAccountId,
            contactId: this.selectedContactId,
            productEntryId: this.selectedProductEntryId,
            quantity: this.quantity,
            unitPrice: this.unitPrice,
            closeDate: this.closeDate,
            stageName: 'Prospecting'
        };

        createQuickOpportunity({ request: requestPayload })
            .then(createdOppId => {
                this.isLoading = false;
                this.showToast('Success', 'Opportunity created successfully!', 'success');

                // Navigate to the newly created Opportunity record
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: createdOppId,
                        objectApiName: 'Opportunity',
                        actionName: 'view'
                    }
                });

                this.resetForm();
            })
            .catch(error => {
                this.isLoading = false;
                const errorMsg = error?.body?.message || error?.message || 'An unexpected error occurred.';
                this.showToast('Error Creating Opportunity', errorMsg, 'error');
            });
    }

    resetForm() {
        if (!this.recordId) {
            this.selectedAccountId = null;
        }
        this.selectedContactId = null;
        this.selectedProductEntryId = null;
        this.quantity = 1;
        this.unitPrice = 0;
        this.calculatedAmount = 0;

        const defaultDate = new Date();
        defaultDate.setDate(defaultDate.getDate() + 30);
        this.closeDate = defaultDate.toISOString().split('T')[0];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}

