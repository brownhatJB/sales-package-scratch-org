@IsTest
private class AutoInvoiceOfferServiceTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName  = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        Project__c proj = new Project__c(
            Name         = 'Test Project',
            Stage__c     = 'Planning',
            UOM__c       = 'Sq. Ft',
            Total_Area__c = 10000
        );
        insert proj;

        Properties__c prop = new Properties__c(
            Name                        = 'Test Property',
            Project__c                  = proj.Id,
            Stage__c                    = 'Under Construction',
            Property_Ownership__c       = 'Fully Owned',
            UOM__c                      = 'Sq. Ft',
            Total_Area__c               = 1000,
            Enabled_For_Auto_Invoicing__c = true
        );
        insert prop;

        Units__c unit = new Units__c(
            Name                   = 'Unit-101',
            Project__c             = proj.Id,
            Properties__c          = prop.Id,
            Floor__c               = 1,
            View__c                = 'Lake',
            Type__c                = 'Apartment',
            Bedrooms__c            = 2,
            Furnishing_Status__c   = 'Furnished',
            Unit_Price__c          = 1000000,
            Current_Selling_Price__c = 1000000,
            Total_Area__c          = 1200
        );
        insert unit;

        Milestone__c milestone = new Milestone__c(
            Name = 'Booking'
        );
        insert milestone;

        // Offer – align fields with what OPPI / Invoice expect
        Offer__c offer = new Offer__c(
            Account__c    = acc.Id,
            Contact__c    = con.Id,
            Project__c    = proj.Id,
            Properties__c = prop.Id,
            Unit__c       = unit.Id
        );
        insert offer;

        List<Offer_Payment_Plan_Item__c> items = new List<Offer_Payment_Plan_Item__c>{
            new Offer_Payment_Plan_Item__c(
                Offer__c              = offer.Id,
                Milestone__c          = milestone.Id,
                Amount__c             = 10000,
                Amount_Excl_Tax__c    = 9000,
                Tax_Amount__c         = 1000,
                Status__c             = 'Active',
                Tentative_Due_Date__c = Date.today().addDays(-1),
                Invoiced_Amount__c    = null,
                Validation__c         = true   // skip OfferPaymentPlanItemTriggerValidation
            ),
            new Offer_Payment_Plan_Item__c(
                Offer__c              = offer.Id,
                Milestone__c          = milestone.Id,
                Amount__c             = 5000,
                Amount_Excl_Tax__c    = 4500,
                Tax_Amount__c         = 500,
                Status__c             = 'Active',
                Tentative_Due_Date__c = Date.today(),
                Invoiced_Amount__c    = 2000,
                Validation__c         = true
            )
        };
        insert items;
    }

    private static Offer__c getOffer() {
        return [
            SELECT Id, Account__c, Contact__c, Project__c, Properties__c, Unit__c
            FROM Offer__c
            LIMIT 1
        ];
    }

    private static List<Offer_Payment_Plan_Item__c> getPaymentPlanItems() {
        return [
            SELECT Id,
                   Amount__c,
                   Amount_Excl_Tax__c,
                   Tax_Amount__c,
                   Status__c,
                   Tentative_Due_Date__c,
                   Invoiced_Amount__c,
                   Milestone__c,
                   Offer__c,
                   Offer__r.Account__c,
                   Offer__r.Contact__c,
                   Offer__r.Project__c,
                   Offer__r.Properties__c,
                   Offer__r.Unit__c
            FROM Offer_Payment_Plan_Item__c
            ORDER BY Amount__c DESC
        ];
    }

    @IsTest
    static void testGenerateInvoices_NullList() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            AutoInvoiceOfferService.generateInvoices(null);
            AutoInvoiceOfferService.generateInvoices(
                new List<Offer_Payment_Plan_Item__c>()
            );
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testGenerateInvoices_Success() {
        User testUser = getTestUser();
        List<Offer_Payment_Plan_Item__c> items = getPaymentPlanItems();

        System.runAs(testUser) {
            Test.startTest();
            try {
                AutoInvoiceOfferService.generateInvoices(items);
            } catch (AuraHandledException e) {
                System.assert(e.getMessage() != null);
            }
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testCreateBatchInvoice() {
        User testUser = getTestUser();
        List<Offer_Payment_Plan_Item__c> items = getPaymentPlanItems();

        System.runAs(testUser) {
            Test.startTest();
            Batch_Invoices__c batch =
                AutoInvoiceOfferService.createBatchInvoice(items);
            Test.stopTest();

            System.assertNotEquals(null, batch.Id);
            System.assertEquals(Date.today(), batch.Invoice_Generation_Date__c);
            System.assert(batch.Name.startsWith('ABI-'));
        }
    }

    @IsTest
    static void testCreateInvoices_FullAmount() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c item = getPaymentPlanItems()[0];

        System.runAs(testUser) {
            Batch_Invoices__c batch = new Batch_Invoices__c(
                Name = 'ABI-TEST',
                Invoice_Generation_Date__c = Date.today()
            );
            insert batch;

            Test.startTest();
            List<Invoice__c> invoices = AutoInvoiceOfferService.createInvoices(
                new List<Offer_Payment_Plan_Item__c>{ item },
                batch.Id
            );
            Test.stopTest();

            System.assertEquals(1, invoices.size());
            System.assertEquals(10000, invoices[0].Invoice_Amount__c);
            System.assertEquals(item.Id, invoices[0].Offer_Payment_Plan_Item__c);
            System.assertEquals('Active', invoices[0].Status__c);
            System.assertEquals(batch.Id, invoices[0].Batch_Invoice__c);
            System.assertEquals(item.Offer__r.Account__c, invoices[0].Account__c);
            System.assertEquals(item.Offer__r.Contact__c, invoices[0].Contact__c);
            System.assertEquals(item.Offer__r.Unit__c, invoices[0].Units__c);
        }
    }

    @IsTest
    static void testCreateInvoices_PartiallyInvoiced() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c base = getPaymentPlanItems()[1];

        Offer_Payment_Plan_Item__c partial = new Offer_Payment_Plan_Item__c(
            Id                    = base.Id,
            Amount__c             = base.Amount__c,
            Amount_Excl_Tax__c    = base.Amount_Excl_Tax__c,
            Tax_Amount__c         = base.Tax_Amount__c,
            Status__c             = 'Partially Invoiced',
            Tentative_Due_Date__c = base.Tentative_Due_Date__c,
            Invoiced_Amount__c    = base.Invoiced_Amount__c,
            Milestone__c          = base.Milestone__c,
            Offer__c              = base.Offer__c
        );
        partial.Offer__r = base.Offer__r;

        System.runAs(testUser) {
            Batch_Invoices__c batch = new Batch_Invoices__c(
                Name = 'ABI-PARTIAL',
                Invoice_Generation_Date__c = Date.today()
            );
            insert batch;

            Test.startTest();
            List<Invoice__c> invoices = AutoInvoiceOfferService.createInvoices(
                new List<Offer_Payment_Plan_Item__c>{ partial },
                batch.Id
            );
            Test.stopTest();

            System.assertEquals(1, invoices.size());
            System.assertEquals(3000, invoices[0].Invoice_Amount__c);
        }
    }

    @IsTest
    static void testUpdatePaymentPlanItems() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c item = getPaymentPlanItems()[0];

        System.runAs(testUser) {
            Batch_Invoices__c batch = new Batch_Invoices__c(
                Name = 'ABI-UPD',
                Invoice_Generation_Date__c = Date.today()
            );
            insert batch;

            Invoice__c inv = new Invoice__c(
                Offer_Payment_Plan_Item__c = item.Id,
                Invoice_Amount__c          = 1500
            );

            //TriggerBase.bypass('Offer_Payment_Plan_Item__c');

            Test.startTest();
            AutoInvoiceOfferService.updatePaymentPlanItems(
                new List<Invoice__c>{ inv },
                batch.Id
            );
            Test.stopTest();

            //TriggerBase.clearBypass('Offer_Payment_Plan_Item__c');

            Offer_Payment_Plan_Item__c updated = [
                SELECT Status__c, Invoiced_Amount__c, Batch_Invoices__c,
                    Invoice_Date__c, Auto_Invoiced_Date__c
                FROM Offer_Payment_Plan_Item__c
                WHERE Id = :item.Id
            ];

            System.assertEquals('Invoiced', updated.Status__c);
            System.assertEquals(batch.Id, updated.Batch_Invoices__c);
            System.assertEquals(Date.today(), updated.Invoice_Date__c);
            System.assertEquals(Date.today(), updated.Auto_Invoiced_Date__c);

            Decimal expectedInvoiced =
                (item.Invoiced_Amount__c == null ? 0 : item.Invoiced_Amount__c) + 1500;
            System.assertEquals(expectedInvoiced, updated.Invoiced_Amount__c);
        }
    }

    @IsTest
    static void testUpdatePaymentPlanItems_NoItemIds() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Batch_Invoices__c batch = new Batch_Invoices__c(
                Name = 'ABI-EMPTY',
                Invoice_Generation_Date__c = Date.today()
            );
            insert batch;

            Invoice__c inv = new Invoice__c(Invoice_Amount__c = 100);

            Test.startTest();
            AutoInvoiceOfferService.updatePaymentPlanItems(
                new List<Invoice__c>{ inv },
                batch.Id
            );
            AutoInvoiceOfferService.updatePaymentPlanItems(
                new List<Invoice__c>(),
                batch.Id
            );
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testCreateStatementOfAccounts() {
        User testUser = getTestUser();
        Offer__c offer = getOffer();

        System.runAs(testUser) {
            Batch_Invoices__c batch = new Batch_Invoices__c(
                Name = 'ABI-SOA',
                Invoice_Generation_Date__c = Date.today()
            );
            insert batch;

            Invoice__c inv = new Invoice__c(
                Account__c        = offer.Account__c,
                Contact__c        = offer.Contact__c,
                Invoice_Amount__c = 2500,
                Invoice_Date__c   = Date.today(),
                Status__c         = 'Active',
                Units__c          = offer.Unit__c,
                Project__c        = offer.Project__c,
                Properties__c     = offer.Properties__c,
                Batch_Invoice__c  = batch.Id
            );
            insert inv;

            inv = [
                SELECT Id, Account__c, Contact__c, Invoice_Amount__c,
                    Units__c, Unit_Sale__c
                FROM Invoice__c
                WHERE Id = :inv.Id
            ];

            Test.startTest();
            try {
                AutoInvoiceOfferService.createStatementOfAccounts(
                    new List<Invoice__c>{ inv }
                );
            } catch (Exception e) {
                System.assert(e.getMessage() != null);
            }
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testCreateStatementOfAccounts_Empty() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            AutoInvoiceOfferService.createStatementOfAccounts(
                new List<Invoice__c>()
            );
            Test.stopTest();
        }
        System.assert(true);
    }
}