import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import recalculateSingleDeal from '@salesforce/apex/DealHealthService.recalculateSingleDeal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import HEALTH_FIELD from '@salesforce/schema/Opportunity.Deal_Health_Score__c';
import RISK_REASON_FIELD from '@salesforce/schema/Opportunity.Deal_Risk_Reason__c';

const FIELDS = [HEALTH_FIELD, RISK_REASON_FIELD];

export default class DealHealthCard extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track overriddenScore = null;
    @track overriddenReason = null;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    oppRecord;

    get currentScore() {
        if (this.overriddenScore !== null) {
            return this.overriddenScore;
        }
        return getFieldValue(this.oppRecord.data, HEALTH_FIELD) || 100;
    }

    get riskReason() {
        if (this.overriddenReason !== null) {
            return this.overriddenReason;
        }
        return getFieldValue(this.oppRecord.data, RISK_REASON_FIELD) || '🟢 Healthy Deal — all pipeline velocity metrics on track.';
    }

    get reasonsList() {
        const text = this.riskReason;
        if (!text) return [];
        return text.split('\n').filter(line => line.trim().length > 0);
    }

    get riskBadgeLabel() {
        const score = this.currentScore;
        if (score >= 70) return '🟢 HEALTHY DEAL (LOW RISK)';
        if (score >= 40) return '🟡 MEDIUM RISK DEAL';
        return '🔴 CRITICAL RISK / AT-RISK';
    }

    get riskBadgeClass() {
        const score = this.currentScore;
        if (score >= 70) return 'slds-badge badge-healthy';
        if (score >= 40) return 'slds-badge badge-warning';
        return 'slds-badge badge-critical';
    }

    get healthCircleStyle() {
        const score = this.currentScore;
        let borderColor = '#04844b';
        if (score < 40) borderColor = '#ea001e';
        else if (score < 70) borderColor = '#fe9339';
        return `border: 3px solid ${borderColor};`;
    }

    handleRefresh() {
        if (!this.recordId) return;
        this.isLoading = true;
        recalculateSingleDeal({ oppId: this.recordId })
            .then(result => {
                this.overriddenScore = result.healthScore;
                this.overriddenReason = result.riskReason;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Deal Health Audited',
                    message: `Deal Health Score updated to ${result.healthScore}/100`,
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Audit Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}

