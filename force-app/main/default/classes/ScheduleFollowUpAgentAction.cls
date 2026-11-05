public without sharing class ScheduleFollowUpAgentAction {

    public class ScheduleRequest {
        @InvocableVariable(label='Record ID or Name' description='Salesforce ID or Name of the Account, Opportunity, Lead, or Contact to link this follow-up task to' required=false)
        public String recordId;

        @InvocableVariable(label='Record Name' description='Name or Company of the Account, Opportunity, Lead, or Contact to associate this task with' required=false)
        public String recordName;

        @InvocableVariable(label='Record Type' description='Type of record to link this task to: Account, Opportunity, Lead, or Contact. Optional.' required=false)
        public String recordType;

        @InvocableVariable(label='Opportunity ID' description='15 or 18 character Salesforce ID of the Opportunity (starts with 006). Optional.' required=false)
        public String opportunityId;

        @InvocableVariable(label='Subject' description='Subject or topic of the task e.g. Contract Review Follow-up, Product Demo' required=false)
        public String subject;

        @InvocableVariable(label='Due Date' description='Due date for the task' required=false)
        public Date dueDate;

        @InvocableVariable(label='Notes' description='Detailed discussion notes or agenda' required=false)
        public String notes;

        @InvocableVariable(label='Priority' description='Task priority: High, Normal, Low' required=false)
        public String priority;

        @InvocableVariable(label='Status' description='Task status e.g. Not Started, In Progress' required=false)
        public String status;
    }

    public class ScheduleResponse {
        @InvocableVariable(label='Is Success' description='True if task was created successfully, false otherwise')
        public Boolean isSuccess;

        @InvocableVariable(label='Task ID' description='Record ID of the newly created Task')
        public Id taskId;

        @InvocableVariable(label='Subject' description='Subject of the scheduled task')
        public String subject;

        @InvocableVariable(label='Due Date' description='Due date of the scheduled task')
        public Date dueDate;

        @InvocableVariable(label='Priority' description='Priority assigned to the task')
        public String priority;

        @InvocableVariable(label='Linked Record Type' description='Type of linked record: Account, Opportunity, Lead, Contact, or Standalone')
        public String linkedRecordType;

        @InvocableVariable(label='Linked Record Name' description='Name of the linked record')
        public String linkedRecordName;

        @InvocableVariable(label='Message' description='Conversational confirmation or validation prompt with interactive user options')
        public String message;
    }

    private class RecordLinkInfo {
        public Id whatId;
        public Id whoId;
        public Id ownerId;
        public String ownerName;
        public String recordType;
        public String recordName;
        public String errorMessage;
    }

    @InvocableMethod(
        label='Schedule Follow-up Task'
        description='Creates a follow-up Task linked to an Account, Opportunity, Lead, or Contact. Validates mandatory details and prompts user interactively if details are missing.'
        category='Sales Operations'
    )
    public static List<ScheduleResponse> scheduleTask(List<ScheduleRequest> requests) {
        List<ScheduleResponse> responses = new List<ScheduleResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        List<Task> tasksToInsert = new List<Task>();
        Map<Integer, ScheduleRequest> indexToRequestMap = new Map<Integer, ScheduleRequest>();
        Map<Integer, RecordLinkInfo> indexToLinkMap = new Map<Integer, RecordLinkInfo>();

        for (Integer i = 0; i < requests.size(); i++) {
            ScheduleRequest req = requests[i];
            ScheduleResponse res = new ScheduleResponse();

            if (req == null) {
                res.isSuccess = false;
                res.message = 'No task details were provided. To schedule a follow-up task, please provide the related record name (Account/Opportunity/Lead/Contact), task subject, and due date. Would you like to provide these details now, or abort?';
                responses.add(res);
                continue;
            }

            // Enterprise Validation: If user provided neither subject nor any record reference
            if (String.isBlank(req.subject) && req.recordId == null && String.isBlank(req.recordName) && req.opportunityId == null) {
                res.isSuccess = false;
                res.message = 'To schedule a follow-up task, the following details are required:\n' +
                              '1. Related record (Account, Opportunity, Lead, or Contact name)\n' +
                              '2. Subject / Topic (e.g., Contract Review Follow-up, Product Demo)\n' +
                              '3. Due Date\n' +
                              '• Would you like to provide these details now, or abort?';
                responses.add(res);
                continue;
            }

            RecordLinkInfo linkInfo = resolveTargetRecord(req);
            if (String.isNotBlank(linkInfo.errorMessage)) {
                res.isSuccess = false;
                res.message = linkInfo.errorMessage;
                responses.add(res);
                continue;
            }

            // Enterprise Validation: Subject is strictly mandatory and must not be blindly defaulted or auto-generated with generic placeholders
            String subLower = req.subject != null ? req.subject.trim().toLowerCase() : '';
            Boolean isGenericSubject = String.isBlank(req.subject) || 
                                       subLower == 'follow-up' || 
                                       subLower == 'follow up' || 
                                       subLower == 'followup' || 
                                       subLower == 'sales follow-up' || 
                                       subLower == 'sales follow up' || 
                                       subLower == 'task' || 
                                       subLower == 'follow-up task' || 
                                       subLower == 'follow up task' || 
                                       subLower.startsWith('follow-up with') || 
                                       subLower.startsWith('follow up with') || 
                                       subLower.startsWith('followup with') || 
                                       subLower.startsWith('follow-up for') || 
                                       subLower.startsWith('follow up for') || 
                                       subLower.startsWith('followup for') || 
                                       subLower.startsWith('follow-up task for') || 
                                       subLower.startsWith('follow up task for') || 
                                       subLower.startsWith('follow-up task with') || 
                                       subLower.startsWith('follow up task with');

            if (isGenericSubject) {
                res.isSuccess = false;
                String targetClarification = (String.isNotBlank(linkInfo.recordName) && linkInfo.recordName != 'None') 
                    ? ' for ' + linkInfo.recordType + ' "' + linkInfo.recordName + '"' 
                    : '';
                res.message = 'To schedule a follow-up task' + targetClarification + ', please specify the discussion topic or purpose (e.g., Contract Review, Demo, Pricing Discussion) and due date. What should be the Subject and Due Date?';
                responses.add(res);
                continue;
            }

            // Enterprise Rule: Follow-up tasks must be linked to a target record (Account, Opportunity, Lead, or Contact)
            if (linkInfo.whatId == null && linkInfo.whoId == null) {
                res.isSuccess = false;
                res.message = 'To schedule a follow-up task, please specify which record it should be linked to (Account, Opportunity, Lead, or Contact name), the subject/purpose, and the priority (High, Normal, Low). Which record would you like to link this task to?';
                responses.add(res);
                continue;
            }

            // Enterprise Validation: Past due dates are not permitted
            if (req.dueDate != null && req.dueDate < Date.today()) {
                res.isSuccess = false;
                res.message = 'The due date cannot be in the past (' + req.dueDate + '). Please provide a valid future due date.';
                responses.add(res);
                continue;
            }

            String taskSubject = req.subject.trim();
            Date taskDueDate = req.dueDate != null ? req.dueDate : Date.today().addDays(2);
            String taskPriority = String.isNotBlank(req.priority) ? req.priority.trim() : 'Normal';
            String taskStatus = String.isNotBlank(req.status) ? req.status.trim() : 'Not Started';

            Task newTask = new Task(
                Subject = taskSubject,
                ActivityDate = taskDueDate,
                Description = req.notes,
                Priority = taskPriority,
                Status = taskStatus
            );

            if (linkInfo.whatId != null) {
                newTask.WhatId = linkInfo.whatId;
            }
            if (linkInfo.whoId != null) {
                newTask.WhoId = linkInfo.whoId;
            }
            if (linkInfo.ownerId != null) {
                newTask.OwnerId = linkInfo.ownerId;
            }

            tasksToInsert.add(newTask);
            indexToRequestMap.put(tasksToInsert.size() - 1, req);
            indexToLinkMap.put(tasksToInsert.size() - 1, linkInfo);
            responses.add(res);
        }

        if (!tasksToInsert.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.insert(tasksToInsert, false);

            Integer taskIndex = 0;
            for (Integer i = 0; i < responses.size(); i++) {
                if (responses[i].message != null) {
                    continue;
                }

                Database.SaveResult sr = saveResults[taskIndex];
                ScheduleRequest origReq = indexToRequestMap.get(taskIndex);
                RecordLinkInfo linkInfo = indexToLinkMap.get(taskIndex);
                Task insertedTask = tasksToInsert[taskIndex];

                if (sr.isSuccess()) {
                    responses[i].isSuccess = true;
                    responses[i].taskId = sr.getId();
                    responses[i].subject = insertedTask.Subject;
                    responses[i].dueDate = insertedTask.ActivityDate;
                    responses[i].priority = insertedTask.Priority;
                    responses[i].linkedRecordType = linkInfo.recordType;
                    responses[i].linkedRecordName = linkInfo.recordName;

                    String statusVal = String.isNotBlank(insertedTask.Status) ? insertedTask.Status : 'Not Started';
                    String dateNote = origReq.dueDate == null ? ' (defaulted to +2 business days)' : '';
                    String assignedToName = String.isNotBlank(linkInfo.ownerName) ? linkInfo.ownerName : UserInfo.getName();

                    responses[i].message = '✅ Follow-up Task Scheduled Successfully!\n' +
                                           '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' +
                                           '• Subject:        ' + insertedTask.Subject + '\n' +
                                           '• Related To:     ' + linkInfo.recordType + ' "' + linkInfo.recordName + '"\n' +
                                           '• Due Date:       ' + String.valueOf(insertedTask.ActivityDate) + dateNote + '\n' +
                                           '• Priority:       ' + insertedTask.Priority + '\n' +
                                           '• Status:         ' + statusVal + '\n' +
                                           '• Assigned To:    ' + assignedToName + '\n' +
                                           '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' +
                                           'Would you like to adjust any details or add notes?';
                } else {
                    responses[i].isSuccess = false;
                    String errorDetail = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorDetail += err.getMessage() + ' ';
                    }
                    responses[i].message = 'Validation failed while creating Task: ' + errorDetail.trim() + 
                                           '. Would you like to provide the required details, or abort?';
                }
                taskIndex++;
            }
        }

        return responses;
    }

    private static RecordLinkInfo resolveTargetRecord(ScheduleRequest req) {
        RecordLinkInfo info = new RecordLinkInfo();
        info.recordType = 'Standalone';
        info.recordName = 'None';

        // 1. Direct recordId provided
        if (String.isNotBlank(req.recordId)) {
            String idStr = req.recordId.trim();
            if ((idStr.length() == 15 || idStr.length() == 18) && 
                (idStr.startsWith('001') || idStr.startsWith('006') || idStr.startsWith('00Q') || idStr.startsWith('003'))) {
                try {
                    Id validId = (Id) idStr;
                    if (idStr.startsWith('001')) {
                        List<Account> accs = [SELECT Id, Name, OwnerId, Owner.Name FROM Account WHERE Id = :validId LIMIT 1];
                        if (!accs.isEmpty()) {
                            info.whatId = accs[0].Id;
                            info.ownerId = accs[0].OwnerId;
                            info.ownerName = accs[0].Owner.Name;
                            info.recordType = 'Account';
                            info.recordName = accs[0].Name;
                            return info;
                        }
                    } else if (idStr.startsWith('006')) {
                        List<Opportunity> opps = [SELECT Id, Name, OwnerId, Owner.Name FROM Opportunity WHERE Id = :validId LIMIT 1];
                        if (!opps.isEmpty()) {
                            info.whatId = opps[0].Id;
                            info.ownerId = opps[0].OwnerId;
                            info.ownerName = opps[0].Owner.Name;
                            info.recordType = 'Opportunity';
                            info.recordName = opps[0].Name;
                            return info;
                        }
                    } else if (idStr.startsWith('00Q')) {
                        List<Lead> leads = [SELECT Id, Name, OwnerId, Owner.Name FROM Lead WHERE Id = :validId LIMIT 1];
                        if (!leads.isEmpty()) {
                            info.whoId = leads[0].Id;
                            info.ownerId = leads[0].OwnerId;
                            info.ownerName = leads[0].Owner.Name;
                            info.recordType = 'Lead';
                            info.recordName = leads[0].Name;
                            return info;
                        }
                    } else if (idStr.startsWith('003')) {
                        List<Contact> contacts = [SELECT Id, Name, OwnerId, Owner.Name FROM Contact WHERE Id = :validId LIMIT 1];
                        if (!contacts.isEmpty()) {
                            info.whoId = contacts[0].Id;
                            info.ownerId = contacts[0].OwnerId;
                            info.ownerName = contacts[0].Owner.Name;
                            info.recordType = 'Contact';
                            info.recordName = contacts[0].Name;
                            return info;
                        }
                    }
                } catch (Exception ex) {
                    // Fall through to name search
                }
            }
            if (String.isBlank(req.recordName)) {
                req.recordName = idStr;
            }
        }

        String rType = String.isNotBlank(req.recordType) ? req.recordType.trim().toLowerCase() : '';

        // 2. opportunityId provided (only handles 15/18-char Opportunity ID if not an Account search)
        if (String.isNotBlank(req.opportunityId) && !rType.contains('acc') && !rType.contains('lead') && !rType.contains('contact')) {
            String oppRef = req.opportunityId.trim();
            if ((oppRef.length() == 15 || oppRef.length() == 18) && oppRef.startsWith('006')) {
                try {
                    Id validOppId = (Id) oppRef;
                    List<Opportunity> opps = [SELECT Id, Name, OwnerId, Owner.Name FROM Opportunity WHERE Id = :validOppId LIMIT 1];
                    if (!opps.isEmpty()) {
                        info.whatId = opps[0].Id;
                        info.ownerId = opps[0].OwnerId;
                        info.ownerName = opps[0].Owner.Name;
                        info.recordType = 'Opportunity';
                        info.recordName = opps[0].Name;
                        return info;
                    }
                } catch (Exception ex) {
                    // Fall through
                }
            }
        }

        // 3. Name provided (search guided by recordType or with smart ambiguity detection)
        String rawName = String.isNotBlank(req.recordName) ? req.recordName : (String.isNotBlank(req.opportunityId) ? req.opportunityId : null);
        if (String.isNotBlank(rawName)) {
            String cleanName = rawName.trim().replaceAll('^[\\\'\\\"\\s]+|[\\\'\\\"\\.\\,\\?\\!\\s]+$', '');
            String wildcard = '%' + cleanName + '%';
            String firstWord = cleanName.contains(' ') ? cleanName.substringBefore(' ').trim() : cleanName;
            String firstWordWildcard = '%' + firstWord + '%';

            // A. Explicit Record Type Specified
            if (String.isNotBlank(rType)) {
                if (rType.contains('opp') || rType.contains('deal')) {
                    List<Opportunity> opps = [SELECT Id, Name, OwnerId, Owner.Name FROM Opportunity WHERE Name LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];
                    if (!opps.isEmpty()) {
                        info.whatId = opps[0].Id;
                        info.ownerId = opps[0].OwnerId;
                        info.ownerName = opps[0].Owner.Name;
                        info.recordType = 'Opportunity';
                        info.recordName = opps[0].Name;
                        return info;
                    }
                    List<Opportunity> partialOpps = [SELECT Id, Name FROM Opportunity WHERE Name LIKE :firstWordWildcard ORDER BY CreatedDate DESC LIMIT 1];
                    if (!partialOpps.isEmpty()) {
                        info.errorMessage = 'Could not find an exact Opportunity match for "' + cleanName + '", but found "' + partialOpps[0].Name + '". Did you mean this deal?';
                        return info;
                    }
                    info.errorMessage = 'Could not find any Opportunity matching "' + cleanName + '". Please verify the deal name.';
                    return info;
                } else if (rType.contains('acc') || rType.contains('comp')) {
                    List<Account> accs = [SELECT Id, Name, OwnerId, Owner.Name FROM Account WHERE Name LIKE :wildcard OR Phone LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];
                    if (!accs.isEmpty()) {
                        info.whatId = accs[0].Id;
                        info.ownerId = accs[0].OwnerId;
                        info.ownerName = accs[0].Owner.Name;
                        info.recordType = 'Account';
                        info.recordName = accs[0].Name;
                        return info;
                    }
                    List<Account> partialAccs = [SELECT Id, Name FROM Account WHERE Name LIKE :firstWordWildcard ORDER BY CreatedDate DESC LIMIT 1];
                    if (!partialAccs.isEmpty()) {
                        info.errorMessage = 'Could not find an exact Account match for "' + cleanName + '", but found "' + partialAccs[0].Name + '". Did you mean this account?';
                        return info;
                    }
                    info.errorMessage = 'Could not find any Account matching "' + cleanName + '". Please verify the account name.';
                    return info;
                } else if (rType.contains('lead') || rType.contains('prosp')) {
                    List<Lead> leads = [SELECT Id, Name, Company, OwnerId, Owner.Name FROM Lead WHERE (Name LIKE :wildcard OR Company LIKE :wildcard) AND IsConverted = false ORDER BY CreatedDate DESC LIMIT 1];
                    if (!leads.isEmpty()) {
                        info.whoId = leads[0].Id;
                        info.ownerId = leads[0].OwnerId;
                        info.ownerName = leads[0].Owner.Name;
                        info.recordType = 'Lead';
                        info.recordName = leads[0].Name;
                        return info;
                    }
                    info.errorMessage = 'Could not find any open Lead matching "' + cleanName + '". Please verify the lead name.';
                    return info;
                } else if (rType.contains('contact') || rType.contains('person')) {
                    List<Contact> contacts = [SELECT Id, Name, OwnerId, Owner.Name FROM Contact WHERE Name LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];
                    if (!contacts.isEmpty()) {
                        info.whoId = contacts[0].Id;
                        info.ownerId = contacts[0].OwnerId;
                        info.ownerName = contacts[0].Owner.Name;
                        info.recordType = 'Contact';
                        info.recordName = contacts[0].Name;
                        return info;
                    }
                    info.errorMessage = 'Could not find any Contact matching "' + cleanName + '". Please verify the contact name.';
                    return info;
                }
            }

            // B. No Record Type Specified -> Smart Ambiguity Check
            List<Opportunity> exactOpps = [SELECT Id, Name, OwnerId, Owner.Name FROM Opportunity WHERE Name LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];
            List<Account> exactAccs = [SELECT Id, Name, OwnerId, Owner.Name FROM Account WHERE Name LIKE :wildcard OR Phone LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];

            // Ambiguity Guardrail: Both Opportunity and Account found!
            if (!exactOpps.isEmpty() && !exactAccs.isEmpty()) {
                info.errorMessage = 'I found both an Account ("' + exactAccs[0].Name + '") and an Opportunity ("' + exactOpps[0].Name + '") for "' + cleanName + '". Which record would you like to link this task to (Account or Opportunity)?';
                return info;
            }

            if (!exactOpps.isEmpty()) {
                info.whatId = exactOpps[0].Id;
                info.ownerId = exactOpps[0].OwnerId;
                info.ownerName = exactOpps[0].Owner.Name;
                info.recordType = 'Opportunity';
                info.recordName = exactOpps[0].Name;
                return info;
            }

            if (!exactAccs.isEmpty()) {
                info.whatId = exactAccs[0].Id;
                info.ownerId = exactAccs[0].OwnerId;
                info.ownerName = exactAccs[0].Owner.Name;
                info.recordType = 'Account';
                info.recordName = exactAccs[0].Name;
                return info;
            }

            // Check Lead
            List<Lead> exactLeads = [SELECT Id, Name, Company, OwnerId, Owner.Name FROM Lead WHERE (Name LIKE :wildcard OR Company LIKE :wildcard) AND IsConverted = false ORDER BY CreatedDate DESC LIMIT 1];
            if (!exactLeads.isEmpty()) {
                info.whoId = exactLeads[0].Id;
                info.ownerId = exactLeads[0].OwnerId;
                info.ownerName = exactLeads[0].Owner.Name;
                info.recordType = 'Lead';
                info.recordName = exactLeads[0].Name;
                return info;
            }

            // Check Contact
            List<Contact> exactContacts = [SELECT Id, Name, OwnerId, Owner.Name FROM Contact WHERE Name LIKE :wildcard ORDER BY CreatedDate DESC LIMIT 1];
            if (!exactContacts.isEmpty()) {
                info.whoId = exactContacts[0].Id;
                info.ownerId = exactContacts[0].OwnerId;
                info.ownerName = exactContacts[0].Owner.Name;
                info.recordType = 'Contact';
                info.recordName = exactContacts[0].Name;
                return info;
            }

            // Fuzzy / Partial Fallback: Ask user for confirmation
            List<Opportunity> partialOpps = [SELECT Id, Name FROM Opportunity WHERE Name LIKE :firstWordWildcard ORDER BY CreatedDate DESC LIMIT 1];
            if (!partialOpps.isEmpty()) {
                info.errorMessage = 'Could not find an exact match for "' + cleanName + '", but found Opportunity "' + partialOpps[0].Name + '". Did you mean this deal? Please confirm so I can link it correctly.';
                return info;
            }

            List<Account> partialAccs = [SELECT Id, Name FROM Account WHERE Name LIKE :firstWordWildcard ORDER BY CreatedDate DESC LIMIT 1];
            if (!partialAccs.isEmpty()) {
                info.errorMessage = 'Could not find an exact match for "' + cleanName + '", but found Account "' + partialAccs[0].Name + '". Did you mean this account? Please confirm so I can link it correctly.';
                return info;
            }

            info.errorMessage = 'Could not find any matching Account, Opportunity, Lead, or Contact for "' + req.recordName + '". Would you like to check the spelling or provide another name, or abort?';
            return info;
        }

        return info;
    }
}
