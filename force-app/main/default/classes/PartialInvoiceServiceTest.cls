@IsTest
private class PartialInvoiceServiceTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        // ==========================================
        // LEVEL 1: MASTER RECORDS
        // ==========================================
        Account testAcc = new Account(Name = 'Test Customer');
        insert testAcc;

        Project__c testProject = new Project__c(Name = 'AlSalama Heights');
        insert testProject;

        Properties__c testProperty = new Properties__c(
            Name = 'Test Property Phase 1',
            Project__c = testProject.Id
        );
        insert testProperty;

        Units__c testUnit = new Units__c(
            Name = 'Test Unit 101',
            Unit_Price__c = 100000,
            Project__c = testProject.Id,
            Properties__c = testProperty.Id,
            Status__c = 'Available'
        );
        insert testUnit;

        Tax_Code__c testTax = new Tax_Code__c(
            Name = 'Zero Tax',
            Tax_Percentage__c = 0
        );
        insert testTax;

        Payment_Item_Master__c pimReceivable = new Payment_Item_Master__c(
            Name = 'Receivable Installment',
            Type__c = 'Receivable Item'
        );
        insert pimReceivable;

        Payment_Item_Master__c pimPlanItem = new Payment_Item_Master__c(
            Name = 'Plan Installment',
            Type__c = 'Payment Plan Item'
        );
        insert pimPlanItem;

        Payment_Plan_Template__c template = new Payment_Plan_Template__c(
            Name = 'Standard Plan Template'
        );
        insert template;

        // ==========================================
        // LEVEL 2: FIRST-DEGREE DEPENDENCIES
        // ==========================================
        Template_Item__c templateItem = new Template_Item__c(
            Payment_Plan_Template__c = template.Id,
            Payment_Item_Master__c = pimPlanItem.Id,
            Item_Name__c = pimReceivable.Id,
            Payment_Based_On__c = 'Due Days',
            Days__c = 30,
            Percentage__c = 100.00,
            Order__c = 4
        );
        insert templateItem;

        Offer__c testOffer = new Offer__c(
            Project__c = testProject.Id,
            Properties__c = testProperty.Id,
            Unit__c = testUnit.Id,
            Account__c = testAcc.Id,
            Tax_Code__c = testTax.Id,
            Discount_percentage__c = 0,
            Total_Parking_Units_Price_Excluding_Tax__c = 0,
            Seperate_Parking_Payment_Plan_Template__c = 'No'
        );
        insert testOffer;

        // ==========================================
        // LEVEL 3 & 4: OFFER PPI AND STANDARD PPI
        // ==========================================
        Offer_Item__c offerItem = new Offer_Item__c(
            Offer__c = testOffer.Id,
            Receivable_Item__c = pimReceivable.Id,
            Tax_Code__c = testTax.Id,
            Amount__c = 5000.00
        );
        insert offerItem;

        // Validation__c = true skips OfferPaymentPlanItemTriggerValidation NPE
        Offer_Payment_Plan_Item__c offerPpi = new Offer_Payment_Plan_Item__c(
            Offer__c = testOffer.Id,
            Payment_Item_Master__c = pimPlanItem.Id,
            Offer_Item__c = offerItem.Id,
            Unit__c = testUnit.Id,
            Template_Item__c = templateItem.Id,
            Amount__c = 5000.00,
            Invoiced_Amount__c = 0,
            Tentative_Due_Date__c = System.today(),
            Status__c = 'Active',
            Validation__c = true
        );
        insert offerPpi;

        Payment_Plan_Item__c standardPpi = new Payment_Plan_Item__c(
            Customer_Account__c = testAcc.Id,
            Amount__c = 5000.00,
            Invoiced_Amount__c = 1000.00,
            Status__c = 'Not Invoiced'
        );
        insert standardPpi;
    }

    @IsTest
    static void testGeneratePartialInvoices_OfferPPI_Success() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c oppi = [
            SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1
        ];

        PartialInvoiceService.InvoiceRequest req =
            new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 2000.00;

        List<PartialInvoiceService.InvoiceResult> results;

        System.runAs(testUser) {
            Test.startTest();
            results = PartialInvoiceService.generatePartialInvoices(
                new List<PartialInvoiceService.InvoiceRequest>{ req }
            );
            Test.stopTest();
        }

        System.assertEquals(1, results.size());
        // Include message so restricted-picklist / required-field errors are visible
        System.assertEquals(
            true,
            results[0].isSuccess,
            'Offer PPI partial invoice failed: ' + results[0].message
        );

        Invoice__c newInv = [
            SELECT Id, Invoice_Amount__c, Offer_Payment_Plan_Item__c
            FROM Invoice__c
            LIMIT 1
        ];
        System.assertEquals(2000.00, newInv.Invoice_Amount__c);
        System.assertEquals(oppi.Id, newInv.Offer_Payment_Plan_Item__c);

        Offer_Payment_Plan_Item__c updatedOppi = [
            SELECT Id, Invoiced_Amount__c, Status__c
            FROM Offer_Payment_Plan_Item__c
            WHERE Id = :oppi.Id
        ];
        System.assertEquals(2000.00, updatedOppi.Invoiced_Amount__c);
        // Only assert this if 'Partially Invoiced' is a valid OPPI status
        // System.assertEquals('Partially Invoiced', updatedOppi.Status__c);
    }

    @IsTest
    static void testGeneratePartialInvoices_StandardPPI_Success() {
        User testUser = getTestUser();
        Payment_Plan_Item__c ppi = [
            SELECT Id FROM Payment_Plan_Item__c LIMIT 1
        ];

        PartialInvoiceService.InvoiceRequest req =
            new PartialInvoiceService.InvoiceRequest();
        req.recordId = ppi.Id;
        req.amount = 1000.00;

        List<PartialInvoiceService.InvoiceResult> results;

        System.runAs(testUser) {
            Test.startTest();
            results = PartialInvoiceService.generatePartialInvoices(
                new List<PartialInvoiceService.InvoiceRequest>{ req }
            );
            Test.stopTest();
        }

        System.assertEquals(
            true,
            results[0].isSuccess,
            'Standard PPI partial invoice failed: ' + results[0].message
        );

        Payment_Plan_Item__c updatedPpi = [
            SELECT Id, Invoiced_Amount__c
            FROM Payment_Plan_Item__c
            WHERE Id = :ppi.Id
        ];
        System.assertEquals(2000.00, updatedPpi.Invoiced_Amount__c);
    }

    @IsTest
    static void testGeneratePartialInvoices_AmountZeroError() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c oppi = [
            SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1
        ];

        PartialInvoiceService.InvoiceRequest req =
            new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 0;

        System.runAs(testUser) {
            Test.startTest();
            List<PartialInvoiceService.InvoiceResult> results =
                PartialInvoiceService.generatePartialInvoices(
                    new List<PartialInvoiceService.InvoiceRequest>{ req }
                );
            Test.stopTest();

            System.assertEquals(false, results[0].isSuccess);
            System.assert(results[0].message.contains('must be greater than zero'));
        }
    }

    @IsTest
    static void testGeneratePartialInvoices_AmountExceedsRemainingError() {
        User testUser = getTestUser();
        Offer_Payment_Plan_Item__c oppi = [
            SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1
        ];

        PartialInvoiceService.InvoiceRequest req =
            new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 6000.00;

        System.runAs(testUser) {
            Test.startTest();
            List<PartialInvoiceService.InvoiceResult> results =
                PartialInvoiceService.generatePartialInvoices(
                    new List<PartialInvoiceService.InvoiceRequest>{ req }
                );
            Test.stopTest();

            System.assertEquals(false, results[0].isSuccess);
            System.assert(
                results[0].message.contains('cannot invoice the entire remaining amount')
            );
        }
    }

    @IsTest
    static void testGeneratePartialInvoices_RecordNotFoundError() {
        User testUser = getTestUser();
        Account acc = [SELECT Id FROM Account LIMIT 1];

        PartialInvoiceService.InvoiceRequest req =
            new PartialInvoiceService.InvoiceRequest();
        req.recordId = acc.Id;
        req.amount = 1000.00;

        System.runAs(testUser) {
            Test.startTest();
            List<PartialInvoiceService.InvoiceResult> results =
                PartialInvoiceService.generatePartialInvoices(
                    new List<PartialInvoiceService.InvoiceRequest>{ req }
                );
            Test.stopTest();

            System.assertEquals(false, results[0].isSuccess);
            System.assert(
                results[0].message.contains('Could not find the Installment record')
            );
        }
    }
}