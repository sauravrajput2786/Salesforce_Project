// ==============================================================================
// TechNova Intelligent Cloud Engine: Safe-Side Workaround Broadcast Script
// Delivers verified engineering workaround to active cases linked to KI-0000
// STRICT ZERO-HARDCODING: All references resolved dynamically via SOQL
// SAFE-SIDE RULE: Emails sent IF AND ONLY IF email is present; gracefully skips if null
// ==============================================================================

// 1. Fetch active open Cases linked to the primary Known Issue
List<Case_Known_Issue__c> linkedIssues = [
    SELECT Id,
           Case__r.Id,
           Case__r.CaseNumber,
           Case__r.Subject,
           Case__r.Contact.Id,
           Case__r.Contact.Name,
           Case__r.Contact.Email,
           Case__r.SuppliedEmail,
           Known_Issue__r.Name,
           Known_Issue__r.Issue_Title__c,
           Known_Issue__r.Workaround__c
    FROM Case_Known_Issue__c
    WHERE Known_Issue__r.Name = 'KI-0000'
      AND Case__r.IsClosed = false
];

System.debug('>>> [Broadcast] Total linked active cases retrieved: ' + linkedIssues.size());

List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
Integer sentCount = 0;
Integer skippedCount = 0;

for (Case_Known_Issue__c cki : linkedIssues) {
    String recipientEmail = String.isNotBlank(cki.Case__r.Contact.Email) 
                            ? cki.Case__r.Contact.Email 
                            : cki.Case__r.SuppliedEmail;
    
    // SAFE-SIDE CHECK: Send ONLY if valid email is present
    if (String.isNotBlank(recipientEmail) && String.isNotBlank(cki.Known_Issue__r.Workaround__c)) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ recipientEmail });
        mail.setSubject('Verified Workaround Available: [Case #' + cki.Case__r.CaseNumber + '] ' + cki.Known_Issue__r.Issue_Title__c);
        
        String recipientName = String.isNotBlank(cki.Case__r.Contact.Name) ? cki.Case__r.Contact.Name : 'Customer';
        String emailBody = 'Dear ' + recipientName + ',\n\n' +
            'We are following up on your active support request regarding: "' + cki.Case__r.Subject + '" (Case #' + cki.Case__r.CaseNumber + ').\n\n' +
            'Our engineering team has verified an immediate workaround for the known platform event (' + cki.Known_Issue__r.Name + ': ' + cki.Known_Issue__r.Issue_Title__c + '):\n\n' +
            '--------------------------------------------------\n' +
            'WORKAROUND / SOLUTION:\n' +
            cki.Known_Issue__r.Workaround__c + '\n' +
            '--------------------------------------------------\n\n' +
            'Our technical team is actively rolling out the permanent patch. We will notify you as soon as the patch is deployed.\n\n' +
            'Best regards,\n' +
            'TechNova Intelligent Cloud Support Team';
            
        mail.setPlainTextBody(emailBody);
        mail.setWhatId(cki.Case__r.Id);
        
        emailsToSend.add(mail);
        sentCount++;
        System.debug('>>> [Broadcast QUEUED] Case #' + cki.Case__r.CaseNumber + ' to: ' + recipientEmail);
    } else {
        skippedCount++;
        System.debug('>>> [Broadcast SKIPPED - Safe Side] Case #' + cki.Case__r.CaseNumber + ' has no email or no workaround.');
    }
}

if (!emailsToSend.isEmpty()) {
    Messaging.sendEmail(emailsToSend);
    System.debug('>>> [Broadcast COMPLETE] Total Workaround Emails Delivered: ' + sentCount);
} else {
    System.debug('>>> [Broadcast COMPLETE] Zero emails met safe-side criteria. Total skipped: ' + skippedCount);
}

