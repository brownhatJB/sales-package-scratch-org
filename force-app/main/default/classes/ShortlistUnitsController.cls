public with sharing class ShortlistUnitsController {

    @AuraEnabled
    public static String savePreference(
        List<Id> unitIds,
        Id opportunityId,
        Id enquiryId,
        Id leadId
    ) {

        if (unitIds == null || unitIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one unit.');
        }

        Unit_Shortlist__c targetPref;
        List<Unit_Shortlist__c> existing;

        // --------------------------
        // Opportunity Flow
        // -------------------------- 
        if (opportunityId != null) {

            Opportunity opp = [
                SELECT Id, Name, Contact__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            existing = [
                SELECT Id
                FROM Unit_Shortlist__c
                WHERE Opportunity__c = :opportunityId
                LIMIT 1
            ];

            if (!existing.isEmpty()) {

                targetPref = existing[0];

            } else {

                targetPref = new Unit_Shortlist__c(
                    Opportunity__c = opportunityId,
                    Contact__c = opp.Contact__c,
                    Name = ('Shortlisted Units - ' + opp.Name).left(80)
                );

                insert targetPref;
            }
        }

        // --------------------------
        // Enquiry Flow
        // --------------------------
        else if (enquiryId != null) {

            existing = [
                SELECT Id
                FROM Unit_Shortlist__c
                WHERE pflexmet__Enquiry__c = :enquiryId
                LIMIT 1
            ];

            if (!existing.isEmpty()) {

                targetPref = existing[0];

            } else {

                targetPref = new Unit_Shortlist__c(
                    pflexmet__Enquiry__c = enquiryId,
                    Name = ('Shortlisted Units - ' + enquiryId).left(80)
                );

                insert targetPref;
            }
        }

        // --------------------------
        // Lead Flow
        // --------------------------
        else if (leadId != null) {

            existing = [
                SELECT Id
                FROM Unit_Shortlist__c
                WHERE Lead__c = :leadId
                LIMIT 1
            ];

            if (!existing.isEmpty()) {

                targetPref = existing[0];

            } else {

                Lead ld = [
                    SELECT Id, Name
                    FROM Lead
                    WHERE Id = :leadId
                    LIMIT 1
                ];

                targetPref = new Unit_Shortlist__c(
                    Lead__c = leadId,
                    Name = ('Shortlisted Units - ' + ld.Name).left(80)
                );

                insert targetPref;
            }
        }
        else {
            throw new AuraHandledException(
                'Opportunity, Enquiry or Lead Id is required.'
            );
        }

        List<Unit_Shortlist_Item__c> itemsToUpsert =
            new List<Unit_Shortlist_Item__c>();

        for (Id uId : unitIds) {

            itemsToUpsert.add(
                new Unit_Shortlist_Item__c(
                    Unit_Shortlist__c = targetPref.Id,
                    Units__c = uId,
                    Unique_Key__c = targetPref.Id + '-' + uId,
                    Status__c = 'Active'
                )
            );
        }

        if (!itemsToUpsert.isEmpty()) {
            upsert itemsToUpsert Unique_Key__c;
        }

        Integer total = [
            SELECT COUNT()
            FROM Unit_Shortlist_Item__c
            WHERE Unit_Shortlist__c = :targetPref.Id
        ];

        return 'Units Shortlisted. Total units now: ' + total;
    }
}