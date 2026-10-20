@isTest
private class PartialInvoiceServiceTest {

    @TestSetup
    static void setupData() {
        // ==========================================
        // LEVEL 1: MASTER RECORDS
        // ==========================================
        Account testAcc = new Account(Name = 'Test Customer');
        insert testAcc;

        Project__c testProject = new Project__c(Name = 'AlSalama Heights');
        insert testProject;
        
        // --- NEW FIX: Create Property ---
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

        // 1. Create the Offer Payment Plan Item (Offer PPI)
        Offer_Payment_Plan_Item__c offerPpi = new Offer_Payment_Plan_Item__c(
            Offer__c = testOffer.Id,
            Payment_Item_Master__c = pimPlanItem.Id, 
            Offer_Item__c = offerItem.Id,
            Unit__c = testUnit.Id,
            Template_Item__c = templateItem.Id, 
            Amount__c = 5000.00,
            Invoiced_Amount__c = 0, // 0 Invoiced so far
            Tentative_Due_Date__c = System.today(),
            Status__c = 'Active'
        );
        insert offerPpi;

        // 2. Create the Standard Payment Plan Item (PPI)
        Payment_Plan_Item__c standardPpi = new Payment_Plan_Item__c(
            Customer_Account__c = testAcc.Id,
            Amount__c = 5000.00,
            Invoiced_Amount__c = 1000.00, // 1000 already invoiced
            Status__c = 'Not Invoiced'
        );
        insert standardPpi;
    }

    @isTest
    static void testGeneratePartialInvoices_OfferPPI_Success() {
        // Get the Offer PPI
        Offer_Payment_Plan_Item__c oppi = [SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1];
        
        PartialInvoiceService.InvoiceRequest req = new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 2000.00; // Total is 5000, so 2000 is valid
        
        Test.startTest();
        List<PartialInvoiceService.InvoiceResult> results = PartialInvoiceService.generatePartialInvoices(new List<PartialInvoiceService.InvoiceRequest>{req});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess, 'Should successfully create partial invoice for Offer PPI');
        
        // Verify the Invoice was created
        Invoice__c newInv = [SELECT Id, Invoice_Amount__c, Offer_Payment_Plan_Item__c FROM Invoice__c LIMIT 1];
        System.assertEquals(2000.00, newInv.Invoice_Amount__c);
        System.assertEquals(oppi.Id, newInv.Offer_Payment_Plan_Item__c);
        
        // Verify Parent was updated
        Offer_Payment_Plan_Item__c updatedOppi = [SELECT Id, Invoiced_Amount__c, Status__c FROM Offer_Payment_Plan_Item__c WHERE Id = :oppi.Id];
        System.assertEquals(2000.00, updatedOppi.Invoiced_Amount__c);
        System.assertEquals('Partially Invoiced', updatedOppi.Status__c);
    }

    @isTest
    static void testGeneratePartialInvoices_StandardPPI_Success() {
        // Get the Standard PPI
        Payment_Plan_Item__c ppi = [SELECT Id FROM Payment_Plan_Item__c LIMIT 1];
        
        PartialInvoiceService.InvoiceRequest req = new PartialInvoiceService.InvoiceRequest();
        req.recordId = ppi.Id;
        req.amount = 1000.00; 
        
        Test.startTest();
        List<PartialInvoiceService.InvoiceResult> results = PartialInvoiceService.generatePartialInvoices(new List<PartialInvoiceService.InvoiceRequest>{req});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, results[0].isSuccess);
        
        // Verify Parent was updated correctly (1000 existing + 1000 new = 2000)
        Payment_Plan_Item__c updatedPpi = [SELECT Id, Invoiced_Amount__c FROM Payment_Plan_Item__c WHERE Id = :ppi.Id];
        System.assertEquals(2000.00, updatedPpi.Invoiced_Amount__c);
    }

    @isTest
    static void testGeneratePartialInvoices_AmountZeroError() {
        Offer_Payment_Plan_Item__c oppi = [SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1];
        
        PartialInvoiceService.InvoiceRequest req = new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 0; // Invalid amount
        
        Test.startTest();
        List<PartialInvoiceService.InvoiceResult> results = PartialInvoiceService.generatePartialInvoices(new List<PartialInvoiceService.InvoiceRequest>{req});
        Test.stopTest();
        
        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].message.contains('must be greater than zero'));
    }

    @isTest
    static void testGeneratePartialInvoices_AmountExceedsRemainingError() {
        Offer_Payment_Plan_Item__c oppi = [SELECT Id FROM Offer_Payment_Plan_Item__c LIMIT 1];
        
        PartialInvoiceService.InvoiceRequest req = new PartialInvoiceService.InvoiceRequest();
        req.recordId = oppi.Id;
        req.amount = 6000.00; // Exceeds the 5000 total amount
        
        Test.startTest();
        List<PartialInvoiceService.InvoiceResult> results = PartialInvoiceService.generatePartialInvoices(new List<PartialInvoiceService.InvoiceRequest>{req});
        Test.stopTest();
        
        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].message.contains('cannot invoice the entire remaining amount'));
    }

    @isTest
    static void testGeneratePartialInvoices_RecordNotFoundError() {
        // Pass a random ID (e.g., the Account ID) to simulate passing the wrong record type
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        PartialInvoiceService.InvoiceRequest req = new PartialInvoiceService.InvoiceRequest();
        req.recordId = acc.Id;
        req.amount = 1000.00; 
        
        Test.startTest();
        List<PartialInvoiceService.InvoiceResult> results = PartialInvoiceService.generatePartialInvoices(new List<PartialInvoiceService.InvoiceRequest>{req});
        Test.stopTest();
        
        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].message.contains('Could not find the Installment record'));
    }
}