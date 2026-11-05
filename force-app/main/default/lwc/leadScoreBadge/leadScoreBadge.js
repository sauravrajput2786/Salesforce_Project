import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import recalculateSingleLead from '@salesforce/apex/LeadScoringService.recalculateSingleLead';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import AI_SCORE_FIELD from '@salesforce/schema/Lead.AI_Lead_Score__c';
import REASON_FIELD from '@salesforce/schema/Lead.Score_Reason__c';
import NBA_FIELD from '@salesforce/schema/Lead.Next_Best_Action__c';

const FIELDS = [AI_SCORE_FIELD, REASON_FIELD, NBA_FIELD];

export default class LeadScoreBadge extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track overriddenScore = null;
    @track overriddenReason = null;
    @track overriddenNba = null;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    leadRecord;

    get currentScore() {
        if (this.overriddenScore !== null) {
            return this.overriddenScore;
        }
        return getFieldValue(this.leadRecord.data, AI_SCORE_FIELD) || 0;
    }

    get scoreReason() {
        if (this.overriddenReason !== null) {
            return this.overriddenReason;
        }
        return getFieldValue(this.leadRecord.data, REASON_FIELD) || 'No score breakdown available.';
    }

    get nextBestAction() {
        if (this.overriddenNba !== null) {
            return this.overriddenNba;
        }
        return getFieldValue(this.leadRecord.data, NBA_FIELD) || 'Log initial outreach to assess customer intent.';
    }

    get reasonsList() {
        const text = this.scoreReason;
        if (!text) return [];
        return text.split('\n').filter(line => line.trim().length > 0);
    }

    get badgeLabel() {
        const score = this.currentScore;
        if (score >= 70) return '🔥 HOT LEAD';
        if (score >= 40) return '☀️ WARM LEAD';
        return '❄️ COLD LEAD';
    }

    get badgeClass() {
        const score = this.currentScore;
        if (score >= 70) return 'slds-badge badge-hot';
        if (score >= 40) return 'slds-badge badge-warm';
        return 'slds-badge badge-cold';
    }

    get scoreCircleStyle() {
        const score = this.currentScore;
        let borderColor = '#04844b';
        if (score < 40) borderColor = '#706e6b';
        else if (score < 70) borderColor = '#fe9339';
        return `border: 3px solid ${borderColor};`;
    }

    handleRefresh() {
        if (!this.recordId) return;
        this.isLoading = true;
        recalculateSingleLead({ leadId: this.recordId })
            .then(result => {
                this.overriddenScore = result.score;
                this.overriddenReason = result.scoreReason;
                this.overriddenNba = result.nextBestAction;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Score Updated',
                    message: `AI Lead Score recalculated to ${result.score}/100`,
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Recalculation Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}

