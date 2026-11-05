/**
 * @description Controller for the public-facing CSAT Survey Visualforce page.
 * Executes without sharing to allow unauthenticated Site Guest Users to securely submit
 * customer ratings and optional feedback comments via single-use GUID tokens.
 * Zero-redundancy: Delegates 100% of data persistence to CSATSurveyService.
 */
public without sharing class CSATSurveyController {

    public Case targetCase { get; private set; }
    public String selectedRating { get; set; }
    public String feedbackComments { get; set; }
    public Boolean isValidToken { get; private set; }
    public Boolean isAlreadySubmitted { get; private set; }
    public Boolean isSuccess { get; private set; }
    public String pageMessage { get; private set; }

    public CSATSurveyController() {
        isValidToken = false;
        isAlreadySubmitted = false;
        isSuccess = false;
    }

    /**
     * @description Validates the token and loads case metadata on page initialization.
     * Enforces token validation, closed status check, and first-write-wins idempotency.
     */
    public PageReference init() {
        String token = ApexPages.currentPage().getParameters().get('token');
        if (String.isBlank(token)) {
            pageMessage = 'Invalid survey link. No access token provided.';
            isValidToken = false;
            return null;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, IsClosed, CSAT_Sent__c, Customer_Rating__c, Feedback_Comments__c
            FROM Case
            WHERE Survey_Token__c = :token.trim()
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            pageMessage = 'Invalid or expired survey link. Ticket record not found.';
            isValidToken = false;
            return null;
        }

        targetCase = cases[0];

        // Security check: Case must be closed and survey must have been dispatched
        if (!targetCase.IsClosed || !targetCase.CSAT_Sent__c) {
            pageMessage = 'This survey is not currently active for this support case.';
            isValidToken = false;
            return null;
        }

        // Idempotency check: First-write-wins protection
        if (targetCase.Customer_Rating__c != null) {
            isAlreadySubmitted = true;
            pageMessage = 'Thank you! Feedback has already been submitted for Case #' + targetCase.CaseNumber + '.';
            isValidToken = false;
            return null;
        }

        isValidToken = true;
        return null;
    }

    /**
     * @description Processes and records the customer rating and optional feedback comments.
     */
    public PageReference submitSurvey() {
        if (!isValidToken || targetCase == null) {
            return null;
        }

        // Server-side rating validation
        if (String.isBlank(selectedRating)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select your rating (1 to 5 stars) before submitting.'));
            return null;
        }

        // Safe comment truncation to avoid DML field length overflow
        String safeComments = (feedbackComments != null) ? feedbackComments.abbreviate(32000) : null;

        // Re-query idempotency check right before DML to prevent race conditions
        List<Case> refreshList = [
            SELECT Id, Customer_Rating__c
            FROM Case
            WHERE Id = :targetCase.Id
            LIMIT 1
        ];

        if (!refreshList.isEmpty() && refreshList[0].Customer_Rating__c != null) {
            isAlreadySubmitted = true;
            pageMessage = 'Thank you! Feedback has already been recorded for Case #' + targetCase.CaseNumber + '.';
            isValidToken = false;
            return null;
        }

        // Delegate persistence strictly to existing enterprise service
        Boolean saved = CSATSurveyService.recordResponse(targetCase.Id, selectedRating, safeComments);

        if (saved) {
            isSuccess = true;
            isValidToken = false;
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to submit your feedback at this moment. Please try again.'));
        }

        return null;
    }

    /**
     * @description High-performance zero-ViewState RemoteAction for instant async submission.
     */
    @RemoteAction
    public static Map<String, Object> submitSurveyRemote(String token, String rating, String comments) {
        Map<String, Object> response = new Map<String, Object>();
        if (String.isBlank(token)) {
            response.put('success', false);
            response.put('message', 'Invalid survey session.');
            return response;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, IsClosed, CSAT_Sent__c, Customer_Rating__c
            FROM Case
            WHERE Survey_Token__c = :token.trim()
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            response.put('success', false);
            response.put('message', 'Invalid or expired survey token.');
            return response;
        }

        Case c = cases[0];
        if (!c.IsClosed || !c.CSAT_Sent__c) {
            response.put('success', false);
            response.put('message', 'This survey is not currently active for this support case.');
            return response;
        }

        if (c.Customer_Rating__c != null) {
            response.put('success', false);
            response.put('alreadySubmitted', true);
            response.put('message', 'Thank you! Feedback has already been recorded for Case #' + c.CaseNumber + '.');
            return response;
        }

        String safeComments = (comments != null) ? comments.abbreviate(32000) : null;
        Boolean saved = CSATSurveyService.recordResponse(c.Id, rating, safeComments);

        if (saved) {
            response.put('success', true);
            response.put('caseNumber', c.CaseNumber);
            response.put('message', 'Your feedback has been successfully submitted and recorded for Case #' + c.CaseNumber + '.');
        } else {
            response.put('success', false);
            response.put('message', 'Unable to submit your feedback at this moment. Please try again.');
        }
        return response;
    }
}

