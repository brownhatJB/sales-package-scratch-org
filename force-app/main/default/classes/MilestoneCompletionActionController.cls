public with sharing class MilestoneCompletionActionController {

    public class MilestoneData {
        @AuraEnabled public Id id;
        @AuraEnabled public String milestoneName;
        @AuraEnabled public Date tentativeDate;
        @AuraEnabled public Date actualDate;
    }

    @AuraEnabled
    public static MilestoneData getMilestone(Id milestoneId) {

        if (milestoneId == null) {
            throw new AuraHandledException('Milestone Id is required.');
        }

        Milestone__c milestone = [
            SELECT
                Id,
                Name,
                Tentative_Due_Date_of_Completion__c,
                Actual_Date_of_Completion__c
            FROM Milestone__c
            WHERE Id = :milestoneId
            LIMIT 1
        ];

        MilestoneData result = new MilestoneData();

        result.id = milestone.Id;
        result.milestoneName = milestone.Name;
        result.tentativeDate =
            milestone.Tentative_Due_Date_of_Completion__c;
        result.actualDate =
            milestone.Actual_Date_of_Completion__c;

        return result;
    }


    @AuraEnabled
    public static void updateCompletion(
        Id milestoneId,
        String dateType,
        Date newDate,
        String comments
    ) {

        if (milestoneId == null) {
            throw new AuraHandledException('Milestone Id is required.');
        }

        if (String.isBlank(dateType)) {
            throw new AuraHandledException(
                'Please select a completion date type.'
            );
        }

        if (newDate == null) {
            throw new AuraHandledException(
                'Please select a completion date.'
            );
        }

        if (String.isBlank(comments)) {
            throw new AuraHandledException(
                'Comments are required.'
            );
        }

        comments = comments.trim();

        if (comments.length() == 0) {
            throw new AuraHandledException(
                'Comments are required.'
            );
        }

        Milestone__c milestone = [
            SELECT
                Id,
                Name,
                Tentative_Due_Date_of_Completion__c,
                Actual_Date_of_Completion__c
            FROM Milestone__c
            WHERE Id = :milestoneId
            LIMIT 1
            FOR UPDATE
        ];

        Date oldDate;

        // checking if the actual date is already set or not
        if (
            dateType == 'TENTATIVE' &&
            milestone.Actual_Date_of_Completion__c != null
        ) {
            throw new AuraHandledException(
                'The Actual Completion Date has already been set. ' +
                'Only the Actual Completion Date can be updated.'
            );
        }

        if (dateType == 'TENTATIVE') {

            oldDate =
                milestone.Tentative_Due_Date_of_Completion__c;

            milestone.Tentative_Due_Date_of_Completion__c = newDate;

        } else if (dateType == 'ACTUAL') {

            oldDate =
                milestone.Actual_Date_of_Completion__c;

            milestone.Actual_Date_of_Completion__c = newDate;

        } else {

            throw new AuraHandledException(
                'Invalid completion date type.'
            );
        }

        milestone.Comments__c = comments;

        update milestone;


        // Post to Chatter
        String dateTypeLabel =
            dateType == 'ACTUAL'
                ? 'Actual Completion Date'
                : 'Tentative Completion Date';

        String oldDateText =
            oldDate == null
                ? 'Not Set'
                : String.valueOf(oldDate);

        String newDateText =
            String.valueOf(newDate);

        String chatterBody =
            'Completion details updated.\n\n' +
            'Date Type: ' + dateTypeLabel + '\n' +
            'Previous Date: ' + oldDateText + '\n' +
            'New Date: ' + newDateText + '\n' +
            'Comments: ' + comments;

        FeedItem post = new FeedItem();

        post.ParentId = milestone.Id;
        post.Body = chatterBody;

        insert post;
    }
}