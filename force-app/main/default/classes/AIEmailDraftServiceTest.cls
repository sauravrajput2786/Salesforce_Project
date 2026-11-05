@IsTest
private class AIEmailDraftServiceTest {

    @IsTest
    static void testDraftLeadEmail() {
        Lead ld = new Lead(
            FirstName = 'Rohan',
            LastName = 'Gupta',
            Company = 'TechCorp',
            Industry = 'Technology',
            Estimated_Budget__c = 80000
        );
        insert ld;

        Task t = new Task(
            Subject = 'Platform Demo',
            WhoId = ld.Id,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;

        Test.startTest();
        AIEmailDraftService.DraftRequest req = new AIEmailDraftService.DraftRequest();
        req.recordId = ld.Id;
        req.draftType = 'Follow-up';
        List<AIEmailDraftService.DraftResponse> resList = AIEmailDraftService.generateDrafts(new List<AIEmailDraftService.DraftRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, resList.size());
        Assert.areEqual('Success', resList[0].status);
        Assert.isTrue(resList[0].subject.contains('TechCorp'));
        Assert.isTrue(resList[0].body.contains('Hi Rohan'));
        Assert.isTrue(resList[0].body.contains('Technology'));
    }

    @IsTest
    static void testDraftOpportunityProposal() {
        Account acc = new Account(Name = 'TechCorp Pvt Ltd', Type = 'Customer', BillingCountry = 'India', Industry = 'Technology', Phone = '+91 9876543210');
        insert acc;

        Contact con = new Contact(FirstName = 'Rohan', LastName = 'Gupta', AccountId = acc.Id, Email = 'rohan@techcorp.com');
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Cloud Migration Deal',
            AccountId = acc.Id,
            StageName = 'Proposal/Price Quote',
            CloseDate = Date.today().addDays(15),
            Amount = 1400000,
            Primary_Contact__c = con.Id
        );
        insert opp;

        Test.startTest();
        AIEmailDraftService.DraftResponse res = AIEmailDraftService.generateSingleDraft(opp.Id, 'Proposal');
        Test.stopTest();

        Assert.areEqual('Success', res.status);
        Assert.isTrue(res.subject.contains('Proposal'));
        Assert.isTrue(res.body.contains('Cloud Migration Deal'));
        Assert.isTrue(res.body.contains('Hi Rohan'));
    }

    @IsTest
    static void testInvalidRecordId() {
        Test.startTest();
        AIEmailDraftService.DraftResponse res = AIEmailDraftService.generateSingleDraft('invalid_id', 'Follow-up');
        Test.stopTest();

        Assert.isTrue(res.status.startsWith('Error'));
    }

    @IsTest
    static void testSendDraftEmail() {
        Lead ld = new Lead(
            FirstName = 'Rohan',
            LastName = 'Gupta',
            Company = 'TechCorp',
            Industry = 'Technology',
            Email = 'rohan@techcorp.com'
        );
        insert ld;

        Test.startTest();
        String sendRes = AIEmailDraftService.sendDraftEmail(ld.Id, 'rohan@techcorp.com', 'Follow-up Call', 'Hello Rohan');
        String invalidRes = AIEmailDraftService.sendDraftEmail(ld.Id, '', '', '');
        Test.stopTest();

        Assert.areEqual('Success', sendRes);
        Assert.isTrue(invalidRes.startsWith('Error'));
    }
}

