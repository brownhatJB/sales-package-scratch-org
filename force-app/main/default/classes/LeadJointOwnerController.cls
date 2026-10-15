
public with sharing class LeadJointOwnerController {

    private static final String BUYER_TYPE_INDIVIDUAL = 'Individual';
    private static final String BUYER_TYPE_JOINT = 'Joint Owner';

    // --------------------------------------------------
    // INITIAL DATA
    // --------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialData(Id leadId) {
        if (leadId == null || leadId.getSObjectType() != Lead.SObjectType) {
            throw new AuraHandledException('A valid Lead ID is required.');
        }

        Lead leadRecord = [
            SELECT Id, pflexmet__Buyer_Type__c,
                (
                    SELECT Id,
                           pflexmet__Customer_Type__c,
                           pflexmet__Customer_Name__c,
                           pflexmet__Ownership_Order__c,
                           pflexmet__Percentage_of_Owner__c,
                           pflexmet__IsPrimary__c
                    FROM pflexmet__Joint_Owners__r
                    ORDER BY pflexmet__Ownership_Order__c ASC
                )
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        List<Map<String, Object>> ownerRows =
            new List<Map<String, Object>>();

        for (pflexmet__Joint_Owner__c owner :
             leadRecord.pflexmet__Joint_Owners__r) {

            Map<String, Object> row = new Map<String, Object>();

            row.put('id', owner.Id);
            row.put('customerContactId',
                owner.pflexmet__Customer_Name__c);
            row.put('customerType',
                owner.pflexmet__Customer_Type__c);
            row.put('ownershipOrder',
                owner.pflexmet__Ownership_Order__c);
            row.put('ownershipPercentage',
                owner.pflexmet__Percentage_of_Owner__c);
            row.put('isPrimary',
                owner.pflexmet__IsPrimary__c);

            ownerRows.add(row);
        }

        // Return active customer-type picklist values as combobox options.
        List<Map<String, String>> customerTypeValues =
            new List<Map<String, String>>();

        Schema.DescribeFieldResult customerTypeDescribe =
            pflexmet__Joint_Owner__c.pflexmet__Customer_Type__c
                .getDescribe();

        for (Schema.PicklistEntry entry :
             customerTypeDescribe.getPicklistValues()) {

            if (entry.isActive()) {
                customerTypeValues.add(
                    new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    }
                );
            }
        }

        Map<String, Object> response = new Map<String, Object>();
        response.put('buyerType',
            leadRecord.pflexmet__Buyer_Type__c);
        response.put('owners', ownerRows);
        response.put('customerTypeValues', customerTypeValues);

        return response;
    }

    // --------------------------------------------------
    // SAVE OWNERS
    // --------------------------------------------------

    @AuraEnabled
    public static Map<String, String> saveOwners(
        Id leadId,
        String ownersJson,
        List<Id> deletedOwnerIds
    ) {
        if (leadId == null || leadId.getSObjectType() != Lead.SObjectType) {
            throw new AuraHandledException('A valid Lead ID is required.');
        }

        if (String.isBlank(ownersJson)) {
            throw new AuraHandledException(
                'Owner data is missing. Please refresh and try again.'
            );
        }

        List<Object> rawOwners;

        try {
            rawOwners = (List<Object>) JSON.deserializeUntyped(ownersJson);
        } catch (Exception ex) {
            throw new AuraHandledException(
                'The submitted owner data is invalid.'
            );
        }

        if (rawOwners == null) {
            throw new AuraHandledException('Owner data is required.');
        }

        if (deletedOwnerIds == null) {
            deletedOwnerIds = new List<Id>();
        }

        // Lock the Lead so concurrent saves for the same Lead are serialized.
        Lead leadRecord;

        try {
            leadRecord = [
                SELECT Id, pflexmet__Buyer_Type__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
                FOR UPDATE
            ];
        } catch (QueryException ex) {
            throw new AuraHandledException(
                'The Lead could not be accessed or no longer exists.'
            );
        }

        // Read all existing joint owners belonging to this Lead.
        List<pflexmet__Joint_Owner__c> existingOwners = [
            SELECT Id,
                   pflexmet__Lead__c,
                   pflexmet__Customer_Type__c,
                   pflexmet__Customer_Name__c,
                   pflexmet__Ownership_Order__c,
                   pflexmet__Percentage_of_Owner__c,
                   pflexmet__IsPrimary__c
            FROM pflexmet__Joint_Owner__c
            WHERE pflexmet__Lead__c = :leadId
        ];

        Map<Id, pflexmet__Joint_Owner__c> existingById =
            new Map<Id, pflexmet__Joint_Owner__c>(existingOwners);

        Set<Id> deletedIds = new Set<Id>();

        for (Id deletedId : deletedOwnerIds) {
            if (deletedId == null) {
                continue;
            }

            if (!existingById.containsKey(deletedId)) {
                throw new AuraHandledException(
                    'A selected owner to remove does not belong to this Lead.'
                );
            }

            deletedIds.add(deletedId);
        }

        // Parse incoming owner data.
        List<pflexmet__Joint_Owner__c> recordsToSave =
            new List<pflexmet__Joint_Owner__c>();

        Set<Id> submittedExistingIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Integer> orders = new Set<Integer>();

        Decimal percentageTotal = 0;
        Integer primaryCount = 0;
        Integer primaryOrder;
        Integer ownerCount = rawOwners.size();

        Map<String, Schema.SObjectField> ownerFieldMap =
            Schema.SObjectType.pflexmet__Joint_Owner__c.fields.getMap();

        Set<String> allowedCustomerTypes = new Set<String>();

        for (Schema.PicklistEntry entry :
             ownerFieldMap.get('pflexmet__Customer_Type__c')
                 .getDescribe().getPicklistValues()) {

            if (entry.isActive()) {
                allowedCustomerTypes.add(entry.getValue());
            }
        }

        for (Object rawItem : rawOwners) {
            Map<String, Object> item;

            try {
                item = (Map<String, Object>) rawItem;
            } catch (Exception ex) {
                throw new AuraHandledException(
                    'One of the submitted owner records is invalid.'
                );
            }

            String idText = asString(item.get('id'));
            String contactText = asString(item.get('customerContactId'));
            String customerType = asString(item.get('customerType'));

            Id ownerId;
            Id contactId;

            try {
                if (!String.isBlank(idText)) {
                    ownerId = Id.valueOf(idText);
                }

                if (!String.isBlank(contactText)) {
                    contactId = Id.valueOf(contactText);
                }
            } catch (Exception ex) {
                throw new AuraHandledException(
                    'An owner or Contact ID is invalid.'
                );
            }

            if (contactId == null ||
                contactId.getSObjectType() != Contact.SObjectType) {
                throw new AuraHandledException(
                    'Select a valid Contact for every owner.'
                );
            }

            contactIds.add(contactId);

            if (String.isBlank(customerType) ||
                !allowedCustomerTypes.contains(customerType)) {
                throw new AuraHandledException(
                    'Select a valid Customer Type for every owner.'
                );
            }

            Integer ownershipOrder =
                asInteger(item.get('ownershipOrder'));

            Decimal ownershipPercentage =
                asDecimal(item.get('ownershipPercentage'));

            Boolean isPrimary = item.get('isPrimary') == true;

            if (ownershipOrder == null || ownershipOrder < 1) {
                throw new AuraHandledException(
                    'Ownership order must be a positive integer.'
                );
            }

            if (orders.contains(ownershipOrder)) {
                throw new AuraHandledException(
                    'Ownership order values must be unique.'
                );
            }

            orders.add(ownershipOrder);

            if (ownershipPercentage == null ||
                ownershipPercentage <= 0 ||
                ownershipPercentage > 100) {
                throw new AuraHandledException(
                    'Each ownership percentage must be greater than 0 and no greater than 100.'
                );
            }

            percentageTotal += ownershipPercentage;

            if (isPrimary) {
                primaryCount++;
                primaryOrder = ownershipOrder;
            }

            pflexmet__Joint_Owner__c ownerRecord =
                new pflexmet__Joint_Owner__c();

            if (ownerId != null) {
                if (!existingById.containsKey(ownerId)) {
                    throw new AuraHandledException(
                        'An owner record does not belong to this Lead.'
                    );
                }

                if (deletedIds.contains(ownerId)) {
                    throw new AuraHandledException(
                        'An owner cannot be updated and deleted in the same request.'
                    );
                }

                if (submittedExistingIds.contains(ownerId)) {
                    throw new AuraHandledException(
                        'An owner was submitted more than once.'
                    );
                }

                submittedExistingIds.add(ownerId);
                ownerRecord.Id = ownerId;
            }

            ownerRecord.pflexmet__Lead__c = leadId;
            ownerRecord.pflexmet__Customer_Name__c = contactId;
            ownerRecord.pflexmet__Customer_Type__c = customerType;
            ownerRecord.pflexmet__Ownership_Order__c = ownershipOrder;
            ownerRecord.pflexmet__Percentage_of_Owner__c =
                ownershipPercentage;
            ownerRecord.pflexmet__IsPrimary__c = isPrimary;

            recordsToSave.add(ownerRecord);
        }

        // Verify the selected Contacts exist and are accessible.
        Set<Id> foundContactIds = new Map<Id, Contact>([
            SELECT Id
            FROM Contact
            WHERE Id IN :contactIds
        ]).keySet();

        if (foundContactIds.size() != contactIds.size()) {
            throw new AuraHandledException(
                'One or more selected Contacts could not be found or accessed.'
            );
        }

        // Validate owner count, ordering, primary, and allocation.
        if (ownerCount > 0) {
            if (primaryCount != 1) {
                throw new AuraHandledException(
                    'Exactly one owner must be marked as primary.'
                );
            }

            if (primaryOrder != 1) {
                throw new AuraHandledException(
                    'The primary owner must have ownership order 1.'
                );
            }

            for (Integer orderValue = 1;
                 orderValue <= ownerCount;
                 orderValue++) {

                if (!orders.contains(orderValue)) {
                    throw new AuraHandledException(
                        'Ownership order must be continuous, starting at 1.'
                    );
                }
            }

            if (Math.abs(percentageTotal - 100) > 0.000001) {
                throw new AuraHandledException(
                    'Ownership percentages must total exactly 100%.'
                );
            }
        } else if (deletedIds.isEmpty()) {
            throw new AuraHandledException(
                'Add at least one owner or remove an existing owner.'
            );
        }

        // The final primary owner can only be removed if it is the
        // sole existing owner. Reassigning primary to another submitted
        // owner before removing the old primary is allowed.
        if (ownerCount == 0) {
            for (Id deletedId : deletedIds) {
                pflexmet__Joint_Owner__c existingOwner =
                    existingById.get(deletedId);

                if (existingOwner.pflexmet__IsPrimary__c == true &&
                    existingById.size() != 1) {
                    throw new AuraHandledException(
                        'The primary owner can only be removed when it is the sole joint owner.'
                    );
                }
            }
        }

        // Delete, then save, and update Buyer Type in the same transaction.
        if (!deletedIds.isEmpty()) {
            List<pflexmet__Joint_Owner__c> recordsToDelete =
                new List<pflexmet__Joint_Owner__c>();

            for (Id idValue : deletedIds) {
                pflexmet__Joint_Owner__c ownerRecord =
                    existingById.get(idValue);

                if (ownerRecord != null) {
                    recordsToDelete.add(ownerRecord);
                }
            }

            if (!recordsToDelete.isEmpty()) {
                delete recordsToDelete;
            }
        }

        if (!recordsToSave.isEmpty()) {
            upsert recordsToSave;
        }

        leadRecord.pflexmet__Buyer_Type__c =
            ownerCount == 0
                ? BUYER_TYPE_INDIVIDUAL
                : BUYER_TYPE_JOINT;

        update leadRecord;

        return new Map<String, String>{
            'message' => ownerCount == 0
                ? 'Joint owners removed. Buyer Type changed to Individual.'
                : 'Joint owners saved successfully.'
        };
    }

    // --------------------------------------------------
    // JSON VALUE HELPERS
    // --------------------------------------------------

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Integer asInteger(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }

        try {
            Decimal numberValue = Decimal.valueOf(String.valueOf(value));

            if (numberValue != numberValue.setScale(0)) {
                throw new AuraHandledException(
                    'Ownership order must be a whole number.'
                );
            }

            return numberValue.intValue();
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Ownership order must be a valid whole number.'
            );
        }
    }

    private static Decimal asDecimal(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }

        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Ownership percentage must be a valid number.'
            );
        }
    }
}
