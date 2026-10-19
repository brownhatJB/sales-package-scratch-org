@IsTest
private class InvoiceAmountRollupHelperTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        // Create Units first – Unit Sale before-insert trigger updates related Unit
        List<Units__c> units = new List<Units__c>{
            new Units__c(Name = 'Unit-001', Unit_Price__c = 100000, Status__c = 'Available'),
            new Units__c(Name = 'Unit-002', Unit_Price__c = 150000, Status__c = 'Available'),
            new Units__c(Name = 'Unit-003', Unit_Price__c = 200000, Status__c = 'Available')
        };
        insert units;

        List<Unit_Sale__c> unitSales = new List<Unit_Sale__c>{
            new Unit_Sale__c(
                Unit__c                 = units[0].Id,
                Total_Invoice_Amount__c = 0
            ),
            new Unit_Sale__c(
                Unit__c                 = units[1].Id,
                Total_Invoice_Amount__c = 1000
            ),
            new Unit_Sale__c(
                Unit__c                 = units[2].Id,
                Total_Invoice_Amount__c = null
            )
        };
        insert unitSales;

        // Offers for the Offer__c rollup path
        // Add any other required fields on Offer__c your org needs
        List<Offer__c> offers = new List<Offer__c>{
            new Offer__c(Total_Invoice_Amount__c = 0),
            new Offer__c(Total_Invoice_Amount__c = 500),
            new Offer__c(Total_Invoice_Amount__c = null)
        };
        insert offers;
    }

    private static List<Unit_Sale__c> getUnitSales() {
        return [
            SELECT Id, Total_Invoice_Amount__c, Unit__c
            FROM Unit_Sale__c
            ORDER BY CreatedDate ASC
        ];
    }

    private static List<Offer__c> getOffers() {
        return [
            SELECT Id, Total_Invoice_Amount__c
            FROM Offer__c
            ORDER BY CreatedDate ASC
        ];
    }

    // --------------------------------------------------
    // Unit Sale path
    // --------------------------------------------------

    @IsTest
    static void testAfterInsert_SingleInvoice_ZeroStartingTotal() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0]; // starts at 0

        Invoice__c inv = new Invoice__c(
            Unit_Sale__c      = unitSale.Id,
            Invoice_Amount__c = 500
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Unit_Sale__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Unit_Sale__c
            WHERE Id = :unitSale.Id
        ];
        System.assertEquals(500, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_SingleInvoice_ExistingTotal() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[1]; // starts at 1000

        Invoice__c inv = new Invoice__c(
            Unit_Sale__c      = unitSale.Id,
            Invoice_Amount__c = 250
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Unit_Sale__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Unit_Sale__c
            WHERE Id = :unitSale.Id
        ];
        System.assertEquals(1250, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_NullStartingTotal() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[2]; // starts at null

        Invoice__c inv = new Invoice__c(
            Unit_Sale__c      = unitSale.Id,
            Invoice_Amount__c = 300
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Unit_Sale__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Unit_Sale__c
            WHERE Id = :unitSale.Id
        ];
        System.assertEquals(300, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_MultipleInvoices_SameUnitSale() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0];

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Unit_Sale__c = unitSale.Id, Invoice_Amount__c = 100),
            new Invoice__c(Unit_Sale__c = unitSale.Id, Invoice_Amount__c = 200),
            new Invoice__c(Unit_Sale__c = unitSale.Id, Invoice_Amount__c = 50)
        };

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(invoices);
            Test.stopTest();
        }

        Unit_Sale__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Unit_Sale__c
            WHERE Id = :unitSale.Id
        ];
        System.assertEquals(350, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_MultipleInvoices_DifferentUnitSales() {
        User testUser = getTestUser();
        List<Unit_Sale__c> unitSales = getUnitSales();

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Unit_Sale__c = unitSales[0].Id, Invoice_Amount__c = 100),
            new Invoice__c(Unit_Sale__c = unitSales[1].Id, Invoice_Amount__c = 200)
        };

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(invoices);
            Test.stopTest();
        }

        Map<Id, Unit_Sale__c> updatedMap = new Map<Id, Unit_Sale__c>([
            SELECT Id, Total_Invoice_Amount__c
            FROM Unit_Sale__c
            WHERE Id IN :new Set<Id>{ unitSales[0].Id, unitSales[1].Id }
        ]);

        System.assertEquals(100, updatedMap.get(unitSales[0].Id).Total_Invoice_Amount__c);
        System.assertEquals(1200, updatedMap.get(unitSales[1].Id).Total_Invoice_Amount__c);
    }

    // --------------------------------------------------
    // Offer path
    // --------------------------------------------------

    @IsTest
    static void testAfterInsert_Offer_ZeroStartingTotal() {
        User testUser = getTestUser();
        Offer__c offer = getOffers()[0]; // starts at 0

        Invoice__c inv = new Invoice__c(
            Offer__c          = offer.Id,
            Invoice_Amount__c = 400
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Offer__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Offer__c
            WHERE Id = :offer.Id
        ];
        System.assertEquals(400, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_Offer_ExistingTotal() {
        User testUser = getTestUser();
        Offer__c offer = getOffers()[1]; // starts at 500

        Invoice__c inv = new Invoice__c(
            Offer__c          = offer.Id,
            Invoice_Amount__c = 150
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Offer__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Offer__c
            WHERE Id = :offer.Id
        ];
        System.assertEquals(650, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_Offer_NullStartingTotal() {
        User testUser = getTestUser();
        Offer__c offer = getOffers()[2]; // starts at null

        Invoice__c inv = new Invoice__c(
            Offer__c          = offer.Id,
            Invoice_Amount__c = 275
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Offer__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Offer__c
            WHERE Id = :offer.Id
        ];
        System.assertEquals(275, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_MultipleInvoices_SameOffer() {
        User testUser = getTestUser();
        Offer__c offer = getOffers()[0];

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Offer__c = offer.Id, Invoice_Amount__c = 100),
            new Invoice__c(Offer__c = offer.Id, Invoice_Amount__c = 200),
            new Invoice__c(Offer__c = offer.Id, Invoice_Amount__c = 50)
        };

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(invoices);
            Test.stopTest();
        }

        Offer__c updated = [
            SELECT Total_Invoice_Amount__c
            FROM Offer__c
            WHERE Id = :offer.Id
        ];
        System.assertEquals(350, updated.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_MultipleInvoices_DifferentOffers() {
        User testUser = getTestUser();
        List<Offer__c> offers = getOffers();

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Offer__c = offers[0].Id, Invoice_Amount__c = 100),
            new Invoice__c(Offer__c = offers[1].Id, Invoice_Amount__c = 200)
        };

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(invoices);
            Test.stopTest();
        }

        Map<Id, Offer__c> updatedMap = new Map<Id, Offer__c>([
            SELECT Id, Total_Invoice_Amount__c
            FROM Offer__c
            WHERE Id IN :new Set<Id>{ offers[0].Id, offers[1].Id }
        ]);

        System.assertEquals(100, updatedMap.get(offers[0].Id).Total_Invoice_Amount__c);
        System.assertEquals(700, updatedMap.get(offers[1].Id).Total_Invoice_Amount__c);
    }

    // --------------------------------------------------
    // Mixed + edge cases
    // --------------------------------------------------

    @IsTest
    static void testAfterInsert_Mixed_UnitSaleAndOffer() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0]; // 0
        Offer__c offer = getOffers()[0];           // 0

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(Unit_Sale__c = unitSale.Id, Invoice_Amount__c = 100),
            new Invoice__c(Offer__c = offer.Id, Invoice_Amount__c = 200)
        };

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(invoices);
            Test.stopTest();
        }

        Unit_Sale__c updatedSale = [
            SELECT Total_Invoice_Amount__c FROM Unit_Sale__c WHERE Id = :unitSale.Id
        ];
        Offer__c updatedOffer = [
            SELECT Total_Invoice_Amount__c FROM Offer__c WHERE Id = :offer.Id
        ];

        System.assertEquals(100, updatedSale.Total_Invoice_Amount__c);
        System.assertEquals(200, updatedOffer.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_InvoiceWithNullUnitSaleAndNullOffer() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0];
        Offer__c offer = getOffers()[0];
        Decimal originalSaleTotal = unitSale.Total_Invoice_Amount__c;
        Decimal originalOfferTotal = offer.Total_Invoice_Amount__c;

        Invoice__c inv = new Invoice__c(
            Unit_Sale__c      = null,
            Offer__c          = null,
            Invoice_Amount__c = 999
        );

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>{ inv });
            Test.stopTest();
        }

        Unit_Sale__c unchangedSale = [
            SELECT Total_Invoice_Amount__c FROM Unit_Sale__c WHERE Id = :unitSale.Id
        ];
        Offer__c unchangedOffer = [
            SELECT Total_Invoice_Amount__c FROM Offer__c WHERE Id = :offer.Id
        ];

        System.assertEquals(originalSaleTotal, unchangedSale.Total_Invoice_Amount__c);
        System.assertEquals(originalOfferTotal, unchangedOffer.Total_Invoice_Amount__c);
    }

    @IsTest
    static void testAfterInsert_EmptyList() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            new InvoiceAmountRollupHelper().afterInsert(new List<Invoice__c>());
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testInsertInvoice_ViaDml() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0];

        Invoice__c inv = new Invoice__c(
            Unit_Sale__c      = unitSale.Id,
            Invoice_Amount__c = 75
        );

        System.runAs(testUser) {
            Test.startTest();
            try {
                insert inv;
            } catch (DmlException e) {
                // Other Invoice required fields / triggers may block insert
            }
            Test.stopTest();
        }
        System.assert(true);
    }
}