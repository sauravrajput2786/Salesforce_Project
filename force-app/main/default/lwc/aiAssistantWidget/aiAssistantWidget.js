import { LightningElement, api, track } from 'lwc';
import startSession from '@salesforce/apex/AgentApiController.startSession';
import sendMessage from '@salesforce/apex/AgentApiController.sendMessage';
import endSession from '@salesforce/apex/AgentApiController.endSession';

export default class AiAssistantWidget extends LightningElement {
    @api recordId;
    @api agentKey = '0Xxaj000004XiRNCA0';

    @track messages = [];
    inputText = '';
    isLoading = false;

    // Session State Management for Agent API
    sessionId = null;
    sequenceId = 1;

    connectedCallback() {
        this.initializeSession();
    }

    disconnectedCallback() {
        this.terminateActiveSession();
    }

    /**
     * Initializes or resets stateful session with Agentforce
     */
    async initializeSession() {
        this.isLoading = true;
        this.messages = [
            {
                id: 'welcome_init',
                isBot: true,
                formattedText: 'Connecting to **Sales Operations Assistant**...',
                containerClass: 'message-row bot-row'
            }
        ];

        try {
            const sessionRes = await startSession({
                agentKey: this.agentKey || null,
                contextRecordId: this.recordId || null
            });

            if (sessionRes && sessionRes.isSuccess) {
                this.sessionId = sessionRes.sessionId;
                this.sequenceId = sessionRes.initialSequenceId || 1;

                this.messages = [
                    {
                        id: 'welcome_' + Date.now(),
                        isBot: true,
                        formattedText: this.formatMarkdown(sessionRes.welcomeMessage || 'Hi! I am **Sales Operations Assistant**. How can I help you today?'),
                        containerClass: 'message-row bot-row'
                    }
                ];
            } else {
                const err = (sessionRes && sessionRes.errorMessage) ? sessionRes.errorMessage : 'Could not initialize session.';
                this.messages = [
                    {
                        id: 'welcome_err',
                        isBot: true,
                        formattedText: '⚠️ ' + this.formatMarkdown(err),
                        containerClass: 'message-row bot-row'
                    }
                ];
            }
        } catch (error) {
            const errMsg = error.body ? error.body.message : (error.message || 'Error connecting to Agent API.');
            this.messages = [
                {
                    id: 'welcome_err',
                    isBot: true,
                    formattedText: '⚠️ **Connection Error:** ' + this.formatMarkdown(errMsg),
                    containerClass: 'message-row bot-row'
                }
            ];
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    async terminateActiveSession() {
        if (this.sessionId) {
            try {
                await endSession({ sessionId: this.sessionId });
            } catch (ignored) {
                // Background cleanup; fail silently on page navigate
            }
            this.sessionId = null;
            this.sequenceId = 1;
        }
    }

    get isSendDisabled() {
        return this.isLoading || !this.inputText || this.inputText.trim().length === 0;
    }

    handleInputChange(event) {
        this.inputText = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            if (!this.isSendDisabled) {
                this.handleSendMessage();
            }
        }
    }

    async handleResetChat() {
        await this.terminateActiveSession();
        await this.initializeSession();
    }

    handleSendMessage() {
        const text = this.inputText ? this.inputText.trim() : '';
        if (!text) return;
        this.inputText = '';
        this.submitPrompt(text);
    }

    async submitPrompt(userText) {
        const userMsg = {
            id: 'user_' + Date.now(),
            isBot: false,
            text: userText,
            containerClass: 'message-row user-row'
        };
        this.messages = [...this.messages, userMsg];
        this.scrollToBottom();

        this.isLoading = true;

        try {
            // Lazy session recovery if session was lost or initial call failed
            if (!this.sessionId) {
                const sessionRes = await startSession({
                    agentKey: this.agentKey || null,
                    contextRecordId: this.recordId || null
                });
                if (sessionRes && sessionRes.isSuccess) {
                    this.sessionId = sessionRes.sessionId;
                    this.sequenceId = sessionRes.initialSequenceId || 1;
                } else {
                    throw new Error((sessionRes && sessionRes.errorMessage) ? sessionRes.errorMessage : 'Unable to establish agent session.');
                }
            }

            // Send message to Agentforce Agent API
            const msgResult = await sendMessage({
                sessionId: this.sessionId,
                userMessage: userText,
                sequenceId: this.sequenceId
            });

            if (msgResult && msgResult.isSuccess) {
                this.sequenceId = msgResult.nextSequenceId || (this.sequenceId + 1);

                const botMsg = {
                    id: 'bot_' + Date.now(),
                    isBot: true,
                    formattedText: this.formatMarkdown(msgResult.replyText || 'Action processed.'),
                    containerClass: 'message-row bot-row'
                };
                this.messages = [...this.messages, botMsg];
            } else {
                const errMsg = (msgResult && msgResult.errorMessage) ? msgResult.errorMessage : 'Action execution failed.';
                this.messages = [
                    ...this.messages,
                    {
                        id: 'bot_err_' + Date.now(),
                        isBot: true,
                        formattedText: '⚠️ ' + this.formatMarkdown(errMsg),
                        containerClass: 'message-row bot-row'
                    }
                ];
            }

        } catch (error) {
            const errMsg = error.body ? error.body.message : (error.message || 'An unexpected error occurred.');
            this.messages = [
                ...this.messages,
                {
                    id: 'bot_err_' + Date.now(),
                    isBot: true,
                    formattedText: '⚠️ ' + this.formatMarkdown(errMsg),
                    containerClass: 'message-row bot-row'
                }
            ];
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    /**
     * Clean markdown formatter for LLM / Agentforce outputs
     */
    formatMarkdown(text) {
        if (!text) return '';
        let formatted = text
            // Bold
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            // Italic
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            // Inline code
            .replace(/`(.*?)`/g, '<code style="background:#eef2f6;padding:2px 6px;border-radius:4px;font-weight:600;font-size:12px;">$1</code>')
            // Bullet points
            .replace(/^[•\-\*]\s+(.*)$/gm, '<li style="margin-left: 18px; list-style-type: disc;">$1</li>')
            // Line breaks
            .replace(/\n/g, '<br/>');
        return formatted;
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const chatBody = this.refs.chatBody;
            if (chatBody) {
                chatBody.scrollTop = chatBody.scrollHeight;
            }
        }, 50);
    }
}
