@IsTest
private class DataQualityAIServiceTest {

    @IsTest
    static void testAccountDuplicateAndQuality() {
        Account existingAcc = new Account(
            Name = 'Acme Solutions Pvt Ltd',
            Industry = 'Technology',
            Type = 'Customer',
            BillingCountry = 'India',
            Phone = '+91 9988776655'
        );
        insert existingAcc;

        Test.startTest();
        DataQualityAIService.DataQualityRequest req = new DataQualityAIService.DataQualityRequest();
        req.objectType = 'Account';
        req.name = 'A.C.M.E. Corp';
        req.phone = '+91 9988776655';
        List<DataQualityAIService.DataQualityResponse> resList = DataQualityAIService.auditRecords(new List<DataQualityAIService.DataQualityRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, resList.size());
        Assert.isTrue(resList[0].hasDuplicates);
        Assert.isFalse(resList[0].matches.isEmpty());
        Assert.areEqual('Technology', resList[0].suggestedIndustry);
    }

    @IsTest
    static void testLeadDuplicateByEmail() {
        Lead existingLead = new Lead(
            FirstName = 'Vikram',
            LastName = 'Malhotra',
            Company = 'FinBank Global',
            Industry = 'Banking',
            Email = 'vikram@finbank.com',
            Phone = '+91 9123456789'
        );
        insert existingLead;

        Test.startTest();
        DataQualityAIService.DataQualityRequest req = new DataQualityAIService.DataQualityRequest();
        req.objectType = 'Lead';
        req.name = 'FinBank India';
        req.email = 'vikram@finbank.com';
        req.phone = '+91 9123456789';
        req.industry = 'Banking';
        DataQualityAIService.DataQualityResponse res = DataQualityAIService.evaluateDataQuality(req);
        Test.stopTest();

        Assert.isTrue(res.hasDuplicates);
        Assert.areEqual('Banking', res.suggestedIndustry);
        Assert.isTrue(res.executiveReport.contains('Potential Duplicates'));
    }

    @IsTest
    static void testCleanRecordAndInference() {
        Test.startTest();
        DataQualityAIService.DataQualityRequest req = new DataQualityAIService.DataQualityRequest();
        req.objectType = 'Account';
        req.name = 'Apex Cloud Systems';
        req.phone = '+91 9876543210';
        DataQualityAIService.DataQualityResponse res = DataQualityAIService.evaluateDataQuality(req);
        Test.stopTest();

        Assert.isFalse(res.hasDuplicates);
        Assert.areEqual('Technology', res.suggestedIndustry);
        Assert.isTrue(res.executiveReport.contains('No conflicting duplicates'));
    }

    @IsTest
    static void testExistingRecordAudit() {
        Account acc = new Account(
            Name = 'Care Hospitals Group',
            Industry = 'Healthcare',
            Type = 'Customer',
            BillingCountry = 'India',
            Phone = '+91 9876512345'
        );
        insert acc;

        Test.startTest();
        DataQualityAIService.DataQualityRequest req = new DataQualityAIService.DataQualityRequest();
        req.objectType = 'Account';
        req.recordId = acc.Id;
        DataQualityAIService.DataQualityResponse res = DataQualityAIService.evaluateDataQuality(req);
        Test.stopTest();

        Assert.isNotNull(res);
        Assert.areEqual('Healthcare', res.suggestedIndustry);
    }

    @IsTest
    static void testNullAndEdgeCases() {
        Test.startTest();
        List<DataQualityAIService.DataQualityResponse> emptyRes = DataQualityAIService.auditRecords(null);
        DataQualityAIService.DataQualityResponse invalidRes = DataQualityAIService.evaluateDataQuality(new DataQualityAIService.DataQualityRequest());
        Test.stopTest();

        Assert.areEqual(0, emptyRes.size());
        Assert.isFalse(invalidRes.isClean);
        Assert.isTrue(invalidRes.executiveReport.startsWith('Error'));
    }
}

