import { LightningElement, api, track } from 'lwc';
import generateSummary from '@salesforce/apex/RecordAISummaryService.generateSummary';

export default class RecordAISummaryCard extends LightningElement {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadSummary();
        }
    }

    @track isLoading = false;
    @track recordName = '';
    @track recordType = '';
    @track rawSummary = '';
    @track riskLevel = '';
    @track nextAction = '';

    connectedCallback() {
        if (this._recordId) {
            this.loadSummary();
        }
    }

    loadSummary = () => {
        if (!this.recordId) return;
        this.isLoading = true;
        generateSummary({ recordId: this.recordId })
            .then(result => {
                if (result && result.isSuccess) {
                    this.recordName = result.recordName;
                    this.recordType = result.recordType;
                    this.rawSummary = result.aiSummary;
                    this.riskLevel = result.riskLevel || '';
                    this.nextAction = result.nextAction || '';
                } else {
                    this.rawSummary = (result && result.aiSummary) ? result.aiSummary : 'Unable to generate summary.';
                    this.riskLevel = '';
                }
            })
            .catch(error => {
                this.rawSummary = error.body ? error.body.message : error.message;
                this.riskLevel = '';
            })
            .finally(() => {
                this.isLoading = false;
            });
    };

    get formattedSummary() {
        if (!this.rawSummary) return '';
        // Convert simple markdown bold and newlines to HTML for rich text display
        return this.rawSummary
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\n/g, '<br/>');
    }

    get hasRiskBadge() {
        return Boolean(this.riskLevel && this.rawSummary && !this.isLoading);
    }

    get riskBadgeLabel() {
        const level = (this.riskLevel || '').toUpperCase();
        if (level === 'HIGH') return '🔴 HIGH RISK';
        if (level === 'MEDIUM') return '🟡 MODERATE RISK';
        if (level === 'LOW') return '🟢 LOW RISK';
        return '';
    }

    get riskBadgeClass() {
        const level = (this.riskLevel || '').toUpperCase();
        if (level === 'HIGH') return 'slds-badge badge-high';
        if (level === 'MEDIUM') return 'slds-badge badge-medium';
        return 'slds-badge badge-low';
    }
}

