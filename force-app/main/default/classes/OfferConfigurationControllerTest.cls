@IsTest
private class OfferConfigurationControllerTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Test data helpers ───────────────────────────────────────────────────

    private static Country__c createCountry() {
        Country__c country = new Country__c(Name = 'Test Country');
        insert country;
        return country;
    }

    private static Units__c createUnit(Id defaultPaymentPlanId) {
        Units__c unit = new Units__c(
            Name = 'Test Unit ' + String.valueOf(Math.random()).substring(2, 6),
            Unit_Price__c = 100000,
            Default_Payment_Plan__c = defaultPaymentPlanId
        );
        insert unit;
        return unit;
    }

    private static Payment_Plan_template__c createPaymentPlan(Id propertyId) {
        Payment_Plan_template__c plan = new Payment_Plan_template__c(
            Name = 'Test Payment Plan'
        );
        if (propertyId != null) {
            plan.Properties__c = propertyId;
        }
        insert plan;
        return plan;
    }

    private static Enquiry__c createEnquiry() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        Enquiry__c enq = new Enquiry__c(
            Account__c = acc.Id,
            Contact__c = con.Id
        );
        insert enq;
        return enq;
    }

    private static Opportunity createOpportunity() {
        Account acc = new Account(Name = 'Opp Account');
        insert acc;

        // Broker account + contact for the trigger to map
        Account brokerAcc = new Account(Name = 'Broker Account', Type = 'Broker');
        insert brokerAcc;

        Contact brokerCon = new Contact(
            LastName = 'Broker Contact',
            AccountId = brokerAcc.Id,
            Type__c = 'Broker'
        );
        insert brokerCon;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Broker_Account__c = brokerAcc.Id,
            Broker_Contact__c = brokerCon.Id
        );
        insert opp;
        return opp;
    }

    private static String buildOfferJson(
        List<String> unitIds,
        String enquiryId,
        String opportunityId,
        List<Map<String, String>> unitConfigEntries
    ) {
        Map<String, Object> payload = new Map<String, Object>{
            'selectedUnitIds' => unitIds,
            'enquiryId' => enquiryId,
            'opportunityId' => opportunityId,
            'unitConfigEntries' => unitConfigEntries
        };
        return JSON.serialize(payload);
    }

    // ─── createConfiguredOffers – success paths ──────────────────────────────

    @IsTest
    static void testCreateConfiguredOffers_WithEnquiry() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Units__c unit = createUnit(null);
            Enquiry__c enquiry = createEnquiry();

            String dataJson = buildOfferJson(
                new List<String>{ unit.Id },
                enquiry.Id,
                null,
                null
            );

            Test.startTest();
            //TriggerBase.bypass('Offer__c');
            List<Id> offerIds =
                OfferConfigurationController.createConfiguredOffers(dataJson);
            //TriggerBase.clearBypass('Offer__c');    
            Test.stopTest();

            System.assertEquals(1, offerIds.size(), 'One offer should be created');

            Offer__c offer = [
                SELECT
                    Id,
                    Unit__c,
                    Enquiry__c,
                    Account__c,
                    Contact__c,
                    Valid_from__c,
                    Valid_to__c
                FROM Offer__c
                WHERE Id = :offerIds[0]
            ];

            System.assertEquals(unit.Id, offer.Unit__c);
            System.assertEquals(enquiry.Id, offer.Enquiry__c);
            System.assertEquals(enquiry.Account__c, offer.Account__c);
            System.assertEquals(enquiry.Contact__c, offer.Contact__c);
            System.assertEquals(Date.today(), offer.Valid_from__c);
            System.assertEquals(Date.today().addDays(7), offer.Valid_to__c);
        }
    }

    @IsTest
    static void testCreateConfiguredOffers_WithOpportunity() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Units__c unit = createUnit(null);
            Opportunity opp = createOpportunity();

            String dataJson = buildOfferJson(
                new List<String>{ unit.Id },
                null,
                opp.Id,
                null
            );

            Test.startTest();
            //TriggerBase.bypass('Offer__c');
            List<Id> offerIds =
                OfferConfigurationController.createConfiguredOffers(dataJson);
            //TriggerBase.clearBypass('Offer__c');
            Test.stopTest();

            System.assertEquals(1, offerIds.size());

            Offer__c offer = [
                SELECT
                    Id,
                    Unit__c,
                    Opportunity__c,
                    Account__c,
                    Broker_Account__c,
                    Broker_Contact__c,
                    Sale_through__c
                FROM Offer__c
                WHERE Id = :offerIds[0]
            ];

            System.assertEquals(unit.Id, offer.Unit__c);
            System.assertEquals(opp.Id, offer.Opportunity__c);
            System.assertEquals(opp.AccountId, offer.Account__c);

            // Trigger should have mapped broker details
            System.assertEquals(
                opp.Broker_Account__c,
                offer.Broker_Account__c,
                'Broker Account should be mapped from Opportunity'
            );
            System.assertEquals(
                opp.Broker_Contact__c,
                offer.Broker_Contact__c,
                'Broker Contact should be mapped from Opportunity'
            );
            System.assertEquals(
                'Agent',
                offer.Sale_through__c,
                'Sale_through should be Agent when Broker Account is present'
            );
        }
    }

    @IsTest
    static void testCreateConfiguredOffers_WithSelectedPaymentPlan() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Payment_Plan_template__c plan = createPaymentPlan(null);
            Units__c unit = createUnit(null);

            List<Map<String, String>> configEntries = new List<Map<String, String>>{
                new Map<String, String>{
                    'unitId' => unit.Id,
                    'selectedPaymentPlanId' => plan.Id
                }
            };

            String dataJson = buildOfferJson(
                new List<String>{ unit.Id },
                null,
                null,
                configEntries
            );

            Test.startTest();
            List<Id> offerIds =
                OfferConfigurationController.createConfiguredOffers(dataJson);
            Test.stopTest();

            System.assertEquals(1, offerIds.size());

            Offer__c offer = [
                SELECT Id, Payment_Plan_Template__c
                FROM Offer__c
                WHERE Id = :offerIds[0]
            ];

            System.assertEquals(
                plan.Id,
                offer.Payment_Plan_Template__c,
                'Selected payment plan should be used'
            );
        }
    }

    @IsTest
    static void testCreateConfiguredOffers_MultipleUnits() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Units__c unit1 = createUnit(null);
            Units__c unit2 = createUnit(null);

            String dataJson = buildOfferJson(
                new List<String>{ unit1.Id, unit2.Id },
                null,
                null,
                null
            );

            Test.startTest();
            List<Id> offerIds =
                OfferConfigurationController.createConfiguredOffers(dataJson);
            Test.stopTest();

            System.assertEquals(2, offerIds.size(), 'Two offers should be created');
        }
    }

    @IsTest
    static void testCreateConfiguredOffers_UsesDefaultPaymentPlan() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Payment_Plan_template__c defaultPlan = createPaymentPlan(null);
            Units__c unit = createUnit(defaultPlan.Id);

            String dataJson = buildOfferJson(
                new List<String>{ unit.Id },
                null,
                null,
                null
            );

            Test.startTest();
            List<Id> offerIds =
                OfferConfigurationController.createConfiguredOffers(dataJson);
            Test.stopTest();

            Offer__c offer = [
                SELECT Payment_Plan_Template__c
                FROM Offer__c
                WHERE Id = :offerIds[0]
            ];

            System.assertEquals(
                defaultPlan.Id,
                offer.Payment_Plan_Template__c,
                'Default payment plan should be used when none selected'
            );
        }
    }

    // ─── createConfiguredOffers – error paths ────────────────────────────────

    @IsTest
    static void testCreateConfiguredOffers_NoUnitsSelected() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            String dataJson = buildOfferJson(
                new List<String>(),
                null,
                null,
                null
            );

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                OfferConfigurationController.createConfiguredOffers(dataJson);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();

            System.assert(
                exceptionThrown,
                'Expected AuraHandledException when no units are selected'
            );
        }
    }

    @IsTest
    static void testCreateConfiguredOffers_NullSelectedUnitIds() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Map<String, Object> payload = new Map<String, Object>{
                'selectedUnitIds' => null,
                'enquiryId' => null,
                'opportunityId' => null,
                'unitConfigEntries' => null
            };
            String dataJson = JSON.serialize(payload);

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                OfferConfigurationController.createConfiguredOffers(dataJson);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();

            System.assert(
                exceptionThrown,
                'Expected AuraHandledException when selectedUnitIds is null'
            );
        }
    }

    // ─── getPaymentPlans ─────────────────────────────────────────────────────

    @IsTest
    static void testGetPaymentPlans_NullUnitId() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            List<Payment_Plan_template__c> results =
                OfferConfigurationController.getPaymentPlans(null);
            Test.stopTest();

            System.assertNotEquals(null, results);
            System.assertEquals(
                0,
                results.size(),
                'Should return empty list for null unitId'
            );
        }
    }

    @IsTest
    static void testGetPaymentPlans_WithUnit() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Units__c unit = createUnit(null);

            Test.startTest();
            List<Payment_Plan_template__c> results =
                OfferConfigurationController.getPaymentPlans(unit.Id);
            Test.stopTest();

            System.assertNotEquals(null, results, 'Result should not be null');
        }
    }
}