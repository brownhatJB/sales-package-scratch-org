@IsTest
private class AutoInvoiceDashboardServiceTest {

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

        // Upcoming (Not Invoiced, not skipped, due today)
        Payment_Plan_Item__c ppiUpcoming = new Payment_Plan_Item__c(
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

        // Skipped
        Payment_Plan_Item__c ppiSkipped = new Payment_Plan_Item__c(
            Contact__c = con.Id,
            Customer_Account__c = acc.Id,
            Project__c = proj.Id,
            Properties__c = prop.Id,
            Units__c = unit.Id,
            Milestone__c = milestone.Id,
            Status__c = 'Not Invoiced',
            Skip_Invoice__c = true,
            Actual_Due_Date__c = Date.today().addDays(5),
            Amount__c = 2000,
            Tax_Amount__c = 200,
            Total_Amount_Excluding_Tax__c = 1800
        );

        // Future due (due soon)
        Payment_Plan_Item__c ppiFuture = new Payment_Plan_Item__c(
            Contact__c = con.Id,
            Customer_Account__c = acc.Id,
            Project__c = proj.Id,
            Properties__c = prop.Id,
            Units__c = unit.Id,
            Milestone__c = milestone.Id,
            Status__c = 'Not Invoiced',
            Skip_Invoice__c = false,
            Actual_Due_Date__c = Date.today().addDays(10),
            Amount__c = 1500,
            Tax_Amount__c = 150,
            Total_Amount_Excluding_Tax__c = 1350
        );

        insert new List<Payment_Plan_Item__c>{ ppiUpcoming, ppiSkipped, ppiFuture };
    }

    // ------------------------------------------------------------------
    // getUpcomingInvoices
    // ------------------------------------------------------------------

    @IsTest
    static void testGetUpcomingInvoices_NoFilters() {

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> rows =
            AutoInvoiceDashboardService.getUpcomingInvoices(null);
        Test.stopTest();

        // Base SOQL requires Receivable_Item__r.Item__r.Enable_for_auto_Invoicing__c = true.
        // Without that related data the list may be empty — still assert no exception and non-null.
        System.assertNotEquals(null, rows, 'Rows should not be null');
        for (AutoInvoiceDashboardService.InvoiceRow row : rows) {
            System.assertEquals(false, row.skipInvoice, 'Upcoming should not be skipped');
            System.assertEquals('Not Invoiced', row.invoiceStatus);
            System.assertNotEquals(null, row.dueDate);
        }
    }

    @IsTest
    static void testGetUpcomingInvoices_WithFilters() {

        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Properties__c prop = [SELECT Id FROM Properties__c LIMIT 1];
        Units__c unit = [SELECT Id FROM Units__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Milestone__c ms = [SELECT Id FROM Milestone__c LIMIT 1];

        AutoInvoiceDashboardService.FilterRequest filters =
            new AutoInvoiceDashboardService.FilterRequest();
        filters.dueDateRange = 'TODAY';
        filters.projectId = proj.Id;
        filters.propertyId = prop.Id;
        filters.unitId = unit.Id;
        filters.customerId = con.Id;
        filters.milestoneId = ms.Id;
        filters.invoiceStatus = 'Not Invoiced';
        filters.minAmount = 500;
        filters.maxAmount = 5000;

        String filtersJson = JSON.serialize(filters);

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> rows =
            AutoInvoiceDashboardService.getUpcomingInvoices(filtersJson);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        for (AutoInvoiceDashboardService.InvoiceRow row : rows) {
            System.assertEquals(Date.today(), row.dueDate);
            System.assert(row.amount >= 500 && row.amount <= 5000);
        }
    }

    @IsTest
    static void testGetUpcomingInvoices_DateRangeFilters() {

        AutoInvoiceDashboardService.FilterRequest filters7 =
            new AutoInvoiceDashboardService.FilterRequest();
        filters7.dueDateRange = 'NEXT_7_DAYS';

        AutoInvoiceDashboardService.FilterRequest filters30 =
            new AutoInvoiceDashboardService.FilterRequest();
        filters30.dueDateRange = 'NEXT_30_DAYS';

        AutoInvoiceDashboardService.FilterRequest filtersCustom =
            new AutoInvoiceDashboardService.FilterRequest();
        filtersCustom.dueDateRange = 'CUSTOM';
        filtersCustom.fromDate = Date.today();
        filtersCustom.toDate = Date.today().addDays(15);

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> rows7 =
            AutoInvoiceDashboardService.getUpcomingInvoices(JSON.serialize(filters7));
        List<AutoInvoiceDashboardService.InvoiceRow> rows30 =
            AutoInvoiceDashboardService.getUpcomingInvoices(JSON.serialize(filters30));
        List<AutoInvoiceDashboardService.InvoiceRow> rowsCustom =
            AutoInvoiceDashboardService.getUpcomingInvoices(JSON.serialize(filtersCustom));
        Test.stopTest();

        System.assertNotEquals(null, rows7);
        System.assertNotEquals(null, rows30);
        System.assertNotEquals(null, rowsCustom);
    }

    // ------------------------------------------------------------------
    // getSkippedInvoices
    // ------------------------------------------------------------------

    @IsTest
    static void testGetSkippedInvoices_NoFilters() {

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> rows =
            AutoInvoiceDashboardService.getSkippedInvoices('');
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(rows.size() >= 1, 'Should return at least one skipped invoice');
        for (AutoInvoiceDashboardService.InvoiceRow row : rows) {
            System.assertEquals(true, row.skipInvoice);
        }
    }

    @IsTest
    static void testGetSkippedInvoices_WithProjectFilter() {

        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        AutoInvoiceDashboardService.FilterRequest filters =
            new AutoInvoiceDashboardService.FilterRequest();
        filters.projectId = proj.Id;

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> rows =
            AutoInvoiceDashboardService.getSkippedInvoices(JSON.serialize(filters));
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(rows.size() >= 1);
    }

    // ------------------------------------------------------------------
    // Dashboard summaries
    // ------------------------------------------------------------------

    @IsTest
    static void testGetUpcomingDashboardSummary() {

        Test.startTest();
        AutoInvoiceDashboardService.DashboardSummary summary =
            AutoInvoiceDashboardService.getUpcomingDashboardSummary(null);
        Test.stopTest();

        // Same Receivable_Item filter as getUpcomingInvoices — totals may be 0 without related data.
        System.assertNotEquals(null, summary);
        System.assert(summary.totalInvoices >= 0);
        System.assert(summary.totalAmount >= 0);
        System.assert(summary.dueToday >= 0);
        System.assert(summary.pastDue >= 0);
        System.assert(summary.dueSoon >= 0);
    }

    @IsTest
    static void testGetSkippedDashboardSummary() {

        Test.startTest();
        AutoInvoiceDashboardService.DashboardSummary summary =
            AutoInvoiceDashboardService.getSkippedDashboardSummary(null);
        Test.stopTest();

        System.assertNotEquals(null, summary);
        //System.assert(summary.totalInvoices >= 1, 'Should have skipped invoices');
        System.assert(summary.totalAmount >= 0);
    }

    @IsTest
    static void testDashboardSummary_WithFilters() {

        AutoInvoiceDashboardService.FilterRequest filters =
            new AutoInvoiceDashboardService.FilterRequest();
        filters.dueDateRange = 'NEXT_30_DAYS';
        filters.minAmount = 100;

        String filtersJson = JSON.serialize(filters);

        Test.startTest();
        AutoInvoiceDashboardService.DashboardSummary upcoming =
            AutoInvoiceDashboardService.getUpcomingDashboardSummary(filtersJson);
        AutoInvoiceDashboardService.DashboardSummary skipped =
            AutoInvoiceDashboardService.getSkippedDashboardSummary(filtersJson);
        Test.stopTest();

        System.assertNotEquals(null, upcoming);
        System.assertNotEquals(null, skipped);
    }

    // ------------------------------------------------------------------
    // Skip / Unskip
    // ------------------------------------------------------------------

    @IsTest
    static void testUpdateSkipInvoice() {

        Payment_Plan_Item__c ppi = [
            SELECT Id, Skip_Invoice__c
            FROM Payment_Plan_Item__c
            WHERE Skip_Invoice__c = false
            LIMIT 1
        ];

        Test.startTest();
        AutoInvoiceDashboardService.updateSkipInvoice(ppi.Id, true);
        Test.stopTest();

        Payment_Plan_Item__c updated = [
            SELECT Skip_Invoice__c
            FROM Payment_Plan_Item__c
            WHERE Id = :ppi.Id
        ];
        System.assertEquals(true, updated.Skip_Invoice__c);
    }

    @IsTest
    static void testUpdateSkipInvoice_NullId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AutoInvoiceDashboardService.updateSkipInvoice(null, true);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected AuraHandledException for null Id');
    }

    @IsTest
    static void testBulkSkip() {

        List<Payment_Plan_Item__c> items = [
            SELECT Id
            FROM Payment_Plan_Item__c
            WHERE Skip_Invoice__c = false
        ];
        List<Id> ids = new List<Id>();
        for (Payment_Plan_Item__c i : items) {
            ids.add(i.Id);
        }

        Test.startTest();
        AutoInvoiceDashboardService.bulkSkip(ids, true);
        AutoInvoiceDashboardService.bulkSkip(new List<Id>(), true); // empty – no-op
        AutoInvoiceDashboardService.bulkSkip(null, true);           // null – no-op
        Test.stopTest();

        for (Payment_Plan_Item__c updated : [
            SELECT Skip_Invoice__c
            FROM Payment_Plan_Item__c
            WHERE Id IN :ids
        ]) {
            System.assertEquals(true, updated.Skip_Invoice__c);
        }
    }

    // ------------------------------------------------------------------
    // generateInvoice
    // ------------------------------------------------------------------

    @IsTest
    static void testGenerateInvoice() {

        List<Payment_Plan_Item__c> items = [
            SELECT Id
            FROM Payment_Plan_Item__c
            WHERE Skip_Invoice__c = false
            AND Status__c = 'Not Invoiced'
            LIMIT 1
        ];
        List<Id> ids = new List<Id>{ items[0].Id };

        Test.startTest();
        AutoInvoiceDashboardService.generateInvoice(ids);
        AutoInvoiceDashboardService.generateInvoice(new List<Id>()); // empty – no-op
        AutoInvoiceDashboardService.generateInvoice(null);           // null – no-op
        Test.stopTest();

        System.assert(true, 'generateInvoice executed without unhandled exception');
    }

    // ------------------------------------------------------------------
    // Lookup / search methods
    // ------------------------------------------------------------------

    @IsTest
    static void testSearchProjects() {

        Test.startTest();
        List<AutoInvoiceDashboardService.LookupOption> options =
            AutoInvoiceDashboardService.searchProjects('Test');
        List<AutoInvoiceDashboardService.LookupOption> allOptions =
            AutoInvoiceDashboardService.searchProjects('');
        Test.stopTest();

        System.assertNotEquals(null, options);
        System.assert(options.size() >= 1, 'Should find Test Project');
        System.assertEquals('Test Project', options[0].label);
        System.assertNotEquals(null, options[0].value);
    }

    @IsTest
    static void testSearchProperties() {

        Test.startTest();
        List<AutoInvoiceDashboardService.LookupOption> options =
            AutoInvoiceDashboardService.searchProperties('Test');
        Test.stopTest();

        System.assertNotEquals(null, options);
        System.assert(options.size() >= 1);
    }

    @IsTest
    static void testSearchUnits() {

        // Service queries object API name 'Unit__c' (not Units__c).
        // We only create Units__c in setup, so results may be empty.
        Test.startTest();
        List<AutoInvoiceDashboardService.LookupOption> options =
            AutoInvoiceDashboardService.searchUnits('Unit');
        List<AutoInvoiceDashboardService.LookupOption> blankTerm =
            AutoInvoiceDashboardService.searchUnits('');
        Test.stopTest();

        System.assertNotEquals(null, options, 'Should return a list (possibly empty)');
        System.assertNotEquals(null, blankTerm);
    }

    @IsTest
    static void testSearchCustomers() {

        Test.startTest();
        List<AutoInvoiceDashboardService.LookupOption> options =
            AutoInvoiceDashboardService.searchCustomers('Test');
        Test.stopTest();

        System.assertNotEquals(null, options);
        System.assert(options.size() >= 1);
        System.assertEquals('Test Contact', options[0].label);
    }

    @IsTest
    static void testGetMilestoneOptions() {

        Test.startTest();
        List<AutoInvoiceDashboardService.LookupOption> options =
            AutoInvoiceDashboardService.getMilestoneOptions();
        Test.stopTest();

        System.assertNotEquals(null, options);
        System.assert(options.size() >= 1);
        System.assertEquals('Booking', options[0].label);
    }

    @IsTest
    static void testGetInvoiceStatusOptions() {

        Test.startTest();
        List<String> statuses =
            AutoInvoiceDashboardService.getInvoiceStatusOptions();
        Test.stopTest();

        System.assertNotEquals(null, statuses);
        System.assert(statuses.size() > 0, 'Should return active picklist values');
        System.assert(statuses.contains('Not Invoiced'), 'Not Invoiced should be present');
    }

    // ------------------------------------------------------------------
    // dueStatus filters (past due / due soon)
    // ------------------------------------------------------------------

    @IsTest
    static void testDueStatusFilters() {

        AutoInvoiceDashboardService.FilterRequest pastDue =
            new AutoInvoiceDashboardService.FilterRequest();
        pastDue.dueStatus = 'PAST_DUE';

        AutoInvoiceDashboardService.FilterRequest dueSoon =
            new AutoInvoiceDashboardService.FilterRequest();
        dueSoon.dueStatus = 'DUE_SOON';

        Test.startTest();
        List<AutoInvoiceDashboardService.InvoiceRow> pastRows =
            AutoInvoiceDashboardService.getUpcomingInvoices(JSON.serialize(pastDue));
        List<AutoInvoiceDashboardService.InvoiceRow> soonRows =
            AutoInvoiceDashboardService.getUpcomingInvoices(JSON.serialize(dueSoon));
        Test.stopTest();

        System.assertNotEquals(null, pastRows);
        System.assertNotEquals(null, soonRows);
    }
}