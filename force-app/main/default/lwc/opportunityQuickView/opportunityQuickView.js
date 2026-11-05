import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import NAME_FIELD from '@salesforce/schema/Opportunity.Name';
import AMOUNT_FIELD from '@salesforce/schema/Opportunity.Amount';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import CLOSE_DATE_FIELD from '@salesforce/schema/Opportunity.CloseDate';

const FIELDS = [NAME_FIELD, AMOUNT_FIELD, STAGE_FIELD, CLOSE_DATE_FIELD];

export default class OpportunityQuickView extends LightningElement {
    // @api decorator receives the recordId from the parent Record Page
    @api recordId;

    // @wire service fetches Opportunity record reactively without Apex
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunity;

    // Getter properties
    get oppName() {
        return getFieldValue(this.opportunity.data, NAME_FIELD) || '';
    }

    get oppAmount() {
        const rawAmount = getFieldValue(this.opportunity.data, AMOUNT_FIELD);
        if (rawAmount !== undefined && rawAmount !== null) {
            return new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD'
            }).format(rawAmount);
        }
        return '$0.00';
    }

    get rawAmountValue() {
        return getFieldValue(this.opportunity.data, AMOUNT_FIELD) || 0;
    }

    get oppStage() {
        return getFieldValue(this.opportunity.data, STAGE_FIELD) || 'N/A';
    }

    get oppCloseDate() {
        return getFieldValue(this.opportunity.data, CLOSE_DATE_FIELD) || 'N/A';
    }

    get isHotDeal() {
        return this.rawAmountValue >= 50000;
    }

    get dealBadgeLabel() {
        return this.isHotDeal ? '🔥 Hot Deal (High Value)' : '🟢 Standard Deal';
    }

    get dealBadgeClass() {
        return this.isHotDeal ? 'badge-banner hot' : 'badge-banner standard';
    }

    get cardTitle() {
        return `Quick Health: ${this.oppName || 'Opportunity'}`;
    }

    get hasData() {
        return !!(this.opportunity && this.opportunity.data);
    }

    get isLoading() {
        return !this.opportunity.data && !this.opportunity.error;
    }

    // Event handling (Demonstrating LWC Events)
    handleNotifyReview() {
        // 1. Dispatch custom DOM event
        const reviewEvent = new CustomEvent('dealhealthreviewed', {
            detail: {
                recordId: this.recordId,
                isHotDeal: this.isHotDeal,
                stage: this.oppStage
            }, 
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(reviewEvent);

        // 2. Dispatch Salesforce Lightning Toast event to show immediate visual feedback
        const toastEvent = new ShowToastEvent({
            title: 'Health Status Logged',
            message: `Quick review recorded for ${this.oppName}. Status: ${this.dealBadgeLabel}`,
            variant: 'success'
        });
        this.dispatchEvent(toastEvent);
    }
}
