public with sharing class GenerateDuePaymentPlanInvoicesHelper implements TriggerAction.AfterInsert {
    
    public void afterInsert(List<Unit_Sale__c> newUnitSales) {
        Feature_Control__c setting = Feature_Control__c.getOrgDefaults();

        if(setting != null && !setting.GenerateDueUnitSaleInvoices__c) {
            return;
        }

        generateDueUnitSaleInvoices(newUnitSales);
    }

    public void generateDueUnitSaleInvoices(List<Unit_Sale__c> uslList) {
        
        if(uslList.isEmpty()) {
            return;
        }

        try {
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
                    Unit_Sale__c IN :uslList
                    AND Status__c IN ('Not Invoiced', 'Partially Received')
                    AND Actual_Due_Date__c <= TODAY
                WITH USER_MODE
            ];

            if(!paymentPlanItems.isEmpty()) {
                AutoInvoiceService.generateInvoices(paymentPlanItems);
            }
        } catch(Exception e) {
            throw new AuraHandledException('Error while creating invoices for paymentPlanItems: ' + e.getMessage());
        }
    }
}