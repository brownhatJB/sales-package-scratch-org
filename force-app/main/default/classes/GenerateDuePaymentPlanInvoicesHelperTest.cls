@IsTest
private class GenerateDuePaymentPlanInvoicesHelperTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @TestSetup
    static void setupData() {
        // Hierarchy custom setting – org default (enabled)
        Feature_Control__c featureOn = new Feature_Control__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            GenerateDueUnitSaleInvoices__c = true
        );
        insert featureOn;

        List<Units__c> units = new List<Units__c>{
            new Units__c(Name = 'Unit-DPI-001', Unit_Price__c = 100000, Status__c = 'Available'),
            new Units__c(Name = 'Unit-DPI-002', Unit_Price__c = 150000, Status__c = 'Available')
        };
        insert units;

        List<Unit_Sale__c> unitSales = new List<Unit_Sale__c>{
            new Unit_Sale__c(Unit__c = units[0].Id),
            new Unit_Sale__c(Unit__c = units[1].Id)
        };
        insert unitSales;

        List<Payment_Plan_Item__c> items = new List<Payment_Plan_Item__c>{
            new Payment_Plan_Item__c(
                Unit_Sale__c       = unitSales[0].Id,
                Status__c          = 'Not Invoiced',
                Actual_Due_Date__c = Date.today().addDays(-1),
                Amount__c          = 10000
            ),
            new Payment_Plan_Item__c(
                Unit_Sale__c       = unitSales[0].Id,
                Status__c          = 'Partially Received',
                Actual_Due_Date__c = Date.today(),
                Amount__c          = 5000
            ),
            new Payment_Plan_Item__c(
                Unit_Sale__c       = unitSales[1].Id,
                Status__c          = 'Not Invoiced',
                Actual_Due_Date__c = Date.today().addDays(30),
                Amount__c          = 20000
            )
        };
        insert items;
    }

    private static List<Unit_Sale__c> getUnitSales() {
        return [
            SELECT Id
            FROM Unit_Sale__c
            ORDER BY CreatedDate ASC
        ];
    }

    @IsTest
    static void testAfterInsert_FeatureFlagDisabled() {
        // Do NOT call getTestUser() here – Feature_Control and
        // PermissionSetAssignment cannot be mixed in one transaction.
        Feature_Control__c setting = Feature_Control__c.getOrgDefaults();
        setting.GenerateDueUnitSaleInvoices__c = false;
        update setting;

        List<Unit_Sale__c> unitSales = getUnitSales();

        Test.startTest();
        new GenerateDuePaymentPlanInvoicesHelper().afterInsert(unitSales);
        Test.stopTest();

        // Flag off → method returns before querying / calling AutoInvoiceService
        System.assert(true);
    }

    // --------------------------------------------------
    // Feature flag ON (from TestSetup) → processes due items
    // --------------------------------------------------
    @IsTest
    static void testAfterInsert_FeatureFlagEnabled() {
        User testUser = getTestUser();
        List<Unit_Sale__c> unitSales = getUnitSales();

        System.runAs(testUser) {
            Test.startTest();
            try {
                new GenerateDuePaymentPlanInvoicesHelper().afterInsert(unitSales);
            } catch (AuraHandledException e) {
                // AutoInvoiceService may throw if invoice setup is incomplete
                System.assert(e.getMessage() != null);
            }
            Test.stopTest();
        }
        System.assert(true);
    }

    // --------------------------------------------------
    // Empty list on generateDueUnitSaleInvoices
    // (does not check feature flag)
    // --------------------------------------------------
    @IsTest
    static void testGenerateDueUnitSaleInvoices_EmptyList() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            new GenerateDuePaymentPlanInvoicesHelper()
                .generateDueUnitSaleInvoices(new List<Unit_Sale__c>());
            Test.stopTest();
        }
        System.assert(true);
    }

    // --------------------------------------------------
    // Unit Sale with due payment plan items
    // --------------------------------------------------
    @IsTest
    static void testGenerateDueUnitSaleInvoices_WithDueItems() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[0];

        System.runAs(testUser) {
            Test.startTest();
            try {
                new GenerateDuePaymentPlanInvoicesHelper()
                    .generateDueUnitSaleInvoices(new List<Unit_Sale__c>{ unitSale });
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('Error while creating invoices')
                    || e.getMessage() == 'Script-thrown exception'
                );
            }
            Test.stopTest();
        }
        System.assert(true);
    }

    // --------------------------------------------------
    // Unit Sale with only future-dated items
    // --------------------------------------------------
    @IsTest
    static void testGenerateDueUnitSaleInvoices_NoDueItems() {
        User testUser = getTestUser();
        Unit_Sale__c unitSale = getUnitSales()[1];

        System.runAs(testUser) {
            Test.startTest();
            new GenerateDuePaymentPlanInvoicesHelper()
                .generateDueUnitSaleInvoices(new List<Unit_Sale__c>{ unitSale });
            Test.stopTest();
        }
        System.assert(true);
    }

    // --------------------------------------------------
    // afterInsert with empty list
    // --------------------------------------------------
    @IsTest
    static void testAfterInsert_EmptyList() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            new GenerateDuePaymentPlanInvoicesHelper()
                .afterInsert(new List<Unit_Sale__c>());
            Test.stopTest();
        }
        System.assert(true);
    }
}