global with sharing class InvoiceCreationScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        List<Payment_Plan_Item__c>  paymentPlanItems = [
            SELECT
                Id,
                Actual_Due_Date__c,
                Contact__c,
                Customer_Account__c,
                Amount__c,
                Milestone__c,
                Milestone__r.name,
                Auto_Invoice_Date__c,
                Project__c,
                Properties__c,
                Tax_Amount__c,
                Total_Amount_Excluding_Tax__c,
                Unit_Sale__c,
                Units__c,
                Status__c,
                Invoiced_Amount__c
            FROM Payment_Plan_Item__c
            WHERE
                Units__r.Properties__c != NULL
                AND Units__r.Properties__r.Enabled_For_Auto_Invoicing__c = TRUE
                AND Status__c IN ('Not Invoiced', 'Partially Received')
                AND Actual_Due_Date__c = TODAY
                AND Skip_Invoice__c = FALSE
                AND Receivable_Item__r.Item__r.Enable_for_auto_Invoicing__c = true
            WITH USER_MODE
        ];

        if(!paymentPlanItems.isEmpty()) {
            AutoInvoiceService.generateInvoices(paymentPlanItems);
        }
    }
}