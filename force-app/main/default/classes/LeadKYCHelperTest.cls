@IsTest
private class LeadKYCHelperTest {

    // ------------------------------------------------------------
    // Test data helpers
    // ------------------------------------------------------------

    private static Contact createContact(String kycStatus) {
        Account acc = new Account(
            Name = 'Lead KYC Test Account'
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Lead KYC Test Contact',
            AccountId = acc.Id,
            KYC_Status__c = kycStatus
        );
        insert con;

        return con;
    }

    private static Lead createLead(
        String lastName,
        Id contactId,
        String kycStatus,
        String stage
    ) {
        Lead ld = new Lead(
            LastName = lastName,
            Company = 'Lead KYC Test Company',
            Contact__c = contactId,
            KYC_Status__c = kycStatus,
            Stage__c = stage
        );
        insert ld;

        return ld;
    }

    // ------------------------------------------------------------
    // 1. Null input
    // ------------------------------------------------------------

    @IsTest
    static void testUpdateLeadKYCStatus_NullInput() {
        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(null);
        Test.stopTest();

        System.assert(true, 'Null input should return without an exception');
    }

    // ------------------------------------------------------------
    // 2. Empty input
    // ------------------------------------------------------------

    @IsTest
    static void testUpdateLeadKYCStatus_EmptyInput() {
        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(new List<Lead>());
        Test.stopTest();

        System.assert(true, 'Empty input should return without an exception');
    }

    // ------------------------------------------------------------
    // 3. Lead without Contact__c
    // ------------------------------------------------------------

    @IsTest
    static void testLeadWithoutContact() {
        Lead ld = createLead(
            'No Contact',
            null,
            null,
            null
        );

        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(
            new List<Lead>{ ld }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, Contact__c, KYC_Status__c,
                   All_Documents_Validated__c,
                   All_Required_Docs_Uploaded__c,
                   Create_Profile__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals(null, actual.Contact__c);
        System.assertEquals(null, actual.KYC_Status__c);
        System.assertEquals(false, actual.All_Documents_Validated__c);
        System.assertEquals(false, actual.All_Required_Docs_Uploaded__c);
        System.assertEquals(false, actual.Create_Profile__c);
    }

    // ------------------------------------------------------------
    // 4. Approved Contact updates the associated Lead
    // ------------------------------------------------------------

    @IsTest
    static void testApprovedContactUpdatesLead() {
        Contact con = createContact('Approved');

        Lead ld = createLead(
            'Approved Lead',
            con.Id,
            null,
            null
        );

        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(
            new List<Lead>{ ld }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, KYC_Status__c,
                   All_Documents_Validated__c,
                   All_Required_Docs_Uploaded__c,
                   Create_Profile__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Approved', actual.KYC_Status__c);
        System.assertEquals(true, actual.All_Documents_Validated__c);
        System.assertEquals(true, actual.All_Required_Docs_Uploaded__c);
        System.assertEquals(true, actual.Create_Profile__c);
        System.assertEquals('Site Visit', actual.Stage__c);
    }

    // ------------------------------------------------------------
    // 5. Non-approved Contact status
    // ------------------------------------------------------------

    @IsTest
    static void testNonApprovedContactUpdatesLead() {
        Contact con = createContact(null);

        Lead ld = createLead(
            'Non Approved Lead',
            con.Id,
            'Approved',
            'New'
        );

        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(
            new List<Lead>{ ld }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, KYC_Status__c,
                   All_Documents_Validated__c,
                   All_Required_Docs_Uploaded__c,
                   Create_Profile__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals(null, actual.KYC_Status__c);
        System.assertEquals(false, actual.All_Documents_Validated__c);
        System.assertEquals(false, actual.All_Required_Docs_Uploaded__c);
        System.assertEquals(false, actual.Create_Profile__c);
        System.assertEquals(
            'New',
            actual.Stage__c,
            'Non-approved status should preserve the existing stage'
        );
    }

    // ------------------------------------------------------------
    // 6. Status already matches
    // ------------------------------------------------------------

    @IsTest
    static void testMatchingStatusDoesNotChangeLead() {
        Contact con = createContact('Approved');

        Lead ld = createLead(
            'Matching Status Lead',
            con.Id,
            'Approved',
            'New'
        );

        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(
            new List<Lead>{ ld }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, KYC_Status__c,
                   All_Documents_Validated__c,
                   All_Required_Docs_Uploaded__c,
                   Create_Profile__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Approved', actual.KYC_Status__c);
        System.assertEquals(
            false,
            actual.All_Documents_Validated__c,
            'The helper should not change other fields when statuses match'
        );
        System.assertEquals('New', actual.Stage__c);
    }

    // ------------------------------------------------------------
    // 7. Multiple Leads associated with one Contact
    // ------------------------------------------------------------

    @IsTest
    static void testMultipleLeadsForSameContact() {
        Contact con = createContact('Approved');

        Lead firstLead = createLead(
            'First Lead',
            con.Id,
            null,
            null
        );

        Lead secondLead = createLead(
            'Second Lead',
            con.Id,
            null,
            null
        );

        Test.startTest();
        LeadKYCHelper.updateLeadKYCStatus(
            new List<Lead>{ firstLead }
        );
        Test.stopTest();

        Map<Id, Lead> actualLeads = new Map<Id, Lead>([
            SELECT Id, KYC_Status__c,
                   All_Documents_Validated__c,
                   All_Required_Docs_Uploaded__c,
                   Create_Profile__c, Stage__c
            FROM Lead
            WHERE Id IN :new Set<Id>{ firstLead.Id, secondLead.Id }
        ]);

        for (Lead actual : actualLeads.values()) {
            System.assertEquals('Approved', actual.KYC_Status__c);
            System.assertEquals(true, actual.All_Documents_Validated__c);
            System.assertEquals(true, actual.All_Required_Docs_Uploaded__c);
            System.assertEquals(true, actual.Create_Profile__c);
            System.assertEquals('Site Visit', actual.Stage__c);
        }

        System.assertEquals(2, actualLeads.size());
    }

    // ------------------------------------------------------------
    // 8. afterInsert entry point
    // ------------------------------------------------------------

    @IsTest
    static void testAfterInsertEntryPoint() {
        Contact con = createContact('Approved');

        Lead ld = createLead(
            'After Insert Lead',
            con.Id,
            null,
            null
        );

        Test.startTest();
        new LeadKYCHelper().afterInsert(
            new List<Lead>{ ld }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, KYC_Status__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Approved', actual.KYC_Status__c);
        System.assertEquals('Site Visit', actual.Stage__c);
    }

    // ------------------------------------------------------------
    // 9. afterUpdate entry point
    // ------------------------------------------------------------

    @IsTest
    static void testAfterUpdateEntryPoint() {
        Contact con = createContact('Approved');

        Lead ld = createLead(
            'After Update Lead',
            con.Id,
            null,
            null
        );

        Lead oldLead = ld.clone(true, true, true, true);

        Test.startTest();
        new LeadKYCHelper().afterUpdate(
            new List<Lead>{ ld },
            new List<Lead>{ oldLead }
        );
        Test.stopTest();

        Lead actual = [
            SELECT Id, KYC_Status__c, Stage__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Approved', actual.KYC_Status__c);
        System.assertEquals('Site Visit', actual.Stage__c);
    }
}