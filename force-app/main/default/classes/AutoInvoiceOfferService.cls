
public with sharing class AutoInvoiceOfferService {

    public static void generateInvoices(
        List<Offer_Payment_Plan_Item__c> paymentPlanItems
    ) {
        if (paymentPlanItems == null || paymentPlanItems.isEmpty()) {
            return;
        }

        try {
            Batch_Invoices__c batchInvoice =
                createBatchInvoice(paymentPlanItems);

            List<Invoice__c> invoicesToCreate =
                createInvoices(paymentPlanItems, batchInvoice.Id);

            if (invoicesToCreate.isEmpty()) {
                return;
            }

            insert invoicesToCreate;

            updatePaymentPlanItems(
                invoicesToCreate,
                batchInvoice.Id
            );

            createStatementOfAccounts(invoicesToCreate);

        } catch (Exception e) {
            System.debug(
                'Error generating offer invoices: ' + e.getMessage()
            );

            throw new AuraHandledException(
                'Error generating offer invoices: ' + e.getMessage()
            );
        }
    }

    public static Batch_Invoices__c createBatchInvoice(
        List<Offer_Payment_Plan_Item__c> paymentPlanItems
    ) {
        Batch_Invoices__c batchInvoice = new Batch_Invoices__c(
            Name = 'ABI-' + Date.today().format(),
            Invoice_Generation_Date__c = Date.today()
        );

        insert batchInvoice;

        return batchInvoice;
    }

    public static List<Invoice__c> createInvoices(
        List<Offer_Payment_Plan_Item__c> paymentPlanItems,
        Id batchInvoiceId
    ) {
        List<Invoice__c> invoices = new List<Invoice__c>();

        for (Offer_Payment_Plan_Item__c item : paymentPlanItems) {

            Decimal invoiceAmount = item.Amount__c;

            if (
                item.Status__c == 'Partially Invoiced' &&
                item.Invoiced_Amount__c != null
            ) {
                invoiceAmount =
                    item.Amount__c - item.Invoiced_Amount__c;
            }

            invoices.add(new Invoice__c(
                Account__c = item.Offer__r.Account__c,
                Actual_Due_Date__c = item.Tentative_Due_Date__c,
                Contact__c = item.Offer__r.Contact__c,
                Invoice_Amount__c = invoiceAmount,
                Invoice_Date__c = Date.today(),
                Milestone__c = item.Milestone__c,

                // Requires a lookup to Offer_Payment_Plan_Item__c
                Offer_Payment_Plan_Item__c = item.Id,

                Project__c = item.Offer__r.Project__c,
                Properties__c = item.Offer__r.Properties__c,
                Status__c = 'Active',
                Tax_Value__c = item.Tax_Amount__c,
                Total_Amount_Excluding_Tax__c =
                    item.Amount_Excl_Tax__c,
               
                Units__c = item.Offer__r.Unit__c,
                Batch_Invoice__c = batchInvoiceId
            ));
        }

        return invoices;
    }

    public static void updatePaymentPlanItems(
        List<Invoice__c> invoices,
        Id batchInvoiceId
    ) {
        Set<Id> offerPaymentPlanItemIds = new Set<Id>();

        for (Invoice__c invoice : invoices) {
            if (invoice.Offer_Payment_Plan_Item__c != null) {
                offerPaymentPlanItemIds.add(
                    invoice.Offer_Payment_Plan_Item__c
                );
            }
        }

        if (offerPaymentPlanItemIds.isEmpty()) {
            return;
        }

        Map<Id, Offer_Payment_Plan_Item__c> paymentPlanItems =
            new Map<Id, Offer_Payment_Plan_Item__c>([
                SELECT Id, Invoiced_Amount__c, Amount__c
                FROM Offer_Payment_Plan_Item__c
                WHERE Id IN :offerPaymentPlanItemIds
            ]);

        List<Offer_Payment_Plan_Item__c> updates =
            new List<Offer_Payment_Plan_Item__c>();

        for (Invoice__c invoice : invoices) {
            Id itemId = invoice.Offer_Payment_Plan_Item__c;

            if (itemId == null || !paymentPlanItems.containsKey(itemId)) {
                continue;
            }

            Offer_Payment_Plan_Item__c item =
                paymentPlanItems.get(itemId);

            updates.add(new Offer_Payment_Plan_Item__c(
                Id = itemId,
                Status__c = 'Invoiced',
                Invoice_Date__c = Date.today(),
                Auto_Invoiced_Date__c = Date.today(),
                Batch_Invoices__c = batchInvoiceId,
                Invoiced_Amount__c =
                    (item.Invoiced_Amount__c == null
                        ? 0
                        : item.Invoiced_Amount__c)
                    + invoice.Invoice_Amount__c
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void createStatementOfAccounts(
        List<Invoice__c> invoices
    ) {
        List<Statement_of_account__c> statements =
            new List<Statement_of_account__c>();

        for (Invoice__c invoice : invoices) {
            Statement_of_account__c soa =
                new Statement_of_account__c();

            if (invoice.Account__c != null) {
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

        if (!statements.isEmpty()) {
            insert statements;
        }
    }
}
