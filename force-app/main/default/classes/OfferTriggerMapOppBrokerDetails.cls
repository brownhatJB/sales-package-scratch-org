/**
 * @module             : Real_Estate_Module
 * @description        : 
 * @namespace          : 
 * @author             : Jouhar C & Abhisheik SR
 * @last modified on   : 14-10-2026
 * @last modified by   : Jouhar C
**/

public with sharing class OfferTriggerMapOppBrokerDetails implements TriggerAction.AfterInsert {
    
    public void afterInsert(List<Offer__c> newOffers) {
        mapBrokerDetails(newOffers);
    }

    public void mapBrokerDetails(List<Offer__c> newOffers) {
        
        Set<Id> opportunityIds = new set<Id>();
        List<Offer__c> offersToUpdate = new List<Offer__c>();

        for(Offer__c offer : newOffers) {
            if(offer.Opportunity__c != null) {
                opportunityIds.add(offer.Opportunity__c);
            }
        }

        if(opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([ SELECT Id, Broker_Account__c, Broker_Contact__c FROM Opportunity WHERE Id IN :opportunityIds ]);

        for(Offer__c offer : newOffers) {

            if(offer.Opportunity__c != null && oppMap.containsKey(offer.Opportunity__c)) {

                Opportunity opp = oppMap.get(offer.Opportunity__c);
                Offer__c updateOffer = new Offer__c();
                updateOffer.Id = offer.Id;
                updateOffer.Broker_Account__c = opp.Broker_Account__c;
                updateOffer.Broker_Contact__c = opp.Broker_Contact__c;
                updateOffer.Sale_through__c = opp.Broker_Account__c != null ? 'Agent' : offer.Sale_Through__c;
                offersToUpdate.add(updateOffer);
            }
        }

        if(!offersToUpdate.isEmpty()) {
            try {
                update offersToUpdate;
            } catch(Exception e) {
                throw new AuraHandledException('Error while Mapping Broker details to Offer from Opportunity: ' + e.getMessage());
            }
        }
    }
}