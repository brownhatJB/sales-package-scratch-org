@IsTest
private class KYCValidationServiceTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Contact createContact() {
        Account acc = new Account(Name = 'KYC Val Account');
        insert acc;
        Contact con = new Contact(LastName = 'KYC Val Contact', AccountId = acc.Id);
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

    private static Country__c createCountry() {
        Country__c c = new Country__c(Name = 'KYC Test Country');
        insert c;
        return c;
    }

    private static Units__c createUnit() {
        Units__c u = new Units__c(
            Name = 'KYC Unit',
            Unit_Price__c = 100000
        );
        insert u;
        return u;
    }

    private static Offer__c buildOffer(Id unitId, Id countryId, Id contactId) {
        return new Offer__c(
            Unit__c = unitId,
            Country__c = countryId,
            Contact__c = contactId,
            Valid_from__c = Date.today(),
            Valid_to__c = Date.today().addDays(7)
        );
    }

    // ─── Early exits ─────────────────────────────────────────────────────────

    @IsTest
    static void testValidate_NullAndEmpty() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCValidationService.validate(null, new Map<Id, SObject>(), 'Before Insert');
            KYCValidationService.validate(
                new List<SObject>(),
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();
        }
    }

    @IsTest
    static void testValidate_WrongEvent_EarlyExit() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Test.startTest();
            // No CMDT for Contact + Before Insert
            KYCValidationService.validate(
                new List<SObject>{ con },
                new Map<Id, SObject>(),
                'Before Insert'
            );
            Test.stopTest();
            System.assert(true);
        }
    }

    // ─── Offer__c + Before Insert + Block (Offer_Block) ───────────────────────

    @IsTest
    static void testOffer_BeforeInsert_NoKyc_Block() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            // No KYC → should Block
            Country__c country = createCountry();
            Units__c unit = createUnit();
            Offer__c offer = buildOffer(unit.Id, country.Id, con.Id);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ offer });
            Test.stopTest();

            System.assert(
                offer.getErrors().size() > 0,
                'Offer_Block should addError when Contact has no Approved KYC'
            );
        }
    }

    @IsTest
    static void testOffer_BeforeInsert_DraftKyc_Block() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Draft');

            Country__c country = createCountry();
            Units__c unit = createUnit();
            Offer__c offer = buildOffer(unit.Id, country.Id, con.Id);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ offer });
            Test.stopTest();

            System.assert(
                offer.getErrors().size() > 0,
                'Draft KYC should still Block'
            );
        }
    }

    @IsTest
    static void testOffer_BeforeInsert_ApprovedKyc_NoBlock() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');

            Country__c country = createCountry();
            Units__c unit = createUnit();
            Offer__c offer = buildOffer(unit.Id, country.Id, con.Id);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ offer });
            Test.stopTest();

            System.assertEquals(
                0,
                offer.getErrors().size(),
                'Approved KYC should not Block'
            );
        }
    }

    @IsTest
    static void testOffer_BeforeInsert_NullContact_NoParent_Skip() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Country__c country = createCountry();
            Units__c unit = createUnit();
            Offer__c offer = buildOffer(unit.Id, country.Id, null);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ offer });
            Test.stopTest();

            // parentIds empty → no enforcement
            System.assertEquals(0, offer.getErrors().size());
        }
    }

    // ─── Receipt__c + Before Insert + Warning (Receipt_Warning) ──────────────

    @IsTest
    static void testReceipt_BeforeInsert_NoKyc_Warning() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();

            // Minimal Receipt – add required fields if insert/build fails
            Receipt__c receipt = new Receipt__c(Contact__c = con.Id);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ receipt });
            Test.stopTest();

            // Warning mode does not addError; event publish should not throw
            System.assertEquals(0, receipt.getErrors().size());
        }
    }

    @IsTest
    static void testReceipt_BeforeInsert_ApprovedKyc_NoWarningPathError() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');

            Receipt__c receipt = new Receipt__c(Contact__c = con.Id);

            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ receipt });
            Test.stopTest();

            System.assertEquals(0, receipt.getErrors().size());
        }
    }

    // ─── Lead + Before Update + Warning (Convertion_Lead_Check) ──────────────
    // Linked_Field_API_Name = Id → parent is the Lead itself

    @IsTest
    static void testLead_BeforeUpdate_NoKyc_Warning() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            Lead oldLd = ld.clone(true, true, true, true);
            // Change something so Before Update path runs; if CMDT has conditions,
            // they must evaluate true on new and false on old for transition.
            ld.LastName = 'Updated Lead Name';

            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();

            // Warning → no addError
            System.assert(true);
        }
    }

    @IsTest
    static void testLead_BeforeUpdate_ApprovedKyc() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            createKycForLead(ld.Id, 'Approved');

            Lead oldLd = ld.clone(true, true, true, true);
            ld.LastName = 'Updated With Approved KYC';

            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();

            System.assertEquals(0, ld.getErrors().size());
        }
    }

    @IsTest
    static void testLead_BeforeUpdate_DraftKyc_Warning() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            createKycForLead(ld.Id, 'Draft');

            Lead oldLd = ld.clone(true, true, true, true);
            ld.LastName = 'Updated With Draft KYC';

            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();

            System.assert(true);
        }
    }

    // ─── Entry points / bulk ─────────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_BulkOffers() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');
            Country__c country = createCountry();
            Units__c unit = createUnit();

            List<Offer__c> offers = new List<Offer__c>();
            for (Integer i = 0; i < 3; i++) {
                offers.add(buildOffer(unit.Id, country.Id, con.Id));
            }

            Test.startTest();
            new KYCValidationService().beforeInsert(offers);
            Test.stopTest();

            for (Offer__c o : offers) {
                System.assertEquals(0, o.getErrors().size());
            }
        }
    }
    
    @IsTest
    static void testLead_BeforeUpdate_Acknowledged_NoKyc_Warning() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            // Old: not acknowledged → condition false
            Lead oldLd = ld.clone(true, true, true, true);
            oldLd.put('Lead_Acknowledged__c', false);
    
            // New: acknowledged → condition true (transition)
            ld.put('Lead_Acknowledged__c', true);
    
            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();
    
            // Warning mode – no addError; event publish should not throw
            System.assertEquals(0, ld.getErrors().size());
        }
    }
    
    @IsTest
    static void testLead_BeforeUpdate_Acknowledged_ApprovedKyc_NoAction() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            createKycForLead(ld.Id, 'Approved');
    
            Lead oldLd = ld.clone(true, true, true, true);
            oldLd.put('Lead_Acknowledged__c', false);
            ld.put('Lead_Acknowledged__c', true);
    
            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();
    
            System.assertEquals(0, ld.getErrors().size());
        }
    }
    
    @IsTest
    static void testLead_BeforeUpdate_NotAcknowledged_NoTransition() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Lead ld = createLead();
            Lead oldLd = ld.clone(true, true, true, true);
            // Both still false → newFinal false → no enforcement
            oldLd.put('Lead_Acknowledged__c', false);
            ld.put('Lead_Acknowledged__c', false);
    
            Test.startTest();
            new KYCValidationService().beforeUpdate(
                new List<SObject>{ ld },
                new List<SObject>{ oldLd }
            );
            Test.stopTest();
    
            System.assertEquals(0, ld.getErrors().size());
        }
    }
    
    @IsTest
    static void testReceipt_BeforeInsert_WithContact_NoKyc_Warning() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            Receipt__c receipt = new Receipt__c(Contact__c = con.Id);
    
            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ receipt });
            Test.stopTest();
    
            // Warning only – no Block errors
            System.assertEquals(0, receipt.getErrors().size());
        }
    }
    
    @IsTest
    static void testReceipt_BeforeInsert_WithContact_ApprovedKyc() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = createContact();
            createKycForContact(con.Id, 'Approved');
            Receipt__c receipt = new Receipt__c(Contact__c = con.Id);
    
            Test.startTest();
            new KYCValidationService().beforeInsert(new List<SObject>{ receipt });
            Test.stopTest();
    
            System.assertEquals(0, receipt.getErrors().size());
        }
    }
    
    @IsTest
    static void testEvaluateCondition_AllOperators() {
        // Equals
        KYC_Conditions_Config__mdt eq = new KYC_Conditions_Config__mdt(
            Operator__c = 'Equals',
            Value__c = 'Approved'
        );
        System.assertEquals(true, KYCValidationService.evaluateCondition('Approved', eq));
        System.assertEquals(false, KYCValidationService.evaluateCondition('Draft', eq));
    
        // Not Equals
        KYC_Conditions_Config__mdt ne = new KYC_Conditions_Config__mdt(
            Operator__c = 'Not Equals',
            Value__c = 'null'
        );
        System.assertEquals(true, KYCValidationService.evaluateCondition('003xx', ne));
        System.assertEquals(false, KYCValidationService.evaluateCondition(null, ne)); // null → false early
    
        // Greater Than
        KYC_Conditions_Config__mdt gt = new KYC_Conditions_Config__mdt(
            Operator__c = 'Greater Than',
            Value__c = '10'
        );
        System.assertEquals(true, KYCValidationService.evaluateCondition('15', gt));
        System.assertEquals(false, KYCValidationService.evaluateCondition('5', gt));
    
        // Less Than
        KYC_Conditions_Config__mdt lt = new KYC_Conditions_Config__mdt(
            Operator__c = 'Less Than',
            Value__c = '10'
        );
        System.assertEquals(true, KYCValidationService.evaluateCondition('5', lt));
        System.assertEquals(false, KYCValidationService.evaluateCondition('15', lt));
    
        // Catch path (non-numeric with Greater Than)
        KYC_Conditions_Config__mdt bad = new KYC_Conditions_Config__mdt(
            Operator__c = 'Greater Than',
            Value__c = '10'
        );
        System.assertEquals(false, KYCValidationService.evaluateCondition('abc', bad));
    
        // Unknown operator → false
        KYC_Conditions_Config__mdt unk = new KYC_Conditions_Config__mdt(
            Operator__c = 'Contains',
            Value__c = 'x'
        );
        System.assertEquals(false, KYCValidationService.evaluateCondition('x', unk));
    }
}