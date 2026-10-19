/**
 * @module            : Real_Estate_Module
 * @description       : 
 * @namespace         :
 * @author            : Jouhar C
 * @group             : 
 * @last modified on  : 19-Oct-2026
 * @last modified by  : Jouhar C
 **/

public with sharing class InvoiceAmountRollupHelper implements TriggerAction.AfterInsert {
    
    public void afterInsert(List<Invoice__c> newInvoices) {
        updateUnitsaleInvoiceAmount(newInvoices);
    }

    private void updateUnitsaleInvoiceAmount(List<Invoice__c> invoices) {
        if(invoices.isEmpty()) {
            return;
        }

        Set<Id> unitSaleIds = new Set<Id>();
        Set<Id> offerIds = new Set<Id>();

        for(Invoice__c inv : invoices) {
            if(inv.Unit_Sale__c != null) {
                unitSaleIds.add(inv.Unit_Sale__c);
            } else if(inv.Offer__c != null) {
                offerIds.add(inv.Offer__c);
            }
        }

        List<Unit_Sale__c> unitSalesToUpdate = [ SELECT Id, Total_Invoice_Amount__c FROM Unit_Sale__c WHERE Id IN :unitSaleIds ];
        List<Offer__c> offersToUpdate = [ SELECT Id, Total_Invoice_Amount__c FROM Offer__c WHERE Id IN :offerIds ];

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

        for(Offer__c offer : offersToUpdate) {
            Decimal totalInvoiceAmount = offer.Total_Invoice_Amount__c != null ? offer.Total_Invoice_Amount__c : 0;

            for(Invoice__c inv : invoices) {
                if(inv.Offer__c == offer.Id) {
                    totalInvoiceAmount += inv.Invoice_Amount__c;
                }
            }

            offer.Total_Invoice_Amount__c = totalInvoiceAmount;
        }

        if(!offersToUpdate.isEmpty()) {
            update offersToUpdate;
        }
    }
}