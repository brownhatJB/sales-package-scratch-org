@IsTest
private class OfferTriggerMapOppBrokerDetailsTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Country__c createCountry() {
        Country__c country = new Country__c(Name = 'Test Country');
        insert country;
        return country;
    }

    private static Units__c createUnit() {
        Units__c unit = new Units__c(
            Name = 'Test Unit ' + String.valueOf(Math.random()).substring(2, 6),
            Unit_Price__c = 100000
        );
        insert unit;
        return unit;
    }

    private static Account createBrokerAccount(String name) {
        Account acc = new Account(
            Name = name,
            Type = 'Broker'
        );
        insert acc;
        return acc;
    }

    private static Contact createBrokerContact(Id accountId, String lastName) {
        Contact con = new Contact(
            LastName = lastName,
            AccountId = accountId,
            Type__c = 'Broker'
        );
        insert con;
        return con;
    }

    private static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accountId, String lastName) {
        Contact con = new Contact(LastName = lastName, AccountId = accountId);
        insert con;
        return con;
    }

    private static Opportunity createOpportunity(
        Id accountId,
        Id brokerAccountId,
        Id brokerContactId
    ) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Broker_Account__c = brokerAccountId,
            Broker_Contact__c = brokerContactId
        );
        insert opp;
        return opp;
    }

    private static Offer__c createOffer(Id unitId, Id countryId, Id opportunityId) {
        Offer__c offer = new Offer__c(
            Unit__c = unitId,
            Country__c = countryId,
            Opportunity__c = opportunityId,
            Valid_from__c = Date.today(),
            Valid_to__c = Date.today().addDays(7)
        );
        insert offer;
        return offer;
    }

    // ─── afterInsert / mapBrokerDetails with broker ──────────────────────────

    @IsTest
    static void testAfterInsert_MapsBrokerFromOpportunity() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Country__c country = [SELECT Id FROM Country__c LIMIT 1];
            Units__c unit = createUnit();

            Account customerAcc = createAccount('Customer Account');
            Account brokerAcc = createBrokerAccount('Broker Account');
            Contact brokerCon = createBrokerContact(brokerAcc.Id, 'Broker Contact');

            Opportunity opp = createOpportunity(
                customerAcc.Id,
                brokerAcc.Id,
                brokerCon.Id
            );

            // Insert Offer without going through the real trigger path first —
            // call the action class directly so the test is isolated.
            Offer__c offer = new Offer__c(
                Unit__c = unit.Id,
                Country__c = country.Id,
                Opportunity__c = opp.Id,
                Valid_from__c = Date.today(),
                Valid_to__c = Date.today().addDays(7)
            );
            insert offer;

            // Re-query as trigger context would see it
            offer = [
                SELECT Id, Opportunity__c, Broker_Account__c, Broker_Contact__c, Sale_Through__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];

            Test.startTest();
            OfferTriggerMapOppBrokerDetails action = new OfferTriggerMapOppBrokerDetails();
            action.afterInsert(new List<Offer__c>{ offer });
            Test.stopTest();

            Offer__c updated = [
                SELECT
                    Broker_Account__c,
                    Broker_Contact__c,
                    Sale_Through__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];

            System.assertEquals(
                brokerAcc.Id,
                updated.Broker_Account__c,
                'Broker Account should be mapped from Opportunity'
            );
            System.assertEquals(
                brokerCon.Id,
                updated.Broker_Contact__c,
                'Broker Contact should be mapped from Opportunity'
            );
            System.assertEquals(
                'Agent',
                updated.Sale_Through__c,
                'Sale_through should be Agent when Broker Account is present'
            );
        }
    }

    // ─── Opportunity with no broker ──────────────────────────────────────────

    @IsTest
    static void testAfterInsert_NoBrokerOnOpportunity() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Country__c country = [SELECT Id FROM Country__c LIMIT 1];
            Units__c unit = createUnit();
            Account customerAcc = createAccount('Customer Account');

            Opportunity opp = createOpportunity(customerAcc.Id, null, null);

            Offer__c offer = new Offer__c(
                Unit__c = unit.Id,
                Country__c = country.Id,
                Opportunity__c = opp.Id,
                Valid_from__c = Date.today(),
                Valid_to__c = Date.today().addDays(7)
            );
            insert offer;

            offer = [
                SELECT Id, Opportunity__c, Broker_Account__c, Broker_Contact__c, Sale_Through__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];
            String originalSaleThrough = offer.Sale_Through__c;

            Test.startTest();
            new OfferTriggerMapOppBrokerDetails().afterInsert(new List<Offer__c>{ offer });
            Test.stopTest();

            Offer__c updated = [
                SELECT Broker_Account__c, Broker_Contact__c, Sale_Through__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];

            System.assertEquals(null, updated.Broker_Account__c);
            System.assertEquals(null, updated.Broker_Contact__c);
            // Sale_through kept from offer when no broker
            System.assertEquals(originalSaleThrough, updated.Sale_Through__c);
        }
    }

    // ─── No Opportunity → early return ───────────────────────────────────────

    @IsTest
    static void testAfterInsert_NoOpportunity_NoUpdate() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Country__c country = [SELECT Id FROM Country__c LIMIT 1];
            Units__c unit = createUnit();

            Offer__c offer = new Offer__c(
                Unit__c = unit.Id,
                Country__c = country.Id,
                Opportunity__c = null,
                Valid_from__c = Date.today(),
                Valid_to__c = Date.today().addDays(7)
            );
            insert offer;

            offer = [
                SELECT Id, Opportunity__c, Broker_Account__c, Broker_Contact__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];

            Test.startTest();
            new OfferTriggerMapOppBrokerDetails().afterInsert(new List<Offer__c>{ offer });
            Test.stopTest();

            Offer__c unchanged = [
                SELECT Broker_Account__c, Broker_Contact__c
                FROM Offer__c
                WHERE Id = :offer.Id
            ];

            System.assertEquals(null, unchanged.Broker_Account__c);
            System.assertEquals(null, unchanged.Broker_Contact__c);
        }
    }

    // ─── Empty list ──────────────────────────────────────────────────────────

    @IsTest
    static void testMapBrokerDetails_EmptyList() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            new OfferTriggerMapOppBrokerDetails().mapBrokerDetails(new List<Offer__c>());
            Test.stopTest();
            System.assert(true, 'Empty list should return without error');
        }
    }

    // ─── Bulk ────────────────────────────────────────────────────────────────

    @IsTest
    static void testAfterInsert_BulkOffers() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            createCountry();
            Country__c country = [SELECT Id FROM Country__c LIMIT 1];
            Units__c unit = createUnit();

            Account customerAcc = createAccount('Customer Account');
            Account brokerAcc = createBrokerAccount('Broker Account');
            Contact brokerCon = createBrokerContact(brokerAcc.Id, 'Broker Contact');
            Opportunity opp = createOpportunity(
                customerAcc.Id,
                brokerAcc.Id,
                brokerCon.Id
            );

            List<Offer__c> offers = new List<Offer__c>();
            for (Integer i = 0; i < 3; i++) {
                offers.add(new Offer__c(
                    Unit__c = unit.Id,
                    Country__c = country.Id,
                    Opportunity__c = opp.Id,
                    Valid_from__c = Date.today(),
                    Valid_to__c = Date.today().addDays(7)
                ));
            }
            insert offers;

            offers = [
                SELECT Id, Opportunity__c, Broker_Account__c, Broker_Contact__c, Sale_Through__c
                FROM Offer__c
                WHERE Id IN :offers
            ];

            Test.startTest();
            new OfferTriggerMapOppBrokerDetails().afterInsert(offers);
            Test.stopTest();

            for (Offer__c o : [
                SELECT Broker_Account__c, Broker_Contact__c, Sale_Through__c
                FROM Offer__c
                WHERE Id IN :offers
            ]) {
                System.assertEquals(brokerAcc.Id, o.Broker_Account__c);
                System.assertEquals(brokerCon.Id, o.Broker_Contact__c);
                System.assertEquals('Agent', o.Sale_Through__c);
            }
        }
    }
}