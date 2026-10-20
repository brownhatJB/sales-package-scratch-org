/**
 * @module            : Real_Estate_Module
 * @description       : 
 * @namespace         : 
 * @author            : Jouhar C
 * @email             : jouhar@metadatacorp.com
 * @last modified on  : 15-07-2026
 * @last modified by  : Jouhar C
**/

public with sharing class AutoInvoiceService {

    public static void generateInvoices(List<Payment_Plan_Item__c> paymentPlanItems) {

        if(paymentPlanItems == null || paymentPlanItems.isEmpty()) {
            return;
        }

        try {
            Batch_Invoices__c batchInvoice = createBatchInvoice(paymentPlanItems);

            List<Invoice__c> invoicesToCreate = createInvoices(paymentPlanItems, batchInvoice.Id);
            System.debug('=========Inside generateInvoices=========');

            if(invoicesToCreate.isEmpty()) {
                return;
            }

            insert invoicesToCreate;

            updatePaymentPlanItems(invoicesToCreate, batchInvoice.Id);

            createStatementOfAccounts(invoicesToCreate);
        } catch(Exception e) {
            System.debug('Error generating invoices: ' + e.getMessage());
            throw new AuraHandledException('Error generating invoices: ' + e.getMessage());
        }
    }

    public static Batch_Invoices__c createBatchInvoice(List<Payment_Plan_Item__c> paymentPlanItems) {

        Payment_Plan_Item__c firstItem = paymentPlanItems[0];

        Batch_Invoices__c batchInvoice = new Batch_Invoices__c(
            Name = 'ABI-' + Date.today().format(),
            Invoice_Generation_Date__c = System.today()
        );

        try {
            insert batchInvoice;
        } catch(Exception e) {
            throw new AuraHandledException('we could not create BatchInvoice' + e.getMessage());
        }
        

        return batchInvoice;
    }
   
    public static List<Invoice__c> createInvoices(
        List<Payment_Plan_Item__c> paymentPlanItems,
        Id batchInvoiceId
    ) {

    List<Invoice__c> invoices = new List<Invoice__c>();

        for(Payment_Plan_Item__c item : paymentPlanItems) {

            if(item.Status__c == 'Partially Invoiced' && item.Invoiced_Amount__c != null) {
                invoices.add(new Invoice__c(
                    Account__c = item.Customer_Account__c,
                    Actual_Due_Date__c = item.Actual_Due_Date__c,
                    Contact__c = item.Contact__c,
                    Invoice_Amount__c = item.Amount__c - item.Invoiced_Amount__c,
                    Invoice_Date__c = System.today(),
                    Milestone__c = item.Milestone__c,
                    Payment_Plan_Item__c = item.Id,
                    Project__c = item.Project__c,
                    Properties__c = item.Properties__c,
                    Status__c = 'Active',
                    Tax_Value__c = item.Tax_Amount__c,
                    Total_Amount_Excluding_Tax__c = item.Total_Amount_Excluding_Tax__c,
                    Unit_Sale__c = item.Unit_Sale__c,
                    Units__c = item.Units__c,
                    Batch_Invoice__c = batchInvoiceId
                ));
                continue;
            }

            invoices.add(new Invoice__c(
                Account__c = item.Customer_Account__c,
                Actual_Due_Date__c = item.Actual_Due_Date__c,
                Contact__c = item.Contact__c,
                Invoice_Amount__c = item.Amount__c,
                Invoice_Date__c = System.today(),
                Milestone__c = item.Milestone__c,
                Payment_Plan_Item__c = item.Id,
                Project__c = item.Project__c,
                Properties__c = item.Properties__c,
                Status__c = 'Active',
                Tax_Value__c = item.Tax_Amount__c,
                Total_Amount_Excluding_Tax__c = item.Total_Amount_Excluding_Tax__c,
                Unit_Sale__c = item.Unit_Sale__c,
                Units__c = item.Units__c,
                Batch_Invoice__c = batchInvoiceId
            ));
        }

        return invoices;
    }

    public static void updatePaymentPlanItems(
        List<Invoice__c> invoices,
        Id batchInvoiceId
    ) {
        Set<Id> PpiIds = new Set<Id>();

        for(Invoice__c inv :  invoices) {
            PpiIds.add(inv.Payment_Plan_Item__c);
        }

        Map<Id, Payment_Plan_Item__c> paymentPlanItems = new Map<Id, Payment_Plan_Item__c>(
            [
                SELECT 
                    Id, Invoiced_Amount__c, Amount__c FROM Payment_Plan_Item__c
                WHERE Id IN : PpiIds
            ]
        );


        List<Payment_Plan_Item__c> updates = new List<Payment_Plan_Item__c>();


        for(Invoice__c invoice : invoices) {

            Payment_Plan_Item__c item = paymentPlanItems.get(invoice.Payment_Plan_Item__c);

            updates.add(new Payment_Plan_Item__c(
                Id = invoice.Payment_Plan_Item__c,
                Status__c = 'Invoiced',
                Invoice_Date__c = System.today(),
                Auto_Invoiced_Date__c = System.today(),
                Batch_Invoices__c = batchInvoiceId,
                Invoiced_Amount__c = (item.Invoiced_Amount__c == null ? 0 : item.Invoiced_Amount__c) + invoice.Invoice_Amount__c
            ));
        }

        if(!updates.isEmpty()) {
            update updates;
        }
    }

    public static void createStatementOfAccounts(List<Invoice__c> invoices) {

        List<Statement_of_account__c> statements = new List<Statement_of_account__c>();

        for(Invoice__c invoice : invoices) {

            Statement_of_account__c soa = new Statement_of_account__c();

            if(invoice.Account__c != null) {
                soa.Account__c = invoice.Account__c;
            }

            soa.Amount__c = invoice.Invoice_Amount__c;
            soa.Customer_Contact__c = invoice.Contact__c;
            soa.Mode__c = 'Debit';
            soa.Invoice__c = invoice.Id;
            soa.Unit__c = invoice.Units__c;
            soa.Unit_sale__c = invoice.Unit_Sale__c;

            statements.add(soa);
        }

        if(!statements.isEmpty()) {
            insert statements;
        }
    }
}