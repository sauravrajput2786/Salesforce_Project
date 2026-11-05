import { LightningElement, api, track } from 'lwc';
import generateSingleDraft from '@salesforce/apex/AIEmailDraftService.generateSingleDraft';
import sendDraftEmail from '@salesforce/apex/AIEmailDraftService.sendDraftEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class AiEmailDraftModal extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track selectedType = 'Follow-up';
    @track recipientEmail = '';
    @track subject = '';
    @track body = '';

    get draftTypeOptions() {
        return [
            { label: 'Follow-up Touchpoint', value: 'Follow-up' },
            { label: 'Commercial Proposal', value: 'Proposal' },
            { label: 'Discovery & Next Steps', value: 'Discovery' }
        ];
    }

    connectedCallback() {
        this.loadDraft();
    }

    loadDraft() {
        if (!this.recordId) return;
        this.isLoading = true;
        generateSingleDraft({ recordId: this.recordId, draftType: this.selectedType })
            .then(result => {
                if (result.status === 'Success') {
                    this.subject = result.subject || '';
                    this.body = result.body || '';
                    if (result.recipientEmail) {
                        this.recipientEmail = result.recipientEmail;
                    }
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Draft Warning',
                        message: result.status,
                        variant: 'warning'
                    }));
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Generation Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleTypeChange(event) {
        this.selectedType = event.detail.value;
        this.loadDraft();
    }

    handleEmailChange(event) {
        this.recipientEmail = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
    }

    handleBodyChange(event) {
        this.body = event.detail.value;
    }

    handleCopy() {
        const fullContent = `Subject: ${this.subject}\n\n${this.body}`;
        navigator.clipboard.writeText(fullContent)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied',
                    message: 'Draft copied to clipboard!',
                    variant: 'success'
                }));
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copy Failed',
                    message: 'Please manually select and copy text.',
                    variant: 'warning'
                }));
            });
    }

    handleSend() {
        if (!this.recipientEmail || !this.subject || !this.body) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Recipient Email, Subject, and Body are all required.',
                variant: 'error'
            }));
            return;
        }

        this.isLoading = true;
        sendDraftEmail({
            recordId: this.recordId,
            recipientEmail: this.recipientEmail,
            subject: this.subject,
            body: this.body
        })
            .then(result => {
                if (result === 'Success') {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Email Sent',
                        message: `Email successfully dispatched to ${this.recipientEmail} and logged to timeline.`,
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Send Failed',
                        message: result,
                        variant: 'error'
                    }));
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Send Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}

