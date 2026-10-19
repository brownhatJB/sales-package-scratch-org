/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : Jouhar C
 * @email             : jouhar@metadatacorp.com
 * @last modified on  : 16-07-2026
 * @last modified by  : Jouhar C
**/

public with sharing class AutoInvoiceDashboardService {

    public class FilterRequest {

        @AuraEnabled public String dueDateRange { get; set; }

        @AuraEnabled public Date fromDate { get; set; }
        @AuraEnabled public Date toDate { get; set; }

        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id propertyId { get; set; }
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public Id milestoneId { get; set; }

        @AuraEnabled public String invoiceStatus { get; set; }

        @AuraEnabled public Decimal minAmount { get; set; }
        @AuraEnabled public Decimal maxAmount { get; set; }

        @AuraEnabled public String dueStatus { get; set; }

        public FilterRequest() {}
    }

    public class DashboardSummary {

        @AuraEnabled public Integer totalInvoices;

        @AuraEnabled public Decimal totalAmount;

        @AuraEnabled public Integer dueToday;

        @AuraEnabled public Integer pastDue;

        @AuraEnabled public Integer dueSoon;
    }

    public class InvoiceRow {

        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String uslName;
        @AuraEnabled public String customer;
        @AuraEnabled public String project;
        @AuraEnabled public String property;
        @AuraEnabled public String unit;
        @AuraEnabled public String milestone;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String invoiceStatus;
        @AuraEnabled public Boolean skipInvoice;
    }

    public class LookupOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;

        public LookupOption(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    @AuraEnabled
    public static List<InvoiceRow> getUpcomingInvoices(String filtersJson) {

        FilterRequest filters =
            String.isBlank(filtersJson)
            ? new FilterRequest()
            : (FilterRequest)JSON.deserialize(filtersJson, FilterRequest.class);

        try {
            String soql =
                'SELECT ' +
                'Id,' +
                'Name, ' +
                'Unit_Sale__r.Name, ' +
                'Amount__c,' +
                'Actual_Due_Date__c,' +
                'Status__c,' +
                'Skip_Invoice__c,' +
                'Contact__r.Name,' +
                'Project__r.Name,' +
                'Properties__r.Name,' +
                'Units__r.Name,' +
                'Milestone__r.Name ' +
                'FROM Payment_Plan_Item__c ' +
                'WHERE Skip_Invoice__c = false ' +
                'AND Receivable_Item__r.Item__r.Enable_for_auto_Invoicing__c = true ' +
                'AND Status__c IN (\'Not Invoiced\', \'Partially Invoiced\') ' +
                'AND Actual_Due_Date__c >= TODAY ';

            soql += buildFilterQuery(filters);

            soql += ' ORDER BY Actual_Due_Date__c ASC';

            List<Payment_Plan_Item__c> items =
                Database.query(soql);

            List<InvoiceRow> rows = new List<InvoiceRow>();

            for(Payment_Plan_Item__c item : items){

                InvoiceRow row = new InvoiceRow();

                row.id = item.Id;
                row.name = item.Name;
                row.uslName = item.Unit_Sale__r != null ? item.Unit_Sale__r.Name : '';
                row.customer = item.Contact__r != null ? item.Contact__r.Name : '';
                row.project = item.Project__r != null ? item.Project__r.Name : '';
                row.property = item.Properties__r != null ? item.Properties__r.Name : '';
                row.unit = item.Units__r != null ? item.Units__r.Name : '';
                row.milestone = item.Milestone__r != null ? item.Milestone__r.Name : '';
                row.dueDate = item.Actual_Due_Date__c;
                row.amount = item.Amount__c;
                row.invoiceStatus = item.Status__c;
                row.skipInvoice = item.Skip_Invoice__c;

                rows.add(row);
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('getUpcomingInvoices: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<InvoiceRow> getSkippedInvoices(String filtersJson) {

        FilterRequest filters =
            String.isBlank(filtersJson)
            ? new FilterRequest()
            : (FilterRequest)JSON.deserialize(filtersJson, FilterRequest.class);

        try {
            String soql =
                'SELECT ' +
                'Id,' +
                'Name, ' +
                'Unit_Sale__r.Name, ' +
                'Amount__c,' +
                'Actual_Due_Date__c,' +
                'Status__c,' +
                'Skip_Invoice__c,' +
                'Contact__r.Name,' +
                'Project__r.Name,' +
                'Properties__r.Name,' +
                'Units__r.Name,' +
                'Milestone__r.Name ' +
                'FROM Payment_Plan_Item__c ' +
                'WHERE Skip_Invoice__c = true ' +
                'AND Status__c IN (\'Not Invoiced\', \'Partially Invoiced\') ';

            soql += buildFilterQuery(filters);

            soql += ' ORDER BY Actual_Due_Date__c ASC';

            List<Payment_Plan_Item__c> items = Database.query(soql);

            List<InvoiceRow> rows = new List<InvoiceRow>();

            for (Payment_Plan_Item__c item : items) {

                InvoiceRow row = new InvoiceRow();

                row.id = item.Id;
                row.name = item.Name;
                row.uslName = item.Unit_Sale__r != null ? item.Unit_Sale__r.Name : '';
                row.customer = item.Contact__r != null ? item.Contact__r.Name : '';
                row.project = item.Project__r != null ? item.Project__r.Name : '';
                row.property = item.Properties__r != null ? item.Properties__r.Name : '';
                row.unit = item.Units__r != null ? item.Units__r.Name : '';
                row.milestone = item.Milestone__r != null ? item.Milestone__r.Name : '';
                row.dueDate = item.Actual_Due_Date__c;
                row.amount = item.Amount__c;
                row.invoiceStatus = item.Status__c;
                row.skipInvoice = item.Skip_Invoice__c;

                rows.add(row);
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('getSkippedInvoices: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static DashboardSummary getUpcomingDashboardSummary(String filtersJson) {

        FilterRequest filters =
            String.isBlank(filtersJson)
            ? new FilterRequest()
            : (FilterRequest)JSON.deserialize(filtersJson, FilterRequest.class);
            
        return getDashboardSummary(filters, false);
    }

    @AuraEnabled
    public static DashboardSummary getSkippedDashboardSummary(String filtersJson) {

        FilterRequest filters =
            String.isBlank(filtersJson)
            ? new FilterRequest()
            : (FilterRequest)JSON.deserialize(filtersJson, FilterRequest.class);
            
        return getDashboardSummary(filters, true);
    }

    @AuraEnabled
    public static void updateSkipInvoice(Id paymentPlanItemId, Boolean skip) {

        if(paymentPlanItemId == null) {
            throw new AuraHandledException('Payment Plan Item Id is required.');
        }

        bulkSkip(new List<Id>{ paymentPlanItemId }, skip);
    }

    @AuraEnabled
    public static void bulkSkip(List<Id> paymentPlanItemIds, Boolean skip) {

        if(paymentPlanItemIds == null || paymentPlanItemIds.isEmpty()) {
            return;
        }

        try {
            List<Payment_Plan_Item__c> paymentPlanItemsToUpdate = new List<Payment_Plan_Item__c>();

            for(Id paymentPlanItemId : paymentPlanItemIds) {

                paymentPlanItemsToUpdate.add(new Payment_Plan_Item__c(
                    Id = paymentPlanItemId,
                    Skip_Invoice__c = skip
                ));
            }

            update paymentPlanItemsToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('bulkSkip: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void generateInvoice(List<Id> paymentPlanItemIds) {

        if(paymentPlanItemIds == null || paymentPlanItemIds.isEmpty()) {
            return;
        }

        try {
            List<Payment_Plan_Item__c> paymentPlanItems = [
                SELECT
                    Id,
                    Amount__c,
                    Actual_Due_Date__c,
                    Contact__c,
                    Customer_Account__c,
                    Project__c,
                    Properties__c,
                    Units__c,
                    Unit_Sale__c,
                    Milestone__c,
                    Milestone__r.Name,
                    Tax_Amount__c,
                    Total_Amount_Excluding_Tax__c,
                    Invoiced_Amount__c,
                    Status__c
                FROM Payment_Plan_Item__c
                WHERE Id IN :paymentPlanItemIds
            ];

            AutoInvoiceService.generateInvoices(paymentPlanItems);
        } catch (Exception e) {
            throw new AuraHandledException('generateInvoice: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------
    // Filter panel lookups (used by the dashboard's filter bar)
    // ------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchProjects(String term) {
        return runNameSearch('Project__c', term);
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchProperties(String term) {
        return runNameSearch('Properties__c', term);
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchUnits(String term) {
        return runNameSearch('Unit__c', term);
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchCustomers(String term) {
        List<LookupOption> options = new List<LookupOption>();
        String likeTerm = '%' + String.escapeSingleQuotes(term) + '%';

        for (Contact c : [
            SELECT Id, Name
            FROM Contact
            WHERE Name LIKE :likeTerm
            ORDER BY Name
            LIMIT 10
        ]) {
            options.add(new LookupOption(c.Id, c.Name));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getMilestoneOptions() {
        return runNameSearch('Milestone__c', null);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getInvoiceStatusOptions() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult dfr =
            Payment_Plan_Item__c.Status__c.getDescribe();

        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    //helper classes

    private static List<LookupOption> runNameSearch(String objectApiName, String term) {
        List<LookupOption> options = new List<LookupOption>();

        String query = 'SELECT Id, Name FROM ' + objectApiName;
        if (String.isNotBlank(term)) {
            query += ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(term) + '%\'';
        }
        query += ' ORDER BY Name LIMIT 10';

        try {
            for (SObject record : Database.query(query)) {
                options.add(new LookupOption(
                    (Id) record.get('Id'),
                    (String) record.get('Name')
                ));
            }
        } catch (Exception e) {
            System.debug('AutoInvoiceDashboardService.runNameSearch error: ' + e.getMessage());
        }

        return options;
    }

    private static String buildFilterQuery(FilterRequest filters){

        List<String> conditions = new List<String>();

        if(filters == null){
            return '';
        }

        // Due Date Range
        if(filters.dueDateRange == 'TODAY'){

            conditions.add(
                'Actual_Due_Date__c = TODAY'
            );
        }

        else if(filters.dueDateRange == 'NEXT_7_DAYS'){

            conditions.add(
                'Actual_Due_Date__c >= TODAY AND Actual_Due_Date__c <= NEXT_N_DAYS:7'
            );
        }

        else if(filters.dueDateRange == 'NEXT_30_DAYS'){

            conditions.add(
                'Actual_Due_Date__c >= TODAY AND Actual_Due_Date__c <= NEXT_N_DAYS:30'
            );
        }

        else if(filters.dueDateRange == 'CUSTOM'){

            if(filters.fromDate != null){

                conditions.add(
                    'Actual_Due_Date__c >= ' +
                    String.valueOf(filters.fromDate)
                );
            }

            if(filters.toDate != null){

                conditions.add(
                    'Actual_Due_Date__c <= ' +
                    String.valueOf(filters.toDate)
                );
            }
        }

        if(filters.dueStatus == 'PAST_DUE'){

            conditions.add('Actual_Due_Date__c < TODAY');
        }

        else if(filters.dueStatus == 'DUE_SOON'){

            conditions.add('Actual_Due_Date__c >= TODAY');
        }

        // Project
        if(filters.projectId != null){

            conditions.add(
                'Project__c = \'' +
                String.escapeSingleQuotes(filters.projectId) +
                '\''
            );
        }

        // Property
        if(filters.propertyId != null){

            conditions.add(
                'Properties__c = \'' +
                String.escapeSingleQuotes(filters.propertyId) +
                '\''
            );
        }

        // Unit
        if(filters.unitId != null){

            conditions.add(
                'Units__c = \'' +
                String.escapeSingleQuotes(filters.unitId) +
                '\''
            );
        }

        // Customer
        if(filters.customerId != null){

            conditions.add(
                'Contact__c = \'' +
                String.escapeSingleQuotes(filters.customerId) +
                '\''
            );
        }

        // Milestone
        if(filters.milestoneId != null){

            conditions.add(
                'Milestone__c = \'' +
                String.escapeSingleQuotes(filters.milestoneId) +
                '\''
            );
        }

        // Invoice Status
        if(String.isNotBlank(filters.invoiceStatus)
            && filters.invoiceStatus != 'All'){

            conditions.add(
                'Status__c = \'' +
                String.escapeSingleQuotes(filters.invoiceStatus) +
                '\''
            );
        }

        // Min Amount
        if(filters.minAmount != null){

            conditions.add(
                'Amount__c >= ' +
                filters.minAmount
            );
        }

        // Max Amount
        if(filters.maxAmount != null){

            conditions.add(
                'Amount__c <= ' +
                filters.maxAmount
            );
        }

        if(conditions.isEmpty()){
            return '';
        }

        return ' AND ' + String.join(conditions,' AND ');
    }

    private static DashboardSummary getDashboardSummary(
        FilterRequest filters,
        Boolean skipped
    ) {
        try {
            DashboardSummary summary = new DashboardSummary();

            String whereClause = skipped
                ? 'Skip_Invoice__c = true AND Status__c IN (\'Not Invoiced\', \'Partially Invoiced\') AND Receivable_Item__r.Item__r.Enable_for_auto_Invoicing__c = true'
                : 'Skip_Invoice__c = false AND Status__c IN (\'Not Invoiced\', \'Partially Invoiced\') AND Receivable_Item__r.Item__r.Enable_for_auto_Invoicing__c = true AND Actual_Due_Date__c >= TODAY';

            whereClause += buildFilterQuery(filters);

            AggregateResult summaryResult = Database.query(
                'SELECT ' +
                'COUNT(Id) totalInvoices,' +
                'SUM(Amount__c) totalAmount ' +
                'FROM Payment_Plan_Item__c ' +
                'WHERE ' + whereClause
            );

            summary.totalInvoices = (Integer) summaryResult.get('totalInvoices');

            summary.totalAmount = (Decimal) summaryResult.get('totalAmount');
            if (summary.totalAmount == null) {
                summary.totalAmount = 0;
            }

            summary.dueToday = getRecordCount(
                whereClause + ' AND Actual_Due_Date__c = TODAY'
            );

            summary.pastDue = getRecordCount(
                whereClause + ' AND Actual_Due_Date__c < TODAY'
            );

            summary.dueSoon = getRecordCount(
                whereClause +
                ' AND Actual_Due_Date__c >= TODAY'
            );

            return summary;
        } catch (Exception e) {
            throw new AuraHandledException('getDashboardSummary: ' + e.getMessage());
        }
    }

    private static Integer getRecordCount(String whereClause) {

        AggregateResult result = Database.query(
            'SELECT COUNT(Id) recordCount ' +
            'FROM Payment_Plan_Item__c ' +
            'WHERE ' + whereClause
        );

        return (Integer) result.get('recordCount');
    }
}