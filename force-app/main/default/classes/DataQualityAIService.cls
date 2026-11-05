public with sharing class DataQualityAIService {

    public class DataQualityRequest {
        @InvocableVariable(label='Object Type' description='Account or Lead' required=true)
        public String objectType;

        @InvocableVariable(label='Record ID' description='Optional existing Record ID' required=false)
        public String recordId;

        @InvocableVariable(label='Name / Company' description='Account Name or Lead Company Name' required=false)
        public String name;

        @InvocableVariable(label='Email' description='Email address for duplicate lookup' required=false)
        public String email;

        @InvocableVariable(label='Phone' description='Phone number for duplicate lookup' required=false)
        public String phone;

        @InvocableVariable(label='Industry' description='Industry if already provided' required=false)
        public String industry;
    }

    public class DuplicateMatch {
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String matchType;
    }

    public class DataQualityResponse {
        @InvocableVariable(label='Is Clean' description='True if no critical duplicates and quality is high')
        public Boolean isClean;

        @InvocableVariable(label='Quality Score' description='Data completeness score out of 100')
        public Integer qualityScore;

        @InvocableVariable(label='Has Duplicates' description='True if potential duplicates detected')
        public Boolean hasDuplicates;

        @InvocableVariable(label='Suggested Industry' description='AI suggested industry if blank')
        public String suggestedIndustry;

        @InvocableVariable(label='Executive Report' description='Actionable intelligence briefing')
        public String executiveReport;

        @AuraEnabled public List<DuplicateMatch> matches;
        @AuraEnabled public List<String> missingFields;
    }

    @InvocableMethod(
        label='Check Duplicates and Data Quality'
        description='Scans for fuzzy duplicate Accounts/Leads and evaluates record data completeness.'
        category='Data Intelligence'
    )
    public static List<DataQualityResponse> auditRecords(List<DataQualityRequest> requests) {
        List<DataQualityResponse> responses = new List<DataQualityResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (DataQualityRequest req : requests) {
            responses.add(evaluateDataQuality(req));
        }
        return responses;
    }

    @AuraEnabled(cacheable=true)
    public static DataQualityResponse evaluateDataQuality(DataQualityRequest req) {
        DataQualityResponse res = new DataQualityResponse();
        res.matches = new List<DuplicateMatch>();
        res.missingFields = new List<String>();

        if (req == null || String.isBlank(req.objectType)) {
            res.isClean = false;
            res.qualityScore = 0;
            res.executiveReport = 'Error: Object Type (Account or Lead) is required.';
            return res;
        }

        String targetType = req.objectType.trim();

        // 1. Fetch existing record data if recordId is supplied
        String evalName = req.name;
        String evalEmail = req.email;
        String evalPhone = req.phone;
        String evalIndustry = req.industry;
        Id excludeId;

        if (String.isNotBlank(req.recordId)) {
            try {
                excludeId = (Id)req.recordId.trim();
                if (targetType.equalsIgnoreCase('Account')) {
                    Account existingAcc = [
                        SELECT Id, Name, Phone, Industry, Type, BillingCountry, AnnualRevenue 
                        FROM Account WHERE Id = :excludeId LIMIT 1
                    ];
                    if (String.isBlank(evalName)) evalName = existingAcc.Name;
                    if (String.isBlank(evalPhone)) evalPhone = existingAcc.Phone;
                    if (String.isBlank(evalIndustry)) evalIndustry = existingAcc.Industry;
                } else if (targetType.equalsIgnoreCase('Lead')) {
                    Lead existingLd = [
                        SELECT Id, Company, FirstName, LastName, Email, Phone, Industry, LeadSource, Estimated_Budget__c 
                        FROM Lead WHERE Id = :excludeId LIMIT 1
                    ];
                    if (String.isBlank(evalName)) evalName = existingLd.Company;
                    if (String.isBlank(evalEmail)) evalEmail = existingLd.Email;
                    if (String.isBlank(evalPhone)) evalPhone = existingLd.Phone;
                    if (String.isBlank(evalIndustry)) evalIndustry = existingLd.Industry;
                }
            } catch (Exception ex) {
                // proceed with supplied request variables
            }
        }

        // 2. Data Completeness Audit
        Integer score = 100;
        if (String.isBlank(evalPhone)) {
            score -= 20;
            res.missingFields.add('Phone Number');
        }
        if (String.isBlank(evalIndustry)) {
            score -= 15;
            res.missingFields.add('Industry');
        }

        if (targetType.equalsIgnoreCase('Lead')) {
            if (String.isBlank(evalEmail)) {
                score -= 25;
                res.missingFields.add('Email Address');
            }
        }

        // 3. Smart Industry Suggestion if blank
        if (String.isBlank(evalIndustry) && String.isNotBlank(evalName)) {
            res.suggestedIndustry = inferIndustry(evalName);
        } else {
            res.suggestedIndustry = evalIndustry;
        }

        // 4. Fuzzy Duplicate Matching
        if (String.isNotBlank(evalName)) {
            String cleanNormalized = normalizeCompanyName(evalName);
            if (String.isNotBlank(cleanNormalized)) {
                String searchPattern = '%' + cleanNormalized + '%';

                if (targetType.equalsIgnoreCase('Account')) {
                    List<Account> accMatches = [
                        SELECT Id, Name, Phone, Industry 
                        FROM Account 
                        WHERE (Name LIKE :searchPattern OR (Phone != null AND Phone = :evalPhone))
                        AND Id != :excludeId
                        LIMIT 5
                    ];
                    for (Account a : accMatches) {
                        DuplicateMatch dm = new DuplicateMatch();
                        dm.recordId = a.Id;
                        dm.recordName = a.Name;
                        dm.matchType = (a.Name.toLowerCase().contains(cleanNormalized.toLowerCase())) ? 'Similar Company Name' : 'Matching Phone Number';
                        res.matches.add(dm);
                    }
                } else if (targetType.equalsIgnoreCase('Lead')) {
                    List<Lead> ldMatches = [
                        SELECT Id, Name, Company, Email, Phone 
                        FROM Lead 
                        WHERE (Company LIKE :searchPattern OR (Email != null AND Email = :evalEmail) OR (Phone != null AND Phone = :evalPhone))
                        AND Id != :excludeId
                        AND IsConverted = false
                        LIMIT 5
                    ];
                    for (Lead l : ldMatches) {
                        DuplicateMatch dm = new DuplicateMatch();
                        dm.recordId = l.Id;
                        dm.recordName = l.Name + ' (' + l.Company + ')';
                        if (String.isNotBlank(evalEmail) && l.Email == evalEmail) {
                            dm.matchType = 'Exact Email Match';
                        } else if (String.isNotBlank(evalPhone) && l.Phone == evalPhone) {
                            dm.matchType = 'Exact Phone Match';
                        } else {
                            dm.matchType = 'Similar Company Name';
                        }
                        res.matches.add(dm);
                    }
                }
            }
        }

        res.hasDuplicates = !res.matches.isEmpty();
        if (res.hasDuplicates) {
            score = Math.max(score - 20, 10);
        }
        res.qualityScore = Math.max(score, 0);
        res.isClean = (!res.hasDuplicates && res.missingFields.isEmpty());

        // 5. Build Executive Briefing
        String report = '🔍 **Data Quality & Duplicate Audit Report**\n';
        report += '• **Overall Quality Score:** ' + res.qualityScore + '/100 (' + (res.isClean ? '🟢 Clean' : (res.hasDuplicates ? '🔴 Duplicates Flagged' : '🟡 Needs Enrichment')) + ')\n';

        if (res.hasDuplicates) {
            report += '• **⚠️ Potential Duplicates (' + res.matches.size() + '):**\n';
            for (DuplicateMatch m : res.matches) {
                report += '   - ' + m.recordName + ' [' + m.matchType + ']\n';
            }
        } else {
            report += '• **Duplicates:** ✅ No conflicting duplicates found.\n';
        }

        if (!res.missingFields.isEmpty()) {
            report += '• **Missing Fields:** ❌ ' + String.join(res.missingFields, ', ') + '\n';
        }

        if (String.isNotBlank(res.suggestedIndustry) && String.isBlank(evalIndustry)) {
            report += '• **AI Suggested Industry:** 💡 ' + res.suggestedIndustry + ' (inferred from entity name)\n';
        }

        res.executiveReport = report;
        return res;
    }

    public static String normalizeCompanyName(String companyName) {
        if (String.isBlank(companyName)) return '';
        String clean = companyName.replaceAll('(?i)[^a-zA-Z0-9\\s]', ' ').trim();
        List<String> stopWords = new List<String>{
            'pvt', 'private', 'ltd', 'limited', 'inc', 'incorporated', 'corp', 'corporation',
            'llc', 'llp', 'co', 'company', 'technologies', 'tech', 'solutions', 'services', 'group'
        };

        List<String> tokens = clean.split('\\s+');
        List<String> validTokens = new List<String>();
        for (String tok : tokens) {
            if (tok.length() > 1 && !stopWords.contains(tok.toLowerCase())) {
                validTokens.add(tok);
            }
        }

        if (!validTokens.isEmpty()) {
            return validTokens[0];
        }
        return tokens.isEmpty() ? '' : tokens[0];
    }

    public static String inferIndustry(String companyName) {
        if (String.isBlank(companyName)) return 'Technology';
        String lower = companyName.toLowerCase();
        if (lower.contains('tech') || lower.contains('soft') || lower.contains('cloud') || lower.contains('data') || lower.contains('ai')) {
            return 'Technology';
        } else if (lower.contains('bank') || lower.contains('fin') || lower.contains('capital') || lower.contains('invest')) {
            return 'Banking';
        } else if (lower.contains('health') || lower.contains('pharma') || lower.contains('care') || lower.contains('med')) {
            return 'Healthcare';
        } else if (lower.contains('retail') || lower.contains('mart') || lower.contains('store') || lower.contains('shop')) {
            return 'Retail';
        } else if (lower.contains('consult') || lower.contains('advis')) {
            return 'Consulting';
        } else if (lower.contains('steel') || lower.contains('motor') || lower.contains('auto') || lower.contains('mfg')) {
            return 'Manufacturing';
        }
        return 'Technology';
    }
}

