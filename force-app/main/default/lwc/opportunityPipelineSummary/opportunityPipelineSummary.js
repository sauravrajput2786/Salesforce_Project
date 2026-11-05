import { LightningElement, wire } from 'lwc';
import getPipelineSummary from '@salesforce/apex/OpportunityPipelineController.getPipelineSummary';
import { refreshApex } from '@salesforce/apex';

export default class OpportunityPipelineSummary extends LightningElement {
    pipelineData = null;
    isLoading = true;
    errorMessage = null;
    wiredPipelineResult;

    @wire(getPipelineSummary)
    wiredPipeline(result) {
        this.wiredPipelineResult = result;
        this.isLoading = false;

        if (result.data) {
            this.pipelineData = result.data;
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = result.error?.body?.message || 'Unable to load pipeline summary.';
            this.pipelineData = null;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredPipelineResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return !this.isLoading && this.pipelineData && this.pipelineData.stages && this.pipelineData.stages.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && (!this.pipelineData || !this.pipelineData.stages || this.pipelineData.stages.length === 0);
    }

    get totalDeals() {
        return this.pipelineData?.totalDeals || 0;
    }

    get formattedGrandTotal() {
        const total = this.pipelineData?.grandTotalAmount || 0;
        return this.formatCurrency(total);
    }

    get stages() {
        if (!this.pipelineData || !this.pipelineData.stages) {
            return [];
        }

        return this.pipelineData.stages.map(stage => ({
            ...stage,
            formattedAmount: this.formatCurrency(stage.totalAmount),
            progressStyle: `width: ${Math.min(stage.percentageOfTotal, 100)}%;`
        }));
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(amount || 0);
    }
}

