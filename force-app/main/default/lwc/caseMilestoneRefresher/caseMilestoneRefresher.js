import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';

export default class CaseMilestoneRefresher extends LightningElement {
    _recordId;
    isSubscribed = false;
    subscription = {};
    channelName = '/event/Milestone_Refresh_Event__e';

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this.isSubscribed) {
            this.handleSubscribe();
        }
    }

    connectedCallback() {
        this.registerErrorListener();
        if (this._recordId && !this.isSubscribed) {
            this.handleSubscribe();
        }
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        if (!this._recordId) {
            return;
        }

        const messageCallback = (response) => {
            const eventPayload = response?.data?.payload;
            const eventCaseId = eventPayload?.Case_Id__c;
            const currentCaseId = this._recordId;

            // Safe 15-char and 18-char Case Id comparison
            const isMatch = Boolean(
                eventCaseId &&
                currentCaseId &&
                (eventCaseId === currentCaseId ||
                 (eventCaseId.length >= 15 && currentCaseId.length >= 15 &&
                  eventCaseId.substring(0, 15) === currentCaseId.substring(0, 15)))
            );

            if (isMatch) {
                console.log(`[MilestoneRefresher] Event matched for Case: ${currentCaseId}. Triggering LDS record cache refresh...`);

                // Invalidate Lightning Data Service cache for the Case.
                // Because the Case record was updated in the DB, LDS detects the record update
                // and automatically spins and refreshes only the support:milestones widget in place!
                notifyRecordUpdateAvailable([{ recordId: currentCaseId }])
                    .then(() => {
                        console.log(`[MilestoneRefresher] LDS invalidated Case ${currentCaseId} successfully.`);
                    })
                    .catch((err) => {
                        console.error('[MilestoneRefresher] LDS invalidation error:', err);
                    });

                // Standard modern refresh event
                try {
                    this.dispatchEvent(new RefreshEvent());
                } catch (e) {
                    // Handled cleanly
                }
            }
        };

        subscribe(this.channelName, -1, messageCallback)
            .then((response) => {
                this.subscription = response;
                this.isSubscribed = true;
                console.log(`[MilestoneRefresher] Subscribed to ${this.channelName} for Case: ${this._recordId}`);
            })
            .catch((err) => {
                console.error('[MilestoneRefresher] Subscription failed:', err);
            });
    }

    handleUnsubscribe() {
        if (this.subscription && this.subscription.id) {
            unsubscribe(this.subscription, () => {
                this.isSubscribed = false;
            });
        }
    }

    registerErrorListener() {
        onError((error) => {
            console.error('[MilestoneRefresher] EMP API Error:', error);
        });
    }
}
