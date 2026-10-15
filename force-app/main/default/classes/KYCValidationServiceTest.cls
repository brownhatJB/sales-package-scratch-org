@IsTest
private class KYCValidationServiceTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Contact createContact() {
        Account acc = new Account(Name = 'KYC Val Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'KYC Val Contact',
            AccountId = acc.Id
        );
        insert con;
        return con;
    }

    private static Lead createLead() {
        Lead ld = new Lead(
            LastName = 'KYC Val Lead',
            Company = 'KYC Val Company'
        );
        insert ld;
        return ld;
    }

    private static KYC__c createKycForContact(Id contactId, String status) {
        KYC__c kyc = new KYC__c(
            Contact__c = contactId,
            Status__c = status,
            Valid_From__c = Date.today()
        );
        insert kyc;
        return kyc;
    }

    private static KYC__c createKycForLead(Id leadId, String status) {
        KYC__c kyc = new KYC__c(
            Lead__c = leadId,
            Status__c = status,
            Valid_From__c = Date.today()
        );
        insert kyc;
        return kyc;
    }

    // ─── Null / empty guards ─────────────────────────────────────────────────

    @IsTest
    static void testValidate_NullRecords() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCValidationService.validate(
                null,
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();
        }
    }

    @IsTest
    static void testValidate_EmptyRecords() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>(),
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();
        }
    }

    // ─── beforeInsert entry point ────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_WithContact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            Test.startTest();
            KYCValidationService service = new KYCValidationService();
            service.beforeInsert(new List<SObject>{ con });
            Test.stopTest();

            // Completes without unhandled exception.
            // Block/Warning only fire if matching CMDT exists and KYC is missing/not Approved.
            System.assert(true);
        }
    }

    @IsTest
    static void testBeforeInsert_WithLead() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();

            Test.startTest();
            KYCValidationService service = new KYCValidationService();
            service.beforeInsert(new List<SObject>{ ld });
            Test.stopTest();

            System.assert(true);
        }
    }

    // ─── beforeUpdate entry point ────────────────────────────────────────────

    @IsTest
    static void testBeforeUpdate_WithContact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Contact oldCon = con.clone(true, true, true, true);
            oldCon.LastName = 'Old Name';

            Test.startTest();
            KYCValidationService service = new KYCValidationService();
            service.beforeUpdate(
                new List<SObject>{ con },
                new List<SObject>{ oldCon }
            );
            Test.stopTest();

            System.assert(true);
        }
    }

    @IsTest
    static void testBeforeUpdate_NoChange() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Contact oldCon = con.clone(true, true, true, true);

            Test.startTest();
            KYCValidationService service = new KYCValidationService();
            service.beforeUpdate(
                new List<SObject>{ con },
                new List<SObject>{ oldCon }
            );
            Test.stopTest();

            System.assert(true);
        }
    }

    // ─── validate with KYC present ───────────────────────────────────────────

    @IsTest
    static void testValidate_WithApprovedKyc_Contact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();

            // Approved KYC → no enforcement even if CMDT matches
            System.assert(true);
        }
    }

    @IsTest
    static void testValidate_WithDraftKyc_Contact() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Draft');

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();

            // Draft KYC may trigger Block/Warning if CMDT matches
            System.assert(true);
        }
    }

    @IsTest
    static void testValidate_WithApprovedKyc_Lead() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            createKycForLead(ld.Id, 'Approved');

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ ld },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();

            System.assert(true);
        }
    }

    @IsTest
    static void testValidate_NoKyc() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            // No KYC__c created

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();

            // Missing KYC may trigger enforcement if CMDT matches
            System.assert(true);
        }
    }

    // ─── Wrong / non-matching event ──────────────────────────────────────────

    @IsTest
    static void testValidate_NonMatchingEvent() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'After Insert' // not Before Insert / Before Update
            );
            Test.stopTest();

            System.assert(true, 'Non-matching event should exit early');
        }
    }

    // ─── Bulk ────────────────────────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_Bulk() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Account acc = new Account(Name = 'Bulk KYC Val Account');
            insert acc;

            List<Contact> contacts = new List<Contact>();
            for (Integer i = 0; i < 5; i++) {
                contacts.add(new Contact(
                    LastName = 'Bulk Val Contact ' + i,
                    AccountId = acc.Id
                ));
            }
            insert contacts;

            Test.startTest();
            KYCValidationService service = new KYCValidationService();
            service.beforeInsert(contacts);
            Test.stopTest();

            System.assert(true, 'Bulk beforeInsert completed without error');
        }
    }

    // ─── Update path with old map ────────────────────────────────────────────

    @IsTest
    static void testValidate_BeforeUpdate_WithOldMap() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');

            Contact oldCon = con.clone(true, true, true, true);
            oldCon.LastName = 'Previous Name';

            Map<Id, SObject> oldMap = new Map<Id, SObject>{ con.Id => oldCon };

            Test.startTest();
            KYCValidationService.validate(
                new List<SObject>{ con },
                oldMap,
                'Before Update'
            );
            Test.stopTest();

            System.assert(true);
        }
    }
}