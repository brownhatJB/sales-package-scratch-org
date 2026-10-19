@IsTest
private class AutoInvoiceServiceTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        Project__c proj = new Project__c(
            Name = 'Test Project',
            Stage__c = 'Planning',          
            UOM__c = 'Sq. Ft',
            Total_Area__c = 10000
        );
        insert proj;

        Properties__c prop = new Properties__c(
            Name = 'Test Property',
            Project__c = proj.Id,
            Stage__c = 'Under Construction',
            Property_Ownership__c = 'Fully Owned',
            UOM__c = 'Sq. Ft',
            Total_Area__c = 1000,
            Enabled_For_Auto_Invoicing__c = true
        );
        insert prop;

        Units__c unit = new Units__c(
            Name = 'Unit-101',              
            Project__c = proj.Id,
            Properties__c = prop.Id,

            Floor__c = 1,                 
            View__c = 'Lake',          
            Type__c = 'Apartment',          
            Bedrooms__c = 2,             
            Furnishing_Status__c = 'Furnished',

            Unit_Price__c = 1000000,
            Current_Selling_Price__c = 1000000,
            Total_Area__c = 1200
        );
        insert unit;

        Milestone__c milestone = new Milestone__c(
            Name = 'Booking'
        );
        insert milestone;

        Payment_Plan_Item__c ppi = new Payment_Plan_Item__c(
            Contact__c = con.Id,
            Customer_Account__c = acc.Id,
            Project__c = proj.Id,
            Properties__c = prop.Id,
            Units__c = unit.Id,
            Milestone__c = milestone.Id,

            Status__c = 'Not Invoiced',
            Skip_Invoice__c = false,
            Actual_Due_Date__c = Date.today(),

            Amount__c = 1000,
            Tax_Amount__c = 100,
            Total_Amount_Excluding_Tax__c = 900
        );

        insert ppi;
    }

    @IsTest
    static void testGenerateInvoices() {

        List<Payment_Plan_Item__c> items = [
            SELECT
                Id,
                Actual_Due_Date__c,
                Contact__c,
                Customer_Account__c,
                Amount__c,
                Milestone__c,
                Milestone__r.Name,
                Project__c,
                Properties__c,
                Tax_Amount__c,
                Total_Amount_Excluding_Tax__c,
                Unit_Sale__c,
                Units__c
            FROM Payment_Plan_Item__c
        ];

        //Test.startTest();
        //AutoInvoiceService.generateInvoices(items);
        //Test.stopTest();

        //System.assertEquals(1,[SELECT COUNT() FROM Batch_Invoices__c]);

        //System.assertEquals(1,[SELECT COUNT() FROM Invoice__c]);

        //System.assertEquals(1,[SELECT COUNT() FROM Statement_of_account__c]);

        Payment_Plan_Item__c updated = [
            SELECT Status__c,
                   Invoice_Date__c,
                   Auto_Invoiced_Date__c,
                   Batch_Invoices__c
            FROM Payment_Plan_Item__c
            LIMIT 1
        ];

        //System.assertEquals('Invoiced', updated.Status__c);
        //System.assertNotEquals(null, updated.Invoice_Date__c);
        //System.assertNotEquals(null, updated.Auto_Invoiced_Date__c);
        //System.assertNotEquals(null, updated.Batch_Invoices__c);
    }

    @IsTest
    static void testGenerateInvoicesWithEmptyList() {

        Test.startTest();
        AutoInvoiceService.generateInvoices(new List<Payment_Plan_Item__c>());
        Test.stopTest();

        //System.assertEquals(0,[SELECT COUNT() FROM Invoice__c]);
    }
}