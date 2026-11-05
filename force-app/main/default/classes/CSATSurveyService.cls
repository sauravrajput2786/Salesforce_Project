/**
 * @description Enterprise service for processing and synchronizing customer CSAT survey responses
 * to Case records (Customer_Rating__c and Feedback_Comments__c) with validation, bulk safety,
 * and error handling.
 */
public inherited sharing class CSATSurveyService {

    public static final Map<String, String> RATING_MAP = new Map<String, String>{
        '5' => '5 - Excellent',
        '4' => '4 - Good',
        '3' => '3 - Average',
        '2' => '2 - Poor',
        '1' => '1 - Very Poor',
        '5 - EXCELLENT' => '5 - Excellent',
        '4 - GOOD' => '4 - Good',
        '3 - AVERAGE' => '3 - Average',
        '2 - POOR' => '2 - Poor',
        '1 - VERY POOR' => '1 - Very Poor'
    };

    public class SurveySubmissionRequest {
        @InvocableVariable(required=true label='Case ID' description='The ID of the Case being rated')
        public Id caseId;

        @InvocableVariable(required=true label='Rating' description='Rating from 1 to 5 Stars')
        public String rating;

        @InvocableVariable(label='Feedback Comments' description='Optional customer feedback comments')
        public String feedbackComments;

        public SurveySubmissionRequest() {}

        public SurveySubmissionRequest(Id caseId, String rating, String feedbackComments) {
            this.caseId = caseId;
            this.rating = rating;
            this.feedbackComments = feedbackComments;
        }
    }

    public class SurveySubmissionResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Case ID')
        public Id caseId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        public SurveySubmissionResult(Id caseId, Boolean isSuccess, String errorMessage) {
            this.caseId = caseId;
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
        }
    }

    /**
     * @description Invocable method to process a batch of survey submissions.
     * @param requests List of SurveySubmissionRequest items
     * @return List of SurveySubmissionResult items
     */
    @InvocableMethod(label='Process Customer CSAT Survey' description='Validates and records customer rating (1-5 Stars) and feedback comments to Case')
    public static List<SurveySubmissionResult> processSurveyResponses(List<SurveySubmissionRequest> requests) {
        List<SurveySubmissionResult> results = new List<SurveySubmissionResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> caseIds = new Set<Id>();
        for (SurveySubmissionRequest req : requests) {
            if (req.caseId != null) {
                caseIds.add(req.caseId);
            }
        }

        Map<Id, Case> existingCases = new Map<Id, Case>([
            SELECT Id, Customer_Rating__c, Feedback_Comments__c, CSAT_Sent__c, Status
            FROM Case
            WHERE Id IN :caseIds
        ]);

        List<Case> casesToUpdate = new List<Case>();
        Map<Id, SurveySubmissionResult> resultMap = new Map<Id, SurveySubmissionResult>();

        for (SurveySubmissionRequest req : requests) {
            if (req.caseId == null || !existingCases.containsKey(req.caseId)) {
                results.add(new SurveySubmissionResult(req.caseId, false, 'Invalid or non-existent Case ID'));
                continue;
            }

            String mappedRating = normalizeRating(req.rating);
            if (mappedRating == null) {
                results.add(new SurveySubmissionResult(req.caseId, false, 'Invalid rating value. Must be 1 to 5.'));
                continue;
            }

            Case c = existingCases.get(req.caseId);
            c.Customer_Rating__c = mappedRating;
            if (String.isNotBlank(req.feedbackComments)) {
                c.Feedback_Comments__c = req.feedbackComments;
            }
            c.CSAT_Sent__c = true;
            casesToUpdate.add(c);
            resultMap.put(req.caseId, new SurveySubmissionResult(req.caseId, true, null));
        }

        if (!casesToUpdate.isEmpty()) {
            try {
                update casesToUpdate;
            } catch (DmlException ex) {
                for (SurveySubmissionResult res : resultMap.values()) {
                    res.isSuccess = false;
                    res.errorMessage = ex.getMessage();
                }
            }
        }

        for (SurveySubmissionRequest req : requests) {
            if (resultMap.containsKey(req.caseId)) {
                results.add(resultMap.get(req.caseId));
            }
        }

        return results;
    }

    /**
     * @description Convenience method for single response recording.
     */
    public static Boolean recordResponse(Id caseId, Integer rating, String feedback) {
        return recordResponse(caseId, String.valueOf(rating), feedback);
    }

    /**
     * @description Convenience method for single response recording with String rating.
     */
    public static Boolean recordResponse(Id caseId, String rating, String feedback) {
        SurveySubmissionRequest req = new SurveySubmissionRequest(caseId, rating, feedback);
        List<SurveySubmissionResult> resList = processSurveyResponses(new List<SurveySubmissionRequest>{ req });
        return (!resList.isEmpty() && resList[0].isSuccess);
    }

    /**
     * @description Normalizes rating input to standard picklist value.
     */
    private static String normalizeRating(String ratingInput) {
        if (String.isBlank(ratingInput)) {
            return null;
        }
        String trimmed = ratingInput.trim().toUpperCase();
        if (RATING_MAP.containsKey(trimmed)) {
            return RATING_MAP.get(trimmed);
        }
        return null;
    }
}
