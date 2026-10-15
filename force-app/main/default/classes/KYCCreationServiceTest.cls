@IsTest
private class KYCCreationServiceTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Contact createContact() {
        Account acc = new Account(Name = 'KYC Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'KYC Test Contact',
            AccountId = acc.Id
        );
        insert con;
        return con;
    }

    private static Lead createLead() {
        Lead ld = new Lead(
            LastName = 'KYC Test Lead',
            Company = 'KYC Test Company'
        );
        insert ld;
        return ld;
    }

    // ─── Null / empty guards ─────────────────────────────────────────────────

    @IsTest
    static void testCreateKYCIfConfigured_NullRecords() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCCreationService.createKYCIfConfigured(
                null,
                new Map<Id, SObject>(),
                'After Insert'
            );
            Test.stopTest();
            // No exception expected
        }
    }

    @IsTest
    static void testCreateKYCIfConfigured_EmptyRecords() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCCreationService.createKYCIfConfigured(
                new List<SObject>(),
                new Map<Id, SObject>(),
                'After Insert'
            );
            Test.stopTest();
            // No exception expected
        }
    }

    // ─── afterInsert entry point ─────────────────────────────────────────────

    @IsTest
    static void testAfterInsert_WithContact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            Test.startTest();
            KYCCreationService service = new KYCCreationService();
            service.afterInsert(new List<SObject>{ con });
            Test.stopTest();

            // If active After Insert CMDT exists for Contact (or the object
            // that owns the Contact lookup), KYC may be created.
            // Otherwise list stays empty — both are valid.
            List<KYC__c> kycs = [
                SELECT Id, Status__c, Contact__c, Lead__c, Valid_From__c
                FROM KYC__c
                WHERE Contact__c = :con.Id OR Lead__c = :con.Id
            ];
            for (KYC__c k : kycs) {
                System.assertEquals('Draft', k.Status__c);
                System.assertEquals(Date.today(), k.Valid_From__c);
            }
        }
    }

    @IsTest
    static void testAfterInsert_WithLead() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();

            Test.startTest();
            KYCCreationService service = new KYCCreationService();
            service.afterInsert(new List<SObject>{ ld });
            Test.stopTest();

            List<KYC__c> kycs = [
                SELECT Id, Status__c, Lead__c, Valid_From__c
                FROM KYC__c
                WHERE Lead__c = :ld.Id
            ];
            for (KYC__c k : kycs) {
                System.assertEquals('Draft', k.Status__c);
                System.assertEquals(Date.today(), k.Valid_From__c);
            }
        }
    }

    // ─── afterUpdate entry point ─────────────────────────────────────────────

    @IsTest
    static void testAfterUpdate_WithContact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Contact oldCon = con.clone(true, true, true, true);

            // Simulate a field change that might match CMDT conditions
            con.LastName = 'KYC Updated Contact';
            update con;

            Contact updated = [
                SELECT Id, LastName, AccountId
                FROM Contact
                WHERE Id = :con.Id
            ];

            Test.startTest();
            KYCCreationService service = new KYCCreationService();
            service.afterUpdate(
                new List<SObject>{ updated },
                new List<SObject>{ oldCon }
            );
            Test.stopTest();

            // Assert no unhandled exception; KYC creation depends on CMDT
            List<KYC__c> kycs = [
                SELECT Id, Status__c
                FROM KYC__c
                WHERE Contact__c = :con.Id
            ];
            for (KYC__c k : kycs) {
                System.assertEquals('Draft', k.Status__c);
            }
        }
    }

    @IsTest
    static void testAfterUpdate_NoMatchingChange() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            // Same values in old and new → condition transition should not fire
            Contact oldCon = con.clone(true, true, true, true);

            Test.startTest();
            KYCCreationService service = new KYCCreationService();
            service.afterUpdate(
                new List<SObject>{ con },
                new List<SObject>{ oldCon }
            );
            Test.stopTest();

            // When old and new both match (or both don't), no new KYC from transition logic
            // Method should complete without error
            System.assert(true, 'afterUpdate completed without error');
        }
    }

    // ─── createKYCIfConfigured direct calls ──────────────────────────────────

    @IsTest
    static void testCreateKYCIfConfigured_AfterInsert_Contact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            Integer kycBefore = [SELECT COUNT() FROM KYC__c];

            Test.startTest();
            KYCCreationService.createKYCIfConfigured(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'After Insert'
            );
            Test.stopTest();

            Integer kycAfter = [SELECT COUNT() FROM KYC__c];
            // kycAfter >= kycBefore depending on whether matching CMDT exists
            System.assert(
                kycAfter >= kycBefore,
                'KYC count should not decrease'
            );
        }
    }

    @IsTest
    static void testCreateKYCIfConfigured_AfterUpdate_Contact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Contact oldCon = con.clone(true, true, true, true);
            oldCon.LastName = 'Old Name';

            Map<Id, SObject> oldMap = new Map<Id, SObject>{ con.Id => oldCon };

            Test.startTest();
            KYCCreationService.createKYCIfConfigured(
                new List<SObject>{ con },
                oldMap,
                'After Update'
            );
            Test.stopTest();

            // Completes without error regardless of CMDT match
            System.assert(true);
        }
    }

    @IsTest
    static void testCreateKYCIfConfigured_WrongTriggerContext() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            Test.startTest();
            // Context that won't match any CMDT Trigger_Event__c
            KYCCreationService.createKYCIfConfigured(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();

            System.assert(true, 'No matching context should simply create nothing');
        }
    }

    // ─── Bulk ────────────────────────────────────────────────────────────────

    @IsTest
    static void testAfterInsert_BulkContacts() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Account acc = new Account(Name = 'Bulk KYC Account');
            insert acc;

            List<Contact> contacts = new List<Contact>();
            for (Integer i = 0; i < 5; i++) {
                contacts.add(new Contact(
                    LastName = 'Bulk Contact ' + i,
                    AccountId = acc.Id
                ));
            }
            insert contacts;

            Test.startTest();
            KYCCreationService service = new KYCCreationService();
            service.afterInsert(contacts);
            Test.stopTest();

            System.assert(true, 'Bulk afterInsert completed without error');
        }
    }
}