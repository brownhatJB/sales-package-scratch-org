public with sharing class GenerateDueOfferPaymentPlanInvoices implements TriggerAction.AfterUpdate {
    
    public void afterUpdate(List<Offer__c> newOffers, List<Offer__c> oldOffers) {
        Feature_Control__c setting = Feature_Control__c.getOrgDefaults();

        if(setting != null && !setting.GenerateDueOfferPaymentPlanInvoices__c) {
            return;
        }

        handleInvoiceGeneration(newOffers, oldOffers);
    }

    public void handleInvoiceGeneration(List<Offer__c> newOffers, List<Offer__c> oldOffers) {

        Map<Id, Offer__c> newOffersMap = new Map<Id, Offer__c>(newOffers);
        Map<Id, Offer__c> oldOffersMap = new Map<Id, Offer__c>(oldOffers);
        
        Set<Id> offerIds = new Set<Id>();
        for(Offer__c offer : newOffers) {
           Offer__c oldOffer = oldOffersMap.get(offer.Id);

           if(offer.Generate_Payment_Plan_Flag__c != oldOffer.Generate_Payment_Plan_Flag__c && offer.Generate_Payment_Plan_Flag__c == true) {
               offerIds.add(offer.Id);
           }
        }

        try {
            List<Offer_Payment_Plan_Item__c>  paymentPlanItems = [
                SELECT
                    Id,
                    Tentative_Due_Date__c,
                    Offer__r.Contact__c,
                    Offer__r.Account__c,
                    Amount__c,
                    Milestone__c,
                    Milestone__r.name,
                    Auto_Invoiced_Date__c,
                    Offer__r.Project__c,
                    Offer__r.Properties__c,
                    Tax_Amount__c,
                    Amount_Excl_Tax__c,
                    Offer__r.Unit__c,
                    Status__c,
                    Invoiced_Amount__c
                FROM Offer_Payment_Plan_Item__c
                WHERE
                    Offer__c IN :offerIds
                    AND Status__c IN ('Active', 'Not Invoiced', 'Partially Invoiced')
                    AND Tentative_Due_Date__c <= TODAY
                WITH USER_MODE
            ];

            if(!paymentPlanItems.isEmpty()) {
                System.debug('===============Generating Invoices for OPPI(s)====================');
                AutoInvoiceOfferService.generateInvoices(paymentPlanItems);
            }
        } catch(Exception e) {
            throw new AuraHandledException('Error while creating invoices for OfferPaymentPlanItems: ' + e.getMessage());
        }
    }
}