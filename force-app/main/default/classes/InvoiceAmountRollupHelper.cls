public with sharing class InvoiceAmountRollupHelper implements TriggerAction.AfterInsert {
    
    public void afterInsert(List<Invoice__c> newInvoices) {
        updateUnitsaleInvoiceAmount(newInvoices);
    }

    private void updateUnitsaleInvoiceAmount(List<Invoice__c> invoices) {
        if(invoices.isEmpty()) {
            return;
        }

        Set<Id> unitSaleIds = new Set<Id>();

        for(Invoice__c inv : invoices) {
            if(inv.Unit_Sale__c != null) {
                unitSaleIds.add(inv.Unit_Sale__c);
            }
        }

        List<Unit_Sale__c> unitSalesToUpdate = [SELECT Id, Total_Invoice_Amount__c FROM Unit_Sale__c WHERE Id IN :unitSaleIds];

        for(Unit_Sale__c unitSale : unitSalesToUpdate) {
            Decimal totalInvoiceAmount = unitSale.Total_Invoice_Amount__c != null ? unitSale.Total_Invoice_Amount__c : 0;

            for(Invoice__c inv : invoices) {
                if(inv.Unit_Sale__c == unitSale.Id) {
                    totalInvoiceAmount += inv.Invoice_Amount__c;
                }
            }

            unitSale.Total_Invoice_Amount__c = totalInvoiceAmount;
        }

        if(!unitSalesToUpdate.isEmpty()) {
            update unitSalesToUpdate;
        }
    }
}